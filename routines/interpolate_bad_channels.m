function EEG = interpolate_bad_channels(EEG, original_chanlocs, bad_idx)
    if isempty(bad_idx)
        fprintf('No channels to interpolate.\n');
        return;
    end

    fprintf('Interpolating %d bad channels using spherical splines...\n', numel(bad_idx));
    EEG = pop_interp(EEG, original_chanlocs, 'spherical');
    EEG = eeg_checkset(EEG);
end