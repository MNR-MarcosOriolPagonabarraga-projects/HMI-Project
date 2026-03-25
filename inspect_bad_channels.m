clc;
clear;
close all;

addpath(genpath('routines'));
cfg = load_project_config();
setup_project_paths(cfg.binica_support_dir);
initialize_output_directories({cfg.output_root, cfg.figures_root, cfg.tables_root, cfg.cache_root});

mode = 'search';  % 'search' or 'inspect'

inspect_cfg = build_default_inspect_cfg(cfg);
search_cfg = build_default_search_cfg(cfg);

switch lower(mode)
    case 'inspect'
        run_single_run_inspection(cfg, inspect_cfg);
    case 'search'
        run_bad_channel_parameter_search(cfg, search_cfg);
    otherwise
        error('Unsupported mode: %s', mode);
end

function inspect_cfg = build_default_inspect_cfg(cfg)
    inspect_cfg = struct();
    inspect_cfg.subject_idx = 7;
    inspect_cfg.run_idx = 2;
    inspect_cfg.preview_sec = 10;
    inspect_cfg.bad_channel_cfg = cfg.bad_channel_cfg;
    inspect_cfg.bad_channel_cfg.normalization = 'trimmed';
    inspect_cfg.bad_channel_cfg.trim_percent = 10;
    inspect_cfg.bad_channel_cfg.use_correlation = true;
    inspect_cfg.bad_channel_cfg.use_variance = true;
    inspect_cfg.bad_channel_cfg.use_range = true;
    inspect_cfg.bad_channel_cfg.use_kurtosis = true;
    inspect_cfg.bad_channel_cfg.corr_z_threshold = 7;
    inspect_cfg.bad_channel_cfg.var_z_threshold = 10;
    inspect_cfg.bad_channel_cfg.range_z_threshold = 8;
    inspect_cfg.bad_channel_cfg.kurt_z_threshold = 20;
end

function search_cfg = build_default_search_cfg(cfg)
    search_cfg = struct();
    search_cfg.subject_indices = 1:cfg.num_subjects;
    search_cfg.run_indices = 1:cfg.num_runs;
    search_cfg.normalization_options = {'standard', 'trimmed'};
    search_cfg.trim_percent_values = [5 10 15 20];
    search_cfg.corr_threshold_values = 3:10;
    search_cfg.var_threshold_values = 4:2:16;
    search_cfg.range_threshold_values = 3:10;
    search_cfg.kurt_threshold_values = 8:4:24;
    search_cfg.max_top_results = 10;
    search_cfg.results_csv_path = fullfile(cfg.tables_root, 'bad_channel_parameter_search_results.csv');
    search_cfg.best_run_csv_path = fullfile(cfg.tables_root, 'bad_channel_best_config_run_comparison.csv');
    search_cfg.score_weights = struct( ...
        'channel_f1', 100, ...
        'positive_exact_rate', 10, ...
        'negative_exact_rate', 5);
end

