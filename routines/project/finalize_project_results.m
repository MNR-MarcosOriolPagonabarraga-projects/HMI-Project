function results = finalize_project_results(results, cfg)
    num_classes = numel(results.movement_codes);
    results.grand_mean_cz = cell(1, num_classes);

    for class_idx = 1:num_classes
        subject_curves = results.cz_average(:, class_idx);
        valid_subjects = ~cellfun(@isempty, subject_curves);

        if any(valid_subjects)
            results.grand_mean_cz{class_idx} = mean(cat(1, subject_curves{valid_subjects}), 1);
        end
    end

    write_d2_good_trial_report(results, cfg);
    write_d3_cz_report_plots( ...
        results.time_vector_sec, ...
        results.cz_average, ...
        results.grand_mean_cz, ...
        cfg.movement_labels, ...
        results.cz_good_trial_count, ...
        cfg.figures_root);
end
