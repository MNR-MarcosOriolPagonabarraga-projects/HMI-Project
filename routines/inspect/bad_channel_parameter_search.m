function bad_channel_parameter_search(cfg, search_cfg)
    if search_cfg.warn_if_flat_search_with_segmented_cfg && cfg.bad_channel_cfg.use_segmented_windows
        warning([ ...
            'bad_channel_parameter_search: cfg.bad_channel_cfg.use_segmented_windows is true. ', ...
            'The fast grid search optimizes flat (whole-recording) z-scores from compute_bad_channel_zscores ', ...
            'and does not match segmented voting. Set search_cfg.run_segmented_pipeline_search = true ', ...
            'to search using get_bad_channels (same as the main pipeline), or temporarily set ', ...
            'use_segmented_windows to false in constants when tuning global thresholds.']);
    end

    expected_bad_channels = build_expected_bad_channels(cfg);
    dataset = load_search_dataset(cfg, search_cfg, expected_bad_channels);
    if isempty(dataset)
        error('No run files were found for the requested subject/run search space.');
    end

    normalization_cfgs = build_normalization_cfgs(search_cfg);
    feature_sets = build_feature_sets(search_cfg);

    fprintf('\nLoaded %d available runs for parameter search.\n', numel(dataset));

    if search_cfg.run_segmented_pipeline_search
        search_results = evaluate_segmented_pipeline_search(dataset, cfg, search_cfg, feature_sets);
        metrics = struct();
        metrics.expected_mask = [];
    else
        metrics = precompute_search_metrics(dataset, normalization_cfgs, cfg);
        fprintf('Reference positive runs: %d | reference clean runs: %d\n', ...
            nnz(metrics.expected_run_has_bad), nnz(~metrics.expected_run_has_bad));
        search_results = evaluate_search_space(metrics, normalization_cfgs, feature_sets, search_cfg);
    end

    writetable(search_results, search_cfg.results_csv_path);

    best_result = search_results(1, :);
    if search_cfg.run_segmented_pipeline_search
        run_comparison_table = build_run_comparison_table_segmented(dataset, cfg, best_result);
    else
        run_comparison_table = build_run_comparison_table(metrics, normalization_cfgs, best_result);
    end
    writetable(run_comparison_table, search_cfg.best_run_csv_path);

    top_count = min(search_cfg.max_top_results, height(search_results));
    fprintf('\nTop %d configurations:\n', top_count);
    disp(search_results(1:top_count, :));

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
        'expected_bad_idx', {});

    for subject_idx = search_cfg.subject_indices
        for run_idx = search_cfg.run_indices
            run_path = fullfile(cfg.data_root, sprintf('S%d', subject_idx), sprintf('ME_S%02d_r%02d.mat', subject_idx, run_idx));
            if ~isfile(run_path)
                continue;
            end

            dataset(end + 1) = struct( ...
                'subject_idx', subject_idx, ...
                'run_idx', run_idx, ...
                'run_path', run_path, ...
                'run_label', sprintf('S%02d R%02d', subject_idx, run_idx), ...
                'expected_bad_idx', expected_bad_channels{subject_idx, run_idx}); %#ok<AGROW>
        end
    end
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

function feature_sets = build_feature_sets(search_cfg)
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

    if isfield(search_cfg, 'feature_set_names') && ~isempty(search_cfg.feature_set_names)
        wanted = string(search_cfg.feature_set_names(:));
        names = strings(numel(feature_sets), 1);
        for i = 1:numel(feature_sets)
            names(i) = string(feature_sets(i).name);
        end
        keep = false(numel(feature_sets), 1);
        for w = 1:numel(wanted)
            idx = find(names == wanted(w), 1);
            if isempty(idx)
                error('build_feature_sets: unknown feature set name ''%s''.', wanted(w));
            end
            keep(idx) = true;
        end
        feature_sets = feature_sets(keep);
    end
end

