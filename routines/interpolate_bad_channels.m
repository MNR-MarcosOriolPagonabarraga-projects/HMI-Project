function EEG = interpolate_bad_channels(EEG, original_chanlocs, bad_idx)
    % Uses spherical interpolation to reconstruct missing channels [cite: 123, 128, 129]
    
    if isempty(bad_idx)
        fprintf('No channels to interpolate.\n');
        return;
    end
    
    fprintf('Interpolating %d bad channels using spherical splines...\n', length(bad_idx));
    
    % pop_interp requires the target dataset to have the FULL chanlocs 
    % so it knows where to put the missing data.
    EEG = pop_interp(EEG, original_chanlocs, 'spherical');
    EEG = eeg_checkset(EEG);
end