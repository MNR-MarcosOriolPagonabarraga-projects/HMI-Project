function results = finalize_subject_results(results, subj, subject_state, cfg)
    cz_idx = find(strcmpi(results.channel_labels, cfg.plot_cfg.erp_channel_label), 1);

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

        cz_good_trials = subject_state.masks{class_idx}(:, cz_idx);
        results.cz_good_trial_count(subj, class_idx) = sum(cz_good_trials);

        if any(cz_good_trials)
            results.cz_average{subj, class_idx} = mean(subject_state.cz_epochs{class_idx}(cz_good_trials, :), 1);
        end
    end

    has_rejection_details = any(~cellfun(@isempty, subject_state.rejection_details));
    if cfg.plot_cfg.enabled && has_rejection_details && ~isempty(results.channel_labels)
        plot_trial_rejection_overview( ...
            subj, ...
            subject_state.rejection_details, ...
            results.channel_labels, ...
            cfg.movement_labels, ...
            cfg.figures_root);
    end
end
