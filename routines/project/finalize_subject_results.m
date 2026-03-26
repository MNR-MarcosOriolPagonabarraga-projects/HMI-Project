function results = finalize_subject_results(results, subj, subject_state, cfg)
    cz_idx = find(strcmpi(results.channel_labels, cfg.report_cfg.erp_channel_label), 1);

    for class_idx = 1:numel(subject_state.masks)
        if isempty(subject_state.masks{class_idx})
            continue;
        end

        results.trial_masks{subj, class_idx} = subject_state.masks{class_idx};
        results.trial_rejection_details{subj, class_idx} = subject_state.rejection_details{class_idx};
        results.class_trial_counts(subj, class_idx) = size(subject_state.masks{class_idx}, 1);
        results.good_trial_percent(subj, class_idx, :) = 100 * mean(subject_state.masks{class_idx}, 1);
        results.good_trial_percent_mean(subj, class_idx) = mean(squeeze(results.good_trial_percent(subj, class_idx, :)), 'omitnan');

        if isempty(cz_idx) || isempty(subject_state.cz_epochs{class_idx})
            continue;
        end

        n_mask_rows = size(subject_state.masks{class_idx}, 1);
        n_cz_rows = size(subject_state.cz_epochs{class_idx}, 1);
        if n_mask_rows ~= n_cz_rows
            error( ...
                'HMI:czEpochMaskMismatch', ...
                ['Trial mask rows (%d) and Cz epoch rows (%d) differ for subject %d, class %d. ', ...
                'This usually means some runs contributed masks but not Cz epochs (e.g. cache or pipeline mismatch).'], ...
                n_mask_rows, n_cz_rows, subj, class_idx);
        end

        cz_good_trials = subject_state.masks{class_idx}(:, cz_idx);
        results.cz_good_trial_count(subj, class_idx) = sum(cz_good_trials);

        if any(cz_good_trials)
            good_ep = subject_state.cz_epochs{class_idx}(cz_good_trials, :);
            results.cz_average{subj, class_idx} = mean(good_ep, 1);
            results.cz_min{subj, class_idx} = min(good_ep, [], 1);
            results.cz_max{subj, class_idx} = max(good_ep, [], 1);
        end
    end

end
