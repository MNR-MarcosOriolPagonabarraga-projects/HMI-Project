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
filtered_patient_run = band_pass_filter(eeg_run_channels, eeg_fs, eeg_filt_order, eeg_filt_band);

%% VISUALIZE FILTERING %%
% Plot one channel
figure;
plot_channels(filtered_patient_run(:, 1:1000))

%% Discard bad channels %%
filtered_patient_run = discard_bad_channels(filtered_patient_run);
figure;
plot_channels(filtered_patient_run(:, 1:1000))


