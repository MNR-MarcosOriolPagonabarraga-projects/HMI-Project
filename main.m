clc;
clear;
close all;

addpath(genpath('routines'));
cfg = load_project_config();
setup_project_paths(cfg.binica_support_dir);
initialize_output_directories({cfg.output_root, cfg.figures_root, cfg.tables_root, cfg.cache_root});
eeglab('nogui');
results = initialize_results(cfg);
d1_report = initialize_d1_bad_channels_report(cfg);

for subj = 1:cfg.num_subjects
    fprintf('\n=== Subject %02d ===\n', subj);
    subject_state = initialize_subject_state(cfg.num_classes);
    for run_idx = 1:cfg.num_runs
        [run_result, was_processed] = run_subject_run_if_available(subj, run_idx, cfg);
        if ~was_processed, continue; end
        d1_report = update_d1_bad_channels_report(d1_report, subj, run_idx, run_result.bad_idx, cfg);
        results = record_run_result(results, subj, run_idx, run_result);
        subject_state = accumulate_run_result(subject_state, run_result);
    end
    results = finalize_subject_results(results, subj, subject_state, cfg);
    save(cfg.results_path, 'results', '-v7.3');
end

results = finalize_project_results(results, cfg);
save(cfg.results_path, 'results', '-v7.3');
fprintf('\nProcessing complete. Results saved to %s\n', cfg.results_path);