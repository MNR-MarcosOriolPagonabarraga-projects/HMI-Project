function write_d3_cz_report_plots(time_vector_sec, cz_average, cz_min, cz_max, grand_mean_cz, movement_labels, cz_good_trial_count, output_dir)
    if isempty(time_vector_sec)
        return;
    end

    for subj = 1:size(cz_average, 1)
        write_subject_cz_plot(subj, time_vector_sec, cz_average, cz_min, cz_max, movement_labels, cz_good_trial_count, output_dir);
    end

    write_grand_mean_cz_plot(time_vector_sec, grand_mean_cz, movement_labels, cz_average, output_dir);
end

function write_subject_cz_plot(subj, time_vector_sec, cz_average, cz_min, cz_max, movement_labels, cz_good_trial_count, output_dir)
    figure_handle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1500 900]);
    layout_handle = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout_handle, sprintf('Subject S%d Cz averages (line=mean; shaded=min–max of good trials)', subj));

    for class_idx = 1:numel(movement_labels)
        nexttile;
        subject_curve = cz_average{subj, class_idx};

        if isempty(subject_curve)
            axis off;
            title(sprintf('Cz average %s', movement_labels{class_idx}));
            text(0.5, 0.5, 'No data', 'HorizontalAlignment', 'center');
            continue;
        end

        n_good = cz_good_trial_count(subj, class_idx);
        lo = cz_min{subj, class_idx};
        hi = cz_max{subj, class_idx};
        if ~isempty(lo) && ~isempty(hi) && numel(lo) == numel(time_vector_sec)
            plot_cz_mean_with_trial_envelope(time_vector_sec, subject_curve, lo, hi);
        else
            plot(time_vector_sec, subject_curve, 'k', 'LineWidth', 1.5);
        end
        xline(0, '--r', 'Stimulus', 'LineWidth', 1);
        yline(0, ':', 'Color', [0.5 0.5 0.5]);
        grid on;
        box off;
        ylim([-20 20]);
        xlabel('Time (s)');
        ylabel('Amplitude (\muV)');
        title(sprintf('Cz average %s (N=%d good trials)', movement_labels{class_idx}, n_good));
    end

    exportgraphics(figure_handle, fullfile(output_dir, sprintf('cz_average_subject_S%02d.png', subj)), 'Resolution', 150);
    close(figure_handle);
end

function write_grand_mean_cz_plot(time_vector_sec, grand_mean_cz, movement_labels, cz_average, output_dir)
    figure_handle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1500 900]);
    layout_handle = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout_handle, 'Grand mean Cz (line=mean across subjects; shaded=min–max of subject means)');

    for class_idx = 1:numel(movement_labels)
        nexttile;
        class_curve = grand_mean_cz{class_idx};

        if isempty(class_curve)
            axis off;
            title(sprintf('Grand mean Cz average %s', movement_labels{class_idx}));
            text(0.5, 0.5, 'No data', 'HorizontalAlignment', 'center');
            continue;
        end

        n_subj = sum(~cellfun(@isempty, cz_average(:, class_idx)));
        subject_curves = cz_average(:, class_idx);
        valid = ~cellfun(@isempty, subject_curves);
        if any(valid)
            stack = cat(1, subject_curves{valid});
            gm_lo = min(stack, [], 1);
            gm_hi = max(stack, [], 1);
            plot_cz_mean_with_trial_envelope(time_vector_sec, class_curve, gm_lo, gm_hi);
        else
            plot(time_vector_sec, class_curve, 'k', 'LineWidth', 1.5);
        end
        xline(0, '--r', 'Stimulus', 'LineWidth', 1);
        yline(0, ':', 'Color', [0.5 0.5 0.5]);
        grid on;
        box off;
        ylim([-20 20]);
        xlabel('Time (s)');
        ylabel('Amplitude (\muV)');
        title(sprintf('Grand mean Cz average %s (N=%d subjects)', movement_labels{class_idx}, n_subj));
    end

    exportgraphics(figure_handle, fullfile(output_dir, 'cz_average_grand_mean.png'), 'Resolution', 150);
    close(figure_handle);
end

function plot_cz_mean_with_trial_envelope(time_vector_sec, mean_curve, lo_curve, hi_curve)
    t = time_vector_sec(:);
    hi = hi_curve(:);
    lo = lo_curve(:);
    fill([t; flipud(t)], [hi; flipud(lo)], [0.78 0.82 0.92], ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.42);
    hold on;
    plot(time_vector_sec, mean_curve, 'k', 'LineWidth', 1.5);
    hold off;
end
