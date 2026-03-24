function results = finalize_project_results(results, trial_rejection_row_blocks, cfg)
    num_classes = numel(results.movement_codes);
    results.grand_mean_cz = cell(1, num_classes);

    for class_idx = 1:num_classes
        subject_curves = results.cz_average(:, class_idx);
        valid_subjects = ~cellfun(@isempty, subject_curves);

        if any(valid_subjects)
            results.grand_mean_cz{class_idx} = mean(cat(1, subject_curves{valid_subjects}), 1);
        end
    end

    trial_rejection_rows = combine_trial_rejection_rows(trial_rejection_row_blocks);

    if isempty(trial_rejection_rows)
        results.trial_rejection_table = table();
    else
        results.trial_rejection_table = struct2table(trial_rejection_rows);
        write_trial_rejection_tables(results.trial_rejection_table, cfg.tables_root);
    end

    plot_cz_erp_summary( ...
        results.time_vector_sec, ...
        results.cz_average, ...
        results.grand_mean_cz, ...
        cfg.movement_labels, ...
        cfg.figures_root);
end

function combined_rows = combine_trial_rejection_rows(row_blocks)
    nonempty_blocks = row_blocks(~cellfun(@isempty, row_blocks));

    if isempty(nonempty_blocks)
        combined_rows = struct([]);
        return;
    end

    combined_rows = vertcat(nonempty_blocks{:});
end
