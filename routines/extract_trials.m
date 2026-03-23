function [epochs_by_class, trial_info_by_class, time_vector_sec] = extract_trials(data, events, processed_fs, epoch_window_sec, baseline_window_sec, class_codes, source_fs)
    if nargin < 7 || isempty(source_fs)
        source_fs = processed_fs;
    end

    start_offset = round(epoch_window_sec(1) * processed_fs);
    end_offset = round(epoch_window_sec(2) * processed_fs);
    sample_offsets = start_offset:(end_offset - 1);
    time_vector_sec = sample_offsets / processed_fs;
    baseline_mask = time_vector_sec >= baseline_window_sec(1) & time_vector_sec < baseline_window_sec(2);

    num_classes = numel(class_codes);
    num_channels = size(data, 1);
    num_samples = numel(sample_offsets);

    epochs_by_class = cell(1, num_classes);
    trial_info_by_class = cell(1, num_classes);

    for class_idx = 1:num_classes
        epochs_by_class{class_idx} = zeros(num_channels, num_samples, 0);
        trial_info_by_class{class_idx} = struct( ...
            'stimulus_code', {}, ...
            'stimulus_sample', {}, ...
            'movement_sample', {}, ...
            'reaction_time_sec', {});
    end

    for event_idx = 1:size(events, 1)
        class_idx = find(class_codes == events(event_idx, 1), 1);
        if isempty(class_idx)
            continue;
        end

        stimulus_sample = round(events(event_idx, 2) * processed_fs / source_fs);
        movement_sample = round(events(event_idx, 3) * processed_fs / source_fs);
        epoch_indices = stimulus_sample + sample_offsets;

        if epoch_indices(1) < 1 || epoch_indices(end) > size(data, 2)
            continue;
        end

        epoch = data(:, epoch_indices);

        if any(baseline_mask)
            baseline = mean(epoch(:, baseline_mask), 2);
            epoch = epoch - baseline;
        end

        epochs_by_class{class_idx}(:, :, end + 1) = epoch;
        trial_info_by_class{class_idx}(end + 1) = struct( ...
            'stimulus_code', events(event_idx, 1), ...
            'stimulus_sample', stimulus_sample, ...
            'movement_sample', movement_sample, ...
            'reaction_time_sec', compute_reaction_time(stimulus_sample, movement_sample, processed_fs));
    end
end

function reaction_time_sec = compute_reaction_time(stimulus_sample, movement_sample, fs)
    if movement_sample <= 0
        reaction_time_sec = NaN;
        return;
    end

    reaction_time_sec = (movement_sample - stimulus_sample) / fs;
end