function metrics = precompute_search_metrics(dataset, normalization_cfgs, cfg)
    num_runs = numel(dataset);
    num_norm_cfgs = numel(normalization_cfgs);
    num_channels = cfg.num_eeg_channels;

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

        [raw_data, ~] = load_patient_run(dataset(run_col).run_path, cfg.num_eeg_channels);
        filtered_data = band_pass_filter(raw_data, cfg.raw_fs, cfg.filter_cfg.order, cfg.filter_cfg.band_hz);

        for norm_idx = 1:num_norm_cfgs
            norm_cfg = normalization_cfgs(norm_idx);
            bc = cfg.bad_channel_cfg;
            bc.use_segmented_windows = false;
            bc.normalization = norm_cfg.normalization;
            bc.trim_percent = norm_cfg.trim_percent;
            zdetail = compute_bad_channel_zscores(filtered_data, bc);

            if norm_idx == 1
                invalid_corr(:, run_col) = ~isfinite(zdetail.mean_corr);
                invalid_var(:, run_col) = ~isfinite(zdetail.variance);
                invalid_range(:, run_col) = ~isfinite(zdetail.range);
                invalid_kurt(:, run_col) = ~isfinite(zdetail.kurtosis);
            end

            abs_z_corr(:, run_col, norm_idx) = abs(zdetail.z_corr);
            abs_z_var(:, run_col, norm_idx) = abs(zdetail.z_var);
            abs_z_range(:, run_col, norm_idx) = abs(zdetail.z_range);
            abs_z_kurt(:, run_col, norm_idx) = abs(zdetail.z_kurt);
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

    fprintf('Evaluating %d parameter combinations (flat z-scores from compute_bad_channel_zscores)...\n', total_configs);
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

function search_results = evaluate_segmented_pipeline_search(dataset, cfg, search_cfg, feature_sets)
    sz_z = numel(search_cfg.segment_z_threshold_values);
    sz_f = numel(search_cfg.segment_bad_fraction_values);
    sz_l = numel(search_cfg.segment_length_sec_values);
    sz_s = numel(search_cfg.segment_step_sec_values);
    n_feat = numel(feature_sets);
    total_configs = sz_z * sz_f * sz_l * sz_s * n_feat;

    fprintf('Evaluating %d segmented pipeline configs (get_bad_channels)...\n', total_configs);

    score = zeros(total_configs, 1);
    channel_f1 = zeros(total_configs, 1);
    positive_exact_rate = zeros(total_configs, 1);
    negative_exact_rate = zeros(total_configs, 1);
    exact_run_matches = zeros(total_configs, 1);
    true_positives = zeros(total_configs, 1);
    false_positives = zeros(total_configs, 1);
    false_negatives = zeros(total_configs, 1);

    seg_z = zeros(total_configs, 1);
    seg_frac = zeros(total_configs, 1);
    seg_len = zeros(total_configs, 1);
    seg_step = zeros(total_configs, 1);
    feature_set_name = strings(total_configs, 1);
    use_correlation = false(total_configs, 1);
    use_variance = false(total_configs, 1);
    use_range = false(total_configs, 1);
    use_kurtosis = false(total_configs, 1);

    num_runs = numel(dataset);
    num_ch = cfg.num_eeg_channels;
    expected_mask = false(num_ch, num_runs);
    for run_col = 1:num_runs
        ex = dataset(run_col).expected_bad_idx;
        if ~isempty(ex)
            expected_mask(ex, run_col) = true;
        end
    end
    expected_run_has_bad = any(expected_mask, 1);

    row_idx = 0;
    for iz = 1:sz_z
        for ifrac = 1:sz_f
            for il = 1:sz_l
                for is = 1:sz_s
                    for feat_idx = 1:n_feat
                        row_idx = row_idx + 1;
                        bc = cfg.bad_channel_cfg;
                        bc.use_segmented_windows = true;
                        bc.sample_rate_hz = cfg.raw_fs;
                        bc.segment_z_threshold = search_cfg.segment_z_threshold_values(iz);
                        bc.segment_bad_fraction = search_cfg.segment_bad_fraction_values(ifrac);
                        bc.segment_length_sec = search_cfg.segment_length_sec_values(il);
                        bc.segment_step_sec = search_cfg.segment_step_sec_values(is);
                        fs = feature_sets(feat_idx);
                        bc.use_correlation = fs.use_correlation;
                        bc.use_variance = fs.use_variance;
                        bc.use_range = fs.use_range;
                        bc.use_kurtosis = fs.use_kurtosis;

                        predicted_mask = false(num_ch, num_runs);
                        for run_col = 1:num_runs
                            [raw_data, ~] = load_patient_run(dataset(run_col).run_path, cfg.num_eeg_channels);
                            fd = band_pass_filter(raw_data, cfg.raw_fs, cfg.filter_cfg.order, cfg.filter_cfg.band_hz);
                            [bad_idx, ~] = get_bad_channels(fd, bc);
                            predicted_mask(bad_idx, run_col) = true;
                        end

                        stats = compute_prediction_stats(predicted_mask, expected_mask, expected_run_has_bad, search_cfg.score_weights);
                        score(row_idx) = stats.score;
                        channel_f1(row_idx) = stats.channel_f1;
                        positive_exact_rate(row_idx) = stats.positive_exact_rate;
                        negative_exact_rate(row_idx) = stats.negative_exact_rate;
                        exact_run_matches(row_idx) = stats.exact_run_matches;
                        true_positives(row_idx) = stats.true_positives;
                        false_positives(row_idx) = stats.false_positives;
                        false_negatives(row_idx) = stats.false_negatives;

                        seg_z(row_idx) = bc.segment_z_threshold;
                        seg_frac(row_idx) = bc.segment_bad_fraction;
                        seg_len(row_idx) = bc.segment_length_sec;
                        seg_step(row_idx) = bc.segment_step_sec;
                        feature_set_name(row_idx) = string(fs.name);
                        use_correlation(row_idx) = fs.use_correlation;
                        use_variance(row_idx) = fs.use_variance;
                        use_range(row_idx) = fs.use_range;
                        use_kurtosis(row_idx) = fs.use_kurtosis;
                    end
                end
            end
        end
    end

    search_results = table( ...
        score, channel_f1, positive_exact_rate, negative_exact_rate, exact_run_matches, ...
        true_positives, false_positives, false_negatives, ...
        seg_z, seg_frac, seg_len, seg_step, ...
        feature_set_name, use_correlation, use_variance, use_range, use_kurtosis);

    search_results = sortrows(search_results, ...
        {'score', 'channel_f1', 'positive_exact_rate', 'negative_exact_rate', 'exact_run_matches', 'false_positives', 'false_negatives'}, ...
        {'descend', 'descend', 'descend', 'descend', 'descend', 'ascend', 'ascend'});
