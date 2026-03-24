clc;
clear;
close all;

addpath(genpath('routines'));
cfg = load_project_config();
setup_project_paths(cfg.binica_support_dir);
initialize_output_directories({cfg.figures_root, cfg.tables_root});

% Edit these values while tuning the detector on a single run.
subject_idx = 1;
run_idx = 5;
preview_sec = 10;

bad_channel_cfg = cfg.bad_channel_cfg;
bad_channel_cfg.normalization = 'trimmed';  % 'trimmed' or 'standard'
bad_channel_cfg.trim_percent = 10;          % percent removed from each tail
bad_channel_cfg.use_correlation = true;
bad_channel_cfg.use_variance = true;
bad_channel_cfg.use_range = true;
bad_channel_cfg.use_kurtosis = true;
bad_channel_cfg.corr_z_threshold = 7;
bad_channel_cfg.var_z_threshold = 10;
bad_channel_cfg.range_z_threshold = 8;
bad_channel_cfg.kurt_z_threshold = 20;

run_path = fullfile(cfg.data_root, sprintf('S%d', subject_idx), sprintf('ME_S%02d_r%02d.mat', subject_idx, run_idx));
if ~isfile(run_path)
    error('Run file not found: %s', run_path);
end

[raw_data, chanlocs] = load_patient_run(run_path, cfg.num_eeg_channels);
filtered_data = band_pass_filter(raw_data, cfg.raw_fs, cfg.filter_cfg.order, cfg.filter_cfg.band_hz);
[bad_idx, details] = get_bad_channels(filtered_data, bad_channel_cfg);
channel_labels = {chanlocs.labels};
bad_labels = channel_labels(bad_idx);

diagnostics_table = build_diagnostics_table(channel_labels, details);
csv_path = fullfile(cfg.tables_root, sprintf('bad_channel_diagnostics_S%02d_R%02d.csv', subject_idx, run_idx));
writetable(diagnostics_table, csv_path);

fprintf('\nBad-channel inspection for S%02d R%02d\n', subject_idx, run_idx);
fprintf('Filter: %.1f-%.1f Hz | normalization: %s | trim: %.1f%% per tail\n', ...
    cfg.filter_cfg.band_hz(1), cfg.filter_cfg.band_hz(2), bad_channel_cfg.normalization, bad_channel_cfg.trim_percent);
fprintf('Thresholds -> corr: %.2f, var: %.2f, range: %.2f, kurt: %.2f\n', ...
    bad_channel_cfg.corr_z_threshold, ...
    bad_channel_cfg.var_z_threshold, ...
    bad_channel_cfg.range_z_threshold, ...
    bad_channel_cfg.kurt_z_threshold);

if isempty(bad_idx)
    fprintf('Detected bad channels: []\n');
