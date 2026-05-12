function ecg_dashboard_1a
    clc; clear; close all;

    %% ── SERIAL SETTINGS ──
    comPort   = 'COM23';
    baudRate  = 115200;
    fs        = 500;
    % At 500 Hz, 50 samples = 100 ms per refresh — same wall-clock cadence as
    % before (13 samples @ 125 Hz was also ~104 ms).
    serialBatchSize = 50;

    %% ── DASHBOARD SETTINGS ──
    displayWindow = 6;    % seconds — keep plot uncluttered at 500 Hz
                          % (was 10 s @ 125 Hz → same ~750 visible samples)
    bpmWindow     = 10;
    hrvWindow     = 60;
    totalSimTime  = 120;

    %% ── OPEN SERIAL PORT ──
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

    %% ── DASHBOARD INIT ──
    dash = dashboard_app;
    dash.initialize('Live ESP32 ECG (AD8232)', [], fs, totalSimTime);
    dash.setStatus('Streaming...');

    %% ── BUFFERS ──
    x              = [];
    t              = [];
    peakTimes      = [];
    lastAcceptedPeak = -inf;
    lastBPMUpdate  = 0;
    peakMergeTol   = 0.25;
    rrMin          = 0.35;
    rrMax          = 1.50;

    sampleCount    = 0;
    leadOffStreak  = 0;
    maxLeadOffWarn = fs * 2;

    %% ── MAIN LOOP ──
    try
        while dash.isOpen()

            batchRaw = zeros(1, serialBatchSize);
            batchN   = 0;

            while batchN < serialBatchSize
                line = strtrim(readline(sp));

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
            batchT     = newSamples / fs;
            sampleCount = sampleCount + batchN;

            x = [x batchRaw];
            t = [t batchT];

            %% ── DISPLAY WINDOW ──
            maxSamples = fs * displayWindow;
            if length(x) > maxSamples
                x_disp = x(end - maxSamples + 1 : end);
                t_disp = t(end - maxSamples + 1 : end);
            else
                x_disp = x;
                t_disp = t;
            end

            %% ── FILTER & PEAK DETECT ──
            y = preprocess_ecg(x_disp, fs);
            % Upsample factor 4 instead of 8 — at 500 Hz native the signal is
            % already sharp; 8× would push plot points to 20 000+ per refresh.
            displayFs = fs * 4;
            [t_up, y_up] = upsample_for_display(t_disp, y, displayFs);
            [locs, pks]  = detect_rpeaks_sharp(y_up, displayFs);

            %% ── DASHBOARD PLOTS ──
            dash.updateRealtimePlot(t_up, y_up, locs, pks);

            if length(locs) >= 2
                cycle = y_up(locs(end-1) : locs(end));
                dash.updateCyclePlot(cycle, displayFs);
            end

            %% ── PEAK ACCUMULATION ──
            pt = t_up(locs);
            for k = 1:length(pt)
                if pt(k) > (lastAcceptedPeak + peakMergeTol)
                    peakTimes(end+1) = pt(k);
                    lastAcceptedPeak = pt(k);
                end
            end

            currentTime = t(end);

            %% ── BPM ──
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

            %% ── HRV ──
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

            %% ── TIME & EXIT ──
            dash.updateTime(currentTime, totalSimTime);

            if currentTime >= totalSimTime
                break;
            end

            drawnow limitrate nocallbacks;
        end

    catch ME
        fprintf('Error: %s\n', ME.message);
    end

    %% ── CLEANUP ──
    if exist('sp', 'var') && isvalid(sp)
        delete(sp);
        disp('Serial port closed.');
    end

    if dash.isOpen()
        dash.setStatus('Stream ended');
    end
end

%% ── HELPER FUNCTIONS ──

function y = preprocess_ecg(x, fs)
    x = double(x(:).');
    x = x - mean(x);

    w = max(3, round(0.60 * fs));
    baseline = movmean(x, w);
    y = x - baseline;

    if exist('butter','file') == 2 && exist('filtfilt','file') == 2 && fs > 40
        hp = 0.5;
        lp = min(40, 0.45 * fs);   % raised LP ceiling to 40 Hz for 500 Hz input
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
    y   = y(:).';
    qrs = y;

    if exist('butter','file') == 2 && exist('filtfilt','file') == 2 && fs > 50
        [b, a] = butter(2, [8 40] / (fs/2), 'bandpass');  % wider QRS band for 500 Hz
        minLen = 3 * (max(length(a), length(b)) - 1);
        if numel(y) > minLen
            qrs = filtfilt(b, a, y);
        elseif numel(y) > max(length(a), length(b))
            qrs = filter(b, a, y);
        end
    end

    env     = qrs .^ 2;
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
