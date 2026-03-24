function [subject_state, run_rows] = accumulate_run_result(subject_state, run_result, subj, run_idx, movement_labels)
    num_classes = numel(run_result.run_trial_masks);
    run_rows = struct([]);

    for class_idx = 1:num_classes
        trial_mask = run_result.run_trial_masks{class_idx};
        reject_details = run_result.run_rejection_details{class_idx};
        trial_info = run_result.run_trial_info{class_idx};

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

        new_rows = build_trial_rejection_rows( ...
            subj, ...
            run_idx, ...
            movement_labels{class_idx}, ...
            run_result.channel_labels, ...
            trial_info, ...
            reject_details);
        run_rows = append_rows(run_rows, new_rows);
    end
end

function rows = append_rows(rows, new_rows)
    if isempty(new_rows)
        return;
    end

    if isempty(rows)
        rows = new_rows;
    else
        rows = [rows; new_rows];
    end
end