else
    fprintf('Detected bad channels: [%s]\n', num2str(bad_idx'));
    fprintf('Detected bad labels: %s\n', strjoin(bad_labels, ', '));
end

flagged_rows = diagnostics_table(diagnostics_table.is_bad, :);
if isempty(flagged_rows)
    disp('No channels were flagged by the current configuration.');
else
    disp(flagged_rows(:, {'channel_index', 'channel_label', 'max_abs_z', 'reasons'}));
end
fprintf('Diagnostics CSV saved to %s\n', csv_path);

figure_path = fullfile(cfg.figures_root, sprintf('bad_channel_diagnostics_S%02d_R%02d.png', subject_idx, run_idx));
plot_bad_channel_diagnostics( ...
    filtered_data, ...
    diagnostics_table, ...
    details, ...
    channel_labels, ...
    cfg.raw_fs, ...
    preview_sec, ...
    subject_idx, ...
    run_idx, ...
    figure_path);
fprintf('Diagnostics figure saved to %s\n', figure_path);

function diagnostics_table = build_diagnostics_table(channel_labels, details)
    channel_indices = (1:numel(channel_labels))';
    max_abs_z = max(abs([details.z_corr, details.z_var, details.z_range, details.z_kurt]), [], 2);
    reasons = arrayfun(@(idx) join_reasons(details, idx), channel_indices, 'UniformOutput', false);

    diagnostics_table = table( ...
        channel_indices, ...
        string(channel_labels(:)), ...
        details.mean_corr, ...
        details.z_corr, ...
        details.variance, ...
        details.z_var, ...
        details.range, ...
        details.z_range, ...
        details.kurtosis, ...
        details.z_kurt, ...
        details.bad_corr_mask, ...
        details.bad_var_mask, ...
        details.bad_range_mask, ...
        details.bad_kurt_mask, ...
        details.bad_mask, ...
        max_abs_z, ...
        string(reasons), ...
        'VariableNames', { ...
            'channel_index', ...
            'channel_label', ...
            'mean_corr', ...
            'z_corr', ...
            'variance', ...
            'z_var', ...
            'range', ...
            'z_range', ...
            'kurtosis', ...
            'z_kurt', ...
            'bad_corr', ...
            'bad_var', ...
            'bad_range', ...
            'bad_kurt', ...
            'is_bad', ...
            'max_abs_z', ...
            'reasons'});

    diagnostics_table = sortrows(diagnostics_table, {'is_bad', 'max_abs_z'}, {'descend', 'descend'});
end

function reason_text = join_reasons(details, idx)
    reasons = {};

    if details.bad_corr_mask(idx), reasons{end + 1} = 'corr'; end
    if details.bad_var_mask(idx), reasons{end + 1} = 'var'; end
    if details.bad_range_mask(idx), reasons{end + 1} = 'range'; end
    if details.bad_kurt_mask(idx), reasons{end + 1} = 'kurt'; end

    if isempty(reasons)
        reason_text = '';
    else
        reason_text = strjoin(reasons, ', ');
    end
end

function plot_bad_channel_diagnostics(filtered_data, diagnostics_table, details, channel_labels, fs, preview_sec, subject_idx, run_idx, figure_path)
    figure_handle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1600 1000]);
    tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot_metric_bars(details.z_corr, details.bad_corr_mask, details.corr_z_threshold, channel_labels, 'Correlation z-score');

    nexttile;
    plot_metric_bars(details.z_var, details.bad_var_mask, details.var_z_threshold, channel_labels, 'Variance z-score');

    nexttile;
    plot_metric_bars(details.z_range, details.bad_range_mask, details.range_z_threshold, channel_labels, 'Range z-score');

    nexttile;
    plot_metric_bars(details.z_kurt, details.bad_kurt_mask, details.kurt_z_threshold, channel_labels, 'Kurtosis z-score');

    nexttile([1 2]);
    plot_preview_channels(filtered_data, diagnostics_table, channel_labels, fs, preview_sec);
    title(sprintf('Filtered EEG preview - S%02d R%02d', subject_idx, run_idx));

    sgtitle(sprintf('Bad-channel diagnostics - S%02d R%02d', subject_idx, run_idx));
    exportgraphics(figure_handle, figure_path, 'Resolution', 150);
    close(figure_handle);
end

function plot_metric_bars(z_values, bad_mask, threshold, channel_labels, title_text)
    bar(z_values, 'FaceColor', [0.65 0.65 0.75], 'EdgeColor', 'none');
    hold on;
    bad_idx = find(bad_mask);
    if ~isempty(bad_idx)
        bar(bad_idx, z_values(bad_idx), 'FaceColor', [0.85 0.25 0.20], 'EdgeColor', 'none');
    end
    yline(threshold, '--r', sprintf('+%.1f', threshold));
    yline(-threshold, '--r', sprintf('-%.1f', threshold));
    hold off;
    xlim([0.5, numel(z_values) + 0.5]);
    xticks(1:numel(channel_labels));
    xticklabels(channel_labels);
    xtickangle(90);
    ylabel('z-score');
    title(title_text);
    grid on;
    box off;
end

function plot_preview_channels(filtered_data, diagnostics_table, channel_labels, fs, preview_sec)
    preview_samples = min(size(filtered_data, 2), round(preview_sec * fs));
    preview_time_sec = (0:(preview_samples - 1)) / fs;
    selected_idx = pick_preview_channels(diagnostics_table);
    selected_data = filtered_data(selected_idx, 1:preview_samples);
    spacing = max(median(max(selected_data, [], 2) - min(selected_data, [], 2)), eps) * 3;

    hold on;
    y_ticks = zeros(numel(selected_idx), 1);
    for row_idx = 1:numel(selected_idx)
        offset = (numel(selected_idx) - row_idx) * spacing;
        plot(preview_time_sec, selected_data(row_idx, :) + offset, 'LineWidth', 1);
        y_ticks(row_idx) = offset;
    end
    hold off;

    set(gca, 'YTick', sort(y_ticks, 'ascend'), 'YTickLabel', channel_labels(selected_idx(end:-1:1)));
    xlabel('Time (s)');
    ylabel('Channel');
    grid on;
    box off;
end

function selected_idx = pick_preview_channels(diagnostics_table)
    flagged_idx = diagnostics_table.channel_index(diagnostics_table.is_bad);

    if ~isempty(flagged_idx)
        selected_idx = flagged_idx(1:min(6, numel(flagged_idx)));
        return;
    end

    selected_idx = diagnostics_table.channel_index(1:min(6, height(diagnostics_table)));
end
