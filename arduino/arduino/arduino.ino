#include <Arduino.h>
#include <Adafruit_TinyUSB.h>
#include <LSM6DS3.h>
#include <Wire.h>
#include <bluefruit.h>
#include <Adafruit_DRV2605.h>

LSM6DS3 myIMU(I2C_MODE, 0x6A);
Adafruit_DRV2605 drv;

bool pose_calibrated = false;
bool calib_running   = false;
bool is_stopped      = false;
bool is_monthly      = false; // 추가!

float calib_x_sum = 0.0;
float calib_y_sum = 0.0;
float calib_z_sum = 0.0;
int   calib_count = 0;

uint32_t calib_start_ms    = 0;
uint32_t last_send_time_ms = 0;

#define CALIB_DURATION_MS 3000
#define MONTHLY_INTERVAL_MS 150 // 추가!

#define SERVICE_UUID        "19B10000-E8F2-537E-4F6C-D104768A1214"
#define CHARACTERISTIC_UUID "19B10001-E8F2-537E-4F6C-D104768A1214"

BLEService        turtlelyService   = BLEService(SERVICE_UUID);
BLECharacteristic cvaCharacteristic = BLECharacteristic(CHARACTERISTIC_UUID);

void receive_ble_callback(uint16_t conn_handle, BLECharacteristic* chr, uint8_t* data, uint16_t len);
void connect_callback(uint16_t conn_handle);
void disconnect_callback(uint16_t conn_handle, uint8_t reason);

void vibrate(uint8_t effect) {
  drv.setWaveform(0, effect);
  drv.setWaveform(1, 0);
  drv.go();
}

void setup() {
  Serial.begin(115200);
  uint32_t timeout = millis();
  while (!Serial && (millis() - timeout < 3000)) { delay(10); }

  Serial.println("================================");
  Serial.println("Turtlely Boot Start");
  Serial.println("================================");

  if (myIMU.begin() != 0) {
    Serial.println("IMU 연결 실패");
  } else {
    Serial.println("IMU 연결 성공");
  }

  if (!drv.begin()) {
    Serial.println("DRV2605 연결 실패!");
  } else {
    Serial.println("DRV2605 연결 성공!");
    drv.selectLibrary(1);
    drv.setMode(DRV2605_MODE_INTTRIG);
    vibrate(1);
    delay(500);
    Serial.println("진동 테스트 완료!");
  }

  Bluefruit.configPrphBandwidth(BANDWIDTH_MAX);
  Bluefruit.begin();
  Bluefruit.setName("Turtlely_XIAO");
  Bluefruit.Periph.setConnectCallback(connect_callback);
  Bluefruit.Periph.setDisconnectCallback(disconnect_callback);

  turtlelyService.begin();

  cvaCharacteristic.setProperties(CHR_PROPS_READ | CHR_PROPS_NOTIFY | CHR_PROPS_WRITE);
  cvaCharacteristic.setPermission(SECMODE_OPEN, SECMODE_OPEN);
  cvaCharacteristic.setMaxLen(50);
  cvaCharacteristic.setWriteCallback(receive_ble_callback);
  cvaCharacteristic.begin();

  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addTxPower();
  Bluefruit.Advertising.addName();
  Bluefruit.ScanResponse.addName();
  Bluefruit.ScanResponse.addService(turtlelyService);
  Bluefruit.Advertising.restartOnDisconnect(true);
  Bluefruit.Advertising.setInterval(32, 32);
  Bluefruit.Advertising.start(0);

  Serial.println("BLE 광고 시작");
}

void loop() {
  if (is_stopped) {
    delay(100);
    return;
  }

  float accX = myIMU.readFloatAccelX();
  float accY = myIMU.readFloatAccelY();
  float accZ = myIMU.readFloatAccelZ();

  if (calib_running) {
    calib_x_sum += accX;
    calib_y_sum += accY;
    calib_z_sum += accZ;
    calib_count++;

    if (millis() - calib_start_ms >= CALIB_DURATION_MS) {
      float avgX = calib_x_sum / calib_count;
      float avgY = calib_y_sum / calib_count;
      float avgZ = calib_z_sum / calib_count;

      pose_calibrated = true;
      calib_running   = false;

      Serial.println("================================");
      Serial.println("캘리브레이션 완료");
      Serial.print("Avg X: "); Serial.println(avgX, 3);
      Serial.print("Avg Y: "); Serial.println(avgY, 3);
      Serial.print("Avg Z: "); Serial.println(avgZ, 3);
      Serial.println("================================");

      if (Bluefruit.connected()) {
        String calibDoneMsg = "CALIB_DONE:" +
                              String(avgX, 3) + "," +
                              String(avgY, 3) + "," +
                              String(avgZ, 3);
        cvaCharacteristic.notify(calibDoneMsg.c_str());
        Serial.print("전송: ");
        Serial.println(calibDoneMsg);
      }

      last_send_time_ms = millis();
    }

    delay(10);
    return;
  }

  // 일일: 1초, 월간: 150ms 주기로 전송
  uint32_t interval = is_monthly ? MONTHLY_INTERVAL_MS : 1000;

  if (millis() - last_send_time_ms >= interval) {
    last_send_time_ms = millis();

    String sendData = String(accX, 3) + "," +
                      String(accY, 3) + "," +
                      String(accZ, 3);

    Serial.print(is_monthly ? "[150ms 전송] " : "[1초 전송] ");
    Serial.println(sendData);

    if (Bluefruit.connected()) {
      cvaCharacteristic.notify(sendData.c_str());
    }
  }

  delay(10);
}

void receive_ble_callback(uint16_t conn_handle, BLECharacteristic* chr, uint8_t* data, uint16_t len) {
  String rxData = "";
  for (uint16_t i = 0; i < len; i++) { rxData += (char)data[i]; }
  rxData.trim();

  Serial.print("BLE 수신: ");
  Serial.println(rxData);

  if (rxData == "CALIB_START") {
    is_stopped      = false;
    calib_x_sum     = 0.0;
    calib_y_sum     = 0.0;
    calib_z_sum     = 0.0;
    calib_count     = 0;
    calib_start_ms  = millis();
    calib_running   = true;
    pose_calibrated = false;
    is_monthly      = false;
    Serial.println("캘리브레이션 시작");
  }

  if (rxData == "MONTHLY_START") {
    is_stopped = false;
    is_monthly = true;
    Serial.println("월간 측정 시작 - 150ms 주기");
  }

  if (rxData == "STOP") {
    pose_calibrated = false;
    calib_running   = false;
    is_stopped      = true;
    is_monthly      = false; // 초기화!
    Serial.println("측정 종료");
  }

  if (rxData == "VIBRATE") {
    Serial.println("진동!");
    vibrate(47);
  }
}

void connect_callback(uint16_t conn_handle) {
  Serial.println("스마트폰 연결 성공");
}

void disconnect_callback(uint16_t conn_handle, uint8_t reason) {
  Serial.println("연결 해제");
  pose_calibrated = false;
  calib_running   = false;
  is_stopped      = false;
  is_monthly      = false; // 초기화!
}