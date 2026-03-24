function report_cells = initialize_d1_bad_channels_report(cfg)
    report_cells = cell(cfg.num_subjects + 1, cfg.num_runs + 1);
    report_cells(1, :) = [{'Subject'}, arrayfun(@(run_idx) sprintf('Run %d', run_idx), 1:cfg.num_runs, 'UniformOutput', false)];
    report_cells(2:end, 1) = arrayfun(@(subj) sprintf('S%d', subj), (1:cfg.num_subjects)', 'UniformOutput', false);
    report_cells(2:end, 2:end) = {''};
    writecell(report_cells, cfg.report_cfg.d1_bad_channels_csv);
end
