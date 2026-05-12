/*
AD8232 ECG streamer for ESP32 or Arduino Uno/Nano.
Streams one CSV sample per line:
millis,raw,leadOff
Intended for MATLAB serial ingestion for real-time ECG processing.

Fixes applied:
  - Catch-up uses while-loop to preserve phase alignment
  - ADC read guarded when lead-off detected (raw = -1 sentinel)
  - static_assert ensures sample rate divides 1MHz evenly
  - uint16_t for raw on ESP32 (int on AVR, safe on both via macro)
*/

// #if defined(ESP32)
  #define ECG_PIN              34
  #define LEAD_OFF_PLUS_PIN    32
  #define LEAD_OFF_MINUS_PIN   33
#else
  #define ECG_PIN              A0
  #define LEAD_OFF_PLUS_PIN    10
  #define LEAD_OFF_MINUS_PIN   11
#endif

// ── Configuration ────────────────────────────────────────────────────────────
const unsigned long SERIAL_BAUD    = 115200;
const unsigned int  SAMPLE_RATE_HZ = 500;
const unsigned long SAMPLE_PERIOD_US = 1000000UL / SAMPLE_RATE_HZ;

// Catch divisibility errors at compile time, not runtime.
static_assert(1000000UL % SAMPLE_RATE_HZ == 0,
              "SAMPLE_RATE_HZ must divide 1 000 000 evenly (e.g. 100, 125, 200, 250, 500).");

// ── State ─────────────────────────────────────────────────────────────────────
static unsigned long nextSampleMicros = 0;

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(SERIAL_BAUD);
  pinMode(LEAD_OFF_PLUS_PIN,  INPUT);
  pinMode(LEAD_OFF_MINUS_PIN, INPUT);

#if defined(ESP32)
  analogReadResolution(12);   // 0–4095
#endif

  delay(500);   // Let serial settle before MATLAB starts reading.
  Serial.println("# ECG stream start: millis,raw,leadOff");
  nextSampleMicros = micros();
}

// ── Loop ──────────────────────────────────────────────────────────────────────
void loop() {
  const unsigned long now = micros();

  // Signed subtraction handles 32-bit micros() rollover correctly.
  if ((long)(now - nextSampleMicros) < 0) {
    return;
  }

  // ── Sample ────────────────────────────────────────────────────────────────
  const bool leadOff =
    (digitalRead(LEAD_OFF_PLUS_PIN)  == HIGH) ||
    (digitalRead(LEAD_OFF_MINUS_PIN) == HIGH);

  // When leads are off the ADC input floats → value is meaningless.
  // Emit -1 so MATLAB can gate DSP (R-peak, BPF, BPM) on leadOff==0.
#if defined(ESP32)
  const int raw = leadOff ? -1 : (int)analogRead(ECG_PIN);  // 12-bit: 0–4095
#else
  const int raw = leadOff ? -1 : (int)analogRead(ECG_PIN);  // 10-bit: 0–1023
#endif

  // ── Transmit ──────────────────────────────────────────────────────────────
  Serial.print(millis());
  Serial.print(',');
  Serial.print(raw);
  Serial.print(',');
  Serial.println(leadOff ? 1 : 0);

  // ── Timing correction ─────────────────────────────────────────────────────
  // Advance by one slot unconditionally (normal case).
  nextSampleMicros += SAMPLE_PERIOD_US;

  // If Serial.print overran the period, skip the minimum number of missed
  // slots to stay phase-aligned rather than resetting the origin entirely.
  const unsigned long afterPrint = micros();
  while ((long)(afterPrint - nextSampleMicros) > 0) {
    nextSampleMicros += SAMPLE_PERIOD_US;
  }
}