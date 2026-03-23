clc; clear;
run('constants.m');
addpath('routines');

% Start EEGLAB in background
[ALLEEG, EEG_empty, CURRENTSET, ALLCOM] = eeglab;

% Initialize Deliverable Structures 
D1_bad_channels = cell(15, 10);
D2_good_trials = zeros(15, 10); 

% Loop over 15 Subjects
for subj = 1:1
    % Loop over 10 Runs
    for run_idx = 1:1
        % Construct file path
        file_path = fullfile('data', sprintf('S%d', subj), sprintf('ME_S%02d_r%02d.mat', subj, run_idx));
        
        if ~isfile(file_path)
            fprintf('File not found, skipping: %s\n', file_path);
            continue;
        end
        fprintf('\n--- Processing Subject %d, Run %d ---\n', subj, run_idx);
        
        %% 1. LOAD DATA & EXTRACT CHANLOCS
        % We load the raw file to get the data and original channel locations
        load(file_path, 'EEG'); 
        raw_data = double(EEG.data(1:61, :));
        original_chanlocs = EEG.chanlocs(1:61);
        events = EEG.events; % Save events for trial extraction
        
        %% 2. FILTERING
        % Bandpass filter 0.3 to 70 Hz [cite: 60]
        filtered_data = band_pass_filter(raw_data, eeg_fs, eeg_filt_order, eeg_filt_band);
        
        %% 3. BAD CHANNEL REJECTION
        [clean_data, bad_idx] = discard_bad_channels(filtered_data, r_coef_threshold);
        D1_bad_channels{subj, run_idx} = bad_idx;
        
        %% 4. CONVERT TO EEGLAB STRUCTURE
        % Pack the cleaned matrix into an EEGLAB structure for advanced functions
        EEG_run = pop_importdata('dataformat', 'array', 'nbchan', size(clean_data,1), ...
            'data', clean_data, 'srate', eeg_fs);
        
        % Assign valid channel locations (excluding the rejected ones)
        EEG_run.chanlocs = original_chanlocs;
        EEG_run.chanlocs(bad_idx) = [];
        EEG_run = eeg_checkset(EEG_run);
        
        %% 5. RE-REFERENCING
        % Common Average Referencing (CAR) 
        EEG_run = apply_car(EEG_run);
        
        %% 6. ICA & ARTIFACT SUBTRACTION
        % Blind source separation and ICLabel classification [cite: 106, 113]
        EEG_run = run_ica_and_clean(EEG_run);
        
        %% 7. INTERPOLATION
        % Spherical spline interpolation of bad channels 
        EEG_run = interpolate_bad_channels(EEG_run, original_chanlocs, bad_idx);
        
        %% 8. TRIAL EXTRACTION
        % Extract epochs from -2.5 to 6s relative to stimulus [cite: 150]
        % (Assuming 'events' structure matches EEGLAB format)
        % EEG_run = extract_trials(EEG_run, events);
        
        % Store arbitrary trial success rate for Deliverable 2 logic
        % D2_good_trials(subj, run_idx) = ... 
    end
end

disp('Processing Complete!');