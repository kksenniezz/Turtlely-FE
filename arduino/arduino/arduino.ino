#include <ArduinoBLE.h>
#include "LSM6DS3.h"
#include "Wire.h"
#include <Adafruit_DRV2605.h>

// ── BLE 서비스 & 특성
BLEService bleService("12345678-1234-1234-1234-123456789012");
BLEStringCharacteristic cvaCharacteristic("87654321-4321-4321-4321-210987654321", BLERead | BLENotify, 100);
BLEStringCharacteristic cmdCharacteristic("11111111-1111-1111-1111-111111111111", BLEWrite, 20);
BLEUnsignedCharCharacteristic battCharacteristic("2A19", BLERead | BLENotify); // ✅ 배터리

// ── IMU
LSM6DS3 myIMU(I2C_MODE, 0x6A);

// ── 햅틱 드라이버
Adafruit_DRV2605 drv;

// ── 상태 변수
bool isCalibrating  = false;
bool isMonitoring   = false;
bool isMonthlyMode  = false;

float calib_x_sum = 0, calib_y_sum = 0, calib_z_sum = 0;
int   calib_count = 0;
const unsigned long CALIB_DURATION_MS   = 3000;
const unsigned long MONTHLY_INTERVAL_MS = 150;
unsigned long calib_start_ms    = 0;
unsigned long last_send_time_ms = 0;
unsigned long last_batt_time_ms = 0;

// ── 배터리 잔량 읽기
int getBatteryPercent() {
  float raw     = analogRead(PIN_VBAT);
  float voltage = raw * 3.3f / 1024.0f * 2.0f;
  int   percent = (int)((voltage - 3.3f) / (4.2f - 3.3f) * 100.0f);
  return constrain(percent, 0, 100);
}

// ── 햅틱 진동
void vibrate(uint8_t effect = 47) {
  drv.setWaveform(0, effect);
  drv.setWaveform(1, 0);
  drv.go();
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  if (myIMU.begin() != 0) {
    Serial.println("IMU 초기화 실패");
  } else {
    Serial.println("IMU 초기화 성공");
  }

  if (!drv.begin()) {
    Serial.println("DRV2605 초기화 실패");
  } else {
    drv.selectLibrary(1);
    drv.setMode(DRV2605_MODE_INTTRIG);
    Serial.println("DRV2605 초기화 성공");
  }

  if (!BLE.begin()) {
    Serial.println("BLE 초기화 실패");
    while (1);
  }

  BLE.setLocalName("Turtlely_XIAO");
  BLE.setAdvertisedService(bleService);
  bleService.addCharacteristic(cvaCharacteristic);
  bleService.addCharacteristic(cmdCharacteristic);
  bleService.addCharacteristic(battCharacteristic); // ✅ 배터리
  BLE.addService(bleService);
  BLE.advertise();

  Serial.println("BLE 광고 시작");
  battCharacteristic.writeValue((uint8_t)getBatteryPercent());
}

void loop() {
  BLEDevice central = BLE.central();

  if (central) {
    Serial.println("연결됨: " + central.address());

    while (central.connected()) {

      if (cmdCharacteristic.written()) {
        String cmd = cmdCharacteristic.value();
        cmd.trim();
        Serial.println("📥 명령 수신: " + cmd);

        if (cmd == "CALIB_START") {
          isCalibrating  = true;
          isMonitoring   = false;
          isMonthlyMode  = false;
          calib_x_sum    = 0;
          calib_y_sum    = 0;
          calib_z_sum    = 0;
          calib_count    = 0;
          calib_start_ms = millis();
          Serial.println("캘리브레이션 시작");

        } else if (cmd == "STOP") {
          isCalibrating = false;
          isMonitoring  = false;
          isMonthlyMode = false;
          Serial.println("측정 중지");

        } else if (cmd == "VIBRATE") {
          vibrate();
          Serial.println("진동!");

        } else if (cmd == "MONTHLY_START") {
          isMonthlyMode     = true;
          isMonitoring      = false;
          isCalibrating     = false;
          last_send_time_ms = millis();
          Serial.println("월간 측정 시작");

        } else if (cmd == "MONTHLY_STOP") {
          isMonthlyMode = false;
          Serial.println("월간 측정 중지");
        }
      }

      unsigned long now = millis();

      // 캘리브레이션
      if (isCalibrating) {
        float ax = myIMU.readFloatAccelX();
        float ay = myIMU.readFloatAccelY();
        float az = myIMU.readFloatAccelZ();

        calib_x_sum += ax;
        calib_y_sum += ay;
        calib_z_sum += az;
        calib_count++;

        if (now - calib_start_ms >= CALIB_DURATION_MS) {
          float avgX = calib_x_sum / calib_count;
          float avgY = calib_y_sum / calib_count;
          float avgZ = calib_z_sum / calib_count;

          String msg = "CALIB_DONE:" + String(avgX, 3) + "," + String(avgY, 3) + "," + String(avgZ, 3);
          cvaCharacteristic.writeValue(msg.c_str());
          Serial.println("캘리브레이션 완료: " + msg);

          isCalibrating     = false;
          isMonitoring      = true;
          last_send_time_ms = now;
        }
        delay(10);
      }

      // 일일 측정 (1초 주기)
      if (isMonitoring && !isMonthlyMode) {
        if (now - last_send_time_ms >= 1000) {
          last_send_time_ms = now;
          float ax = myIMU.readFloatAccelX();
          float ay = myIMU.readFloatAccelY();
          float az = myIMU.readFloatAccelZ();
          String data = String(ax, 4) + "," + String(ay, 4) + "," + String(az, 4);
          cvaCharacteristic.writeValue(data.c_str());
          Serial.println("📤 일일 전송: " + data);
        }
      }

      // 월간 측정 (150ms 주기)
      if (isMonthlyMode) {
        if (now - last_send_time_ms >= MONTHLY_INTERVAL_MS) {
          last_send_time_ms = now;
          float ax = myIMU.readFloatAccelX();
          float ay = myIMU.readFloatAccelY();
          float az = myIMU.readFloatAccelZ();
          String data = String(ax, 4) + "," + String(ay, 4) + "," + String(az, 4);
          cvaCharacteristic.writeValue(data.c_str());
        }
      }

      // ✅ 배터리 10초마다 전송
      if (now - last_batt_time_ms >= 10000) {
        last_batt_time_ms = now;
        int batt = getBatteryPercent();
        battCharacteristic.writeValue((uint8_t)batt);
        Serial.println("🔋 배터리: " + String(batt) + "%");
      }
    }

    Serial.println("연결 끊김");
    isCalibrating = false;
    isMonitoring  = false;
    isMonthlyMode = false;
  }
}