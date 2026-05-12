function ecg_dashboard_raw
% ECG_DASHBOARD  Real-time ECG monitor for Octave + instrument-control package.
%
% Packages required:
%   instrument-control  — serial port I/O
%   signal              — butter / filtfilt
%
% Output:
%   ECG_<YYYYMMDD_HHMMSS>.csv  saved in the same folder as this script.
%   Columns: time_s, raw_normalised, filtered, r_peak (0/1), bpm, hrv_ms

    clc; clear; clear functions; close all;

    %% ── Load required Octave packages ────────────────────────────────────────
    pkg load instrument-control;
    pkg load signal;

    %% ── SERIAL SETTINGS ──────────────────────────────────────────────────────
    comPort         = 'COM8';
    baudRate        = 115200;
    fs              = 125;
    serialBatchSize = 13;

    %% ── DASHBOARD SETTINGS ───────────────────────────────────────────────────
    displayWindow = 10;
    bpmWindow     = 5;
    hrvWindow     = 30;
    totalSimTime  = 120;

    %% ── CSV OUTPUT ───────────────────────────────────────────────────────────
    scriptDir = fileparts(mfilename('fullpath'));
    if isempty(scriptDir)
        scriptDir = pwd;
    end
    csvName = ['ECG_' datestr(now, 'yyyymmdd_HHMMSS') '.csv'];
    csvPath = fullfile(scriptDir, csvName);
    csvFid  = fopen(csvPath, 'w');
    if csvFid == -1
        warning('Could not open %s for writing — CSV will not be saved.', csvPath);
        csvFid = -1;
    else
        fprintf(csvFid, 'time_s,raw_normalised,filtered,r_peak,bpm,hrv_ms\n');
        fprintf('CSV recording → %s\n', csvPath);
    end

    csvBPM = NaN;
    csvHRV = NaN;

    %% ── OPEN SERIAL PORT ─────────────────────────────────────────────────────
    sp = serialport(comPort, baudRate);

    disp('Waiting for ESP32 sync header...');
    while true
        line = serial_readline(sp);
        if ~isempty(line) && line(1) == '#'
            fprintf('Sync received: %s\n', line);
            break;
        end
    end

    %% ── DASHBOARD INIT ───────────────────────────────────────────────────────
    dash = dashboard_app();
    dash.initialize('Live ESP32 ECG (AD8232)', [], fs, totalSimTime);
    dash.setStatus('Streaming...');

    %% ── BUFFERS ──────────────────────────────────────────────────────────────
    x                = [];
    t                = [];
    peakTimes        = [];
    lastAcceptedPeak = -inf;
    lastBPMUpdate    = 0;
    peakMergeTol     = 0.40;
    rrMin            = 0.40;
    rrMax            = 1.50;

    sampleCount      = 0;
    leadOffStreak    = 0;
    maxLeadOffWarn   = fs * 2;

    %% ── MAIN LOOP ────────────────────────────────────────────────────────────
    try
        while dash.isOpen()

            batchRaw = zeros(1, serialBatchSize);
            batchN   = 0;

            while batchN < serialBatchSize
                line = serial_readline(sp);

                if isempty(line) || line(1) == '#'
                    continue;
                end

                parts = strsplit(line, ',');
                if numel(parts) ~= 3
                    continue;
                end

                rawVal  = str2double(parts{2});
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

                normalised = (rawVal / 4095) * 2 - 1;

                batchN = batchN + 1;
                batchRaw(batchN) = normalised;
            end

            batchRaw = batchRaw(1:batchN);
            if batchN == 0
                continue;
            end

            newSamples  = sampleCount : sampleCount + batchN - 1;
            batchT      = newSamples / fs;
            sampleCount = sampleCount + batchN;

            x = [x batchRaw];
            t = [t batchT];

            %% ── DISPLAY WINDOW ───────────────────────────────────────────────
            maxSamples = fs * displayWindow;
            if length(x) > maxSamples
                x_disp = x(end - maxSamples + 1 : end);
                t_disp = t(end - maxSamples + 1 : end);
            else
                x_disp = x;
                t_disp = t;
            end

            %% ── PROCESS & PEAK DETECT ────────────────────────────────────────
            y = preprocess_ecg(x_disp, fs);
            [t_up, y_up] = upsample_for_display(t_disp, y, fs * 8);
            [locs, pks]  = detect_rpeaks_sharp(y_up, fs * 8);

            %% ── DASHBOARD PLOTS ──────────────────────────────────────────────
            dash.updateRealtimePlot(t_up, y_up, locs, pks);

            if ~isempty(locs)
                halfWin = round(0.40 * fs * 8);
                rIdx    = locs(end);
                i1      = max(1, rIdx - halfWin);
                i2      = min(length(y_up), rIdx + halfWin);
                cycle   = y_up(i1:i2);
                if length(cycle) > 4
                    dash.updateCyclePlot(cycle, fs * 8);
                end
            end

            if isfield(dash, 'updateFFT')
                dash.updateFFT(y_up, fs * 8);
            end

            %% ── PEAK ACCUMULATION ────────────────────────────────────────────
            pt = t_up(locs);
            for k = 1:length(pt)
                if pt(k) > (lastAcceptedPeak + peakMergeTol)
                    peakTimes(end+1) = pt(k);
                    lastAcceptedPeak = pt(k);
                end
            end

            currentTime = t(end);

            %% ── BPM ──────────────────────────────────────────────────────────
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

            %% ── HRV ──────────────────────────────────────────────────────────
            if currentTime >= hrvWindow && length(peakTimes) >= 3
                recentHrvPeaks = peakTimes(peakTimes >= currentTime - hrvWindow);
                if length(recentHrvPeaks) >= 3
                    rr_all = diff(recentHrvPeaks);
                    rr_all = rr_all(rr_all >= rrMin & rr_all <= rrMax);

                    if length(rr_all) >= 3
                        rrMed  = median(rr_all);
                        rr_all = rr_all(abs(rr_all - rrMed) <= 0.20 * rrMed);
                    end

                    if length(rr_all) >= 3
                        csvHRV = std(rr_all) * 1000;
                        dash.updateHRV(csvHRV);
                    end
                end
            end

            %% ── CSV WRITE ────────────────────────────────────────────────────
            if csvFid ~= -1
                peakTimesInBatch = t_up(locs);

                dispLen     = length(x_disp);
                batchOffset = dispLen - batchN;

                for si = 1:batchN
                    tSample  = batchT(si);
                    rawSamp  = batchRaw(si);   % raw normalised — no filter applied

                    % filtered column: baseline-removed only (no bandpass)
                    yIdx = batchOffset + si;
                    if yIdx >= 1 && yIdx <= length(y)
                        filtSamp = y(yIdx);
                    else
                        filtSamp = NaN;
                    end

                    isRpeak = any(abs(peakTimesInBatch - tSample) <= (1 / fs));

                    fprintf(csvFid, '%.4f,%.6f,%.6f,%d,%.2f,%.2f\n', ...
                        tSample, rawSamp, filtSamp, isRpeak, csvBPM, csvHRV);
                end
            end

            %% ── TIME & EXIT ──────────────────────────────────────────────────
            dash.updateTime(currentTime, totalSimTime);

            if currentTime >= totalSimTime
                break;
            end

            drawnow;
        end

    catch e
        fprintf('Error: %s\n', e.message);
    end

    %% ── CLEANUP ──────────────────────────────────────────────────────────────
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
        dash.setStatus(['Stream ended  |  ' csvName]);
    end
end

%% ── SERIAL HELPER ────────────────────────────────────────────────────────────

function line = serial_readline(sp)
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

%% ── DSP HELPERS ──────────────────────────────────────────────────────────────

function y = preprocess_ecg(x, fs)
    % Baseline removal only — bandpass filter removed
    x = double(x(:).');
    x = x - mean(x);

    w = max(3, round(0.60 * fs));
    baseline = movmean(x, w);
    y = x - baseline;

    % Normalise amplitude for display
    y = y / (max(abs(y)) + eps);
end

function [t_up, y_up] = upsample_for_display(t, y, displayFs)
    if numel(t) < 2
        t_up = t;  y_up = y;  return;
    end
    t_up = t(1) : 1/displayFs : t(end);
    y_up = interp1(t, y, t_up, 'pchip');
    y_up = y_up / (max(abs(y_up)) + eps);
end

function [locs, pks] = detect_rpeaks_sharp(y, fs)
    % QRS bandpass filter removed — operate directly on input signal
    y   = y(:).';

    env     = y .^ 2;
    thr     = mean(env) + 0.5 * std(env);
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
    pks  = y(locs);
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
