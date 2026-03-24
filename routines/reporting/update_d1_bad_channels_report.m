function report_cells = update_d1_bad_channels_report(report_cells, subj, run_idx, bad_idx, cfg)
    report_cells{subj + 1, run_idx + 1} = format_bad_channel_entry(bad_idx);
    writecell(report_cells, cfg.report_cfg.d1_bad_channels_csv);
end

function entry = format_bad_channel_entry(bad_idx)
    if isempty(bad_idx)
        entry = '[]';
        return;
    end

    entry = strjoin(arrayfun(@num2str, bad_idx(:)', 'UniformOutput', false), ' ');
end
