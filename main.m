clc;
clear;
close all;

addpath(genpath('routines'));
cfg = load_project_config();
setup_project_paths(cfg.binica_support_dir);
initialize_output_directories({cfg.output_root, cfg.figures_root, cfg.tables_root, cfg.cache_root});
eeglab('nogui');
results = initialize_results(cfg);
trial_rejection_row_blocks = cell(cfg.num_subjects, cfg.num_runs);

for subj = 1:1
    fprintf('\n=== Subject %02d ===\n', subj);
    subject_state = initialize_subject_state(cfg.num_classes);
    for run_idx = 1:1
        [run_result, was_processed] = run_subject_run_if_available(subj, run_idx, cfg);
        if ~was_processed, continue; end
        results = record_run_result(results, subj, run_idx, run_result);
        [subject_state, run_rows] = accumulate_run_result(subject_state, run_result, subj, run_idx, cfg.movement_labels);
        trial_rejection_row_blocks{subj, run_idx} = run_rows;
    end
    results = finalize_subject_results(results, subj, subject_state, cfg);
    save(cfg.results_path, 'results', '-v7.3');
end

results = finalize_project_results(results, trial_rejection_row_blocks, cfg);
save(cfg.results_path, 'results', '-v7.3');
fprintf('\nProcessing complete. Results saved to %s\n', cfg.results_path);