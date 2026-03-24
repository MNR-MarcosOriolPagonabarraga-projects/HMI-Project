function plot_trial_rejection_overview(subject_idx, subject_rejection_details, channel_labels, movement_labels, output_dir)
    num_classes = numel(subject_rejection_details);
    num_channels = numel(channel_labels);
    num_tiles = num_classes + 1;
    num_cols = 2;
    num_rows = ceil(num_tiles / num_cols);

    aggregate_bad = zeros(0, num_channels);

    figure_handle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1600 max(900, 300 * num_rows)]);
    tiledlayout(num_rows, num_cols, 'TileSpacing', 'compact', 'Padding', 'compact');
    colormap(figure_handle, [1 1 1; 0.84 0.22 0.16; 0.30 0.30 0.30]);

    for class_idx = 1:num_classes
        nexttile;
        details = subject_rejection_details{class_idx};

        if isempty(details)
            axis off;
            title(sprintf('%s - no trials', strrep(movement_labels{class_idx}, '_', ' ')));
            continue;
        end

        state_matrix = zeros(size(details.amplitude_bad_mask));
        state_matrix(details.amplitude_bad_mask) = 1;
        state_matrix(details.rt_invalid_mask, :) = 2;
        aggregate_bad = [aggregate_bad; state_matrix > 0]; %#ok<AGROW>

        imagesc(state_matrix');
        set(gca, 'YDir', 'normal');
        clim([0 2]);
        title(sprintf('%s | trials=%d | RT=%d | channel rejects=%d', ...
            strrep(movement_labels{class_idx}, '_', ' '), ...
            size(state_matrix, 1), ...
            sum(details.rt_invalid_mask), ...
            sum(details.amplitude_bad_mask, 'all')));
        xlabel('Trial');
        ylabel('Channel');
        yticks(channel_tick_positions(num_channels));
        yticklabels(channel_labels(channel_tick_positions(num_channels)));
        xticks(trial_tick_positions(size(state_matrix, 1)));
        grid off;
        box on;
    end

    nexttile;
    if isempty(aggregate_bad)
        axis off;
        title('No rejection summary available');
    else
        rejection_rate = 100 * mean(aggregate_bad, 1);
        barh(rejection_rate, 'FaceColor', [0.20 0.45 0.75], 'EdgeColor', 'none');
        set(gca, 'YDir', 'reverse');
        yticks(channel_tick_positions(num_channels));
        yticklabels(channel_labels(channel_tick_positions(num_channels)));
        xlabel('Rejected trials (%)');
        ylabel('Channel');
        title('Aggregate rejection rate across classes');
        grid on;
        box off;
    end

    colorbar_handle = colorbar;
    colorbar_handle.Ticks = [0 1 2];
    colorbar_handle.TickLabels = {'Good', 'Amplitude reject', 'RT reject'};
    colorbar_handle.Layout.Tile = 'east';

    sgtitle(sprintf('Trial rejection overview - Subject %02d', subject_idx));
    exportgraphics(figure_handle, fullfile(output_dir, sprintf('trial_rejection_overview_S%02d.png', subject_idx)), 'Resolution', 150);
    close(figure_handle);
end

function positions = channel_tick_positions(num_channels)
    positions = unique([1:5:num_channels, num_channels]);
end

function positions = trial_tick_positions(num_trials)
    if num_trials <= 10
        positions = 1:num_trials;
        return;
    end

    positions = unique(round(linspace(1, num_trials, min(10, num_trials))));
end
