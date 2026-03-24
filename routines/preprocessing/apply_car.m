function EEG = apply_car(EEG)
    avg_signal = mean(EEG.data, 1);
    EEG.data = EEG.data - avg_signal;
    EEG = eeg_checkset(EEG);
    fprintf('Applied Common Average Referencing.\n');
end