end

function run_comparison_table = build_run_comparison_table_segmented(dataset, cfg, best_result)
    bc = cfg.bad_channel_cfg;
    bc.use_segmented_windows = true;
    bc.sample_rate_hz = cfg.raw_fs;
    bc.segment_z_threshold = best_result.seg_z;
    bc.segment_bad_fraction = best_result.seg_frac;
    bc.segment_length_sec = best_result.seg_len;
    bc.segment_step_sec = best_result.seg_step;
    bc.use_correlation = best_result.use_correlation;
    bc.use_variance = best_result.use_variance;
    bc.use_range = best_result.use_range;
    bc.use_kurtosis = best_result.use_kurtosis;

    num_runs = numel(dataset);
    num_ch = cfg.num_eeg_channels;
    predicted_mask = false(num_ch, num_runs);
    metrics = struct();
    metrics.expected_mask = false(num_ch, num_runs);
    for run_col = 1:num_runs
        ex = dataset(run_col).expected_bad_idx;
        if ~isempty(ex)
            metrics.expected_mask(ex, run_col) = true;
        end
        [raw_data, ~] = load_patient_run(dataset(run_col).run_path, cfg.num_eeg_channels);
        fd = band_pass_filter(raw_data, cfg.raw_fs, cfg.filter_cfg.order, cfg.filter_cfg.band_hz);
        [bad_idx, ~] = get_bad_channels(fd, bc);
        predicted_mask(bad_idx, run_col) = true;
    end

    metrics.subject_idx = [dataset.subject_idx]';
    metrics.run_idx = [dataset.run_idx]';
    metrics.run_label = string({dataset.run_label}');
    run_comparison_table = pack_run_comparison_table(metrics, predicted_mask);
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
    run_comparison_table = pack_run_comparison_table(metrics, predicted_mask);
end

function run_comparison_table = pack_run_comparison_table(metrics, predicted_mask)
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
