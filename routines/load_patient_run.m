function [data] = load_patient_run(run_path)
    load(run_path);

    %% Discard the unused channels
    data = EEG.data(1:61, :);
end