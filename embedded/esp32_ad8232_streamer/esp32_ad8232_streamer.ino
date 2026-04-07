/*
  AD8232 ECG streamer for ESP32 or Arduino Uno/Nano.

  Streams one CSV sample per line:
    millis,raw,leadOff

  Intended for MATLAB serial ingestion for real-time ECG processing.
*/

#if defined(ESP32)
  #define ECG_PIN 34
  #define LEAD_OFF_PLUS_PIN 25
  #define LEAD_OFF_MINUS_PIN 26
#else
  #define ECG_PIN A0
  #define LEAD_OFF_PLUS_PIN 10
  #define LEAD_OFF_MINUS_PIN 11
#endif

const unsigned long SERIAL_BAUD = 115200;
const unsigned int SAMPLE_RATE_HZ = 250;
const unsigned long SAMPLE_PERIOD_US = 1000000UL / SAMPLE_RATE_HZ;

unsigned long nextSampleMicros = 0;

void setup() {
  Serial.begin(SERIAL_BAUD);

  pinMode(LEAD_OFF_PLUS_PIN, INPUT);
  pinMode(LEAD_OFF_MINUS_PIN, INPUT);

#if defined(ESP32)
  analogReadResolution(12);
#endif

  delay(500);
  Serial.println("# ECG stream start: millis,raw,leadOff");
  nextSampleMicros = micros();
}

void loop() {
  const unsigned long now = micros();
  if ((long)(now - nextSampleMicros) < 0) {
    return;
  }

  nextSampleMicros += SAMPLE_PERIOD_US;

  const int raw = analogRead(ECG_PIN);
  const bool leadOff = (digitalRead(LEAD_OFF_PLUS_PIN) == HIGH) ||
                       (digitalRead(LEAD_OFF_MINUS_PIN) == HIGH);

  Serial.print(millis());
  Serial.print(',');
  Serial.print(raw);
  Serial.print(',');
  Serial.println(leadOff ? 1 : 0);

  // Catch up gracefully if serial printing or other delays made us miss slots.
  const unsigned long afterPrint = micros();
  if ((long)(afterPrint - nextSampleMicros) > 0) {
    nextSampleMicros = afterPrint + SAMPLE_PERIOD_US;
  }
}
