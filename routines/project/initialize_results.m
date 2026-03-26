function results = initialize_results(cfg)
    results = struct();
    results.config = struct( ...
        'filter_cfg', cfg.filter_cfg, ...
        'bad_channel_cfg', cfg.bad_channel_cfg, ...
        'decimation_factor', cfg.decimation_factor, ...
        'ica_cfg', cfg.ica_cfg, ...
        'epoch_cfg', cfg.epoch_cfg, ...
        'run_cache_cfg', cfg.run_cache_cfg);
    results.movement_codes = cfg.movement_codes;
    results.movement_labels = cfg.movement_labels;
    results.processed_fs = cfg.processed_fs;
    results.processed_run_mask = false(cfg.num_subjects, cfg.num_runs);
    results.bad_channels = cell(cfg.num_subjects, cfg.num_runs);
    results.bad_channel_labels = cell(cfg.num_subjects, cfg.num_runs);
    results.bad_channel_details = cell(cfg.num_subjects, cfg.num_runs);
    results.trial_masks = cell(cfg.num_subjects, cfg.num_classes);
    results.trial_rejection_details = cell(cfg.num_subjects, cfg.num_classes);
    results.run_trial_summary = cell(cfg.num_subjects, cfg.num_runs, cfg.num_classes);
    results.good_trial_percent = nan(cfg.num_subjects, cfg.num_classes, cfg.num_eeg_channels);
    results.good_trial_percent_mean = nan(cfg.num_subjects, cfg.num_classes);
    results.class_trial_counts = zeros(cfg.num_subjects, cfg.num_classes);
    results.cz_average = cell(cfg.num_subjects, cfg.num_classes);
    results.cz_min = cell(cfg.num_subjects, cfg.num_classes);
    results.cz_max = cell(cfg.num_subjects, cfg.num_classes);
    results.cz_good_trial_count = zeros(cfg.num_subjects, cfg.num_classes);
    results.time_vector_sec = [];
    results.channel_labels = {};
end
