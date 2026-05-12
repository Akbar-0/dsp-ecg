# DSP-ECG: Digital Signal Processing for Electrocardiogram (ECG)

A comprehensive electrocardiogram (ECG) signal processing and analysis system designed for real-time acquisition, visualization, and cardiac metrics computation. This project combines embedded microcontroller firmware for hardware data acquisition with digital signal processing algorithms for advanced ECG analysis.

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Getting Started](#getting-started)
- [Project Architecture](#project-architecture)
- [Hardware Setup](#hardware-setup)
- [Firmware Installation](#firmware-installation)
- [Software Components](#software-components)
- [Usage Guide](#usage-guide)
- [Technical Specifications](#technical-specifications)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Overview

**DSP-ECG** provides a complete solution for ECG signal processing:

- **Embedded Component**: Microcontroller firmware (ESP32/Arduino) that interfaces with AD8232 ECG sensors and streams digitized ECG data via serial communication
- **DSP Component**: Octave/MATLAB-based signal processing for real-time visualization, R-peak detection, heart rate calculation, and heart rate variability (HRV) analysis
- **Hardware Agnostic**: Supports multiple microcontroller platforms (ESP32, Arduino Uno, Arduino Nano)
- **Research-Ready**: Designed for ECG signal analysis and cardiac monitoring applications

## Key Features

### Embedded Firmware
- ✅ Real-time ECG acquisition from AD8232 analog sensors
- ✅ Configurable sampling rate (default 125 Hz)
- ✅ Lead-off detection for electrode quality monitoring
- ✅ Serial data streaming in CSV format
- ✅ Support for ESP32 (12-bit ADC) and Arduino (10-bit ADC)
- ✅ Timestamp synchronization with device uptime

### Signal Processing & Visualization
- ✅ Multiple MATLAB/Octave dashboard implementations
- ✅ Real-time ECG visualization with scrolling display
- ✅ R-peak detection using adaptive threshold
- ✅ Heart rate (BPM) calculation from detected peaks
- ✅ Various signal processing approaches (stream handlers)
- ✅ Raw and filtered signal visualization

### Data Collection
- ✅ Real ECG recordings with various conditions (baseline, artifact, etc.)
- ✅ Time-stamped data files for analysis
- ✅ Multiple artifact scenarios captured
- ✅ Standardized CSV format for analysis

### Software Compatibility
- ✅ Works with Octave 6.0+ (open-source MATLAB alternative)
- ✅ Compatible with MATLAB 2020a+
- ✅ Cross-platform (Windows, macOS, Linux)

## Getting Started

### Minimum Requirements
- **Microcontroller**: ESP32 DevKit or Arduino Uno/Nano
- **ECG Sensor**: AD8232 analog ECG sensor module
- **PC Software**: Arduino IDE 2.0+ for firmware upload
- **Serial Connection**: USB cable matching your microcontroller

### Quick Setup (Firmware Only)

Clone this repository:
```bash
git clone https://github.com/Akbar-0/dsp-ecg.git
cd dsp-ecg
```

Open [src/embedded/esp32_ad8232_streamer.ino](src/embedded/esp32_ad8232_streamer.ino) in Arduino IDE, select your board and COM port, upload (115200 baud), then verify output in Serial Monitor (115200 baud).

### Quick Setup (With MATLAB/Octave Dashboard)

Clone this repository:
```bash
git clone https://github.com/Akbar-0/dsp-ecg.git
cd dsp-ecg
```

**MATLAB (core dashboards)**:
- [dashboard_app.m](src/dsp/MATLAB/workspace/dashboard_app.m)
- [ecg_dashboard.m](src/dsp/MATLAB/workspace/ecg_dashboard.m)

**Octave (full dashboards + stream handlers)**:
- [dashboard_app.m](src/dsp/Octave/workspace/dashboard_app.m)
- [ecg_dashboard.m](src/dsp/Octave/workspace/ecg_dashboard.m)
- [ecg_dashboard_1a.m](src/dsp/Octave/workspace/ecg_dashboard_1a.m)
- [ecg_dashboard_raw.m](src/dsp/Octave/workspace/ecg_dashboard_raw.m)
- [stream_a.m](src/dsp/Octave/workspace/stream_a.m)
- [stream_b.m](src/dsp/Octave/workspace/stream_b.m)
- [stream_c.m](src/dsp/Octave/workspace/stream_c.m)

Run a dashboard (example):
```matlab
cd src/dsp/Octave/workspace
run ecg_dashboard
```
For recorded data, select a CSV from data/recorded_real_time.

### Expected Output (Firmware)
```
# ECG stream start: millis,raw,leadOff
1245,1872,0
1249,1868,0
1253,1875,1
1257,1880,0
```

## Project Architecture

### Directory Structure (Current)

- src/
  - dsp/
    - MATLAB/workspace/
      - [dashboard_app.m](src/dsp/MATLAB/workspace/dashboard_app.m)
      - [ecg_dashboard.m](src/dsp/MATLAB/workspace/ecg_dashboard.m)
    - Octave/workspace/
      - [dashboard_app.m](src/dsp/Octave/workspace/dashboard_app.m)
      - [ecg_dashboard.m](src/dsp/Octave/workspace/ecg_dashboard.m)
      - [ecg_dashboard_1a.m](src/dsp/Octave/workspace/ecg_dashboard_1a.m)
      - [ecg_dashboard_raw.m](src/dsp/Octave/workspace/ecg_dashboard_raw.m)
      - [stream_a.m](src/dsp/Octave/workspace/stream_a.m)
      - [stream_b.m](src/dsp/Octave/workspace/stream_b.m)
      - [stream_c.m](src/dsp/Octave/workspace/stream_c.m)
  - embedded/
    - [esp32_ad8232_streamer.ino](src/embedded/esp32_ad8232_streamer.ino)
- data/
  - recorded_real_time/
    - [ECG_20260510_001229 (baseline - still).csv](data/recorded_real_time/ECG_20260510_001229%20%28baseline%20-%20still%29.csv)
    - [ECG_20260510_003618 (artifact - walking).csv](data/recorded_real_time/ECG_20260510_003618%20%28artifact%20-%20walking%29.csv)
    - [ECG_20260510_004523 (artifact - hand swing).csv](data/recorded_real_time/ECG_20260510_004523%20%28artifact%20-%20hand%20swing%29.csv)
    - [ECG_20260510_005729 (artifact - tapping patches).csv](data/recorded_real_time/ECG_20260510_005729%20%28artifact%20-%20tapping%20patches%29.csv)
    - [ECG_20260510_012003 (artifact - rapid breathing).csv](data/recorded_real_time/ECG_20260510_012003%20%28artifact%20-%20rapid%20breathing%29.csv)
    - [ECG_20260511_230935 (raw - no filter).csv](data/recorded_real_time/ECG_20260511_230935%20%28raw%20-%20no%20filter%29.csv)
- src_combined/
  - [scripts_combined.m](src_combined/scripts_combined.m)
  - [scripts_combined.py](src_combined/scripts_combined.py)
- [ECG_MiniProject_Task1_Task2_Submission_Template.docx](ECG_MiniProject_Task1_Task2_Submission_Template.docx)
- [README.md](README.md)
- [LICENSE](LICENSE)
- [.gitignore](.gitignore)

### System Diagram
```
AD8232 ECG Sensor
       ↓
Microcontroller (ESP32/Arduino)
       ↓
Serial/USB Connection
       ↓
Octave/MATLAB Processing
   ├── Real-time visualization
   ├── Peak detection
   ├── Heart rate calculation
   └── HRV analysis
       ↓
Data Storage & Analysis
```

## Hardware Setup

### Components Needed
| Component | Type | Specification |
|-----------|------|---------------|
| Microcontroller | ESP32 DevKit | ESP-WROOM-32 module |
| ECG Sensor | AD8232 | Single-lead ECG front-end |
| Electrodes | Pre-gelled | Standard ECG electrodes |
| USB Cable | Micro-USB or USB-C | For programming & power |
| Power | USB 5V | From computer or adapter |

### Wiring Diagram

#### ESP32 Connection
```
AD8232 Pin    →    ESP32 Pin    →    Purpose
═══════════════════════════════════════════════
3.3V          →    3V3          →    Power supply
GND           →    GND          →    Ground
OUTPUT        →    GPIO34       →    ECG signal (ADC)
LO+           →    GPIO25       →    Lead-off detect (+)
LO-           →    GPIO26       →    Lead-off detect (-)
```

#### Arduino Uno/Nano Connection
```
AD8232 Pin    →    Arduino Pin    →    Purpose
═════════════════════════════════════════════════
3.3V          →    3.3V           →    Power supply
GND           →    GND            →    Ground
OUTPUT        →    A0             →    ECG signal (ADC)
LO+           →    10             →    Lead-off detect (+)
LO-           →    11             →    Lead-off detect (-)
```

### Electrode Placement

For single-lead ECG (3-electrode):
- **Right arm (RA)**: Right shoulder
- **Left arm (LA)**: Left shoulder or upper chest
- **Right leg (RL)**: Right hip or abdomen (ground reference)

**Tips for optimal signal**:
- Clean skin with alcohol pad before application
- Press electrodes firmly for good contact
- Position electrodes on bony areas to minimize motion artifact
- Avoid placing electrodes on muscle bulk
- Keep electrodes clean and dry

## Firmware Installation

### Prerequisites
1. **Download Arduino IDE**: [https://www.arduino.cc/en/software](https://www.arduino.cc/en/software)
2. **Install board support**:
   - For ESP32: Add this URL to Settings → Additional Boards Manager URLs:
     ```
     https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
     ```
   - Then Tools → Board Manager → Install `esp32 by Espressif Systems`

### Step-by-Step Upload

**Step 1**: Open the sketch
- Arduino IDE → File → Open
- Navigate to: [src/embedded/esp32_ad8232_streamer.ino](src/embedded/esp32_ad8232_streamer.ino)

**Step 2**: Configure board settings
- **For ESP32**:
  - Tools → Board → ESP32 Arduino → ESP32 Dev Module
  - Tools → Upload Speed → 115200
  - Tools → Port → Select COM port
  
- **For Arduino Uno**:
  - Tools → Board → Arduino AVR Boards → Arduino Uno
  - Tools → Port → Select COM port
  
- **For Arduino Nano** (if using clone):
  - Tools → Board → Arduino AVR Boards → Arduino Nano
  - Tools → Processor → ATmega328P (Old Bootloader)
  - Tools → Port → Select COM port

**Step 3**: Compile and upload
- Click **Verify** (✓) to compile
- Click **Upload** (→) to program the board
- If ESP32 hangs at "Connecting...": Hold BOOT button while uploading

**Step 4**: Verify operation
- Tools → Serial Monitor
- Set baud rate to **115200**
- You should see: `# ECG stream start: millis,raw,leadOff`
- Followed by CSV data lines

## Software Components

### Embedded Firmware: [esp32_ad8232_streamer.ino](src/embedded/esp32_ad8232_streamer.ino)

**Purpose**: Real-time ECG data acquisition and serial streaming

**Key Parameters**:
```cpp
const unsigned int SAMPLE_RATE_HZ = 125;      // Sampling frequency (Hz)
const unsigned long SERIAL_BAUD = 115200;     // Serial baud rate
const unsigned int ECG_PIN = 34;               // ADC input (ESP32)
const unsigned int LEAD_OFF_PLUS_PIN = 25;     // Lead-off detect (+)
const unsigned int LEAD_OFF_MINUS_PIN = 26;    // Lead-off detect (-)
```

**Features**:
- Timer-based precise sampling at 125 Hz
- Lead-off electrode detection
- CSV data output format
- Support for both ESP32 and Arduino boards

**Data Format**: CSV lines (one per sample)
```
millis,raw,leadOff
```

### DSP Workspaces (src/dsp/)

**MATLAB Workspace (src/dsp/MATLAB/workspace)**:

1. [dashboard_app.m](src/dsp/MATLAB/workspace/dashboard_app.m) - Complete ECG dashboard application
2. [ecg_dashboard.m](src/dsp/MATLAB/workspace/ecg_dashboard.m) - Main dashboard with visualization

**Octave Workspace (src/dsp/Octave/workspace)**:

1. [dashboard_app.m](src/dsp/Octave/workspace/dashboard_app.m) - Complete ECG dashboard application
2. [ecg_dashboard.m](src/dsp/Octave/workspace/ecg_dashboard.m) - Main dashboard with visualization
3. [ecg_dashboard_1a.m](src/dsp/Octave/workspace/ecg_dashboard_1a.m) - Alternative dashboard variant 1a
4. [ecg_dashboard_raw.m](src/dsp/Octave/workspace/ecg_dashboard_raw.m) - Raw signal processing and display
5. [stream_a.m](src/dsp/Octave/workspace/stream_a.m) - Data stream handler A
6. [stream_b.m](src/dsp/Octave/workspace/stream_b.m) - Data stream handler B
7. [stream_c.m](src/dsp/Octave/workspace/stream_c.m) - Data stream handler C

**Combined Scripts (src_combined)**:

- [scripts_combined.m](src_combined/scripts_combined.m)
- [scripts_combined.py](src_combined/scripts_combined.py)

**Features**:
- Real-time ECG visualization
- R-peak detection algorithms
- Heart rate calculation
- Multiple signal processing approaches
- Raw and filtered display options
- Integration with hardware or CSV data

**To Use (Octave)**:
```octave
cd src/dsp/Octave/workspace
run ecg_dashboard
run dashboard_app
```

**To Use (MATLAB)**:
```matlab
cd src/dsp/MATLAB/workspace
run ecg_dashboard
run dashboard_app
```

### Data Folder (data/)

**Purpose**: Storage and analysis of real ECG recordings

**Contents**: `recorded_real_time/` folder with 6 ECG recordings

**Data Files** (CSV format, timestamp-based):
1. [ECG_20260510_001229 (baseline - still).csv](data/recorded_real_time/ECG_20260510_001229%20%28baseline%20-%20still%29.csv) - Baseline reading, stationary
2. [ECG_20260510_003618 (artifact - walking).csv](data/recorded_real_time/ECG_20260510_003618%20%28artifact%20-%20walking%29.csv) - Motion artifact from walking
3. [ECG_20260510_004523 (artifact - hand swing).csv](data/recorded_real_time/ECG_20260510_004523%20%28artifact%20-%20hand%20swing%29.csv) - Artifact from hand movement
4. [ECG_20260510_005729 (artifact - tapping patches).csv](data/recorded_real_time/ECG_20260510_005729%20%28artifact%20-%20tapping%20patches%29.csv) - Artifact from electrode tapping
5. [ECG_20260510_012003 (artifact - rapid breathing).csv](data/recorded_real_time/ECG_20260510_012003%20%28artifact%20-%20rapid%20breathing%29.csv) - Artifact from breathing
6. [ECG_20260511_230935 (raw - no filter).csv](data/recorded_real_time/ECG_20260511_230935%20%28raw%20-%20no%20filter%29.csv) - Raw unfiltered data

**Data Format**: CSV with columns
```
millis,raw,leadOff
```

**Usage**:
```matlab
% Load ECG data in MATLAB/Octave
data = readmatrix('data/recorded_real_time/ECG_20260510_001229 (baseline - still).csv');
time = data(:,1);      % Timestamp in milliseconds
signal = data(:,2);    % Raw ADC values
leadOff = data(:,3);   % Lead-off status
```

**Data Characteristics**:
- Sampling rate: 125 Hz (8 ms between samples)
- Duration: ~60-120 seconds per recording
- ADC resolution: 12-bit (ESP32) or 10-bit (Arduino)
- Multiple artifact conditions captured for testing robustness

## Usage Guide

### Using Real-Time Hardware (Firmware)

Once firmware is uploaded to your microcontroller:

1. **Connect USB cable** to your computer
2. **Open Serial Monitor** in Arduino IDE (or any serial terminal)
3. **Observe data stream**:
   ```
   # ECG stream start: millis,raw,leadOff
   1000,2048,0
   1008,2052,0
   1016,2045,0
   ...
   ```

4. **To stream to file** (Windows PowerShell):
   ```powershell
   # Open serial port and save to file
   $port = new-Object System.IO.Ports.SerialPort COM3,115200,None,8,one
   $port.Open()
   # Read and save data
   ```

5. **To stream to file** (Linux/macOS):
   ```bash
   # Capture serial data to file
   cat /dev/ttyUSB0 > ecg_recording.csv
   
   # Or with timeout
   timeout 120 cat /dev/ttyUSB0 > ecg_recording.csv
   ```

### Using MATLAB/Octave Dashboard

**Option 1: With Recorded Data (Octave)**
```matlab
% Use existing ECG recordings from data/recorded_real_time/
cd src/dsp/Octave/workspace
run ecg_dashboard

% Select data file:
% data/recorded_real_time/ECG_20260510_001229 (baseline - still).csv
```

**Option 1b: With Recorded Data (MATLAB)**
```matlab
cd src/dsp/MATLAB/workspace
run ecg_dashboard
```

**Option 2: With Real-Time Hardware (Octave or MATLAB)**
```matlab
% Connect hardware and stream data
cd src/dsp/Octave/workspace
run dashboard_app

% For MATLAB, use:
% cd src/dsp/MATLAB/workspace
```

**Available Dashboard Variations (Octave workspace)**:
- [ecg_dashboard.m](src/dsp/Octave/workspace/ecg_dashboard.m) - Main dashboard with full features
- [ecg_dashboard_1a.m](src/dsp/Octave/workspace/ecg_dashboard_1a.m) - Alternative variant
- [ecg_dashboard_raw.m](src/dsp/Octave/workspace/ecg_dashboard_raw.m) - Raw signal processing
- [stream_a.m](src/dsp/Octave/workspace/stream_a.m) - Stream handler A
- [stream_b.m](src/dsp/Octave/workspace/stream_b.m) - Stream handler B
- [stream_c.m](src/dsp/Octave/workspace/stream_c.m) - Stream handler C

**Available Dashboards (MATLAB workspace)**:
- [dashboard_app.m](src/dsp/MATLAB/workspace/dashboard_app.m) - Live dashboard app
- [ecg_dashboard.m](src/dsp/MATLAB/workspace/ecg_dashboard.m) - Main dashboard

### Data Analysis Workflow

**Step 1: Load your ECG data**
```matlab
% Load from recorded data
data = readmatrix('data/recorded_real_time/ECG_20260510_001229 (baseline - still).csv');
time = data(:,1) / 1000;  % Convert ms to seconds
signal = data(:,2);        % Raw ECG signal
leadOff = data(:,3);       % Electrode status
```

**Step 2: Visualize**
```matlab
figure;
plot(time, signal);
xlabel('Time (s)');
ylabel('Amplitude (mV)');
title('ECG Signal');
grid on;
```

**Step 3: Run dashboard analysis**
```matlab
cd src/dsp/Octave/workspace
run ecg_dashboard

% For MATLAB, use:
% cd src/dsp/MATLAB/workspace
```

### Comparing Different Conditions

Your data folder contains 6 recordings under different conditions:
- **Baseline**: Stationary, clean ECG signal
- **Walking**: Motion artifact from activity
- **Hand swing**: Artifact from hand movement
- **Tapping patches**: Artifact from electrode disturbance
- **Rapid breathing**: Artifact from respiratory movement
- **Raw unfiltered**: Pure signal without preprocessing

Use these to test your algorithms under various conditions!

## Technical Specifications

### Sampling & Digitization
- **Sampling Rate**: 125 Hz (configurable in firmware)
- **Analog Input Range**: 0-3.3V (ESP32), 0-5V (Arduino)
- **ADC Resolution**: 12-bit (ESP32), 10-bit (Arduino)
- **Quantization Step**: 0.8 mV (ESP32), 4.9 mV (Arduino)
- **Nyquist Frequency**: 62.5 Hz

### Serial Communication
- **Protocol**: RS-232 serial (via USB UART bridge)
- **Baud Rate**: 115200 bps
- **Data Rate**: ~1.5 KB/s (125 samples/sec × 13 bytes/line)
- **Format**: ASCII CSV (human-readable)

### Signal Processing (Planned)
- **Filtering**: Moving average (baseline removal)
- **Peak Detection**: Adaptive threshold method
- **Metrics Window**: BPM (10 sec), HRV (60 sec)

### Latency
- **Hardware**: < 8 ms per sample (125 Hz)
- **Serial**: ~1-10 ms (depends on USB latency)
- **Visualization**: ~100 ms (depends on MATLAB/Octave performance)

## Configuration

### Firmware Configuration

**Sampling Rate** (in [src/embedded/esp32_ad8232_streamer.ino](src/embedded/esp32_ad8232_streamer.ino)):
```cpp
const unsigned int SAMPLE_RATE_HZ = 125;  // Change this value to adjust sampling rate
const unsigned long SERIAL_BAUD = 115200; // Serial baud rate
```

**Pin Configuration** (ESP32):
```cpp
#define ECG_PIN 34              // ADC input pin
#define LEAD_OFF_PLUS_PIN 25    // Lead-off detect (+)
#define LEAD_OFF_MINUS_PIN 26   // Lead-off detect (-)
```

**Pin Configuration** (Arduino):
```cpp
#define ECG_PIN A0              // ADC input pin
#define LEAD_OFF_PLUS_PIN 10    // Lead-off detect (+)
#define LEAD_OFF_MINUS_PIN 11   // Lead-off detect (-)
```

### MATLAB/Octave Dashboard Configuration

Most dashboards accept user input for:
- **Data source**: File path or serial port for live streaming
- **Display parameters**: Window size, refresh rate, scroll speed
- **Processing parameters**: Filter cutoff frequency, peak detection threshold
- **Visualization options**: Raw vs. filtered signal, zoom level, marker display

## Troubleshooting

### No Data Appears in Serial Monitor

**Problem**: Serial Monitor shows nothing
```
Solution:
1. Verify correct COM port selected
2. Check baud rate is 115200
3. Try pressing RESET button on board
4. Swap USB cable (some are charge-only)
5. Check for driver issues in Device Manager
```

### Unstable/Noisy ECG Signal

**Problem**: ECG waveform is very noisy or flat
```
Solution:
1. Verify electrode placement on skin
2. Clean skin with alcohol pad
3. Check electrode isn't dry
4. Ensure electrode contacts are clean
5. Move away from electrical interference
6. Verify common ground between sensor and board
```

### Lead-Off Always Shows 1

**Problem**: `leadOff` column always reads 1
```
Solution:
1. Check LO+/LO- wiring connections
2. Verify pins 25 and 26 (ESP32) or 10 and 11 (Arduino)
3. Re-seat electrodes firmly
4. Check if electrodes are degraded (replace if needed)
5. Ensure at least 2 of 3 electrodes have good contact
```

### Board Won't Upload Firmware

**Problem**: Upload fails with timeout error

**For ESP32**:
```
Solution:
1. Hold BOOT button while upload starts (release after "Uploading...")
2. Try different USB cable
3. Try different USB port
4. Update ESP32 board package
5. Select slower upload speed (115200)
```

**For Arduino Nano** (if clone):
```
Solution:
1. Select "ATmega328P (Old Bootloader)" in Tools → Processor
2. Reduce upload speed to 57600 or 115200
3. Try different USB cable
4. Update Arduino board drivers
```

## Contributing

Contributions are welcome! Areas of interest:

- **Firmware Improvements**:
  - Additional microcontroller support
  - Alternative sensor types (ADS1115 ADC module, etc.)
  - Improved sampling stability

- **DSP/Software**:
  - Real-time visualization implementation
  - Advanced peak detection algorithms
  - HRV analysis features
  - Data logging and export

- **Documentation**:
  - Hardware assembly guides
  - MATLAB integration examples
  - Performance benchmarks

- **Testing**:
  - Hardware validation reports
  - Signal quality assessment
  - Cross-platform testing

## References & Resources

### ECG Theory
- **Physiology**: ECG basics, cardiac conduction, arrhythmias
- **Signal Processing**: QRS detection, RR interval analysis
- **Databases**: [PhysioNet MIT-BIH](https://physionet.org/)

### Hardware Documentation
- **AD8232**: [Analog Devices Datasheet](https://www.analog.com/en/products/ad8232.html)
- **ESP32**: [Espressif Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/)
- **Arduino**: [Arduino Reference](https://www.arduino.cc/reference/en/)

### Software Tools
- **Octave**: [GNU Octave](https://www.gnu.org/software/octave/)
- **Arduino IDE**: [arduino.cc](https://www.arduino.cc/en/software)
- **MATLAB**: [MathWorks](https://www.mathworks.com/products/matlab.html)

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

**MIT License Summary**:
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ⚠️ No warranty provided
- ⚠️ License and copyright notice required

## Project Status

**Current Status**: Active Development  
**Last Updated**: May 2026

**Completed**:
- ✅ Embedded firmware for ESP32/Arduino ([esp32_ad8232_streamer.ino](src/embedded/esp32_ad8232_streamer.ino))
- ✅ Serial data streaming with CSV format
- ✅ Lead-off detection
- ✅ Multiple MATLAB/Octave dashboard implementations
- ✅ Real ECG data collection (6 recordings with various conditions)
- ✅ Signal visualization and processing scripts
- ✅ Combined scripts ([scripts_combined.m](src_combined/scripts_combined.m), [scripts_combined.py](src_combined/scripts_combined.py))

**In Progress**:
- 🔄 Performance optimization of peak detection algorithms
- 🔄 Enhanced visualization features
- 🔄 Documentation and examples

**Planned/Future**:
- 📅 Advanced HRV analysis metrics
- 📅 Real-time artifact detection and filtering
- 📅 Multi-lead ECG support
- 📅 Cloud data storage integration
- 📅 Web-based dashboard
- 📅 Mobile app integration

**Test Data Available**:
6 real ECG recordings with different artifact conditions:
1. ✅ Baseline (clean signal)
2. ✅ Walking (motion artifact)
3. ✅ Hand swing (movement artifact)
4. ✅ Electrode tapping (contact artifact)
5. ✅ Rapid breathing (respiratory artifact)
6. ✅ Raw unfiltered signal

---

## Contact & Support

For issues, questions, or suggestions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review hardware wiring against [Hardware Setup](#hardware-setup)
3. Verify firmware configuration in [src/embedded/esp32_ad8232_streamer.ino](src/embedded/esp32_ad8232_streamer.ino)
4. Check Arduino IDE console for compilation errors

**Enjoy your ECG signal processing! 📊❤️**
