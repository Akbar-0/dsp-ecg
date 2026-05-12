% STREAM B: Motion Artifact Removal - REAL RECORDED DATA & OCTAVE SAFE
clc; clear; close all;
pkg load signal;

%% B.1 - Load Data
filename = 'ECG_20260510_005729 (artifact - tapping patches).csv';

data = csvread(filename, 1, 0);
t = data(:, 1)';
ecg_noisy = data(:, 2)';
fs = 125;

% Trim to a 10-second window that explicitly contains the artifact
if length(t) > 10*fs
    t = t(1:10*fs);
    ecg_noisy = ecg_noisy(1:10*fs);
end

%% B.2 - Fixed Filter Failure
[b, a] = butter(2, [0.5 40]/(fs/2), 'bandpass');
ecg_fixed = filter(b, a, ecg_noisy);

figure('Name', 'B.2 Fixed Filter Failure');
plot(t, ecg_noisy, 'b', t, ecg_fixed, 'r', 'LineWidth', 1.5);
title('Fixed Filter Fails on Transient Artifacts');
legend('Recorded Noisy Signal', 'Fixed Filtered (Notice Ringing/Distortion)');
xlabel('Time (s)'); ylabel('Amplitude');

%% B.3 - Time-Frequency Analysis (3 STFT Window Sizes - MANUAL OCTAVE STFT)
disp('Running B.3: Computing STFT for 3 different window sizes...');
win_lengths = [round(0.1*fs), round(0.5*fs), round(1.0*fs)]; % 0.1s, 0.5s, 1.0s
figure('Name', 'B.3 STFT Window Size Comparison');

for i = 1:3
    win_len = win_lengths(i);
    win = hamming(win_len)'; % Ensure row vector
    noverlap = round(win_len * 0.8); % 80% overlap
    step_size = win_len - noverlap;
    nfft = 512;

    % Prepare manual STFT matrix
    num_cols = floor((length(ecg_noisy) - win_len) / step_size) + 1;
    S = zeros(nfft/2 + 1, num_cols);
    t_spec = zeros(1, num_cols);

    % Loop to calculate FFT frame by frame
    for k = 1:num_cols
        idx_start = (k-1)*step_size + 1;
        idx_end = idx_start + win_len - 1;

        segment = ecg_noisy(idx_start : idx_end) .* win;
        X = fft(segment, nfft);
        S(:, k) = X(1 : nfft/2 + 1);
        t_spec(k) = t(idx_start + round(win_len/2));
    end

    f_spec = (0:nfft/2) * (fs/nfft);

    subplot(3, 1, i);
    % eps prevents log10(0) errors
    imagesc(t_spec, f_spec, 10*log10(abs(S) + eps));
    axis xy;
    title(sprintf('Spectrogram (Window = %.1f s)', win_lengths(i)/fs));
    ylabel('Freq (Hz)');
    if i == 3; xlabel('Time (s)'); end
end
drawnow;

%% B.4 & B.5 - Frame-based Artifact Detection
disp('Running B.4 & B.5: Performing frame-based artifact detection...');
frame_len = round(0.5 * fs);
step_size = round(0.25 * fs);
num_frames = floor((length(ecg_noisy) - frame_len) / step_size) + 1;

% Dynamic threshold: 2x the variance of the overall signal
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
plot(t, ecg_noisy, 'k', 'LineWidth', 1); hold on;

for i = 1:num_frames
    if is_artifact(i) == 1
        idx_start = (i-1)*step_size + 1;
        idx_end = idx_start + frame_len - 1;
        plot(t(idx_start:idx_end), ecg_noisy(idx_start:idx_end), 'r', 'LineWidth', 1.5);
    end
end

title('Artifact Detection (Red = Flagged as Corrupted)');
xlabel('Time (s)'); ylabel('Amplitude');
h1 = plot(NaN, NaN, 'k', 'LineWidth', 1);
h2 = plot(NaN, NaN, 'r', 'LineWidth', 1.5);
legend([h1, h2], 'Clean Signal', 'Detected Artifact Region');
drawnow;

%% B.6 - Artifact Suppression (Two Methods)
disp('Running B.6 & B.7: Removing artifacts and computing metrics...');
% Method 1: Interpolation
ecg_interp = ecg_noisy;
for i = 1:num_frames
    if is_artifact(i) == 1
        idx_start = (i-1)*step_size + 1;
        idx_end = idx_start + frame_len - 1;
        ecg_interp(idx_start:idx_end) = linspace(ecg_interp(idx_start), ecg_interp(idx_end), frame_len);
    end
end

% Method 2: Median Filtering
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

%% B.7 - Quantitative Performance Comparison
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
    fprintf('  B.7 QUANTITATIVE COMPARISON (Artifact Regions)        \n');
    fprintf('======================================================\n');
    fprintf(' Metric               | Interpolation | Median Filter \n');
    fprintf('------------------------------------------------------\n');
    fprintf(' Est. SNR Improvement | %8.2f dB   | %8.2f dB\n', snr_interp, snr_median);
    fprintf(' RMS Error (vs Raw)   | %8.4f      | %8.4f\n', rmse_interp, rmse_median);
    fprintf('======================================================\n\n');
else
    disp('No artifacts detected to compare. Try lowering variance_thresh.');
end
