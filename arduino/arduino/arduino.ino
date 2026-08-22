#include <ArduinoBLE.h>
#include "LSM6DS3.h"
#include "Wire.h"
#include <Adafruit_DRV2605.h>

// BLE 서비스 및 특성 정의
BLEService bleService("12345678-1234-1234-1234-123456789012");
BLEStringCharacteristic cvaCharacteristic("87654321-4321-4321-4321-210987654321", BLERead | BLENotify, 100);
BLEStringCharacteristic cmdCharacteristic("11111111-1111-1111-1111-111111111111", BLEWrite, 20);
BLEUnsignedCharCharacteristic battCharacteristic("2A19", BLERead | BLENotify);

// IMU 센서 객체
LSM6DS3 myIMU(I2C_MODE, 0x6A);

// 햅틱 모터 드라이버 객체
Adafruit_DRV2605 drv;

// 동작 상태 플래그
bool isCalibrating  = false;
bool isMonitoring   = false;
bool isMonthlyMode  = false;

float calib_x_sum = 0, calib_y_sum = 0, calib_z_sum = 0;
int   calib_count = 0;
const unsigned long CALIB_DURATION_MS   = 3000;
const unsigned long MONTHLY_INTERVAL_MS = 250;
unsigned long calib_start_ms    = 0;
unsigned long last_send_time_ms = 0;
unsigned long last_batt_time_ms = 0;

int smoothedBatteryPercent = -1;

// 배터리 잔량 측정 함수
int getBatteryPercent() {
  #ifdef PIN_VBAT_ENABLE
    pinMode(PIN_VBAT_ENABLE, OUTPUT);
    digitalWrite(PIN_VBAT_ENABLE, LOW);
    delay(5);
  #endif

  long rawSum = 0;
  for (int i = 0; i < 10; i++) {
    rawSum += analogRead(PIN_VBAT);
    delay(2);
  }
  float raw = rawSum / 10.0f;

  #ifdef PIN_VBAT_ENABLE
    digitalWrite(PIN_VBAT_ENABLE, HIGH);
  #endif

  float voltage = raw * (3.6f / 4096.0f) * (1510.0f / 510.0f);
  int rawPercent = (int)((voltage - 3.3f) / (4.2f - 3.3f) * 100.0f);
  rawPercent = constrain(rawPercent, 0, 100);

  if (smoothedBatteryPercent < 0) {
    smoothedBatteryPercent = rawPercent;
  } else {
    smoothedBatteryPercent = (int)(smoothedBatteryPercent * 0.7f + rawPercent * 0.3f);
  }

  return smoothedBatteryPercent;
}

// ── 초미세 햅틱 탭 함수 (스마트폰 미세 진동 수준)
void vibrate() {
  drv.setMode(DRV2605_MODE_REALTIME);
  drv.setRealtimeValue(25); // ✅ 0~127 중 최저 강도 수준 (약 20% 세기)
  delay(35);                 // ✅ 35ms만 살짝 '톡' 치고 바로 정지
  drv.setRealtimeValue(0);
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  #if defined(TARGET_SEEED_XIAO_NRF52840_SENSE) || defined(ARDUINO_SEEED_XIAO_NRF52840) || defined(ARDUINO_SEEED_XIAO_NRF52840_SENSE)
    analogReadResolution(12);
  #endif

  // IMU 초기화
  if (myIMU.begin() != 0) {
    Serial.println("IMU 초기화 실패");
  } else {
    Serial.println("IMU 초기화 성공");
  }

  // LRA 햅틱 드라이버 초기화
  if (!drv.begin()) {
    Serial.println("DRV2605 초기화 실패");
  } else {
    drv.selectLibrary(6);
    drv.useLRA();
    drv.setMode(DRV2605_MODE_REALTIME); // 실시간 초미세 제어 모드

    // 전압 및 게인 완전 최소화
    drv.writeRegister8(0x16, 0x20); // Rated Voltage 최저
    drv.writeRegister8(0x17, 0x30); // Overdrive Clamp 최저
    drv.writeRegister8(0x1D, 0x00); // Feedback Gain 최저

    Serial.println("DRV2605 초미세 햅틱 세팅 완료");
  }

  // BLE 초기화
  if (!BLE.begin()) {
    Serial.println("BLE 초기화 실패");
    while (1);
  }

  BLE.setLocalName("Turtlely_XIAO");
  BLE.setAdvertisedService(bleService);
  bleService.addCharacteristic(cvaCharacteristic);
  bleService.addCharacteristic(cmdCharacteristic);
  bleService.addCharacteristic(battCharacteristic);
  BLE.addService(bleService);
  BLE.advertise();

  Serial.println("BLE 광고 시작");
  battCharacteristic.writeValue((uint8_t)getBatteryPercent());
}

void loop() {
  BLEDevice central = BLE.central();

  if (central) {
    Serial.println("연결됨: " + central.address());
    battCharacteristic.writeValue((uint8_t)getBatteryPercent());
    last_batt_time_ms = millis();

    while (central.connected()) {
      BLE.poll();

      if (cmdCharacteristic.written()) {
        String cmd = cmdCharacteristic.value();
        cmd.trim();
        Serial.println("명령 수신: " + cmd);

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
          Serial.println("초미세 진동 실행");

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

      // 1. 캘리브레이션
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

      // 2. 일일 측정 (1,000ms 주기)
      if (isMonitoring && !isMonthlyMode) {
        if (now - last_send_time_ms >= 1000) {
          last_send_time_ms = now;
          float ax = myIMU.readFloatAccelX();
          float ay = myIMU.readFloatAccelY();
          float az = myIMU.readFloatAccelZ();
          String data = String(ax, 4) + "," + String(ay, 4) + "," + String(az, 4);
          cvaCharacteristic.writeValue(data.c_str());
          Serial.println("일일 전송: " + data);
        }
      }

      // 3. 월간 측정 (250ms 주기)
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

      // 4. 배터리 잔량 전송 (10초 주기)
      if (now - last_batt_time_ms >= 10000) {
        last_batt_time_ms = now;
        int batt = getBatteryPercent();
        battCharacteristic.writeValue((uint8_t)batt);
        Serial.print("배터리 잔량: ");
        Serial.print(batt);
        Serial.println("%");
      }
    }

    Serial.println("연결 끊김");
    isCalibrating = false;
    isMonitoring  = false;
    isMonthlyMode = false;
  }
}