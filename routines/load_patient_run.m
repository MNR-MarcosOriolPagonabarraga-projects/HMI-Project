function [raw_data, chanlocs, events] = load_patient_run(run_path, num_eeg_channels)
    loaded = load(run_path, 'EEG');
    EEG = loaded.EEG;

    raw_data = double(EEG.data(1:num_eeg_channels, :));
    chanlocs = EEG.chanlocs(1:num_eeg_channels);
    events = double(EEG.events);
end