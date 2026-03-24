function results = record_run_result(results, subj, run_idx, run_result)
    results.processed_run_mask(subj, run_idx) = true;
    results.bad_channels{subj, run_idx} = run_result.bad_idx;
    results.bad_channel_labels{subj, run_idx} = run_result.bad_labels;
    results.bad_channel_details{subj, run_idx} = run_result.bad_details;

    if isempty(results.time_vector_sec)
        results.time_vector_sec = run_result.time_vector_sec;
        results.channel_labels = run_result.channel_labels;
    end

    for class_idx = 1:numel(run_result.run_trial_summaries)
        results.run_trial_summary{subj, run_idx, class_idx} = run_result.run_trial_summaries{class_idx};
    end
end
