clc; clear;
% Load constants
run("constants.m")
addpath('routines');

%% LOAD DATA %
% Load a patient run
patient_run_path = 'data/S1/ME_S01_r01.mat';
eeg_run_channels = load_patient_run(patient_run_path);

%% FILTERING %%
% Filter it
filtered_eeg_run_channels = band_pass_filter(eeg_run_channels, eeg_fs, eeg_filt_order, eeg_filt_band);

%% VISUALIZE FILTERING %%
% Plot one channel
figure;
plot_channels(filtered_eeg_run_channels(:, 1:1000))

%% Discard bad channels %%
filtered_eeg_run_channels = discard_bad_channels(filtered_eeg_run_channels, r_coef_threshold);
figure;
plot_channels(filtered_eeg_run_channels(:, 1:1000))


