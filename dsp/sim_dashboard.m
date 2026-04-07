function sim_dashboard
    clc; clear; close all;

    %% SETTINGS
    fileName = resolve_data_file();
    fs = 125;
    displayWindow = 10;
    bpmWindow = 10;
    hrvWindow = 60;
    totalSimTime = 120;

    %% LOAD DATA
    if strlength(fileName) == 0
        error("No ECG data file selected.");
    end

    if ~isfile(fileName)
        error("File not found: " + fileName);
    end

    data = readmatrix(fileName);

    if isempty(data)
        error("The file was found, but no data could be read.");
    end

    signals = data(:,1:end-1);
    labels  = data(:,end);

    % remove rows with NaN if any
    validRows = all(~isnan(signals),2) & ~isnan(labels);
    signals = signals(validRows,:);
    labels  = labels(validRows);

    if isempty(signals)
        error("No valid ECG rows found in the file.");
    end

    % pick one normal and one abnormal beat
    normalIdx = find(labels == 0, 1, 'first');
    abnormalIdx = find(labels ~= 0, 1, 'first');

    if isempty(normalIdx)
        error("No normal beat with label 0 found.");
    end
    if isempty(abnormalIdx)
        error("No abnormal beat found.");
    end

    normalBeat = signals(normalIdx, :);
    abnormalBeat = signals(abnormalIdx, :);
    abnormalLabel = labels(abnormalIdx);

    %% SHOW DATASET EXAMPLES
    figure('Name','Dataset ECG Beats','Color','w');

    subplot(2,1,1);
    plot(normalBeat,'b','LineWidth',1.5);
    title('Normal ECG Beat (Label = 0)');
    xlabel('Sample Index');
    ylabel('Amplitude');
    grid on;

    subplot(2,1,2);
    plot(abnormalBeat,'r','LineWidth',1.5);
    title(['Abnormal ECG Beat (Label = ' num2str(abnormalLabel) ')']);
    xlabel('Sample Index');
    ylabel('Amplitude');
    grid on;

    %% BUILD CONTINUOUS SIGNAL FROM NORMAL BEATS
    normalBeats = signals(labels == 0,:);
    [t_all, x_all] = build_stream(normalBeats, fs, totalSimTime);

    %% CREATE DASHBOARD
    fig = uifigure('Name','ECG Dashboard','Position',[100 100 1000 700]);

    ax1 = uiaxes(fig,'Position',[50 400 900 250]);
    title(ax1,'Real-Time ECG');
    xlabel(ax1,'Time (s)');
    ylabel(ax1,'Amplitude');

    ax2 = uiaxes(fig,'Position',[50 120 420 200]);
    title(ax2,'One ECG Cycle');
    xlabel(ax2,'Time (s)');
    ylabel(ax2,'Amplitude');

    panel = uipanel(fig,'Title','Results','Position',[550 120 250 200]);

    bpmLabel = uilabel(panel,'Text','Heart Rate: -- BPM', ...
        'Position',[20 110 220 30],'FontSize',16,'FontWeight','bold');

    hrvLabel = uilabel(panel,'Text','HRV: -- ms', ...
        'Position',[20 60 220 30],'FontSize',16,'FontWeight','bold');

    %% BUFFERS
    x = [];
    t = [];
    peakTimes = [];
    lastBPMUpdate = 0;

    %% MAIN LOOP
    for n = 1:length(x_all)
        if ~isvalid(fig)
            break;
        end

        num = x_all(n);
        x(end+1) = num; %#ok<AGROW>
        t(end+1) = t_all(n); %#ok<AGROW>

        % keep only last displayWindow seconds
        maxSamples = fs * displayWindow;
        if length(x) > maxSamples
            x_disp = x(end-maxSamples+1:end);
            t_disp = t(end-maxSamples+1:end);
        else
            x_disp = x;
            t_disp = t;
        end

        % filtering
        y = simple_filter(x_disp, fs);

        % peak detection
        [locs, pks] = detect_peaks(y, fs);

        % real-time ECG plot
        plot(ax1, t_disp, y, 'b', 'LineWidth', 1.1);
        hold(ax1, 'on');
        if ~isempty(locs)
            plot(ax1, t_disp(locs), pks, 'ro', 'MarkerFaceColor', 'r');
        end
        hold(ax1, 'off');

        if numel(t_disp) > 1
            xlim(ax1, [t_disp(1) t_disp(end)]);
        end

        % one ECG cycle
        cla(ax2);
        if length(locs) >= 2
            cycle = y(locs(end-1):locs(end));
            tc = (0:length(cycle)-1)/fs;
            plot(ax2, tc, cycle, 'k', 'LineWidth', 1.5);
            title(ax2, 'One ECG Cycle');
            xlabel(ax2, 'Time (s)');
            ylabel(ax2, 'Amplitude');
        end

        % store unique peak times
        pt = t_disp(locs);
        for k = 1:length(pt)
            if isempty(peakTimes) || min(abs(peakTimes - pt(k))) > 0.2
                peakTimes(end+1) = pt(k); %#ok<AGROW>
            end
        end

        currentTime = t(end);

        % BPM every 10 seconds
        if currentTime >= bpmWindow && (currentTime - lastBPMUpdate) >= bpmWindow
            recent = peakTimes(peakTimes >= currentTime - bpmWindow);
            if length(recent) >= 2
                rr = diff(recent);
                bpm = 60 / mean(rr);
                bpmLabel.Text = ['Heart Rate: ' num2str(bpm, '%.1f') ' BPM'];
            end
            lastBPMUpdate = currentTime;
        end

        % HRV after 1 minute
        if currentTime >= hrvWindow && length(peakTimes) >= 3
            rr_all = diff(peakTimes);
            hrv = std(rr_all) * 1000;
            hrvLabel.Text = ['HRV: ' num2str(hrv, '%.1f') ' ms'];
        end

        drawnow;
        pause(1/fs);
    end
