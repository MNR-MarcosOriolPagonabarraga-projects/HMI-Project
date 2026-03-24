function write_d3_cz_report_plots(time_vector_sec, cz_average, grand_mean_cz, movement_labels, output_dir)
    if isempty(time_vector_sec)
        return;
    end

    for subj = 1:size(cz_average, 1)
        write_subject_cz_plot(subj, time_vector_sec, cz_average, movement_labels, output_dir);
    end

    write_grand_mean_cz_plot(time_vector_sec, grand_mean_cz, movement_labels, output_dir);
end

function write_subject_cz_plot(subj, time_vector_sec, cz_average, movement_labels, output_dir)
    figure_handle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1500 900]);
    layout_handle = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout_handle, sprintf('Subject S%d Cz averages', subj));

    for class_idx = 1:numel(movement_labels)
        nexttile;
        subject_curve = cz_average{subj, class_idx};

        if isempty(subject_curve)
            axis off;
            title(sprintf('Cz average %s', movement_labels{class_idx}));
            text(0.5, 0.5, 'No data', 'HorizontalAlignment', 'center');
            continue;
        end

        plot(time_vector_sec, subject_curve, 'k', 'LineWidth', 1.5);
        xline(0, '--r', 'Stimulus', 'LineWidth', 1);
        yline(0, ':', 'Color', [0.5 0.5 0.5]);
        grid on;
        box off;
        xlabel('Time (s)');
        ylabel('Amplitude (\muV)');
        title(sprintf('Cz average %s', movement_labels{class_idx}));
    end

    exportgraphics(figure_handle, fullfile(output_dir, sprintf('cz_average_subject_S%02d.png', subj)), 'Resolution', 150);
    close(figure_handle);
end

function write_grand_mean_cz_plot(time_vector_sec, grand_mean_cz, movement_labels, output_dir)
    figure_handle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1500 900]);
    layout_handle = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout_handle, 'Grand mean Cz averages');

    for class_idx = 1:numel(movement_labels)
        nexttile;
        class_curve = grand_mean_cz{class_idx};

        if isempty(class_curve)
            axis off;
            title(sprintf('Grand mean Cz average %s', movement_labels{class_idx}));
            text(0.5, 0.5, 'No data', 'HorizontalAlignment', 'center');
            continue;
        end

        plot(time_vector_sec, class_curve, 'k', 'LineWidth', 1.5);
        xline(0, '--r', 'Stimulus', 'LineWidth', 1);
        yline(0, ':', 'Color', [0.5 0.5 0.5]);
        grid on;
        box off;
        xlabel('Time (s)');
        ylabel('Amplitude (\muV)');
        title(sprintf('Grand mean Cz average %s', movement_labels{class_idx}));
    end

    exportgraphics(figure_handle, fullfile(output_dir, 'cz_average_grand_mean.png'), 'Resolution', 150);
    close(figure_handle);
end
