function [bad_idx, details] = get_bad_channels_segmented(channels, cfg)
    % Sliding-window bad-channel vote (Fer's approach): per segment, z-score each
    % feature across channels; flag channels exceeding segment_z_threshold in any
    % enabled metric; mark bad if bad in more than segment_bad_fraction of segments.
    num_channels = size(channels, 1);
    n_samples = size(channels, 2);
    fs = cfg.sample_rate_hz;

    if isempty(fs) || ~isfinite(fs) || fs <= 0
        error('get_bad_channels_segmented:cfg.sample_rate_hz must be a positive sample rate (Hz).');
    end

    segment_length = round(cfg.segment_length_sec * fs);
    step = round(cfg.segment_step_sec * fs);

    if segment_length < 2
        error('get_bad_channels_segmented:segment_length_sec is too small for the sample rate.');
    end

    if step < 1
        error('get_bad_channels_segmented:segment_step_sec is too small.');
    end

    starts = 1:step:(n_samples - segment_length + 1);
    n_segments = numel(starts);

    if n_segments == 0
        warning('get_bad_channels_segmented:Recording shorter than one segment; no bad channels flagged.');
        cfg_flat = cfg;
        cfg_flat.use_segmented_windows = false;
        [bad_idx, details] = get_bad_channels(channels, cfg_flat);
        details.use_segmented_windows = true;
        details.n_segments = 0;
        details.bad_segment_counts = zeros(num_channels, 1);
        details.segmented_bad_fraction_per_channel = zeros(num_channels, 1);
        return;
    end

    z_th = cfg.segment_z_threshold;
    bad_count = zeros(num_channels, 1);

    for s = 1:n_segments
        seg = channels(:, starts(s):(starts(s) + segment_length - 1));
        bad_seg = collect_bad_channels_in_segment(seg, z_th, cfg);
        bad_count(bad_seg) = bad_count(bad_seg) + 1;
    end

    vote_threshold = n_segments * cfg.segment_bad_fraction;
    bad_idx = find(bad_count > vote_threshold);

    if numel(bad_idx) >= num_channels
        warning('get_bad_channels_segmented:All channels exceeded the vote threshold; keeping all channels.');
        bad_idx = [];
    end

    cfg_flat = cfg;
    cfg_flat.use_segmented_windows = false;
    [~, details] = get_bad_channels(channels, cfg_flat);

    details.use_segmented_windows = true;
    details.n_segments = n_segments;
    details.bad_segment_counts = bad_count;
    details.segmented_bad_fraction_per_channel = bad_count / n_segments;
    details.segment_bad_fraction = cfg.segment_bad_fraction;
    details.segment_vote_threshold = vote_threshold;
    details.segment_z_threshold = cfg.segment_z_threshold;
    details.segment_length_sec = cfg.segment_length_sec;
    details.segment_step_sec = cfg.segment_step_sec;

    bad_mask = false(num_channels, 1);
    bad_mask(bad_idx) = true;
    details.bad_mask = bad_mask;
    details.bad_corr_mask = bad_mask;
    details.bad_var_mask = bad_mask;
    details.bad_range_mask = bad_mask;
    details.bad_kurt_mask = bad_mask;
end

function bad_seg = collect_bad_channels_in_segment(segment, z_th, cfg)
    num_channels = size(segment, 1);
    bad_seg = [];

    R = corrcoef(segment');
    ch_corr = zeros(num_channels, 1);
    for i = 1:num_channels
        idx = [1:(i - 1), (i + 1):num_channels];
        ch_corr(i) = mean(R(i, idx), 'omitnan');
    end

    ch_var = var(segment, 0, 2);
    ch_amp = max(segment, [], 2) - min(segment, [], 2);
    ch_kurt = kurtosis(segment, 0, 2);

    z_corr = zscore_safe(ch_corr);
    z_var = zscore_safe(ch_var);
    z_amp = zscore_safe(ch_amp);
    z_kurt = zscore_safe(ch_kurt);

    if cfg.use_correlation
        bad_seg = [bad_seg; find(abs(z_corr) > z_th & isfinite(z_corr))]; %#ok<AGROW>
    end

    if cfg.use_variance
        bad_seg = [bad_seg; find(abs(z_var) > z_th & isfinite(z_var))]; %#ok<AGROW>
    end

    if cfg.use_range
        bad_seg = [bad_seg; find(abs(z_amp) > z_th & isfinite(z_amp))]; %#ok<AGROW>
    end

    if cfg.use_kurtosis
        bad_seg = [bad_seg; find(abs(z_kurt) > z_th & isfinite(z_kurt))]; %#ok<AGROW>
    end

    bad_seg = unique(bad_seg);
end

function z = zscore_safe(x)
    x = x(:);
    z = zeros(size(x));
    finite_mask = isfinite(x);
    if nnz(finite_mask) < 2
        return;
    end
    xv = x(finite_mask);
    mu = mean(xv);
    sigma = std(xv, 0);
    if sigma <= eps
        return;
    end
    z(finite_mask) = (xv - mu) ./ sigma;
end
