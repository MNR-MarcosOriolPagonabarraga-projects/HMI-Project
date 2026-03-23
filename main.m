clc;
clear;
close all;

run('constants.m');
addpath('routines');

if ~exist(output_root, 'dir')
    mkdir(output_root);
end

if ~exist(figures_root, 'dir')
    mkdir(figures_root);
end

if ~exist(tables_root, 'dir')
    mkdir(tables_root);
end

eeglab('nogui');

num_classes = numel(movement_codes);
processed_fs = raw_fs / decimation_factor;

results = struct();
results.config = struct( ...
    'filter_cfg', filter_cfg, ...
    'bad_channel_cfg', bad_channel_cfg, ...
    'decimation_factor', decimation_factor, ...
    'ica_cfg', ica_cfg, ...
    'epoch_cfg', epoch_cfg);
results.movement_codes = movement_codes;
results.movement_labels = movement_labels;
results.processed_fs = processed_fs;
results.bad_channels = cell(num_subjects, num_runs);
results.bad_channel_labels = cell(num_subjects, num_runs);
results.bad_channel_details = cell(num_subjects, num_runs);
results.trial_masks = cell(num_subjects, num_classes);
results.trial_rejection_details = cell(num_subjects, num_classes);
results.run_trial_summary = cell(num_subjects, num_runs, num_classes);
results.good_trial_percent = nan(num_subjects, num_classes, num_eeg_channels);
results.good_trial_percent_mean = nan(num_subjects, num_classes);
results.class_trial_counts = zeros(num_subjects, num_classes);
results.cz_average = cell(num_subjects, num_classes);
results.cz_good_trial_count = zeros(num_subjects, num_classes);
results.time_vector_sec = [];
results.channel_labels = {};
trial_rejection_rows = struct([]);