function run_single_run_inspection(cfg, inspect_cfg)
    subject_idx = inspect_cfg.subject_idx;
    run_idx = inspect_cfg.run_idx;
    preview_sec = inspect_cfg.preview_sec;
    bad_channel_cfg = inspect_cfg.bad_channel_cfg;

    run_path = fullfile(cfg.data_root, sprintf('S%d', subject_idx), sprintf('ME_S%02d_r%02d.mat', subject_idx, run_idx));
    if ~isfile(run_path)
        error('Run file not found: %s', run_path);
    end

    [raw_data, chanlocs] = load_patient_run(run_path, cfg.num_eeg_channels);
    filtered_data = band_pass_filter(raw_data, cfg.raw_fs, cfg.filter_cfg.order, cfg.filter_cfg.band_hz);
    [bad_idx, details] = get_bad_channels(filtered_data, bad_channel_cfg);
    channel_labels = {chanlocs.labels};
    bad_labels = channel_labels(bad_idx);

    diagnostics_table = build_diagnostics_table(channel_labels, details);
    csv_path = fullfile(cfg.tables_root, sprintf('bad_channel_diagnostics_S%02d_R%02d.csv', subject_idx, run_idx));
    writetable(diagnostics_table, csv_path);

    fprintf('\nBad-channel inspection for S%02d R%02d\n', subject_idx, run_idx);
    fprintf('Filter: %.1f-%.1f Hz | normalization: %s | trim: %.1f%% per tail\n', ...
        cfg.filter_cfg.band_hz(1), cfg.filter_cfg.band_hz(2), bad_channel_cfg.normalization, bad_channel_cfg.trim_percent);
    fprintf('Thresholds -> corr: %.2f, var: %.2f, range: %.2f, kurt: %.2f\n', ...
        bad_channel_cfg.corr_z_threshold, ...
        bad_channel_cfg.var_z_threshold, ...
        bad_channel_cfg.range_z_threshold, ...
        bad_channel_cfg.kurt_z_threshold);

    if isempty(bad_idx)
        fprintf('Detected bad channels: []\n');
    else
        fprintf('Detected bad channels: [%s]\n', num2str(bad_idx'));
        fprintf('Detected bad labels: %s\n', strjoin(bad_labels, ', '));
    end

    flagged_rows = diagnostics_table(diagnostics_table.is_bad, :);
    if isempty(flagged_rows)
        disp('No channels were flagged by the current configuration.');
    else
        disp(flagged_rows(:, {'channel_index', 'channel_label', 'max_abs_z', 'reasons'}));
    end
    fprintf('Diagnostics CSV saved to %s\n', csv_path);

    figure_path = fullfile(cfg.figures_root, sprintf('bad_channel_diagnostics_S%02d_R%02d.png', subject_idx, run_idx));
    plot_bad_channel_diagnostics( ...
        filtered_data, ...
        diagnostics_table, ...
        details, ...
        channel_labels, ...
        cfg.raw_fs, ...
        preview_sec, ...
        subject_idx, ...
        run_idx, ...
        figure_path);
    fprintf('Diagnostics figure saved to %s\n', figure_path);
end

function run_bad_channel_parameter_search(cfg, search_cfg)
    expected_bad_channels = build_expected_bad_channels(cfg);
    dataset = load_search_dataset(cfg, search_cfg, expected_bad_channels);
    if isempty(dataset)
        error('No run files were found for the requested subject/run search space.');
    end

    normalization_cfgs = build_normalization_cfgs(search_cfg);
    feature_sets = build_feature_sets();
    metrics = precompute_search_metrics(dataset, normalization_cfgs, cfg.num_eeg_channels);

    fprintf('\nLoaded %d available runs for parameter search.\n', numel(dataset));
    fprintf('Reference positive runs: %d | reference clean runs: %d\n', ...
        nnz(metrics.expected_run_has_bad), nnz(~metrics.expected_run_has_bad));

    search_results = evaluate_search_space(metrics, normalization_cfgs, feature_sets, search_cfg);
    writetable(search_results, search_cfg.results_csv_path);

    best_result = search_results(1, :);
    run_comparison_table = build_run_comparison_table(metrics, normalization_cfgs, best_result);
    writetable(run_comparison_table, search_cfg.best_run_csv_path);

    top_count = min(search_cfg.max_top_results, height(search_results));
    fprintf('\nTop %d configurations:\n', top_count);
    disp(search_results(1:top_count, { ...
        'score', ...
        'channel_f1', ...
        'positive_exact_rate', ...
        'negative_exact_rate', ...
        'exact_run_matches', ...
        'normalization', ...
        'trim_percent', ...
        'feature_set_name', ...
        'corr_z_threshold', ...
        'var_z_threshold', ...
        'range_z_threshold', ...
        'kurt_z_threshold'}));

    fprintf('Full search results saved to %s\n', search_cfg.results_csv_path);
    fprintf('Best configuration run-by-run comparison saved to %s\n', search_cfg.best_run_csv_path);

    mismatches = run_comparison_table(~run_comparison_table.is_exact_match, :);
    if isempty(mismatches)
        fprintf('Best configuration matched all available runs exactly.\n');
    else
        fprintf('Best configuration mismatches (%d runs):\n', height(mismatches));
        disp(mismatches(:, {'subject_idx', 'run_idx', 'expected_bad_channels', 'detected_bad_channels', 'missing_channels', 'extra_channels'}));
    end
end

function expected_bad_channels = build_expected_bad_channels(cfg)
    expected_bad_channels = repmat({[]}, cfg.num_subjects, cfg.num_runs);

    expected_bad_channels(3, :) = repmat({[15 29 31 35]}, 1, cfg.num_runs);
    expected_bad_channels(4, :) = { ...
        [13 27 51], ...
        [13 27 51], ...
        [13 51], ...
        [13 51], ...
        [13 51], ...
        [13 41 51], ...
        [13 51], ...
        [13 51], ...
        [13 51], ...
        [13 51]};
    expected_bad_channels(5, :) = repmat({41}, 1, cfg.num_runs);
end

function dataset = load_search_dataset(cfg, search_cfg, expected_bad_channels)
    dataset = struct( ...
        'subject_idx', {}, ...
        'run_idx', {}, ...
        'run_path', {}, ...
        'run_label', {}, ...
        'expected_bad_idx', {}, ...
        'features', {});

    for subject_idx = search_cfg.subject_indices
        for run_idx = search_cfg.run_indices
            run_path = fullfile(cfg.data_root, sprintf('S%d', subject_idx), sprintf('ME_S%02d_r%02d.mat', subject_idx, run_idx));
            if ~isfile(run_path)
                continue;
            end

            [raw_data, ~] = load_patient_run(run_path, cfg.num_eeg_channels);
            filtered_data = band_pass_filter(raw_data, cfg.raw_fs, cfg.filter_cfg.order, cfg.filter_cfg.band_hz);

            dataset(end + 1) = struct( ...
                'subject_idx', subject_idx, ...
                'run_idx', run_idx, ...
                'run_path', run_path, ...
                'run_label', sprintf('S%02d R%02d', subject_idx, run_idx), ...
                'expected_bad_idx', expected_bad_channels{subject_idx, run_idx}, ...
                'features', extract_channel_features(filtered_data)); %#ok<AGROW>
        end
    end
end

function feature_struct = extract_channel_features(channels)
    num_channels = size(channels, 1);

    corr_matrix = corrcoef(channels');
    corr_matrix(1:(num_channels + 1):end) = NaN;

    feature_struct = struct( ...
        'mean_corr', mean(corr_matrix, 2, 'omitnan'), ...
        'variance', var(channels, 0, 2), ...
        'range', max(channels, [], 2) - min(channels, [], 2), ...
        'kurtosis', kurtosis(channels, 0, 2));
end

function normalization_cfgs = build_normalization_cfgs(search_cfg)
    normalization_cfgs = struct('normalization', {}, 'trim_percent', {}, 'label', {});

    if any(strcmpi(search_cfg.normalization_options, 'standard'))
        normalization_cfgs(end + 1) = struct( ...
            'normalization', 'standard', ...
            'trim_percent', 0, ...
            'label', 'standard_trim0'); %#ok<AGROW>
    end

    if any(strcmpi(search_cfg.normalization_options, 'trimmed'))
        for trim_percent = search_cfg.trim_percent_values
            normalization_cfgs(end + 1) = struct( ...
                'normalization', 'trimmed', ...
                'trim_percent', trim_percent, ...
                'label', sprintf('trimmed_trim%d', trim_percent)); %#ok<AGROW>
        end
    end
end

function feature_sets = build_feature_sets()
    feature_names = {'corr', 'var', 'range', 'kurt'};
    feature_sets = struct( ...
        'use_correlation', {}, ...
        'use_variance', {}, ...
        'use_range', {}, ...
        'use_kurtosis', {}, ...
        'name', {});

    for mask_value = 1:(2^numel(feature_names) - 1)
        mask = logical([bitget(mask_value, 4), bitget(mask_value, 3), bitget(mask_value, 2), bitget(mask_value, 1)]);
        feature_sets(end + 1) = struct( ... %#ok<AGROW>
            'use_correlation', mask(1), ...
            'use_variance', mask(2), ...
            'use_range', mask(3), ...
            'use_kurtosis', mask(4), ...
            'name', strjoin(feature_names(mask), '+'));
    end
end

function metrics = precompute_search_metrics(dataset, normalization_cfgs, num_channels)
    num_runs = numel(dataset);
    num_norm_cfgs = numel(normalization_cfgs);

    expected_mask = false(num_channels, num_runs);
    invalid_corr = false(num_channels, num_runs);
    invalid_var = false(num_channels, num_runs);
    invalid_range = false(num_channels, num_runs);
    invalid_kurt = false(num_channels, num_runs);

    abs_z_corr = zeros(num_channels, num_runs, num_norm_cfgs);
    abs_z_var = zeros(num_channels, num_runs, num_norm_cfgs);
    abs_z_range = zeros(num_channels, num_runs, num_norm_cfgs);
    abs_z_kurt = zeros(num_channels, num_runs, num_norm_cfgs);

    subject_idx = zeros(num_runs, 1);
    run_idx = zeros(num_runs, 1);
    run_label = strings(num_runs, 1);

    for run_col = 1:num_runs
        subject_idx(run_col) = dataset(run_col).subject_idx;
        run_idx(run_col) = dataset(run_col).run_idx;
        run_label(run_col) = string(dataset(run_col).run_label);

        expected_bad_idx = dataset(run_col).expected_bad_idx;
        if ~isempty(expected_bad_idx)
            expected_mask(expected_bad_idx, run_col) = true;
        end

        features = dataset(run_col).features;
        invalid_corr(:, run_col) = ~isfinite(features.mean_corr);
        invalid_var(:, run_col) = ~isfinite(features.variance);
        invalid_range(:, run_col) = ~isfinite(features.range);
        invalid_kurt(:, run_col) = ~isfinite(features.kurtosis);

        for norm_idx = 1:num_norm_cfgs
            norm_cfg = normalization_cfgs(norm_idx);
            abs_z_corr(:, run_col, norm_idx) = abs(compute_feature_zscore(features.mean_corr, norm_cfg));
            abs_z_var(:, run_col, norm_idx) = abs(compute_feature_zscore(features.variance, norm_cfg));
            abs_z_range(:, run_col, norm_idx) = abs(compute_feature_zscore(features.range, norm_cfg));
            abs_z_kurt(:, run_col, norm_idx) = abs(compute_feature_zscore(features.kurtosis, norm_cfg));
        end
    end

    metrics = struct( ...
        'subject_idx', subject_idx, ...
        'run_idx', run_idx, ...
        'run_label', run_label, ...
        'expected_mask', expected_mask, ...
        'expected_run_has_bad', any(expected_mask, 1), ...
        'invalid_corr', invalid_corr, ...
        'invalid_var', invalid_var, ...
        'invalid_range', invalid_range, ...
        'invalid_kurt', invalid_kurt, ...
        'abs_z_corr', abs_z_corr, ...
        'abs_z_var', abs_z_var, ...
        'abs_z_range', abs_z_range, ...
        'abs_z_kurt', abs_z_kurt);
end

function z_values = compute_feature_zscore(values, norm_cfg)
    values = values(:);
    z_values = zeros(size(values));
    finite_mask = isfinite(values);

    if nnz(finite_mask) < 2
        return;
    end

    finite_values = values(finite_mask);
    [center_value, spread_value] = compute_center_spread(finite_values, norm_cfg);
    if spread_value <= eps
        return;
    end

    z_values(finite_mask) = (finite_values - center_value) ./ spread_value;
end

function [center_value, spread_value] = compute_center_spread(values, norm_cfg)
    use_trimmed = strcmpi(norm_cfg.normalization, 'trimmed') && norm_cfg.trim_percent > 0;

    if use_trimmed
        trimmed_values = trim_each_tail(values, norm_cfg.trim_percent);
        if numel(trimmed_values) >= 2
            center_value = mean(trimmed_values);
            spread_value = std(trimmed_values, 0);
            return;
        end
    end

    center_value = mean(values);
    spread_value = std(values, 0);
end

function trimmed_values = trim_each_tail(values, trim_percent)
    sorted_values = sort(values(:));
    trim_count = floor(numel(sorted_values) * trim_percent / 100);

    if (2 * trim_count) >= numel(sorted_values)
        trimmed_values = sorted_values;
        return;
    end

    trimmed_values = sorted_values((trim_count + 1):(end - trim_count));
end

function search_results = evaluate_search_space(metrics, normalization_cfgs, feature_sets, search_cfg)
    num_norm_cfgs = numel(normalization_cfgs);
    num_feature_sets = numel(feature_sets);
    num_corr = numel(search_cfg.corr_threshold_values);
    num_var = numel(search_cfg.var_threshold_values);
    num_range = numel(search_cfg.range_threshold_values);
    num_kurt = numel(search_cfg.kurt_threshold_values);
    total_configs = num_norm_cfgs * num_feature_sets * num_corr * num_var * num_range * num_kurt;

    score = zeros(total_configs, 1);
    channel_precision = zeros(total_configs, 1);
    channel_recall = zeros(total_configs, 1);
    channel_f1 = zeros(total_configs, 1);
    positive_exact_rate = zeros(total_configs, 1);
    negative_exact_rate = zeros(total_configs, 1);
    exact_run_matches = zeros(total_configs, 1);
    positive_run_exact_matches = zeros(total_configs, 1);
    negative_run_clean_matches = zeros(total_configs, 1);
    true_positives = zeros(total_configs, 1);
    false_positives = zeros(total_configs, 1);
    false_negatives = zeros(total_configs, 1);
    normalization = strings(total_configs, 1);
    trim_percent = zeros(total_configs, 1);
    feature_set_name = strings(total_configs, 1);
    use_correlation = false(total_configs, 1);
    use_variance = false(total_configs, 1);
    use_range = false(total_configs, 1);
    use_kurtosis = false(total_configs, 1);
    corr_z_threshold = zeros(total_configs, 1);
    var_z_threshold = zeros(total_configs, 1);
    range_z_threshold = zeros(total_configs, 1);
    kurt_z_threshold = zeros(total_configs, 1);

    expected_mask = metrics.expected_mask;
    expected_run_has_bad = metrics.expected_run_has_bad;
    zero_mask = false(size(expected_mask));

    fprintf('Evaluating %d parameter combinations...\n', total_configs);
    row_idx = 0;
    for norm_idx = 1:num_norm_cfgs
        norm_cfg = normalization_cfgs(norm_idx);
        corr_masks = build_threshold_masks(metrics.abs_z_corr(:, :, norm_idx), metrics.invalid_corr, search_cfg.corr_threshold_values);
        var_masks = build_threshold_masks(metrics.abs_z_var(:, :, norm_idx), metrics.invalid_var, search_cfg.var_threshold_values);
        range_masks = build_threshold_masks(metrics.abs_z_range(:, :, norm_idx), metrics.invalid_range, search_cfg.range_threshold_values);
        kurt_masks = build_threshold_masks(metrics.abs_z_kurt(:, :, norm_idx), metrics.invalid_kurt, search_cfg.kurt_threshold_values);

        for feature_idx = 1:num_feature_sets
            feature_set = feature_sets(feature_idx);

            for corr_idx = 1:num_corr
                if feature_set.use_correlation
                    corr_mask = corr_masks(:, :, corr_idx);
                else
                    corr_mask = zero_mask;
                end

                for var_idx = 1:num_var
                    if feature_set.use_variance
                        var_mask = var_masks(:, :, var_idx);
                    else
                        var_mask = zero_mask;
                    end

                    for range_idx = 1:num_range
                        if feature_set.use_range
                            range_mask = range_masks(:, :, range_idx);
                        else
                            range_mask = zero_mask;
                        end

                        for kurt_idx = 1:num_kurt
                            if feature_set.use_kurtosis
                                kurt_mask = kurt_masks(:, :, kurt_idx);
                            else
                                kurt_mask = zero_mask;
                            end

                            predicted_mask = corr_mask | var_mask | range_mask | kurt_mask;
                            stats = compute_prediction_stats(predicted_mask, expected_mask, expected_run_has_bad, search_cfg.score_weights);

                            row_idx = row_idx + 1;
                            score(row_idx) = stats.score;
                            channel_precision(row_idx) = stats.channel_precision;
                            channel_recall(row_idx) = stats.channel_recall;
                            channel_f1(row_idx) = stats.channel_f1;
                            positive_exact_rate(row_idx) = stats.positive_exact_rate;
                            negative_exact_rate(row_idx) = stats.negative_exact_rate;
                            exact_run_matches(row_idx) = stats.exact_run_matches;
                            positive_run_exact_matches(row_idx) = stats.positive_run_exact_matches;
                            negative_run_clean_matches(row_idx) = stats.negative_run_clean_matches;
                            true_positives(row_idx) = stats.true_positives;
                            false_positives(row_idx) = stats.false_positives;
                            false_negatives(row_idx) = stats.false_negatives;
                            normalization(row_idx) = string(norm_cfg.normalization);
                            trim_percent(row_idx) = norm_cfg.trim_percent;
                            feature_set_name(row_idx) = string(feature_set.name);
                            use_correlation(row_idx) = feature_set.use_correlation;
                            use_variance(row_idx) = feature_set.use_variance;
                            use_range(row_idx) = feature_set.use_range;
                            use_kurtosis(row_idx) = feature_set.use_kurtosis;
                            corr_z_threshold(row_idx) = search_cfg.corr_threshold_values(corr_idx);
                            var_z_threshold(row_idx) = search_cfg.var_threshold_values(var_idx);
                            range_z_threshold(row_idx) = search_cfg.range_threshold_values(range_idx);
                            kurt_z_threshold(row_idx) = search_cfg.kurt_threshold_values(kurt_idx);
                        end
                    end
                end
            end
        end

        fprintf('  finished normalization mode %s (trim %.1f%%)\n', norm_cfg.normalization, norm_cfg.trim_percent);
    end

    search_results = table( ...
        score, ...
        channel_precision, ...
        channel_recall, ...
        channel_f1, ...
        positive_exact_rate, ...
        negative_exact_rate, ...
        exact_run_matches, ...
        positive_run_exact_matches, ...
        negative_run_clean_matches, ...
        true_positives, ...
        false_positives, ...
        false_negatives, ...
        normalization, ...
        trim_percent, ...
        feature_set_name, ...
        use_correlation, ...
        use_variance, ...
        use_range, ...
        use_kurtosis, ...
        corr_z_threshold, ...
        var_z_threshold, ...
        range_z_threshold, ...
        kurt_z_threshold);

    search_results = sortrows(search_results, ...
        {'score', 'channel_f1', 'positive_exact_rate', 'negative_exact_rate', 'exact_run_matches', 'false_positives', 'false_negatives'}, ...
        {'descend', 'descend', 'descend', 'descend', 'descend', 'ascend', 'ascend'});
end

function threshold_masks = build_threshold_masks(abs_z_values, invalid_mask, threshold_values)
    threshold_masks = false(size(abs_z_values, 1), size(abs_z_values, 2), numel(threshold_values));
    for threshold_idx = 1:numel(threshold_values)
        threshold_masks(:, :, threshold_idx) = invalid_mask | (abs_z_values > threshold_values(threshold_idx));
    end
end

function stats = compute_prediction_stats(predicted_mask, expected_mask, expected_run_has_bad, score_weights)
    true_positives = nnz(predicted_mask & expected_mask);
    false_positives = nnz(predicted_mask & ~expected_mask);
    false_negatives = nnz(~predicted_mask & expected_mask);

    channel_precision = safe_ratio(true_positives, true_positives + false_positives);
    channel_recall = safe_ratio(true_positives, true_positives + false_negatives);
    channel_f1 = safe_ratio(2 * channel_precision * channel_recall, channel_precision + channel_recall);

    exact_run_mask = all(predicted_mask == expected_mask, 1);
    positive_run_exact_matches = nnz(exact_run_mask & expected_run_has_bad);
    negative_run_clean_matches = nnz(exact_run_mask & ~expected_run_has_bad);
    positive_exact_rate = safe_ratio(positive_run_exact_matches, nnz(expected_run_has_bad));
    negative_exact_rate = safe_ratio(negative_run_clean_matches, nnz(~expected_run_has_bad));

    score = ...
        (score_weights.channel_f1 * channel_f1) + ...
        (score_weights.positive_exact_rate * positive_exact_rate) + ...
        (score_weights.negative_exact_rate * negative_exact_rate);

    stats = struct( ...
        'score', score, ...
        'channel_precision', channel_precision, ...
        'channel_recall', channel_recall, ...
        'channel_f1', channel_f1, ...
        'positive_exact_rate', positive_exact_rate, ...
        'negative_exact_rate', negative_exact_rate, ...
        'exact_run_matches', nnz(exact_run_mask), ...
        'positive_run_exact_matches', positive_run_exact_matches, ...
        'negative_run_clean_matches', negative_run_clean_matches, ...
        'true_positives', true_positives, ...
        'false_positives', false_positives, ...
        'false_negatives', false_negatives);
end

function run_comparison_table = build_run_comparison_table(metrics, normalization_cfgs, best_result)
    predicted_mask = predict_mask_for_result(metrics, normalization_cfgs, best_result);
    num_runs = size(predicted_mask, 2);

    expected_bad_channels = strings(num_runs, 1);
    detected_bad_channels = strings(num_runs, 1);
    missing_channels = strings(num_runs, 1);
    extra_channels = strings(num_runs, 1);
    is_exact_match = false(num_runs, 1);
    num_missing = zeros(num_runs, 1);
    num_extra = zeros(num_runs, 1);

    for run_col = 1:num_runs
        expected_idx = find(metrics.expected_mask(:, run_col));
        detected_idx = find(predicted_mask(:, run_col));
        missing_idx = setdiff(expected_idx, detected_idx);
        extra_idx = setdiff(detected_idx, expected_idx);

        expected_bad_channels(run_col) = string(format_channel_list(expected_idx));
        detected_bad_channels(run_col) = string(format_channel_list(detected_idx));
        missing_channels(run_col) = string(format_channel_list(missing_idx));
        extra_channels(run_col) = string(format_channel_list(extra_idx));
        is_exact_match(run_col) = isempty(missing_idx) && isempty(extra_idx);
        num_missing(run_col) = numel(missing_idx);
        num_extra(run_col) = numel(extra_idx);
    end

    run_comparison_table = table( ...
        metrics.subject_idx, ...
        metrics.run_idx, ...
        metrics.run_label, ...
        expected_bad_channels, ...
        detected_bad_channels, ...
        missing_channels, ...
        extra_channels, ...
        num_missing, ...
        num_extra, ...
        is_exact_match, ...
        'VariableNames', { ...
            'subject_idx', ...
            'run_idx', ...
            'run_label', ...
            'expected_bad_channels', ...
            'detected_bad_channels', ...
            'missing_channels', ...
            'extra_channels', ...
            'num_missing', ...
            'num_extra', ...
            'is_exact_match'});
end

function predicted_mask = predict_mask_for_result(metrics, normalization_cfgs, result_row)
    norm_match = strcmpi({normalization_cfgs.normalization}, char(result_row.normalization)) & ...
        ([normalization_cfgs.trim_percent] == result_row.trim_percent);
    norm_idx = find(norm_match, 1, 'first');
    if isempty(norm_idx)
        error('Unable to locate normalization configuration for the selected result.');
    end

    predicted_mask = false(size(metrics.expected_mask));
    if result_row.use_correlation
        predicted_mask = predicted_mask | metrics.invalid_corr | (metrics.abs_z_corr(:, :, norm_idx) > result_row.corr_z_threshold);
    end
    if result_row.use_variance
        predicted_mask = predicted_mask | metrics.invalid_var | (metrics.abs_z_var(:, :, norm_idx) > result_row.var_z_threshold);
    end
    if result_row.use_range
        predicted_mask = predicted_mask | metrics.invalid_range | (metrics.abs_z_range(:, :, norm_idx) > result_row.range_z_threshold);
    end
    if result_row.use_kurtosis
        predicted_mask = predicted_mask | metrics.invalid_kurt | (metrics.abs_z_kurt(:, :, norm_idx) > result_row.kurt_z_threshold);
    end
end

function value = safe_ratio(numerator, denominator)
    if denominator == 0
        value = 0;
    else
        value = numerator / denominator;
    end
end

function text_value = format_channel_list(channel_idx)
    if isempty(channel_idx)
        text_value = '[]';
        return;
    end

    text_value = strjoin(arrayfun(@num2str, channel_idx(:)', 'UniformOutput', false), ' ');
end

function diagnostics_table = build_diagnostics_table(channel_labels, details)
    channel_indices = (1:numel(channel_labels))';
    max_abs_z = max(abs([details.z_corr, details.z_var, details.z_range, details.z_kurt]), [], 2);
    reasons = arrayfun(@(idx) join_reasons(details, idx), channel_indices, 'UniformOutput', false);

    diagnostics_table = table( ...
        channel_indices, ...
        string(channel_labels(:)), ...
        details.mean_corr, ...
        details.z_corr, ...
        details.variance, ...
        details.z_var, ...
        details.range, ...
        details.z_range, ...
        details.kurtosis, ...
        details.z_kurt, ...
        details.bad_corr_mask, ...
        details.bad_var_mask, ...
        details.bad_range_mask, ...
        details.bad_kurt_mask, ...
        details.bad_mask, ...
        max_abs_z, ...
        string(reasons), ...
        'VariableNames', { ...
            'channel_index', ...
            'channel_label', ...
            'mean_corr', ...
            'z_corr', ...
            'variance', ...
            'z_var', ...
            'range', ...
            'z_range', ...
            'kurtosis', ...
            'z_kurt', ...
            'bad_corr', ...
            'bad_var', ...
            'bad_range', ...
            'bad_kurt', ...
            'is_bad', ...
            'max_abs_z', ...
            'reasons'});

    diagnostics_table = sortrows(diagnostics_table, {'is_bad', 'max_abs_z'}, {'descend', 'descend'});
end

function reason_text = join_reasons(details, idx)
    reasons = {};

    if details.bad_corr_mask(idx), reasons{end + 1} = 'corr'; end
    if details.bad_var_mask(idx), reasons{end + 1} = 'var'; end
    if details.bad_range_mask(idx), reasons{end + 1} = 'range'; end
    if details.bad_kurt_mask(idx), reasons{end + 1} = 'kurt'; end

    if isempty(reasons)
        reason_text = '';
    else
        reason_text = strjoin(reasons, ', ');
    end
end

function plot_bad_channel_diagnostics(filtered_data, diagnostics_table, details, channel_labels, fs, preview_sec, subject_idx, run_idx, figure_path)
    figure_handle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1600 1000]);
    tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot_metric_bars(details.z_corr, details.bad_corr_mask, details.corr_z_threshold, channel_labels, 'Correlation z-score');

    nexttile;
    plot_metric_bars(details.z_var, details.bad_var_mask, details.var_z_threshold, channel_labels, 'Variance z-score');

    nexttile;
    plot_metric_bars(details.z_range, details.bad_range_mask, details.range_z_threshold, channel_labels, 'Range z-score');

    nexttile;
    plot_metric_bars(details.z_kurt, details.bad_kurt_mask, details.kurt_z_threshold, channel_labels, 'Kurtosis z-score');

    nexttile([1 2]);
    plot_preview_channels(filtered_data, diagnostics_table, channel_labels, fs, preview_sec);
    title(sprintf('Filtered EEG preview - S%02d R%02d', subject_idx, run_idx));

    sgtitle(sprintf('Bad-channel diagnostics - S%02d R%02d', subject_idx, run_idx));
    exportgraphics(figure_handle, figure_path, 'Resolution', 150);
    close(figure_handle);
end

function plot_metric_bars(z_values, bad_mask, threshold, channel_labels, title_text)
    bar(z_values, 'FaceColor', [0.65 0.65 0.75], 'EdgeColor', 'none');
    hold on;
    bad_idx = find(bad_mask);
    if ~isempty(bad_idx)
        bar(bad_idx, z_values(bad_idx), 'FaceColor', [0.85 0.25 0.20], 'EdgeColor', 'none');
    end
    yline(threshold, '--r', sprintf('+%.1f', threshold));
    yline(-threshold, '--r', sprintf('-%.1f', threshold));
    hold off;
    xlim([0.5, numel(z_values) + 0.5]);
    xticks(1:numel(channel_labels));
    xticklabels(channel_labels);
    xtickangle(90);
    ylabel('z-score');
    title(title_text);
    grid on;
    box off;
end

function plot_preview_channels(filtered_data, diagnostics_table, channel_labels, fs, preview_sec)
    preview_samples = min(size(filtered_data, 2), round(preview_sec * fs));
    preview_time_sec = (0:(preview_samples - 1)) / fs;
    selected_idx = pick_preview_channels(diagnostics_table);
    selected_data = filtered_data(selected_idx, 1:preview_samples);
    spacing = max(median(max(selected_data, [], 2) - min(selected_data, [], 2)), eps) * 3;

    hold on;
    y_ticks = zeros(numel(selected_idx), 1);
    for row_idx = 1:numel(selected_idx)
        offset = (numel(selected_idx) - row_idx) * spacing;
        plot(preview_time_sec, selected_data(row_idx, :) + offset, 'LineWidth', 1);
        y_ticks(row_idx) = offset;
    end
    hold off;

    set(gca, 'YTick', sort(y_ticks, 'ascend'), 'YTickLabel', channel_labels(selected_idx(end:-1:1)));
    xlabel('Time (s)');
    ylabel('Channel');
    grid on;
    box off;
end

function selected_idx = pick_preview_channels(diagnostics_table)
    flagged_idx = diagnostics_table.channel_index(diagnostics_table.is_bad);

    if ~isempty(flagged_idx)
        selected_idx = flagged_idx(1:min(6, numel(flagged_idx)));
        return;
    end

    selected_idx = diagnostics_table.channel_index(1:min(6, height(diagnostics_table)));
end
