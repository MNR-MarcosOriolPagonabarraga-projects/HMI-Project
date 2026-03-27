function run_result = process_subject_run(run_path, subj, run_idx, cfg)
    % Backward-compatible wrapper around the clearer pipeline entry point.
    run_result = run_patient_run(run_path, subj, run_idx, cfg);
end
