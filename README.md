# dsp-ecg
Real-Time ECG acquisition, plotting, R-peak detection, heart rate, and HRV in MATLAB.

## Current phase: software only

The active workflow is software simulation in MATLAB using:

- `dsp/sim_dashboard.m`

This script currently runs at `fs = 125`, so embedded defaults are aligned to `125 Hz` for consistency if hardware streaming is used later.

## Task 1: Embedded work started

This repository includes a first embedded firmware target for AD8232-style ECG sensors:

- `embedded/esp32_ad8232_streamer/esp32_ad8232_streamer.ino`

The sketch samples ECG at a fixed rate and streams CSV lines over serial for MATLAB.

## Hardware target (initial)

- Sensor: AD8232 (or compatible analog ECG output)
- Board: ESP32 DevKit (recommended) or Arduino Uno/Nano

## Wiring

### AD8232 -> ESP32

- `3.3V` -> `3V3`
- `GND` -> `GND`
- `OUTPUT` -> `GPIO34` (default `ECG_PIN`)
- `LO+` -> `GPIO25` (default `LEAD_OFF_PLUS_PIN`)
- `LO-` -> `GPIO26` (default `LEAD_OFF_MINUS_PIN`)

### AD8232 -> Arduino Uno/Nano

- `3.3V` -> `3.3V`
- `GND` -> `GND`
- `OUTPUT` -> `A0`
- `LO+` -> `10`
- `LO-` -> `11`

Note: If your board/sensor wiring differs, update pin constants in the sketch.

## Serial data format

Each sample is sent as one CSV line:

`millis,raw,leadOff`

Example:

`12450,1872,0`

- `millis`: board uptime timestamp in milliseconds
- `raw`: ADC sample
- `leadOff`: `1` if electrode lead-off is detected, otherwise `0`

Default serial baud: `115200`

## Sample rate

The firmware uses timer-based scheduling and sends samples at:

- `125 Hz` (default, aligned with current MATLAB software dashboard)

You can change `SAMPLE_RATE_HZ` in the sketch.

## Arduino IDE upload checklist

### 1) Install Arduino IDE and board packages

- Install Arduino IDE 2.x.
- Open Arduino IDE -> File -> Preferences.
- In `Additional boards manager URLs`, add ESP32 URL:
	- `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
- Open Tools -> Board -> Boards Manager.
- Install:
	- `esp32 by Espressif Systems` (for ESP32)
	- `Arduino AVR Boards` (for Uno/Nano)

### 2) Open firmware sketch

- Open this file in Arduino IDE:
	- `embedded/esp32_ad8232_streamer/esp32_ad8232_streamer.ino`

### 3) Select board and port

For ESP32:
- Tools -> Board -> ESP32 Arduino -> your ESP32 variant (for example, `ESP32 Dev Module`).
- Tools -> Port -> select the detected serial port.

For Uno/Nano:
- Tools -> Board -> Arduino AVR Boards -> `Arduino Uno` (or your Nano variant).
- For many Nano clones, set Tools -> Processor -> `ATmega328P (Old Bootloader)` if upload fails.
- Tools -> Port -> select the detected serial port.

### 4) Verify and upload

- Click Verify (check mark).
- Click Upload (right arrow).
- If ESP32 upload hangs at `Connecting...`, hold the board `BOOT` button while upload starts.

### 5) Validate serial output

- Open Tools -> Serial Monitor.
- Set baud rate to `115200`.
- You should see lines like:
	- `# ECG stream start: millis,raw,leadOff`
	- `12450,1872,0`
	- `12454,1868,0`

### 6) Quick troubleshooting

- No serial data:
	- Confirm correct COM/TTY port.
	- Confirm Serial Monitor baud is `115200`.
	- Press reset button on board.
- Flat or noisy ECG:
	- Re-check electrode placement and skin contact.
	- Ensure common ground between board and sensor.
	- Keep sensor wires away from USB power noise sources.
- Frequent `leadOff = 1`:
	- Check LO+ and LO- wiring.
	- Re-seat electrodes.

## Next step

The next repo step is MATLAB-side live reader + dashboard (real-time ECG, one-cycle panel, R-peaks, BPM per 10 s, HRV per 60 s).
