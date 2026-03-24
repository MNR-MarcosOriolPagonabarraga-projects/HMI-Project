clc;
clear;
close all;

addpath(genpath('routines'));
cfg = load_project_config();
setup_project_paths(cfg.binica_support_dir);

data_root = cfg.data_root;
figures_root = cfg.figures_root;
num_eeg_channels = cfg.num_eeg_channels;
raw_fs = cfg.raw_fs;
filter_cfg = cfg.filter_cfg;
epoch_cfg = cfg.epoch_cfg;

subject_idx = 1;
run_idx = 1;
channel_label = 'Cz';
candidate_factors = [1 2 3 4];
preview_window_sec = [30 35];
max_plot_frequency_hz = 100;

run_path = fullfile(data_root, sprintf('S%d', subject_idx), sprintf('ME_S%02d_r%02d.mat', subject_idx, run_idx));
if ~isfile(run_path)
    error('Run file not found: %s', run_path);
end

[raw_data, chanlocs] = load_patient_run(run_path, num_eeg_channels);
filtered_data = band_pass_filter(raw_data, raw_fs, filter_cfg.order, filter_cfg.band_hz);

channel_labels = {chanlocs.labels};
channel_idx = find(strcmpi(channel_labels, channel_label), 1);
if isempty(channel_idx)
    error('Channel %s was not found.', channel_label);
end

nyquist_requirement_hz = 2 * filter_cfg.band_hz(2);
recommended_factor = floor((raw_fs - eps) / nyquist_requirement_hz);

fprintf('Decimation inspection for S%02d R%02d using channel %s.\n', subject_idx, run_idx, channel_label);
fprintf('Current filter upper bound: %.1f Hz\n', filter_cfg.band_hz(2));
fprintf('Theoretical minimum sampling rate to preserve that band: %.1f Hz\n', nyquist_requirement_hz);
fprintf('Largest integer decimation factor that still preserves %.1f Hz from %d Hz: %d\n\n', ...
    filter_cfg.band_hz(2), raw_fs, recommended_factor);

fprintf('%8s %14s %14s %16s %18s %14s\n', ...
    'Factor', 'New Fs (Hz)', 'Nyquist (Hz)', 'Safe For 70 Hz', 'ICLabel Compatible', 'Epoch Samples');
fprintf('%8s %14s %14s %16s %18s %14s\n', ...
    '------', '-----------', '------------', '--------------', '------------------', '-------------');

summary = struct('factor', {}, 'fs', {}, 'nyquist', {}, 'is_safe', {}, 'is_iclabel_compatible', {}, 'epoch_samples', {});

for factor_idx = 1:numel(candidate_factors)
    factor = candidate_factors(factor_idx);
    effective_fs = raw_fs / factor;
    nyquist_hz = effective_fs / 2;
    is_safe = effective_fs >= nyquist_requirement_hz;
    is_iclabel_compatible = abs(effective_fs - round(effective_fs)) <= 1e-9;

    start_offset = round(epoch_cfg.window_sec(1) * effective_fs);
    end_offset = round(epoch_cfg.window_sec(2) * effective_fs);
    epoch_samples = numel(start_offset:(end_offset - 1));

    summary(factor_idx).factor = factor;
    summary(factor_idx).fs = effective_fs;
    summary(factor_idx).nyquist = nyquist_hz;
    summary(factor_idx).is_safe = is_safe;
    summary(factor_idx).is_iclabel_compatible = is_iclabel_compatible;
    summary(factor_idx).epoch_samples = epoch_samples;

    fprintf('%8d %14.2f %14.2f %16s %18s %14d\n', ...
        factor, effective_fs, nyquist_hz, string(is_safe), string(is_iclabel_compatible), epoch_samples);
end

fprintf('\nRecommendation:\n');
fprintf('- Minimum theoretical sampling rate for the current %.1f Hz upper band: %.1f Hz\n', ...
    filter_cfg.band_hz(2), nyquist_requirement_hz);
fprintf('- Use only factors that keep both the Nyquist limit and an integer processed sampling rate for ICLabel.\n');
fprintf('- With raw_fs=%d Hz and a 70 Hz upper band, factor 2 (%.2f Hz) is the only practical ICLabel-safe downsampling choice.\n', ...
    raw_fs, raw_fs / 2);
fprintf('- Factor %d preserves the band but is not ICLabel-compatible because it produces a non-integer sampling rate.\n', ...
    recommended_factor);
fprintf('- Factors above %d do not preserve the current 70 Hz upper band.\n\n', recommended_factor);

preview_start_sample = max(1, round(preview_window_sec(1) * raw_fs) + 1);
preview_end_sample = min(size(filtered_data, 2), round(preview_window_sec(2) * raw_fs));
preview_indices = preview_start_sample:preview_end_sample;
preview_time_sec = (preview_indices - 1) / raw_fs;
reference_signal = filtered_data(channel_idx, preview_indices);

if ~exist(figures_root, 'dir')
    mkdir(figures_root);
end

figure_handle = figure('Color', 'w', 'Position', [100 100 1500 250 * numel(candidate_factors)]);
tiledlayout(numel(candidate_factors), 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for factor_idx = 1:numel(candidate_factors)
    factor = candidate_factors(factor_idx);
    effective_fs = raw_fs / factor;
    decimated_data = decimate_eeg(filtered_data, factor);
    decimated_signal = decimated_data(channel_idx, :);

    reconstructed_signal = resample(decimated_signal', factor, 1)';
    reconstructed_signal = reconstructed_signal(1:min(numel(reconstructed_signal), size(filtered_data, 2)));
    reconstructed_preview = reconstructed_signal(preview_indices(1:numel(reference_signal)));

    nexttile;
    plot(preview_time_sec, reference_signal, 'k', 'LineWidth', 1.2);
    hold on;
    plot(preview_time_sec, reconstructed_preview, 'r', 'LineWidth', 1.0);
    hold off;
    grid on;
    box off;
    xlabel('Time (s)');
    ylabel('Amplitude (\muV)');
    title(sprintf('Factor %d | fs = %.2f Hz | safe = %s', factor, effective_fs, string(summary(factor_idx).is_safe)));
    legend({'Filtered @ 512 Hz', sprintf('Decimate x%d -> resample', factor)}, 'Location', 'best');

    nexttile;
    [power_spectrum, freq_axis] = pwelch(decimated_signal, [], [], [], effective_fs);
    plot(freq_axis, 10 * log10(power_spectrum), 'LineWidth', 1.2);
    hold on;
    xline(filter_cfg.band_hz(2), '--r', '70 Hz');
    hold off;
    grid on;
    box off;
    xlabel('Frequency (Hz)');
    ylabel('PSD (dB/Hz)');
    xlim([0 min(max_plot_frequency_hz, effective_fs / 2)]);
    title(sprintf('PSD after factor %d', factor));
end

sgtitle(sprintf('Decimation comparison for S%02d R%02d (%s)', subject_idx, run_idx, channel_label));
exportgraphics(figure_handle, fullfile(figures_root, sprintf('decimation_comparison_S%02d_R%02d.png', subject_idx, run_idx)), 'Resolution', 150);

disp('Figure saved to output/figures.');
