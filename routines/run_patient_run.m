function run_result = run_patient_run(run_path, subj, run_idx, cfg)
    [raw_data, original_chanlocs, events] = load_patient_run(run_path, cfg.num_eeg_channels);

    % 1) Filter the continuous EEG in the assignment band.
    filtered_data = band_pass_filter(raw_data, cfg.raw_fs, cfg.filter_cfg.order, cfg.filter_cfg.band_hz);

    % 2) Detect and remove bad channels before spatial processing.
    [retained_data, bad_idx, bad_details] = discard_bad_channels(filtered_data, cfg.bad_channel_cfg);
    retained_chanlocs = remove_bad_chanlocs(original_chanlocs, bad_idx);

    % 3) Decimate the retained EEG if requested.
    decimated_data = decimate_eeg(retained_data, cfg.decimation_factor);
    processed_fs = resolve_processed_fs(cfg.raw_fs, cfg.decimation_factor);

    % 4) Re-reference the remaining channels with CAR.
    EEG_run = build_eeglab_dataset(decimated_data, processed_fs, retained_chanlocs, sprintf('S%02d_R%02d', subj, run_idx));
    EEG_run = apply_car(EEG_run);

    % 5) Run ICA and remove components classified as artifacts.
    EEG_run = run_ica_and_clean(EEG_run, cfg.ica_cfg);

    % 6) Reconstruct previously removed channels by spherical interpolation.
    EEG_run = interpolate_bad_channels(EEG_run, original_chanlocs, bad_idx);

    % 7) Extract baseline-corrected epochs around each stimulus.
    final_data = double(EEG_run.data);
    [run_epochs, run_trial_info, time_vector_sec] = extract_trials( ...
        final_data, ...
        events, ...
        processed_fs, ...
        cfg.epoch_cfg.window_sec, ...
        cfg.epoch_cfg.baseline_sec, ...
        cfg.movement_codes, ...
        cfg.raw_fs);

    % 8) Reject bad trials and collect the ERP channel data for reporting.
    channel_labels = arrayfun(@(chanloc) chanloc.labels, EEG_run.chanlocs, 'UniformOutput', false);
    [run_trial_masks, run_trial_summaries, run_rejection_details, run_cz_epochs] = evaluate_run_trials( ...
        run_epochs, ...
        run_trial_info, ...
        channel_labels, ...
        cfg);

    run_result = struct( ...
        'subject', subj, ...
        'run', run_idx, ...
        'cache_signature', build_run_cache_signature(cfg), ...
        'bad_idx', bad_idx, ...
        'bad_labels', {arrayfun(@(chanloc) chanloc.labels, original_chanlocs(bad_idx), 'UniformOutput', false)}, ...
        'bad_details', bad_details, ...
        'channel_labels', {channel_labels}, ...
        'time_vector_sec', time_vector_sec, ...
        'run_trial_info', {run_trial_info}, ...
        'run_trial_masks', {run_trial_masks}, ...
        'run_trial_summaries', {run_trial_summaries}, ...
        'run_rejection_details', {run_rejection_details}, ...
        'run_cz_epochs', {run_cz_epochs}, ...
        'class_trial_counts', cellfun(@(mask) size(mask, 1), run_trial_masks));
end

function retained_chanlocs = remove_bad_chanlocs(original_chanlocs, bad_idx)
    retained_chanlocs = original_chanlocs;
    retained_chanlocs(bad_idx) = [];
end

function [run_trial_masks, run_trial_summaries, run_rejection_details, run_cz_epochs] = evaluate_run_trials(run_epochs, run_trial_info, channel_labels, cfg)
    num_classes = numel(cfg.movement_codes);
    run_trial_masks = cell(1, num_classes);
    run_trial_summaries = cell(1, num_classes);
    run_rejection_details = cell(1, num_classes);
    run_cz_epochs = cell(1, num_classes);
    cz_idx = find(strcmpi(channel_labels, cfg.erp_channel_label), 1);

    for class_idx = 1:num_classes
        [trial_mask, reject_summary, reject_details] = reject_bad_trials(run_epochs{class_idx}, run_trial_info{class_idx}, cfg.epoch_cfg);
        run_trial_masks{class_idx} = trial_mask;
        run_trial_summaries{class_idx} = reject_summary;
        run_rejection_details{class_idx} = reject_details;
        run_cz_epochs{class_idx} = extract_channel_epochs(run_epochs{class_idx}, cz_idx);
    end
end

function channel_epochs = extract_channel_epochs(class_epochs, channel_idx)
    if isempty(channel_idx) || isempty(class_epochs)
        channel_epochs = [];
        return;
    end

    channel_epochs = squeeze(class_epochs(channel_idx, :, :))';
end
