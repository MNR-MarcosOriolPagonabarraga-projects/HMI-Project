function write_d2_good_trial_report(results, cfg)
    channel_labels = cfg.report_cfg.d2_channel_labels;
    class_codes = [1540, 1541];
    class_indices = zeros(size(class_codes));

    for idx = 1:numel(class_codes)
        class_indices(idx) = find(results.movement_codes == class_codes(idx), 1);
        if isempty(class_indices(idx))
            error('Missing movement code %d in results.movement_codes.', class_codes(idx));
        end
    end

    channel_indices = zeros(size(channel_labels));
    for channel_idx = 1:numel(channel_labels)
        channel_indices(channel_idx) = find(strcmpi(results.channel_labels, channel_labels{channel_idx}), 1);
        if isempty(channel_indices(channel_idx))
            error('Missing D2 report channel %s in results.channel_labels.', channel_labels{channel_idx});
        end
    end

    num_subjects = size(results.good_trial_percent, 1);
    num_header_columns = 1 + numel(class_codes) * numel(channel_labels);
    report_cells = cell(num_subjects + 2, num_header_columns);
    report_cells(1, :) = {''};
    report_cells{1, 1} = 'SUBJECT';
    report_cells{1, 2} = 'CLOSE HAND (1540)';
    report_cells{1, 2 + numel(channel_labels)} = 'OPEN HAND (1541)';
    report_cells(2, :) = [{''}, repmat(channel_labels, 1, numel(class_codes))];

    for subj = 1:num_subjects
        report_cells{subj + 2, 1} = sprintf('S%d', subj);
        write_offset = 2;

        for class_pos = 1:numel(class_indices)
            class_idx = class_indices(class_pos);
            for channel_pos = 1:numel(channel_indices)
                value = results.good_trial_percent(subj, class_idx, channel_indices(channel_pos));
                report_cells{subj + 2, write_offset} = format_percent(value);
                write_offset = write_offset + 1;
            end
        end
    end

    writecell(report_cells, cfg.report_cfg.d2_good_trials_csv);
end

function value_text = format_percent(value)
    if isnan(value)
        value_text = '';
        return;
    end

    rounded_value = round(value);
    if abs(value - rounded_value) < 1e-9
        value_text = sprintf('%d%%', rounded_value);
    else
        value_text = sprintf('%.2f%%', value);
    end
end
