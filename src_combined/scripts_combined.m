%% Task 1A Code

function ecg_dashboard

clc; clear; close all;

% ── SERIAL SETTINGS ──

comPort = 'COM23';

baudRate = 115200;

fs = 500;

% At 500 Hz, 50 samples = 100 ms per refresh — same wall-clock cadence as

% before (13 samples @ 125 Hz was also ~104 ms).

serialBatchSize = 50;

% ── DASHBOARD SETTINGS ──

displayWindow = 6; % seconds — keep plot uncluttered at 500 Hz

% (was 10 s @ 125 Hz → same ~750 visible samples)

bpmWindow = 10;

hrvWindow = 60;

totalSimTime = 120;

% ── OPEN SERIAL PORT ──

sp = serialport(comPort, baudRate);

configureTerminator(sp, "LF");

sp.Timeout = 3;

flush(sp);

disp('Waiting for ESP32 sync header...');

while true
    
    line = strtrim(readline(sp));
    
    if startsWith(line, '#')
        
        fprintf('Sync received: %s\n', line);
        
        break;
        
    end
    
end

% ── DASHBOARD INIT ──

dash = dashboard_app;

dash.initialize('Live ESP32 ECG (AD8232)', [], fs, totalSimTime);

dash.setStatus('Streaming...');

% ── BUFFERS ──

x = [];

t = [];

peakTimes = [];

lastAcceptedPeak = -inf;

lastBPMUpdate = 0;

peakMergeTol = 0.25;

rrMin = 0.35;

rrMax = 1.50;

sampleCount = 0;

leadOffStreak = 0;

maxLeadOffWarn = fs * 2;

% ── MAIN LOOP ──

try
    
    while dash.isOpen()
        
        batchRaw = zeros(1, serialBatchSize);
        
        batchN = 0;
        
        while batchN < serialBatchSize
            
            line = strtrim(readline(sp));
            
            if isempty(line) || line(1) == '#'
                
                continue;
                
            end
            
            parts = strsplit(line, ',');
            
            if numel(parts) ~= 3
                
                continue;
                
            end
            
            rawVal = str2double(parts{2});
            
            leadOff = str2double(parts{3});
            
            if leadOff == 1 || rawVal < 0
                
                leadOffStreak = leadOffStreak + 1;
                
                if leadOffStreak == maxLeadOffWarn
                    
                    dash.setStatus('WARNING: Lead-off detected — check electrodes');
                    
                end
                
                continue;
                
            else
                
                if leadOffStreak >= maxLeadOffWarn
                    
                    dash.setStatus('Streaming...');
                    
                end
                
                leadOffStreak = 0;
                
            end
            
            normalised = (rawVal / 4095) * 2 - 1;
            
            batchN = batchN + 1;
            
            batchRaw(batchN) = normalised;
            
        end
        
        batchRaw = batchRaw(1:batchN);
        
        if batchN == 0
            
            continue;
            
        end
        
        newSamples = sampleCount : sampleCount + batchN - 1;
        
        batchT = newSamples / fs;
        
        sampleCount = sampleCount + batchN;
        
        x = [x batchRaw];
        
        t = [t batchT];
        
        % ── DISPLAY WINDOW ──
        
        maxSamples = fs * displayWindow;
        
        if length(x) > maxSamples
            
            x_disp = x(end - maxSamples + 1 : end);
            
            t_disp = t(end - maxSamples + 1 : end);
            
        else
            
            x_disp = x;
            
            t_disp = t;
            
        end
        
        % ── FILTER & PEAK DETECT ──
        
        y = preprocess_ecg(x_disp, fs);
        
        % Upsample factor 4 instead of 8 — at 500 Hz native the signal is
        
        % already sharp; 8× would push plot points to 20 000+ per refresh.
        
        displayFs = fs * 4;
        
        [t_up, y_up] = upsample_for_display(t_disp, y, displayFs);
        
        [locs, pks] = detect_rpeaks_sharp(y_up, displayFs);
        
        % ── DASHBOARD PLOTS ──
        
        dash.updateRealtimePlot(t_up, y_up, locs, pks);
        
        if length(locs) >= 2
            
            cycle = y_up(locs(end-1) : locs(end));
            
            dash.updateCyclePlot(cycle, displayFs);
            
        end
        
        % ── PEAK ACCUMULATION ──
        
        pt = t_up(locs);
        
        for k = 1:length(pt)
            
            if pt(k) > (lastAcceptedPeak + peakMergeTol)
                
                peakTimes(end+1) = pt(k);
                
                lastAcceptedPeak = pt(k);
                
            end
            
        end
        
        currentTime = t(end);
        
        % ── BPM ──
        
        if currentTime >= bpmWindow && (currentTime - lastBPMUpdate) >= bpmWindow
            
            recent = peakTimes(peakTimes >= currentTime - bpmWindow);
            
            if length(recent) >= 2
                
                rr = diff(recent);
                
                rr = rr(rr >= rrMin & rr <= rrMax);
                
                if ~isempty(rr)
                    
                    dash.updateBPM(60 / mean(rr));
                    
                end
                
            end
            
            lastBPMUpdate = currentTime;
            
        end
        
        % ── HRV ──
        
        if currentTime >= hrvWindow && length(peakTimes) >= 3
            
            recentHrvPeaks = peakTimes(peakTimes >= currentTime - hrvWindow);
            
            if length(recentHrvPeaks) >= 3
                
                rr_all = diff(recentHrvPeaks);
                
                rr_all = rr_all(rr_all >= rrMin & rr_all <= rrMax);
                
                if length(rr_all) >= 3
                    
                    rrMed = median(rr_all);
                    
                    rr_all = rr_all(abs(rr_all - rrMed) <= 0.20 * rrMed);
                    
                end
                
                if length(rr_all) >= 3
                    
                    dash.updateHRV(std(rr_all) * 1000);
                    
                end
                
            end
            
        end
        
        % ── TIME & EXIT ──
        
        dash.updateTime(currentTime, totalSimTime);
        
        if currentTime >= totalSimTime
            
            break;
            
        end
        
        drawnow limitrate nocallbacks;
        
    end
    
