% STREAM C: Multi-Lead Phase Consistency - OCTAVE SAFE
clc; clear; close all;
pkg load signal;

%% C.1 - Multi-Lead Dataset Loading (PhysioNet PTB Database)
record_name = 'ptbdb/patient001/s0010_re'; % Example real 12-lead record
[sig, fs, tm] = rdsamp(record_name);

t = tm';
num_samples = 2 * fs; % Limit to 2 seconds to clearly see the phase alignment
t = t(1:num_samples);

% Extract Leads (Usually Col 1 = I, Col 7 = V1 in PTB DB)
lead_I = sig(1:num_samples, 1)';
lead_V1 = sig(1:num_samples, 7)';

%% C.2 & C.3 - Demonstrate Phase Distortion
[b, a] = butter(4, 15/(fs/2), 'low'); % Aggressive IIR filter

% Process independently with standard causal filter
filt_I = filter(b, a, lead_I);
filt_V1 = filter(b, a, lead_V1);

figure('Name', 'C.3 Phase Distortion');
plot(t, lead_I, 'k--', t, filt_I, 'r', t, filt_V1, 'b');
title('Timing Shift introduced by Standard IIR Filter');
legend('Original Lead I', 'Filtered Lead I (Delayed)', 'Filtered Lead V1');

%% C.4 - Group Delay Matching (Zero-Phase Filtering)
% filtfilt runs forward and backward, eliminating phase distortion entirely
zero_phase_I = filtfilt(b, a, lead_I);
zero_phase_V1 = filtfilt(b, a, lead_V1);

figure('Name', 'C.4 Zero-Phase Correction');
plot(t, lead_I, 'k--', t, zero_phase_I, 'r', t, zero_phase_V1, 'b');
title('Timing Preserved using Zero-Phase Filtering (filtfilt)');
legend('Original Lead I', 'Zero-Phase Lead I', 'Zero-Phase Lead V1');

%% C.5 - Cross-Correlation Alignment Analysis
[xc_bad, lags_bad] = xcorr(lead_I, filt_I);
[~, max_idx_bad] = max(xc_bad);
lag_samples_bad = lags_bad(max_idx_bad);

[xc_good, lags_good] = xcorr(lead_I, zero_phase_I);
[~, max_idx_good] = max(xc_good);
lag_samples_good = lags_good(max_idx_good);

fprintf('\n======================================================\n');
fprintf('  C.5 CROSS-CORRELATION ALIGNMENT ANALYSIS              \n');
fprintf('======================================================\n');
fprintf('Timing Error (Causal Filter): %d samples (%.2f ms)\n', abs(lag_samples_bad), abs(lag_samples_bad)/fs * 1000);
fprintf('Timing Error (Zero-Phase filtfilt): %d samples (%.2f ms)\n', abs(lag_samples_good), abs(lag_samples_good)/fs * 1000);
fprintf('======================================================\n\n');
