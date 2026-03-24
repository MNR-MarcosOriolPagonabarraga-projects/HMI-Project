function write_trial_rejection_tables(trial_rejection_table, output_dir)
    if isempty(trial_rejection_table)
        return;
    end

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    writetable(trial_rejection_table, fullfile(output_dir, 'trial_rejection_details.csv'));

    summary_table = groupsummary( ...
        trial_rejection_table, ...
        {'subject', 'class_code', 'class_label'}, ...
        {'sum', 'mean'}, ...
        {'rt_rejected', 'amplitude_rejected_channel_count', 'final_rejected_channel_count'});

    writetable(summary_table, fullfile(output_dir, 'trial_rejection_summary.csv'));
end