catch ME
    
    fprintf('Error: %s\n', ME.message);
    
end

% ── CLEANUP ──

if exist('sp', 'var') && isvalid(sp)
    
    delete(sp);
    
    disp('Serial port closed.');
    
end

if dash.isOpen()
    
    dash.setStatus('Stream ended');
    
end

end

% ── HELPER FUNCTIONS ──

function y = preprocess_ecg(x, fs)

x = double(x(:).');

x = x - mean(x);

w = max(3, round(0.60 * fs));

baseline = movmean(x, w);

y = x - baseline;

if exist('butter','file') == 2 && exist('filtfilt','file') == 2 && fs > 40
    
    hp = 0.5;
    
    lp = min(40, 0.45 * fs); % raised LP ceiling to 40 Hz for 500 Hz input
    
    if lp > hp
        
        [b, a] = butter(2, [hp lp] / (fs/2), 'bandpass');
        
        minLen = 3 * (max(length(a), length(b)) - 1);
        
        if numel(y) > minLen
            
            y = filtfilt(b, a, y);
            
        elseif numel(y) > max(length(a), length(b))
            
            y = filter(b, a, y);
            
        end
        
    end
    
end

y = y / (max(abs(y)) + eps);

end

function [t_up, y_up] = upsample_for_display(t, y, displayFs)

if numel(t) < 2
    
    t_up = t;
    
    y_up = y;
    
    return;
    
end

t_up = t(1) : 1/displayFs : t(end);

y_up = interp1(t, y, t_up, 'pchip');

y_up = y_up / (max(abs(y_up)) + eps);

end

function [locs, pks] = detect_rpeaks_sharp(y, fs)

y = y(:).';

qrs = y;

if exist('butter','file') == 2 && exist('filtfilt','file') == 2 && fs > 50
    
    [b, a] = butter(2, [8 40] / (fs/2), 'bandpass'); % wider QRS band for 500 Hz
    
    minLen = 3 * (max(length(a), length(b)) - 1);
    
    if numel(y) > minLen
        
        qrs = filtfilt(b, a, y);
        
    elseif numel(y) > max(length(a), length(b))
        
        qrs = filter(b, a, y);
        
    end
    
end

env = qrs .^ 2;

thr = mean(env) + 0.5 * std(env);

minDist = round(0.35 * fs);

roughLocs = simple_peak_pick(env, thr, minDist);

refineWin = round(0.05 * fs);

locs = zeros(size(roughLocs));

for k = 1:numel(roughLocs)
    
    i1 = max(1, roughLocs(k) - refineWin);
    
    i2 = min(length(y), roughLocs(k) + refineWin);
    
    [~, idx] = max(y(i1:i2));
    
    locs(k) = i1 + idx - 1;
    
end

locs = unique(locs);

pks = y(locs);

end

function locs = simple_peak_pick(sig, thr, minDist)

locs = [];

for i = 2:length(sig)-1
    
    if sig(i) > sig(i-1) && sig(i) >= sig(i+1) && sig(i) > thr
        
        if isempty(locs)
            
            locs(end+1) = i;
            
        elseif (i - locs(end)) > minDist
            
            locs(end+1) = i;
            
        elseif sig(i) > sig(locs(end))
            
            locs(end) = i;
            
        end
        
    end
    
end

end

%% Task 1B Code

function ecg_dashboard

% ECG_DASHBOARD Real-time ECG monitor for Octave + instrument-control package.

%

% Packages required:

% instrument-control — serial port I/O

% signal — butter / filtfilt

%

% Output:

% ECG_<YYYYMMDD_HHMMSS>.csv saved in the same folder as this script.

% Columns: time_s, raw_normalised, filtered, r_peak (0/1), bpm, hrv_ms

clc; clear; clear functions; close all;

% ── Load required Octave packages ────────────────────────────────────────

pkg load instrument-control;

pkg load signal;

% ── SERIAL SETTINGS ──────────────────────────────────────────────────────

comPort = 'COM8'; % Windows: 'COM7' Linux/Mac: '/dev/ttyUSB0'

baudRate = 115200;

fs = 125;

serialBatchSize = 13;

% ── DASHBOARD SETTINGS ───────────────────────────────────────────────────

displayWindow = 10;

bpmWindow = 5; % update BPM every 5 s (was 10)

hrvWindow = 30; % start HRV after 30 s, use 30 s window (was 60)

totalSimTime = 120;

% ── CSV OUTPUT ───────────────────────────────────────────────────────────

% Save next to this script file regardless of cwd

scriptDir = fileparts(mfilename('fullpath'));

if isempty(scriptDir)
    
    scriptDir = pwd;
    
end

csvName = ['ECG_' datestr(now, 'yyyymmdd_HHMMSS') '.csv'];

csvPath = fullfile(scriptDir, csvName);

csvFid = fopen(csvPath, 'w');

if csvFid == -1
    
    warning('Could not open %s for writing — CSV will not be saved.', csvPath);
    
    csvFid = -1;
    
else
    
    fprintf(csvFid, 'time_s,raw_normalised,filtered,r_peak,bpm,hrv_ms\n');
    
    fprintf('CSV recording → %s\n', csvPath);
    
end

% Current BPM/HRV to stamp on each row (updated lazily)

csvBPM = NaN;

csvHRV = NaN;

% ── OPEN SERIAL PORT ─────────────────────────────────────────────────────

sp = serialport(comPort, baudRate);

% Wait for the firmware sync header

disp('Waiting for ESP32 sync header...');

while true
    
    line = serial_readline(sp);
    
    if ~isempty(line) && line(1) == '#'
        
        fprintf('Sync received: %s\n', line);
        
        break;
        
    end
    
end

% ── DASHBOARD INIT ───────────────────────────────────────────────────────

dash = dashboard_app();

dash.initialize('Live ESP32 ECG (AD8232)', [], fs, totalSimTime);

dash.setStatus('Streaming...');

% ── BUFFERS ──────────────────────────────────────────────────────────────

x = [];

t = [];

peakTimes = [];

lastAcceptedPeak = -inf;

lastBPMUpdate = 0;

peakMergeTol = 0.40; % min gap between accepted peaks (was 0.25) = max ~150 BPM

rrMin = 0.40; % min valid RR = 150 BPM (was 0.35)

rrMax = 1.50;

sampleCount = 0;

leadOffStreak = 0;

maxLeadOffWarn = fs * 2;

% ── MAIN LOOP ────────────────────────────────────────────────────────────

try
    
    while dash.isOpen()
        
        batchRaw = zeros(1, serialBatchSize);
        
        batchN = 0;
        
        while batchN < serialBatchSize
            
            line = serial_readline(sp);
            
            if isempty(line) || line(1) == '#'
                
                continue;
                
            end
            
            % Parse "millis,raw,leadOff"
            
            parts = strsplit(line, ',');
            
            if numel(parts) ~= 3
                
                continue;
                
            end
            
            rawVal = str2double(parts{2});
            
            leadOff = str2double(parts{3});
            
            if leadOff == 1 || rawVal < 0
                
                leadOffStreak = leadOffStreak + 1;
                
                if leadOffStreak == maxLeadOffWarn
                    
                    dash.setStatus('WARNING: Lead-off detected - check electrodes');
                    
                end
                
                continue;
                
            else
                
                if leadOffStreak >= maxLeadOffWarn
                    
                    dash.setStatus('Streaming...');
                    
                end
                
                leadOffStreak = 0;
                
            end
            
            % Normalise 12-bit ADC to [-1, 1] (change 4095->1023 for Uno/Nano)
            
            normalised = (rawVal / 4095) * 2 - 1;
            
            batchN = batchN + 1;
            
            batchRaw(batchN) = normalised;
            
        end
        
        batchRaw = batchRaw(1:batchN);
        
        if batchN == 0
            
            continue;
            
        end
        
        newSamples = sampleCount : sampleCount + batchN - 1;
        
        batchT = newSamples / fs;
        
        sampleCount = sampleCount + batchN;
        
        x = [x batchRaw];
        
        t = [t batchT];
        
        % ── DISPLAY WINDOW ───────────────────────────────────────────────
        
        maxSamples = fs * displayWindow;
        
        if length(x) > maxSamples
            
            x_disp = x(end - maxSamples + 1 : end);
            
            t_disp = t(end - maxSamples + 1 : end);
            
        else
            
            x_disp = x;
            
            t_disp = t;
            
        end
        
        % ── FILTER & PEAK DETECT ─────────────────────────────────────────
        
        y = preprocess_ecg(x_disp, fs);
        
        [t_up, y_up] = upsample_for_display(t_disp, y, fs * 8);
        
        [locs, pks] = detect_rpeaks_sharp(y_up, fs * 8);
        
        % ── DASHBOARD PLOTS ──────────────────────────────────────────────
        
        dash.updateRealtimePlot(t_up, y_up, locs, pks);
        
        % Centre the single-cycle window on the most recent R-peak (±400 ms)
        
        if ~isempty(locs)
            
            halfWin = round(0.40 * fs * 8);
            
            rIdx = locs(end);
            
            i1 = max(1, rIdx - halfWin);
            
            i2 = min(length(y_up), rIdx + halfWin);
            
            cycle = y_up(i1:i2);
            
            if length(cycle) > 4
                
                dash.updateCyclePlot(cycle, fs * 8);
                
            end
            
        end
        
        if isfield(dash, 'updateFFT')
            
            dash.updateFFT(y_up, fs * 8);
            
        end
        
        % ── PEAK ACCUMULATION ────────────────────────────────────────────
        
        pt = t_up(locs);
        
        for k = 1:length(pt)
            
            if pt(k) > (lastAcceptedPeak + peakMergeTol)
                
                peakTimes(end+1) = pt(k);
                
                lastAcceptedPeak = pt(k);
                
            end
            
        end
        
        currentTime = t(end);
        
        % ── BPM ──────────────────────────────────────────────────────────
        
        if currentTime >= bpmWindow && (currentTime - lastBPMUpdate) >= bpmWindow
            
            recent = peakTimes(peakTimes >= currentTime - bpmWindow);
            
            if length(recent) >= 2
                
                rr = diff(recent);
                
                rr = rr(rr >= rrMin & rr <= rrMax);
                
                if ~isempty(rr)
                    
                    csvBPM = 60 / mean(rr);
                    
                    dash.updateBPM(csvBPM);
                    
                end
                
            end
            
            lastBPMUpdate = currentTime;
            
        end
        
        % ── HRV ──────────────────────────────────────────────────────────
        
        if currentTime >= hrvWindow && length(peakTimes) >= 3
            
            recentHrvPeaks = peakTimes(peakTimes >= currentTime - hrvWindow);
            
            if length(recentHrvPeaks) >= 3
                
                rr_all = diff(recentHrvPeaks);
                
                rr_all = rr_all(rr_all >= rrMin & rr_all <= rrMax);
                
                if length(rr_all) >= 3
                    
                    rrMed = median(rr_all);
                    
                    rr_all = rr_all(abs(rr_all - rrMed) <= 0.20 * rrMed);
                    
                end
                
                if length(rr_all) >= 3
                    
                    csvHRV = std(rr_all) * 1000;
                    
                    dash.updateHRV(csvHRV);
                    
                end
                
            end
            
        end
        
        % ── CSV WRITE (one row per sample in this batch) ─────────────────
        
        % Written AFTER BPM/HRV so values are always current for this batch
        
        if csvFid ~= -1
            
            % Build a set of R-peak times for this batch (from full t_up)
            
            peakTimesInBatch = t_up(locs);
            
            % Map each batch sample to its filtered counterpart
            
            % y was computed on x_disp; align indices to the batch tail
            
            dispLen = length(x_disp);
            
            batchOffset = dispLen - batchN;
            
            for si = 1:batchN
                
                tSample = batchT(si);
                
                rawSamp = batchRaw(si);
                
                % Filtered value: pick from y at the corresponding index
                
                yIdx = batchOffset + si;
                
                if yIdx >= 1 && yIdx <= length(y)
                    
                    filtSamp = y(yIdx);
                    
                else
                    
                    filtSamp = NaN;
                    
                end
                
                % R-peak flag: 1 if a detected peak falls within ±1 sample
                
                isRpeak = any(abs(peakTimesInBatch - tSample) <= (1 / fs));
                
                fprintf(csvFid, '%.4f,%.6f,%.6f,%d,%.2f,%.2f\n', ...
                    
            tSample, rawSamp, filtSamp, isRpeak, csvBPM, csvHRV);
            
            end
            
        end
        
        % ── TIME & EXIT ──────────────────────────────────────────────────
        
        dash.updateTime(currentTime, totalSimTime);
        
        if currentTime >= totalSimTime
            
            break;
            
        end
        
        drawnow;
        
    end
    
catch e
    
    fprintf('Error: %s\n', e.message);
    
end

% ── CLEANUP ──────────────────────────────────────────────────────────────

if csvFid ~= -1
    
    fclose(csvFid);
    
    fprintf('CSV saved → %s\n', csvPath);
    
end

if exist('sp', 'var')
    
    try
        
        delete(sp);
        
        disp('Serial port closed.');
        
    catch
        
    end
    
end

if dash.isOpen()
    
    dash.setStatus(['Stream ended | ' csvName]);
    
end

end

% ── SERIAL HELPER ────────────────────────────────────────────────────────────

function line = serial_readline(sp)

% Read one '\n'-terminated line from an instrument-control serialport object.

line = '';

while true
    
    ch = char(read(sp, 1, 'uint8'));
    
    if isempty(ch)
        
        break;
        
    end
    
    if ch == newline || ch == char(13)
        
        break;
        
    end
    
    line(end+1) = ch;
    
end

line = strtrim(line);

end

% ── DSP HELPERS ──────────────────────────────────────────────────────────────

function y = preprocess_ecg(x, fs)

x = double(x(:).');

x = x - mean(x);

w = max(3, round(0.60 * fs));

baseline = movmean(x, w);

y = x - baseline;

hp = 0.5;

lp = min(15, 0.45 * fs);

if lp > hp && fs > 40
    
    [b, a] = butter(2, [hp lp] / (fs/2), 'bandpass');
    
    minLen = 3 * (max(length(a), length(b)) - 1);
    
    if numel(y) > minLen
        
        y = filtfilt(b, a, y);
        
    elseif numel(y) > max(length(a), length(b))
        
        y = filter(b, a, y);
        
    end
    
end

y = y / (max(abs(y)) + eps);

end

function [t_up, y_up] = upsample_for_display(t, y, displayFs)

if numel(t) < 2
    
    t_up = t; y_up = y; return;
    
end

t_up = t(1) : 1/displayFs : t(end);

y_up = interp1(t, y, t_up, 'pchip');

y_up = y_up / (max(abs(y_up)) + eps);

end

function [locs, pks] = detect_rpeaks_sharp(y, fs)

y = y(:).';

qrs = y;

if fs > 50
    
    [b, a] = butter(2, [8 22] / (fs/2), 'bandpass');
    
    minLen = 3 * (max(length(a), length(b)) - 1);
    
    if numel(y) > minLen
        
        qrs = filtfilt(b, a, y);
        
    elseif numel(y) > max(length(a), length(b))
        
        qrs = filter(b, a, y);
        
    end
    
end

env = qrs .^ 2;

thr = mean(env) + 0.5 * std(env);

minDist = round(0.35 * fs);

roughLocs = simple_peak_pick(env, thr, minDist);

refineWin = round(0.05 * fs);

locs = zeros(size(roughLocs));

for k = 1:numel(roughLocs)
    
    i1 = max(1, roughLocs(k) - refineWin);
    
    i2 = min(length(y), roughLocs(k) + refineWin);
    
    [~, idx] = max(y(i1:i2));
    
    locs(k) = i1 + idx - 1;
    
end

locs = unique(locs);

pks = y(locs);

end

function locs = simple_peak_pick(sig, thr, minDist)

locs = [];

for i = 2:length(sig)-1
    
    if sig(i) > sig(i-1) && sig(i) >= sig(i+1) && sig(i) > thr
        
        if isempty(locs)
            
            locs(end+1) = i;
            
        elseif (i - locs(end)) > minDist
            
            locs(end+1) = i;
            
        elseif sig(i) > sig(locs(end))
            
            locs(end) = i;
            
        end
        
    end
    
end

end

%% Stream A Code

% STREAM A: DeNoising (Classical Filtering) - RECORDED DATA

clc; clear; close all;

pkg load signal; % Required for Octave

% A.1 - Signal Loading

filename = 'ECG_20260511_230935 (raw - no filter).csv';

data = csvread(filename, 1, 0);

t = data(:, 1)';

raw_ecg = data(:, 2)';

fs = 125;

% Optional: Trim data to the first 10 seconds for clearer plotting

if length(t) > 10*fs
    
    t = t(1:10*fs);
    
    raw_ecg = raw_ecg(1:10*fs);
    
end

% [PLOT 1] Raw Time Domain

figure('Name', 'A.1 Time-Domain Inspection');

plot(t, raw_ecg);

title('Raw Recorded ECG Signal'); xlabel('Time (s)'); ylabel('Amplitude');

% A.2 - FFT & Frequency-Domain Analysis

N = length(raw_ecg);

f = (0:N/2-1)*(fs/N);

X = fft(raw_ecg);

P1 = abs(X/N);

P1 = P1(1:N/2);

P1(2:end-1) = 2*P1(2:end-1);

% [PLOT 2] Raw Frequency Domain

figure('Name', 'A.2 Frequency Spectrum');

plot(f, P1);

title('Single-Sided Amplitude Spectrum (Raw)');

xlabel('Frequency (Hz)'); ylabel('|P1(f)|');

xlim([0 fs/2]);

% A.3 - Noise Power Estimation (Pre-filtering)

sig_idx = find(f >= 0.5 & f <= 40);

noise_idx = find((f >= 0 & f < 0.5) | (f >= 49 & f <= 51) | (f > 40));

P_signal_pre = sum(P1(sig_idx).^2);

P_noise_pre = sum(P1(noise_idx).^2);

SNR_pre = 10 * log10(P_signal_pre / P_noise_pre);

% A.4 - A.6 Filter Design (OCTAVE SAFE)

% 1. High-Pass (Baseline) - FIR

hp_order = round(1.5 * fs);

b_hp = fir1(hp_order, 0.5/(fs/2), 'high');

a_hp = 1;

% 2. Notch (Powerline 50Hz) - Narrow Butterworth Bandstop

notch_freqs = [49.5 50.5] / (fs/2);

[b_notch, a_notch] = butter(2, notch_freqs, 'stop');

% 3. Low-Pass (EMG) - FIR

lp_order = round(0.5 * fs);

b_lp = fir1(lp_order, 40/(fs/2), 'low');

a_lp = 1;

% [PLOT 3] Magnitude and Phase Responses for all 3 filters

figure('Name', 'Filter Mag & Phase Responses');

subplot(3,1,1); freqz(b_hp, a_hp, 1024, fs); title('High-Pass Filter (0.5 Hz)');

subplot(3,1,2); freqz(b_notch, a_notch, 1024, fs); title('Notch Bandstop Filter (50 Hz)');

subplot(3,1,3); freqz(b_lp, a_lp, 1024, fs); title('Low-Pass Filter (40 Hz)');

% A.7 - Combined Pipeline (Time Domain)

ecg_hp = filter(b_hp, a_hp, raw_ecg);

ecg_notch = filter(b_notch, a_notch, ecg_hp);

ecg_clean = filter(b_lp, a_lp, ecg_notch);

% Delay compensation for FIR filters

total_delay = round(hp_order/2 + lp_order/2);

ecg_clean_shifted = [ecg_clean(total_delay+1:end), zeros(1, total_delay)];

% [PLOT 4] Time Domain Before vs After

figure('Name', 'A.7 Time Domain Comparison');

subplot(2,1,1); plot(t, raw_ecg); title('Raw Recorded ECG');

subplot(2,1,2); plot(t, ecg_clean_shifted); title('Filtered ECG (Delay Compensated)'); xlabel('Time (s)');

% A.7 - Combined Pipeline (Frequency Domain Before/After)

X_clean = fft(ecg_clean_shifted);

P1_clean = abs(X_clean/N);

P1_clean = P1_clean(1:N/2);

P1_clean(2:end-1) = 2*P1_clean(2:end-1);

% [PLOT 5] Freq Domain Before vs After

figure('Name', 'Frequency Domain Comparison');

subplot(2,1,1); plot(f, P1); title('Raw Spectrum'); xlim([0 fs/2]); ylabel('Magnitude');

subplot(2,1,2); plot(f, P1_clean); title('Cleaned Spectrum'); xlim([0 fs/2]); xlabel('Frequency (Hz)'); ylabel('Magnitude');

% SNR Computation (Post-filtering)

P_signal_post = sum(P1_clean(sig_idx).^2);

P_noise_post = sum(P1_clean(noise_idx).^2);

SNR_post = 10 * log10(P_signal_post / P_noise_post);

% Print SNR Table to Command Window

fprintf('\n====================================\n');

fprintf(' SNR COMPUTATION TABLE (dB) \n');

fprintf('====================================\n');

fprintf(' Pre-filtering SNR: %8.2f dB\n', SNR_pre);

fprintf(' Post-filtering SNR: %8.2f dB\n', SNR_post);

fprintf(' SNR Improvement: %8.2f dB\n', SNR_post - SNR_pre);

fprintf('====================================\n\n');

% A.8 - Group Delay Analysis for ALL Filters

[gd_hp, w_hp] = grpdelay(b_hp, a_hp, 1024, fs);

[gd_notch, w_notch] = grpdelay(b_notch, a_notch, 1024, fs);

[gd_lp, w_lp] = grpdelay(b_lp, a_lp, 1024, fs);

% [PLOT 6] Group Delays

figure('Name', 'A.8 Group Delay for All Filters');

subplot(3,1,1); plot(w_hp, gd_hp); title('Group Delay: FIR High-Pass'); ylabel('Samples');

subplot(3,1,2); plot(w_notch, gd_notch); title('Group Delay: IIR Notch'); ylabel('Samples');

subplot(3,1,3); plot(w_lp, gd_lp); title('Group Delay: FIR Low-Pass'); ylabel('Samples'); xlabel('Frequency (Hz)');

%% Stream B Code:

% STREAM B: Motion Artifact Removal - REAL RECORDED DATA & OCTAVE SAFE
clc; clear; close all;

pkg load signal;

% B.1 - Load Data
filename = 'ECG_20260510_012003 (artifact - rapid breathing).csv';
data = csvread(filename, 1, 0);
t = data(:, 1)';
ecg_noisy = data(:, 2)';
fs = 125;

% Trim to a 10-second window that explicitly contains the artifact
if length(t) > 10*fs
    t = t(1:10*fs);
    ecg_noisy = ecg_noisy(1:10*fs);
end

% B.2 - Fixed Filter Failure
[b, a] = butter(2, [0.5 40]/(fs/2), 'bandpass');
ecg_fixed = filter(b, a, ecg_noisy);

figure('Name', 'B.2 Fixed Filter Failure');
plot(t, ecg_noisy, 'b', t, ecg_fixed, 'r', 'LineWidth', 1.5);
title('Fixed Filter Fails on Transient Artifacts');
legend('Recorded Noisy Signal', 'Fixed Filtered (Notice Ringing/Distortion)');
xlabel('Time (s)');
ylabel('Amplitude');

% B.3 - Time-Frequency Analysis (3 STFT Window Sizes - MANUAL OCTAVE STFT)
disp('Running B.3: Computing STFT for 3 different window sizes...');
win_lengths = [round(0.1*fs), round(0.5*fs), round(1.0*fs)];

figure('Name', 'B.3 STFT Window Size Comparison');
for i = 1:3
    win_len = win_lengths(i);
    win = hamming(win_len)';
    noverlap = round(win_len * 0.8);
    step_size = win_len - noverlap;
    nfft = 512;

    num_cols = floor((length(ecg_noisy) - win_len) / step_size) + 1;
    S = zeros(nfft/2 + 1, num_cols);
    t_spec = zeros(1, num_cols);

    for k = 1:num_cols
        idx_start = (k-1)*step_size + 1;
        idx_end = idx_start + win_len - 1;
        segment = ecg_noisy(idx_start:idx_end) .* win;
        X = fft(segment, nfft);
        S(:, k) = X(1:nfft/2 + 1);
        t_spec(k) = t(idx_start + round(win_len/2));
    end

    f_spec = (0:nfft/2) * (fs/nfft);
    subplot(3, 1, i);
    imagesc(t_spec, f_spec, 10*log10(abs(S) + eps));
    axis xy;
    title(sprintf('Spectrogram (Window = %.1f s)', win_lengths(i)/fs));
    ylabel('Freq (Hz)');
    if i == 3
        xlabel('Time (s)');
    end
end
drawnow;

% B.4 & B.5 - Frame-based Artifact Detection
disp('Running B.4 & B.5: Performing frame-based artifact detection...');
frame_len = round(0.5 * fs);
step_size = round(0.25 * fs);
num_frames = floor((length(ecg_noisy) - frame_len) / step_size) + 1;

variance_thresh = var(ecg_noisy) * 2;
is_artifact = zeros(1, num_frames);
detected_count = 0;

for i = 1:num_frames
    idx_start = (i-1)*step_size + 1;
    idx_end = idx_start + frame_len - 1;
    if var(ecg_noisy(idx_start:idx_end)) > variance_thresh
        is_artifact(i) = 1;
        detected_count = detected_count + 1;
    end
end

fprintf(' -> Detected %d corrupted frames out of %d total frames.\n', detected_count, num_frames);

% Plot: Highlight Artifacts
figure('Name', 'B.4 & B.5 Artifact Detection');
plot(t, ecg_noisy, 'k', 'LineWidth', 1);
hold on;
for i = 1:num_frames
    if is_artifact(i) == 1
        idx_start = (i-1)*step_size + 1;
        idx_end = idx_start + frame_len - 1;
        plot(t(idx_start:idx_end), ecg_noisy(idx_start:idx_end), 'r', 'LineWidth', 1.5);
    end
end
title('Artifact Detection (Red = Flagged as Corrupted)');
xlabel('Time (s)');
ylabel('Amplitude');
h1 = plot(NaN, NaN, 'k', 'LineWidth', 1);
h2 = plot(NaN, NaN, 'r', 'LineWidth', 1.5);
legend([h1, h2], 'Clean Signal', 'Detected Artifact Region');
drawnow;

% B.6 - Artifact Suppression (Two Methods)
disp('Running B.6 & B.7: Removing artifacts and computing metrics...');

ecg_interp = ecg_noisy;
for i = 1:num_frames
    if is_artifact(i) == 1
        idx_start = (i-1)*step_size + 1;
        idx_end = idx_start + frame_len - 1;
        ecg_interp(idx_start:idx_end) = linspace(ecg_interp(idx_start), ecg_interp(idx_end), frame_len);
    end
end

ecg_median = ecg_noisy;
med_window = round(0.4 * fs);
for i = 1:num_frames
    if is_artifact(i) == 1
        idx_start = (i-1)*step_size + 1;
        idx_end = idx_start + frame_len - 1;
        segment = ecg_noisy(idx_start:idx_end);
        ecg_median(idx_start:idx_end) = segment - medfilt1(segment, med_window);
    end
end

figure('Name', 'B.6 Artifact Removal Methods');
subplot(3,1,1); plot(t, ecg_noisy, 'k'); title('Original Corrupted Signal');
subplot(3,1,2); plot(t, ecg_interp, 'b'); title('Method 1: Segment Interpolation');
subplot(3,1,3); plot(t, ecg_median, 'r'); title('Method 2: Adaptive Median Filtering'); xlabel('Time (s)');

% B.7 - Quantitative Performance Comparison
art_idx = find(is_artifact == 1);
if ~isempty(art_idx)
    var_noisy = var(ecg_noisy);
    var_interp = var(ecg_interp);
    var_median = var(ecg_median);

    snr_interp = 10 * log10(var_interp / abs(var_noisy - var_interp + eps));
    snr_median = 10 * log10(var_median / abs(var_noisy - var_median + eps));

    rmse_interp = sqrt(mean((ecg_noisy - ecg_interp).^2));
    rmse_median = sqrt(mean((ecg_noisy - ecg_median).^2));

    fprintf('\n======================================================\n');
    fprintf(' B.7 QUANTITATIVE COMPARISON (Artifact Regions) \n');
    fprintf('======================================================\n');
    fprintf(' Metric | Interpolation | Median Filter \n');
    fprintf('------------------------------------------------------\n');
    fprintf(' Est. SNR Improvement | %8.2f dB | %8.2f dB\n', snr_interp, snr_median);
    fprintf(' RMS Error (vs Raw) | %8.4f | %8.4f\n', rmse_interp, rmse_median);
    fprintf('======================================================\n\n');
else
    disp('No artifacts detected to compare. Try lowering variance_thresh.');
end

% Stream C was done in python