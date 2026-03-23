function EEG = apply_car(EEG)
    % Applies Common Average Referencing (CAR) [cite: 93, 104]
    % Subtracts the mean of all good channels from each channel.
    
    avg_signal = mean(EEG.data, 1);
    EEG.data = EEG.data - avg_signal;
    EEG = eeg_checkset(EEG);
    fprintf('Applied Common Average Referencing.\n');
end