clc;
clear;
close all;

addpath(genpath('routines'));
cfg = load_project_config();
setup_project_paths(cfg.binica_support_dir);
initialize_output_directories({cfg.output_root, cfg.figures_root, cfg.tables_root, cfg.cache_root});

mode = 'search';  % 'search' or 'inspect'

inspect_cfg = bad_channel_inspect_defaults(cfg, 'inspect');
search_cfg = bad_channel_inspect_defaults(cfg, 'search');
search_cfg.normalization_options = {'standard'};
search_cfg.feature_set_names = {'corr+var+range+kurt'};
search_cfg.corr_threshold_values = 3:0.5:10;
search_cfg.var_threshold_values = 5:2:20;
search_cfg.range_threshold_values = 5:0.5:14;
search_cfg.kurt_threshold_values = 16:2:28;

switch lower(mode)
    case 'inspect'
        run_bad_channel_single_run_inspection(cfg, inspect_cfg);
    case 'search'
        bad_channel_parameter_search(cfg, search_cfg);
    otherwise
        error('Unsupported mode: %s', mode);
end
