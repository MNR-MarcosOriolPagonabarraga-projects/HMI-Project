function bad_idx = get_bad_channels(channels, threshold, trim_percent)
    % 1. Correlation Matrix (Vectorized)
    R = corrcoef(channels');
    
    % 2. Mean correlation per channel (excluding self-correlation)
    % Setting diagonal to NaN allows using 'omitnan' to get the mean of others
    R(logical(eye(size(R)))) = NaN;
    mean_corr = mean(R, 2, 'omitnan');
    
    % 3. Robust Statistics using trimmean
    % trimmean automatically handles the sorting and indexing for you
    robust_mean = trimmean(mean_corr, trim_percent);
    
    % Calculate robust standard deviation (on the trimmed data)
    % We manually trim here to get the SD of the 'clean' distribution
    q = trim_percent / 100 / 2;
    trimmed_vals = sort(mean_corr);
    n = length(trimmed_vals);
    trimmed_vals = trimmed_vals(ceil(n*q)+1 : floor(n*(1-q)));
    robust_std = std(trimmed_vals);
    
    % 4. Z-Score and Thresholding
    z_corr = (mean_corr - robust_mean) / robust_std;
    bad_idx = find(z_corr < -threshold);

end