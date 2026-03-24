function EEG = run_ica_and_clean(EEG, cfg)
    dataRank = rank(double(EEG.data));
    ica_backend = select_ica_backend(cfg);
    fprintf('[%s] Running ICA with %s...\n', timestamp_string(), upper(ica_backend));
    ica_timer = tic;
    EEG = pop_runica(EEG, 'icatype', ica_backend, 'extended', 1, 'pca', dataRank);
    fprintf('[%s] ICA finished in %.1f minutes.\n', timestamp_string(), toc(ica_timer) / 60);

    fprintf('[%s] Starting ICLabel classification.\n', timestamp_string());
    fprintf('[%s] If MatConvNet is not compiled, this step can be very slow.\n', timestamp_string());
    if isunix && ~contains(getenv('LD_PRELOAD'), 'libstdc++.so.6')
        fprintf('[%s] Hint: launch MATLAB through run_matlab_fast.sh to avoid slow ICLabel fallback.\n', timestamp_string());
    end

    heartbeat = start_console_heartbeat('ICLabel', cfg.heartbeat_sec);
    heartbeat_cleanup = onCleanup(@() stop_console_heartbeat(heartbeat));
    iclabel_timer = tic;
    EEG = iclabel(EEG);
    stop_console_heartbeat(heartbeat);
    clear heartbeat_cleanup;
    fprintf('[%s] ICLabel finished in %.1f minutes.\n', timestamp_string(), toc(iclabel_timer) / 60);

    probabilities = EEG.etc.ic_classification.ICLabel.classifications;
    selected_probabilities = probabilities(:, cfg.artifact_class_indices);
    bad_components = find(any(selected_probabilities > cfg.threshold, 2));

    if isempty(bad_components)
        fprintf('[%s] ICA: No artifact components found above threshold.\n', timestamp_string());
    else
        fprintf('[%s] ICA: Subtracting %d bad components.\n', timestamp_string(), numel(bad_components));
        EEG = pop_subcomp(EEG, bad_components, 0);
    end

    EEG = eeg_checkset(EEG);
end

function ica_backend = select_ica_backend(cfg)
    requested_algorithm = lower(string(cfg.algorithm));

    if requested_algorithm ~= "auto"
        ica_backend = char(requested_algorithm);
        return;
    end

    if can_use_binica()
        ica_backend = 'binica';
    else
        ica_backend = 'runica';
    end
end

function is_available = can_use_binica()
    project_root = fileparts(fileparts(mfilename('fullpath')));
    support_dir = fullfile(project_root, 'eeglab_binica_support');
    binary_path = fullfile(support_dir, 'ica_linux');
    source_path = fullfile(support_dir, 'binica.sc');

    is_available = exist('binica', 'file') == 2 && ...
        exist(binary_path, 'file') == 2 && ...
        exist(source_path, 'file') == 2;

    if ~is_available
        return;
    end

    is_available = ~contains(binary_path, ' ') && ~contains(source_path, ' ');
end

function heartbeat = start_console_heartbeat(stage_name, period_sec)
    heartbeat = struct('enabled', false, 'marker_path', '', 'script_path', '');

    if ~(isunix || ismac)
        return;
    end

    heartbeat.marker_path = tempname;
    marker_fid = fopen(heartbeat.marker_path, 'w');
    if marker_fid == -1
        return;
    end
    fprintf(marker_fid, '%s\n', stage_name);
    fclose(marker_fid);

    heartbeat.script_path = [tempname '.sh'];
    script_fid = fopen(heartbeat.script_path, 'w');
    if script_fid == -1
        delete_if_exists(heartbeat.marker_path);
        heartbeat.marker_path = '';
        return;
    end

    fprintf(script_fid, '#!/usr/bin/env bash\n');
    fprintf(script_fid, 'marker="%s"\n', heartbeat.marker_path);
    fprintf(script_fid, 'parent_pid=%d\n', feature('getpid'));
    fprintf(script_fid, 'while kill -0 "$parent_pid" 2>/dev/null && [ -f "$marker" ]; do\n');
    fprintf(script_fid, '  printf ''[%%s] %s still running...\\n'' "$(date +%%H:%%M:%%S)"\n', stage_name);
    fprintf(script_fid, '  sleep %d\n', period_sec);
    fprintf(script_fid, 'done\n');
    fclose(script_fid);

    fileattrib(heartbeat.script_path, '+x');
    system(sprintf('bash "%s" &', heartbeat.script_path));
    heartbeat.enabled = true;
end

function stop_console_heartbeat(heartbeat)
    if ~isstruct(heartbeat)
        return;
    end

    if isfield(heartbeat, 'marker_path') && ~isempty(heartbeat.marker_path)
        delete_if_exists(heartbeat.marker_path);
    end

    if isfield(heartbeat, 'script_path') && ~isempty(heartbeat.script_path)
        delete_if_exists(heartbeat.script_path);
    end
end

function delete_if_exists(path_to_delete)
    if ~isempty(path_to_delete) && isfile(path_to_delete)
        delete(path_to_delete);
    end
end

function value = timestamp_string()
    value = char(datetime('now', 'Format', 'HH:mm:ss'));
end