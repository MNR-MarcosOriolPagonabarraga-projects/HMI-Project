function bad_idx = get_bad_channels(channels, threshold)
    % 1. Correlation Matrix (Vectorized)
    R = corrcoef(channels');
    
    % 2. Mean correlation per channel (excluding self-correlation)
    % Setting diagonal to NaN allows using 'omitnan' to get the mean of others
    R(logical(eye(size(R)))) = NaN;
    mean_corr = mean(R, 2, 'omitnan');

    bad_idx = find(mean_corr < threshold);
end