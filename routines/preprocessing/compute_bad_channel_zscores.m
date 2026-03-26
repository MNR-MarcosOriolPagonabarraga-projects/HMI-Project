function [details, cfg] = compute_bad_channel_zscores(channels, cfg_in)
    % Same feature extraction and robust z-scoring as get_bad_channels (flat path).
    % Used by the pipeline and by hyperparameter search — single source of truth.
    cfg = bad_channel_cfg_apply_defaults(cfg_in);

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

    details = struct( ...
        'mean_corr', mean_corr, ...
        'variance', channel_variance, ...
        'range', channel_range, ...
        'kurtosis', channel_kurtosis, ...
        'z_corr', z_corr, ...
        'z_var', z_var, ...
        'z_range', z_range, ...
        'z_kurt', z_kurt);
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
