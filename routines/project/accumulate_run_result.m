function subject_state = accumulate_run_result(subject_state, run_result)
    num_classes = numel(run_result.run_trial_masks);

    for class_idx = 1:num_classes
        trial_mask = run_result.run_trial_masks{class_idx};
        reject_details = run_result.run_rejection_details{class_idx};

        if isempty(subject_state.masks{class_idx})
            subject_state.masks{class_idx} = trial_mask;
        else
            subject_state.masks{class_idx} = [subject_state.masks{class_idx}; trial_mask];
        end

        if isempty(subject_state.rejection_details{class_idx})
            subject_state.rejection_details{class_idx} = struct( ...
                'rt_invalid_mask', reject_details.rt_invalid_mask, ...
                'amplitude_bad_mask', reject_details.amplitude_bad_mask);
        else
            subject_state.rejection_details{class_idx}.rt_invalid_mask = [ ...
                subject_state.rejection_details{class_idx}.rt_invalid_mask; ...
                reject_details.rt_invalid_mask];
            subject_state.rejection_details{class_idx}.amplitude_bad_mask = [ ...
                subject_state.rejection_details{class_idx}.amplitude_bad_mask; ...
                reject_details.amplitude_bad_mask];
        end

        if isempty(subject_state.cz_epochs{class_idx})
            subject_state.cz_epochs{class_idx} = run_result.run_cz_epochs{class_idx};
        elseif ~isempty(run_result.run_cz_epochs{class_idx})
            subject_state.cz_epochs{class_idx} = [subject_state.cz_epochs{class_idx}; run_result.run_cz_epochs{class_idx}];
        end
    end
end
