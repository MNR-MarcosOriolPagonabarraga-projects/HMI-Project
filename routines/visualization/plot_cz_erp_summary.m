function plot_cz_erp_summary(time_vector_sec, cz_average, grand_mean_cz, movement_labels, output_dir)
    valid_classes = find(~cellfun(@isempty, grand_mean_cz));
    if isempty(valid_classes)
        return;
    end

    figure_handle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1400 max(300 * numel(valid_classes), 400)]);
    tiledlayout(numel(valid_classes), 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    for plot_idx = 1:numel(valid_classes)
        class_idx = valid_classes(plot_idx);
        nexttile;
        hold on;

        for subject_idx = 1:size(cz_average, 1)
            if isempty(cz_average{subject_idx, class_idx})
                continue;
            end

            plot(time_vector_sec, cz_average{subject_idx, class_idx}, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.75);
        end

        plot(time_vector_sec, grand_mean_cz{class_idx}, 'k', 'LineWidth', 2);
        xline(0, '--r', 'Stimulus', 'LineWidth', 1);
        yline(0, ':', 'Color', [0.5 0.5 0.5]);
        hold off;
        grid on;
        box off;
        xlabel('Time (s)');
        ylabel('Amplitude (\muV)');
        title(sprintf('Cz average - %s', strrep(movement_labels{class_idx}, '_', ' ')));
    end

    exportgraphics(figure_handle, fullfile(output_dir, 'cz_erp_summary.png'), 'Resolution', 150);
    close(figure_handle);
end
