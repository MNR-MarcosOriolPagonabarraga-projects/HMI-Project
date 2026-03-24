function plot_preprocessing_steps(raw_data, filtered_data, final_data, chanlocs, bad_idx, raw_fs, processed_fs, subject_idx, run_idx, output_dir, plot_cfg)
    channel_labels = {chanlocs.labels};
    selected_idx = map_channel_labels(channel_labels, plot_cfg.channels_to_plot);

    raw_preview_samples = min(size(raw_data, 2), round(plot_cfg.preview_sec * raw_fs));
    final_preview_samples = min(size(final_data, 2), round(plot_cfg.preview_sec * processed_fs));
    raw_time_vector = (0:(raw_preview_samples - 1)) / raw_fs;
    final_time_vector = (0:(final_preview_samples - 1)) / processed_fs;

    figure_handle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1500 1000]);
    tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot_channels(raw_data(selected_idx, 1:raw_preview_samples), raw_time_vector, channel_labels(selected_idx), ...
        sprintf('Raw EEG (representative channels) - S%02d R%02d', subject_idx, run_idx));

    nexttile;
    plot_all_channel_heatmap(raw_data(:, 1:raw_preview_samples), raw_time_vector, channel_labels, 'Raw EEG (all channels)');

    nexttile;
    plot_channels(filtered_data(selected_idx, 1:raw_preview_samples), raw_time_vector, channel_labels(selected_idx), ...
        'Band-pass filtered (representative channels)');

    nexttile;
    plot_all_channel_heatmap(final_data(:, 1:final_preview_samples), final_time_vector, channel_labels, ...
        'After CAR, ICA cleaning, and interpolation (all channels)');

    nexttile;
    plot_channels(final_data(selected_idx, 1:final_preview_samples), final_time_vector, channel_labels(selected_idx), ...
        'After CAR, ICA cleaning, and interpolation (representative channels)');

    nexttile;
    rejected_mask = ismember(1:numel(channel_labels), bad_idx);
    bar(double(rejected_mask), 'FaceColor', [0.2 0.4 0.7]);
    ylim([0 1.2]);
    xlim([0.5 numel(channel_labels) + 0.5]);
    xticks(1:numel(channel_labels));
    xticklabels(channel_labels);
    xtickangle(90);
    ylabel('Rejected');

    if isempty(bad_idx)
        title('Bad channel rejection: none');
    else
        title(sprintf('Bad channel rejection: %s', strjoin(channel_labels(bad_idx), ', ')));
    end

    grid on;
    exportgraphics(figure_handle, fullfile(output_dir, sprintf('preprocessing_S%02d_R%02d.png', subject_idx, run_idx)), 'Resolution', 150);
    close(figure_handle);
end

function selected_idx = map_channel_labels(channel_labels, labels_to_plot)
    selected_idx = zeros(1, numel(labels_to_plot));

    for label_idx = 1:numel(labels_to_plot)
        selected_idx(label_idx) = find(strcmpi(channel_labels, labels_to_plot{label_idx}), 1);
    end

    selected_idx = selected_idx(selected_idx > 0);

    if isempty(selected_idx)
        selected_idx = 1:min(4, numel(channel_labels));
    end
end

function plot_all_channel_heatmap(data, time_vector_sec, channel_labels, title_text)
    channel_scale = std(data, 0, 2);
    channel_scale(channel_scale < eps) = 1;
    normalized_data = data ./ channel_scale;

    imagesc(time_vector_sec, 1:size(data, 1), normalized_data);
    set(gca, 'YDir', 'normal');
    xlabel('Time (s)');
    ylabel('Channel');
    title(title_text);
    yticks(unique([1:5:size(data, 1), size(data, 1)]));
    yticklabels(channel_labels(unique([1:5:size(data, 1), size(data, 1)])));
    colorbar;
    grid off;
    box off;
end
