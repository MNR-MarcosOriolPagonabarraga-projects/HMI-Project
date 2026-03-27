function cfg_out = bad_channel_inspect_defaults(cfg, mode)
    switch lower(mode)
        case 'inspect'
            cfg_out = build_default_inspect_cfg(cfg);
        case 'search'
            cfg_out = build_default_search_cfg(cfg);
        otherwise
            error('bad_channel_inspect_defaults: unknown mode ''%s'' (use ''inspect'' or ''search'').', mode);
    end
end

function inspect_cfg = build_default_inspect_cfg(cfg)
    inspect_cfg = struct();
    inspect_cfg.subject_idx = 7;
    inspect_cfg.run_idx = 2;
    inspect_cfg.preview_sec = 10;
    inspect_cfg.bad_channel_cfg = cfg.bad_channel_cfg;
end

function search_cfg = build_default_search_cfg(cfg)
    search_cfg = struct();
    search_cfg.subject_indices = 1:cfg.num_subjects;
    search_cfg.run_indices = 1:cfg.num_runs;

    search_cfg.normalization_options = {'standard', 'trimmed'};
    search_cfg.trim_percent_values = [5 7 10 12 15 18 20 25];

    search_cfg.corr_threshold_values = 2:0.5:12;
    search_cfg.var_threshold_values = 3:1:20;
    search_cfg.range_threshold_values = 2:0.5:12;
    search_cfg.kurt_threshold_values = 5:1:30;

    % Empty = search all 15 non-empty feature subsets; set to e.g. {'corr+var+range+kurt'} for a faster grid.
    search_cfg.feature_set_names = {};

    search_cfg.max_top_results = 15;
    search_cfg.results_csv_path = fullfile(cfg.tables_root, 'bad_channel_parameter_search_results.csv');
    search_cfg.best_run_csv_path = fullfile(cfg.tables_root, 'bad_channel_best_config_run_comparison.csv');
    search_cfg.score_weights = struct( ...
        'channel_f1', 100, ...
        'positive_exact_rate', 10, ...
        'negative_exact_rate', 5);
end
