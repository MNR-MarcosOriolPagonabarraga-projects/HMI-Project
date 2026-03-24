function [run_result, was_processed] = run_subject_run_if_available(subj, run_idx, cfg)
    run_result = [];
    was_processed = false;
    run_path = fullfile(cfg.data_root, sprintf('S%d', subj), sprintf('ME_S%02d_r%02d.mat', subj, run_idx));

    if ~isfile(run_path)
        fprintf('Missing file, skipping: %s\n', run_path);
        return;
    end

    run_cfg = build_run_cfg(cfg, subj, run_idx);
    run_result = load_or_run_patient_run(run_path, subj, run_idx, run_cfg, cfg.cache_root, cfg.run_cache_cfg);
    was_processed = true;
end

function run_cfg = build_run_cfg(cfg, subj, run_idx)
    should_plot = cfg.plot_cfg.enabled && ...
        ismember(subj, cfg.plot_cfg.diagnostic_subjects) && ...
        ismember(run_idx, cfg.plot_cfg.diagnostic_runs);

    run_cfg = struct( ...
        'num_eeg_channels', cfg.num_eeg_channels, ...
        'raw_fs', cfg.raw_fs, ...
        'filter_cfg', cfg.filter_cfg, ...
        'bad_channel_cfg', cfg.bad_channel_cfg, ...
        'decimation_factor', cfg.decimation_factor, ...
        'ica_cfg', cfg.ica_cfg, ...
        'epoch_cfg', cfg.epoch_cfg, ...
        'movement_codes', cfg.movement_codes, ...
        'erp_channel_label', cfg.plot_cfg.erp_channel_label, ...
        'plot_enabled', should_plot, ...
        'plot_cfg', cfg.plot_cfg, ...
        'figures_root', cfg.figures_root);
end

function run_result = load_or_run_patient_run(run_path, subj, run_idx, run_cfg, cache_root, run_cache_cfg)
    cache_path = fullfile(cache_root, sprintf('S%02d_R%02d_cache.mat', subj, run_idx));
    expected_cache_signature = build_run_cache_signature(run_cfg);

    if run_cache_cfg.enabled && isfile(cache_path) && ~run_cache_cfg.overwrite_existing
        fprintf('Loading cached S%02d R%02d...\n', subj, run_idx);
        loaded_cache = load(cache_path, 'run_result');
        run_result = loaded_cache.run_result;

        if ~isfield(run_result, 'cache_signature') || ~isequaln(run_result.cache_signature, expected_cache_signature)
            fprintf('Cache signature mismatch for S%02d R%02d, recomputing.\n', subj, run_idx);
            run_result = run_patient_run(run_path, subj, run_idx, run_cfg);
            save(cache_path, 'run_result', '-v7.3');
        end
        return;
    end

    fprintf('Processing S%02d R%02d...\n', subj, run_idx);
    run_result = run_patient_run(run_path, subj, run_idx, run_cfg);

    if run_cache_cfg.enabled
        save(cache_path, 'run_result', '-v7.3');
    end
end
