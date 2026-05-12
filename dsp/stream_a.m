% STREAM A: DeNoising (Classical Filtering) - RECORDED DATA
clc; clear; close all;
pkg load signal; % Required for Octave

%% A.1 - Signal Loading
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

%% A.2 - FFT & Frequency-Domain Analysis
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

%% A.3 - Noise Power Estimation (Pre-filtering)
sig_idx = find(f >= 0.5 & f <= 40);
noise_idx = find((f >= 0 & f < 0.5) | (f >= 49 & f <= 51) | (f > 40));

P_signal_pre = sum(P1(sig_idx).^2);
P_noise_pre  = sum(P1(noise_idx).^2);
SNR_pre = 10 * log10(P_signal_pre / P_noise_pre);

%% A.4 - A.6 Filter Design (OCTAVE SAFE)
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

%% A.7 - Combined Pipeline (Time Domain)
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

%% A.7 - Combined Pipeline (Frequency Domain Before/After)
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
P_noise_post  = sum(P1_clean(noise_idx).^2);
SNR_post = 10 * log10(P_signal_post / P_noise_post);

% Print SNR Table to Command Window
fprintf('\n====================================\n');
fprintf('     SNR COMPUTATION TABLE (dB)     \n');
fprintf('====================================\n');
fprintf(' Pre-filtering SNR:   %8.2f dB\n', SNR_pre);
fprintf(' Post-filtering SNR:  %8.2f dB\n', SNR_post);
fprintf(' SNR Improvement:     %8.2f dB\n', SNR_post - SNR_pre);
fprintf('====================================\n\n');

%% A.8 - Group Delay Analysis for ALL Filters
[gd_hp, w_hp] = grpdelay(b_hp, a_hp, 1024, fs);
[gd_notch, w_notch] = grpdelay(b_notch, a_notch, 1024, fs);
[gd_lp, w_lp] = grpdelay(b_lp, a_lp, 1024, fs);

% [PLOT 6] Group Delays
figure('Name', 'A.8 Group Delay for All Filters');
subplot(3,1,1); plot(w_hp, gd_hp); title('Group Delay: FIR High-Pass'); ylabel('Samples');
subplot(3,1,2); plot(w_notch, gd_notch); title('Group Delay: IIR Notch'); ylabel('Samples');
subplot(3,1,3); plot(w_lp, gd_lp); title('Group Delay: FIR Low-Pass'); ylabel('Samples'); xlabel('Frequency (Hz)');
