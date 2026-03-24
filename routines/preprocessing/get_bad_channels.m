function [bad_idx, details] = get_bad_channels(channels, cfg)
    num_channels = size(channels, 1);

    corr_matrix = corrcoef(channels');
    corr_matrix(1:(num_channels + 1):end) = NaN;
    mean_corr = mean(corr_matrix, 2, 'omitnan');

    channel_variance = var(channels, 0, 2);
    channel_range = max(channels, [], 2) - min(channels, [], 2);
    channel_kurtosis = kurtosis(channels, 0, 2);

    z_corr = safe_zscore(mean_corr);
    z_var = safe_zscore(channel_variance);
    z_range = safe_zscore(channel_range);
    z_kurt = safe_zscore(channel_kurtosis);

    bad_corr_mask = ~isfinite(mean_corr) | abs(z_corr) > cfg.z_threshold;
    bad_var_mask = ~isfinite(channel_variance) | abs(z_var) > cfg.z_threshold;
    bad_range_mask = ~isfinite(channel_range) | abs(z_range) > cfg.z_threshold;
    bad_kurt_mask = ~isfinite(channel_kurtosis) | abs(z_kurt) > cfg.z_threshold;

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
        'z_threshold', cfg.z_threshold);
end

function z_values = safe_zscore(values)
    values = values(:);
    z_values = zeros(size(values));
    finite_mask = isfinite(values);

    if nnz(finite_mask) < 2
        return;
    end

    finite_values = values(finite_mask);
    center_value = mean(finite_values);
    spread_value = std(finite_values, 0);

    if spread_value <= eps
        return;
    end

    z_values(finite_mask) = (finite_values - center_value) ./ spread_value;
end