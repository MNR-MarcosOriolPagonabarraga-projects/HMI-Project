function filt_eeg_channels = band_pass_filter(eeg_channels, fs, order, band)
    if size(eeg_channels, 2) < (order * 3)
        error('Not enough samples to filter the EEG channels.');
    end

    Wn = band / (fs / 2);
    [b, a] = butter(order, Wn, 'bandpass');
    filt_eeg_channels = filtfilt(b, a, detrend(eeg_channels', 'constant'))';
end