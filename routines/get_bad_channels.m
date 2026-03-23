function [bad_idx, details] = get_bad_channels(channels, cfg)
    corr_matrix = corrcoef(channels');
    corr_matrix(logical(eye(size(corr_matrix)))) = NaN;
    mean_corr = mean(corr_matrix, 2, 'omitnan');

    channel_variance = var(channels, 0, 2);
    channel_mad = mad(channels, 1, 2);
    channel_kurtosis = kurtosis(channels, 0, 2);

    low_corr_mask = mean_corr < cfg.corr_threshold;
    variance_mask = is_outlier_tukey(channel_variance, cfg.iqr_multiplier) | abs(trimmed_zscore(channel_variance, cfg.trim_percent)) > cfg.z_threshold;
    mad_mask = is_outlier_tukey(channel_mad, cfg.iqr_multiplier) | abs(trimmed_zscore(channel_mad, cfg.trim_percent)) > cfg.z_threshold;
    kurtosis_mask = is_outlier_tukey(channel_kurtosis, cfg.iqr_multiplier) | trimmed_zscore(channel_kurtosis, cfg.trim_percent) > cfg.z_threshold;

    bad_mask = low_corr_mask | variance_mask;
    bad_idx = find(bad_mask);

    details = struct( ...
        'mean_corr', mean_corr, ...
        'variance', channel_variance, ...
        'mad', channel_mad, ...
        'kurtosis', channel_kurtosis, ...
        'low_corr_mask', low_corr_mask, ...
        'variance_mask', variance_mask, ...
        'mad_mask', mad_mask, ...
        'kurtosis_mask', kurtosis_mask);
end

function z_values = trimmed_zscore(values, trim_percent)
    values = values(:);
    trim_fraction = max(0, min(trim_percent, 49.9)) / 100;
    sorted_values = sort(values);
    trim_count = floor(numel(sorted_values) * trim_fraction);
    trimmed_values = sorted_values((trim_count + 1):(numel(sorted_values) - trim_count));

    center_value = mean(trimmed_values);
    spread_value = std(trimmed_values);

    if spread_value <= eps
        z_values = zeros(size(values));
        return;
    end

    z_values = (values - center_value) ./ spread_value;
end

function mask = is_outlier_tukey(values, multiplier)
    quartiles = quantile(values, [0.25 0.75]);
    iqr_value = quartiles(2) - quartiles(1);

    if iqr_value <= eps
        mask = false(size(values));
        return;
    end

    lower_bound = quartiles(1) - multiplier * iqr_value;
    upper_bound = quartiles(2) + multiplier * iqr_value;
    mask = values < lower_bound | values > upper_bound;
end