function process_one_subject_1(subj)

clc;

%% =========================
% PARÁMETROS
%% =========================
fs = 512;
runs = 1:10;

classes = [1536 1537 1538 1539 1540 1541 1542];
n_classes = length(classes);

%% =========================
% VARIABLES
%% =========================
bad_channels_all = cell(1,10);
good_trials_matrix_all = cell(1,10);
class_labels_all = cell(1,10);
ERP_runs = cell(n_classes,1);

perc_good_trials = zeros(n_classes,1);

fprintf('Procesando sujeto %d...\n', subj);

%% =========================
% LOOP RUNS
%% =========================
for run = runs
    
    fprintf('  Run %d...\n', run);
    
    %% -------- LOAD --------
    filename = sprintf('S%d/ME_S%02d_r%02d.mat', subj, subj, run);
    
    if ~isfile(filename)
        warning('Archivo no encontrado: %s', filename);
        continue;
    end
    
    EEG_orig = load(filename);
    data = EEG_orig.EEG.data(1:61,:);
    events = EEG_orig.EEG.events;
    
    %% -------- PREPROCESSING --------
    data = detrend(double(data)')';
    
    % notch
    [b_notch,a_notch] = butter(2,[49 51]/(fs/2),'stop');
    data = filtfilt(b_notch,a_notch,data')';
    
    % bandpass
    [b_band,a_band] = butter(4,[0.3 70]/(fs/2),'bandpass');
    data = filtfilt(b_band,a_band,data')';
    
    %% -------- BAD CHANNELS --------
    num_channels = size(data,1);
    n_samples = size(data,2);
    
    segment_length = fs * 2;
    step = segment_length / 2;
    
    starts = 1:step:(n_samples - segment_length + 1);
    n_segments = length(starts);
    
    bad_count = zeros(num_channels,1);
    
    for s = 1:n_segments
        
        segment = data(:, starts(s):starts(s)+segment_length-1);
        
        R = corrcoef(segment');
        
        ch_corr = zeros(num_channels,1);
        for i=1:num_channels
            ch_corr(i) = mean(R(i,[1:i-1 i+1:num_channels]));
        end
        
        ch_var = var(segment,0,2);
        ch_amp = max(segment,[],2) - min(segment,[],2);
        ch_kurt = kurtosis(segment,0,2);
        
        z_corr = zscore(ch_corr);
        z_var  = zscore(ch_var);
        z_amp  = zscore(ch_amp);
        z_kurt = zscore(ch_kurt);
        
        z_th = 3;
        
        bad_seg = unique([find(abs(z_corr)>z_th); ...
                          find(abs(z_var)>z_th); ...
                          find(abs(z_amp)>z_th); ...
                          find(abs(z_kurt)>z_th)]);
        
        bad_count(bad_seg) = bad_count(bad_seg) + 1;
    end
    
    bad_channels = find(bad_count > n_segments/2);
    bad_channels_all{run} = bad_channels;
    
    good_channels = setdiff(1:61, bad_channels);
    
    if isempty(good_channels)
        warning('Todos los canales marcados como malos');
        good_channels = 1:61;
    end
    
    %% -------- CAR --------
    global_avg = mean(data(good_channels,:),1);
    data = data - global_avg;
    
    %% -------- EEGLAB --------
    EEG = eeg_emptyset;
    EEG.data = data;
    EEG.srate = fs;
    EEG.nbchan = 61;
    EEG.pnts = size(data,2);
    EEG.trials = 1;
    EEG.chanlocs = EEG_orig.EEG.chanlocs(1:61);
    
    EEG.event = [];
    for e=1:size(events,1)
        EEG.event(e).type = events(e,1);
        EEG.event(e).latency = events(e,2);
    end
    
    EEG = eeg_checkset(EEG,'eventconsistency');
    
    %% -------- ICA -------- 
    EEG = pop_runica(EEG, 'icatype', 'sobi');
    
    EEG = pop_iclabel(EEG,'default');
    
    EEG = pop_icflag(EEG,[NaN NaN;
                         0.7 1;
                         0.7 1;
                         0.7 1;
                         0.7 1;
                         0.7 1;
                         NaN NaN]);
    
    EEG = pop_subcomp(EEG, [], 0);
    
    %% -------- INTERPOLATION --------
    EEG = pop_interp(EEG, EEG_orig.EEG.chanlocs(1:61),'spherical');
    
    %% -------- EPOCHING --------
    EEG_ep = pop_epoch(EEG, num2cell(classes), [-2.5 6]);
    EEG_ep = pop_rmbase(EEG_ep, [-200 0]);
    
    data_ep = permute(EEG_ep.data,[3 1 2]); % trials x ch x time
    n_trials = size(data_ep,1);
    
    %% -------- LABELS --------
    labels = [EEG_ep.event.type];
    class_labels_all{run} = labels;
    
    %% -------- REACTION TIME --------
    stim = events(:,2);
    onset = events(:,3);
    
    valid_idx = ismember(events(:,1), classes);
    stim = stim(valid_idx);
    onset = onset(valid_idx);
    
    rt = (onset - stim) / fs;
    
    %% -------- TRIAL REJECTION --------
    good_trials = ones(n_trials,1);
    good_matrix = ones(n_trials,61);
    
    for t=1:n_trials
        
        trial = squeeze(data_ep(t,:,:)); % canales x tiempo
        
        % RT SOLO PARA MOVIMIENTOS
        if labels(t) ~= 1542
            
            if rt(t) < 0.1 || rt(t) > 2
                good_trials(t) = 0;
                good_matrix(t,:) = 0;
                continue;
            end
            
        end
        
        % features por canal
        trial_var = var(trial,0,2);
        trial_kurt = kurtosis(trial,0,2);
        
        z_var = zscore(trial_var);
        z_kurt = zscore(trial_kurt);
        
        for ch = 1:61
            
            signal = trial(ch,:);
            
            % amplitud
            if max(abs(signal)) > 150
                good_matrix(t,ch) = 0;
            end
            
            % outliers
            if abs(z_var(ch)) > 5 || abs(z_kurt(ch)) > 5
                good_matrix(t,ch) = 0;
            end
        end
        
        % criterio de mayoría de canales
        if sum(good_matrix(t,:)) < 0.5*61
            good_trials(t) = 0;
        end
        
    end
    
    good_trials_matrix_all{run} = good_matrix;
    
    %% -------- ERP --------
    for c=1:n_classes
        
        idx = find(labels == classes(c));
        valid = intersect(idx, find(good_trials));
        
        if ~isempty(valid)
            
            new_data = data_ep(valid,:,:);
            
            if isempty(ERP_runs{c})
                ERP_runs{c} = new_data;
            else
                ERP_runs{c} = cat(1, ERP_runs{c}, new_data);
            end
            
            perc_good_trials(c) = perc_good_trials(c) + ...
                length(valid)/length(idx);
        end
    end
    
end

%% =========================
% MEDIA FINAL (Cz)
%% =========================
cz = 30;

time_len = [];

for c=1:n_classes
    if ~isempty(ERP_runs{c})
        time_len = size(ERP_runs{c},3);
        break;
    end
end

if isempty(time_len)
    error('No hay datos válidos para ningún ERP');
end

ERP_subject = nan(n_classes, time_len);

for c=1:n_classes
    
    if isempty(ERP_runs{c})
        warning('Clase %d vacía en sujeto %d', classes(c), subj);
        continue;
    end
    
    ERP_subject(c,:) = squeeze(mean(ERP_runs{c}(:,cz,:),1));
end

perc_good_trials = perc_good_trials / length(runs);

%% =========================
% GUARDAR
%% =========================
save(sprintf('results_S%d.mat',subj), ...
     'ERP_subject',...
     'bad_channels_all',...
     'good_trials_matrix_all',...
     'class_labels_all',...
     'perc_good_trials');

fprintf('Sujeto %d terminado\n', subj);

end