% Filtering
eeg_fs = 512;
eeg_filt_order = 4;
eeg_filt_band = [0.3 70];

% Selecting bad channels (channels with mean correlation below this are discarded)
r_coef_threshold = 0.5;