end

function fileName = resolve_data_file()
    % Prefer a repo-local default, then ask user to pick any CSV.
    scriptDir = fileparts(mfilename('fullpath'));
    defaultFile = fullfile(scriptDir, 'mitbih_test.csv');

    if isfile(defaultFile)
        fileName = string(defaultFile);
        return;
    end

    [f, p] = uigetfile({'*.csv', 'CSV Files (*.csv)'}, 'Select MIT-BIH CSV file');
    if isequal(f, 0)
        fileName = "";
    else
        fileName = string(fullfile(p, f));
    end
end

%% ===== HELPER FUNCTIONS =====

function [t, x] = build_stream(beats, fs, totalTime)
    x = [];

    while length(x)/fs < totalTime
        b = beats(randi(size(beats,1)), :);

        % remove trailing zeros if present
        nz = find(abs(b) > 1e-8, 1, 'last');
        if ~isempty(nz)
            b = b(1:nz);
        end

        % normalize beat
        b = b - mean(b);
        b = b / (max(abs(b)) + eps);

        % RR interval
        rr = 0.8 + 0.2*rand;
        L = round(rr * fs);

        seg = zeros(1, L);
        copyLen = min(L, length(b));
        seg(1:copyLen) = b(1:copyLen);

        % add mild drift and noise
        tt = (0:L-1)/fs;
        seg = seg + 0.02*sin(2*pi*0.25*tt) + 0.01*randn(size(seg));

        x = [x seg]; %#ok<AGROW>
    end

    t = (0:length(x)-1)/fs;
end

function y = simple_filter(x, fs)
    w = round(0.6 * fs);
    if w < 3
        w = 3;
    end

    baseline = movmean(x, w);
    y = x - baseline;

    y = movmean(y, 5);

    y = y / (max(abs(y)) + eps);
end

function [locs, pks] = detect_peaks(y, fs)
    locs = [];
    pks = [];

    thr = mean(y) + 0.4 * std(y);
    minDist = round(0.4 * fs);

    for i = 2:length(y)-1
        if y(i) > y(i-1) && y(i) >= y(i+1) && y(i) > thr
            if isempty(locs)
                locs(end+1) = i; %#ok<AGROW>
                pks(end+1) = y(i); %#ok<AGROW>
            else
                if (i - locs(end)) > minDist
                    locs(end+1) = i; %#ok<AGROW>
                    pks(end+1) = y(i); %#ok<AGROW>
                elseif y(i) > pks(end)
                    locs(end) = i;
                    pks(end) = y(i);
                end
            end
        end
    end
end
