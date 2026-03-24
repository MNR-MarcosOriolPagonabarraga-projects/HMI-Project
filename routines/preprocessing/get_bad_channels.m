function [bad_idx, details] = get_bad_channels(channels, cfg)
    cfg = apply_defaults(cfg);
    num_channels = size(channels, 1);

    corr_matrix = corrcoef(channels');
    corr_matrix(1:(num_channels + 1):end) = NaN;
    mean_corr = mean(corr_matrix, 2, 'omitnan');

    channel_variance = var(channels, 0, 2);
    channel_range = max(channels, [], 2) - min(channels, [], 2);
    channel_kurtosis = kurtosis(channels, 0, 2);

    z_corr = safe_zscore(mean_corr, cfg);
    z_var = safe_zscore(channel_variance, cfg);
    z_range = safe_zscore(channel_range, cfg);
    z_kurt = safe_zscore(channel_kurtosis, cfg);

    bad_corr_mask = build_feature_mask(mean_corr, z_corr, cfg.use_correlation, cfg.corr_z_threshold);
    bad_var_mask = build_feature_mask(channel_variance, z_var, cfg.use_variance, cfg.var_z_threshold);
    bad_range_mask = build_feature_mask(channel_range, z_range, cfg.use_range, cfg.range_z_threshold);
    bad_kurt_mask = build_feature_mask(channel_kurtosis, z_kurt, cfg.use_kurtosis, cfg.kurt_z_threshold);

    bad_mask = bad_corr_mask | bad_var_mask | bad_range_mask | bad_kurt_mask;
    bad_idx = find(bad_mask);

    details = struct( ...
        'mean_corr', mean_corr, ...
        'variance', channel_variance, ...
        'range', channel_range, ...
        'kurtosis', channel_kurtosis, ...
        'z_corr', z_corr, ...
        'z_var', z_var, ...
        'z_range', z_range, ...
        'z_kurt', z_kurt, ...
        'bad_corr_mask', bad_corr_mask, ...
        'bad_var_mask', bad_var_mask, ...
        'bad_range_mask', bad_range_mask, ...
        'bad_kurt_mask', bad_kurt_mask, ...
        'bad_mask', bad_mask, ...
        'z_threshold', cfg.z_threshold, ...
        'corr_z_threshold', cfg.corr_z_threshold, ...
        'var_z_threshold', cfg.var_z_threshold, ...
        'range_z_threshold', cfg.range_z_threshold, ...
        'kurt_z_threshold', cfg.kurt_z_threshold, ...
        'use_correlation', cfg.use_correlation, ...
        'use_variance', cfg.use_variance, ...
        'use_range', cfg.use_range, ...
        'use_kurtosis', cfg.use_kurtosis, ...
        'normalization', cfg.normalization, ...
        'trim_percent', cfg.trim_percent);
end

function cfg = apply_defaults(cfg)
    default_fields = struct( ...
        'z_threshold', 5, ...
        'corr_z_threshold', [], ...
        'var_z_threshold', [], ...
        'range_z_threshold', [], ...
        'kurt_z_threshold', [], ...
        'use_correlation', true, ...
        'use_variance', true, ...
        'use_range', true, ...
        'use_kurtosis', true, ...
        'normalization', 'trimmed', ...
        'trim_percent', 10);

    default_names = fieldnames(default_fields);
    for field_idx = 1:numel(default_names)
        field_name = default_names{field_idx};
        if ~isfield(cfg, field_name) || isempty(cfg.(field_name))
            cfg.(field_name) = default_fields.(field_name);
        end
    end

    if isempty(cfg.corr_z_threshold), cfg.corr_z_threshold = cfg.z_threshold; end
    if isempty(cfg.var_z_threshold), cfg.var_z_threshold = cfg.z_threshold; end
    if isempty(cfg.range_z_threshold), cfg.range_z_threshold = cfg.z_threshold; end
    if isempty(cfg.kurt_z_threshold), cfg.kurt_z_threshold = cfg.z_threshold; end
end

function bad_mask = build_feature_mask(feature_values, z_values, is_enabled, z_threshold)
    if ~is_enabled
        bad_mask = false(size(feature_values));
        return;
    end

    bad_mask = ~isfinite(feature_values) | abs(z_values) > z_threshold;
end

function z_values = safe_zscore(values, cfg)
    values = values(:);
    z_values = zeros(size(values));
    finite_mask = isfinite(values);

    if nnz(finite_mask) < 2
        return;
    end

    finite_values = values(finite_mask);
    [center_value, spread_value] = compute_center_spread(finite_values, cfg);

    if spread_value <= eps
        return;
    end

    z_values(finite_mask) = (finite_values - center_value) ./ spread_value;
end

function [center_value, spread_value] = compute_center_spread(values, cfg)
    use_trimmed = strcmpi(cfg.normalization, 'trimmed') && cfg.trim_percent > 0;

    if use_trimmed
        trimmed_values = trim_each_tail(values, cfg.trim_percent);
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