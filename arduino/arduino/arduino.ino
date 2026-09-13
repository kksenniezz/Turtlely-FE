#include <ArduinoBLE.h>
#include "LSM6DS3.h"
#include <Wire.h>
#include <Adafruit_DRV2605.h>
#include "nrf_gpio.h"

// ── 핀 정의
#define HAPTIC_EN    D1                       // DRV2605 EN 핀 제어
#define SWITCH_PIN   D6                       // P0.04: 전원 스위치 감지 핀
#define VBAT_ENABLE  NRF_GPIO_PIN_MAP(0, 14)  // P0.14: 배터리 분압 회로 스위치

// ── 물리 배선에 맞춘 커스텀 I2C 통로 (SDA=D5, SCL=D4)
arduino::MbedI2C myWire(D5, D4);

// BLE 서비스 및 특성 정의
BLEService bleService("12345678-1234-1234-1234-123456789012");
BLEStringCharacteristic cvaCharacteristic("87654321-4321-4321-4321-210987654321", BLERead | BLENotify, 100);
BLEStringCharacteristic cmdCharacteristic("11111111-1111-1111-1111-111111111111", BLEWrite, 20);
BLEUnsignedCharCharacteristic battCharacteristic("2A19", BLERead | BLENotify);

// 센서 및 모터 드라이버 객체
LSM6DS3 myIMU(I2C_MODE, 0x6A);
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

// ── 배터리 잔량 측정 함수 (이동평균 필터)
int getBatteryPercent() {
  nrf_gpio_cfg_output(VBAT_ENABLE);
  nrf_gpio_pin_clear(VBAT_ENABLE);
  delay(15);

  long rawSum = 0;
  for (int i = 0; i < 20; i++) {
    rawSum += analogRead(PIN_VBAT);
    delay(2);
  }
  float raw = rawSum / 20.0f;

  nrf_gpio_pin_set(VBAT_ENABLE);

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

// ── 검증된 LRA 내장 파형 햅틱 진동 함수
void vibrate() {
  drv.writeRegister8(0x01, 0x00);      // Standby 모드 해제
  drv.setMode(DRV2605_MODE_INTTRIG);   // 내장 파형 트리거 모드
  drv.setWaveform(0, 1);               // 1번 파형: Strong Click 100%
  drv.setWaveform(1, 0);               // 끝 표시
  drv.go();                            // 진동 실행
}

// ── 초저전력 슬립(System OFF) 모드 진입
void enterSystemOff() {
  Serial.println("스위치 OFF 감지: 초저전력 슬립(System OFF) 모드 진입");

  digitalWrite(LED_BLUE, HIGH);
  #if defined(LED_RED) && defined(LED_GREEN)
    digitalWrite(LED_RED, HIGH);
    digitalWrite(LED_GREEN, HIGH);
  #endif

  if (BLE.connected()) {
    BLE.disconnect();
  }
  BLE.stopAdvertise();
  BLE.end();

  drv.writeRegister8(0x01, 0x40); // 칩 Standby
  digitalWrite(HAPTIC_EN, LOW);   // EN LOW로 전원 차단

  uint32_t pin_num = NRF_GPIO_PIN_MAP(0, 4);
  nrf_gpio_cfg_input(pin_num, NRF_GPIO_PIN_PULLUP);
  nrf_gpio_cfg_sense_set(pin_num, NRF_GPIO_PIN_SENSE_LOW);

  delay(100);
  NRF_POWER->SYSTEMOFF = 1;
  while (1);
}

void setup() {
  Serial.begin(115200);

  // 1. DRV2605 EN 핀 활성화
  pinMode(HAPTIC_EN, OUTPUT);
  digitalWrite(HAPTIC_EN, HIGH);
  delay(50);

  // 2. 전원 스위치 체크
  pinMode(SWITCH_PIN, INPUT_PULLUP);
  delay(200);

  if (digitalRead(SWITCH_PIN) == HIGH) {
    delay(50);
    if (digitalRead(SWITCH_PIN) == HIGH) {
      enterSystemOff();
    }
  }

  pinMode(LED_BLUE, OUTPUT);
  digitalWrite(LED_BLUE, LOW);

  #if defined(TARGET_SEEED_XIAO_NRF52840_SENSE) || defined(ARDUINO_SEEED_XIAO_NRF52840) || defined(ARDUINO_SEEED_XIAO_NRF52840_SENSE)
    analogReadResolution(12);
  #endif

  // 3. 커스텀 I2C 통로 시작 (D5=SDA, D4=SCL)
  myWire.begin();

  // 4. IMU 센서 초기화
  if (myIMU.begin() != 0) {
    Serial.println("IMU 초기화 실패");
  } else {
    Serial.println("IMU 초기화 성공");
  }

  // 5. DRV2605 초기화 및 LRA 내장 파형 세팅
  if (!drv.begin(&myWire)) {
    Serial.println("DRV2605 초기화 실패");
  } else {
    drv.selectLibrary(6);              // LRA 전용 내장 라이브러리
    drv.useLRA();
    drv.setMode(DRV2605_MODE_INTTRIG); // 내장 파형 모드
    drv.setWaveform(0, 1);             // Strong Click 100%
    drv.setWaveform(1, 0);

    Serial.println("DRV2605 세팅 완료: 부팅 확인 진동 1회");
    vibrate(); // 부팅 즉시 1회 진동
  }

  // 6. BLE 초기화
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
  // 스위치 OFF 감지
  if (digitalRead(SWITCH_PIN) == HIGH) {
    delay(50);
    if (digitalRead(SWITCH_PIN) == HIGH) {
      enterSystemOff();
    }
  }

  BLEDevice central = BLE.central();

  if (central) {
    Serial.println("연결됨: " + central.address());
    battCharacteristic.writeValue((uint8_t)getBatteryPercent());
    last_batt_time_ms = millis();

    while (central.connected()) {
      // 통신 중 스위치 OFF 감지
      if (digitalRead(SWITCH_PIN) == HIGH) {
        delay(50);
        if (digitalRead(SWITCH_PIN) == HIGH) {
          enterSystemOff();
        }
      }

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
          Serial.println("진동 실행 완료");

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

      // 2. 일일 측정 (1000ms 주기)
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