for subj = 1:num_subjects
    fprintf('\n=== Subject %02d ===\n', subj);
    subject_epochs = cell(1, num_classes);
    subject_masks = cell(1, num_classes);
    subject_rejection_details = cell(1, num_classes);

    for run_idx = 1:num_runs
        run_path = fullfile(data_root, sprintf('S%d', subj), sprintf('ME_S%02d_r%02d.mat', subj, run_idx));
        if ~isfile(run_path)
            fprintf('Missing file, skipping: %s\n', run_path);
            continue;
        end

        fprintf('Processing S%02d R%02d...\n', subj, run_idx);
        [raw_data, original_chanlocs, events] = load_patient_run(run_path, num_eeg_channels);

        filtered_data = band_pass_filter(raw_data, raw_fs, filter_cfg.order, filter_cfg.band_hz);
        [clean_data, bad_idx, bad_details] = discard_bad_channels(filtered_data, bad_channel_cfg);
        results.bad_channels{subj, run_idx} = bad_idx;
        results.bad_channel_labels{subj, run_idx} = {original_chanlocs(bad_idx).labels};
        results.bad_channel_details{subj, run_idx} = bad_details;

        decimated_data = decimate_eeg(clean_data, decimation_factor);
        good_chanlocs = original_chanlocs;
        good_chanlocs(bad_idx) = [];
        EEG_run = build_eeglab_dataset(decimated_data, processed_fs, good_chanlocs, sprintf('S%02d_R%02d', subj, run_idx));
        EEG_run = apply_car(EEG_run);
        EEG_run = run_ica_and_clean(EEG_run, ica_cfg);
        EEG_run = interpolate_bad_channels(EEG_run, original_chanlocs, bad_idx);

        final_data = double(EEG_run.data);
        [run_epochs, run_trial_info, time_vector_sec] = extract_trials( ...
            final_data, ...
            events, ...
            processed_fs, ...
            epoch_cfg.window_sec, ...
            epoch_cfg.baseline_sec, ...
            movement_codes, ...
            raw_fs);

        if isempty(results.time_vector_sec)
            results.time_vector_sec = time_vector_sec;
            results.channel_labels = arrayfun(@(chanloc) chanloc.labels, EEG_run.chanlocs, 'UniformOutput', false);
        end

        if plot_cfg.enabled && ismember(subj, plot_cfg.diagnostic_subjects) && ismember(run_idx, plot_cfg.diagnostic_runs)
            plot_preprocessing_steps( ...
                raw_data, ...
                filtered_data, ...
                final_data, ...
                original_chanlocs, ...
                bad_idx, ...
                raw_fs, ...
                processed_fs, ...
                subj, ...
                run_idx, ...
                figures_root, ...
                plot_cfg);
        end

        for class_idx = 1:num_classes
            [trial_mask, reject_summary, reject_details] = reject_bad_trials(run_epochs{class_idx}, run_trial_info{class_idx}, epoch_cfg);
            results.run_trial_summary{subj, run_idx, class_idx} = reject_summary;

            if isempty(subject_epochs{class_idx})
                subject_epochs{class_idx} = run_epochs{class_idx};
            else
                subject_epochs{class_idx} = cat(3, subject_epochs{class_idx}, run_epochs{class_idx});
            end

            if isempty(subject_masks{class_idx})
                subject_masks{class_idx} = trial_mask;
            else
                subject_masks{class_idx} = [subject_masks{class_idx}; trial_mask];
            end

            if isempty(subject_rejection_details{class_idx})
                subject_rejection_details{class_idx} = struct( ...
                    'rt_invalid_mask', reject_details.rt_invalid_mask, ...
                    'amplitude_bad_mask', reject_details.amplitude_bad_mask);
            else
                subject_rejection_details{class_idx}.rt_invalid_mask = [ ...
                    subject_rejection_details{class_idx}.rt_invalid_mask; ...
                    reject_details.rt_invalid_mask];
                subject_rejection_details{class_idx}.amplitude_bad_mask = [ ...
                    subject_rejection_details{class_idx}.amplitude_bad_mask; ...
                    reject_details.amplitude_bad_mask];
            end

            new_rows = build_trial_rejection_rows( ...
                subj, ...
                run_idx, ...
                movement_labels{class_idx}, ...
                results.channel_labels, ...
                run_trial_info{class_idx}, ...
                reject_details);

            if isempty(trial_rejection_rows)
                trial_rejection_rows = new_rows;
            else
                trial_rejection_rows = [trial_rejection_rows; new_rows]; %#ok<AGROW>
            end
        end
    end

    cz_idx = find(strcmpi(results.channel_labels, plot_cfg.erp_channel_label), 1);

    for class_idx = 1:num_classes
        if isempty(subject_masks{class_idx})
            continue;
        end

        results.trial_masks{subj, class_idx} = subject_masks{class_idx};
        results.trial_rejection_details{subj, class_idx} = subject_rejection_details{class_idx};
        results.class_trial_counts(subj, class_idx) = size(subject_masks{class_idx}, 1);
        results.good_trial_percent(subj, class_idx, :) = 100 * mean(subject_masks{class_idx}, 1);
        results.good_trial_percent_mean(subj, class_idx) = mean(squeeze(results.good_trial_percent(subj, class_idx, :)), 'omitnan');

        if isempty(cz_idx) || isempty(subject_epochs{class_idx})
            continue;
        end

        cz_good_trials = subject_masks{class_idx}(:, cz_idx);
        results.cz_good_trial_count(subj, class_idx) = sum(cz_good_trials);

        if any(cz_good_trials)
            cz_epochs = squeeze(subject_epochs{class_idx}(cz_idx, :, :))';
            results.cz_average{subj, class_idx} = mean(cz_epochs(cz_good_trials, :), 1);
        end
    end

    if plot_cfg.enabled
        plot_trial_rejection_overview(subj, subject_rejection_details, results.channel_labels, movement_labels, figures_root);
    end
end

results.grand_mean_cz = cell(1, num_classes);
for class_idx = 1:num_classes
    subject_curves = results.cz_average(:, class_idx);
    valid_subjects = ~cellfun(@isempty, subject_curves);

    if any(valid_subjects)
        results.grand_mean_cz{class_idx} = mean(cat(1, subject_curves{valid_subjects}), 1);
    end
end

if isempty(trial_rejection_rows)
    results.trial_rejection_table = table();
else
    results.trial_rejection_table = struct2table(trial_rejection_rows);
    write_trial_rejection_tables(results.trial_rejection_table, tables_root);
end

plot_cz_erp_summary(results.time_vector_sec, results.cz_average, results.grand_mean_cz, movement_labels, figures_root);
save(results_path, 'results', '-v7.3');
fprintf('\nProcessing complete. Results saved to %s\n', results_path);