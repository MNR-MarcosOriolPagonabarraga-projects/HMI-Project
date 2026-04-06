clear; clc;

%% =========================
% PARÁMETROS
%% =========================
subjects = [1 3 4 5 6 7 9 12];
runs = 1:10;

classes = [1536 1537 1538 1539 1540 1541 1542];
n_classes = length(classes);

movement_names = {'Elbow flex','Elbow ext','Supination','Pronation','Close hand','Open hand','Rest'};

channels_of_interest = [17 23 30 40]; % FC4 FCC2h Cz CCP6h
channel_names = {'FC4','FCC2h','Cz','CCP6h'};

fs = 512;
t = (-2.5:1/fs:6-1/fs);

%% =========================
% 1. PROCESAR TODOS LOS SUJETOS
%% =========================
eeglab

for subj = subjects
    process_one_subject_1(subj);
end

%% =========================
% 2. CARGAR RESULTADOS
%% =========================
ERP_subject_all = nan(length(subjects), n_classes, length(t)); % <-- NAN importante

bad_channels_all_total = cell(length(subjects),10);
good_trials_matrix_total = cell(length(subjects),10);
class_labels_total = cell(length(subjects),10);

for s = 1:length(subjects)
    
    subj = subjects(s);
    
    S = load(sprintf('results_S%d.mat',subj));
    
    ERP_subject_all(s,:,:) = S.ERP_subject;
    
    bad_channels_all_total(s,:) = S.bad_channels_all;
    good_trials_matrix_total(s,:) = S.good_trials_matrix_all;
    class_labels_total(s,:) = S.class_labels_all;
end

%% =========================
% D1 → BAD CHANNELS (TABLA)
%% =========================
fprintf('\n=========== D1: BAD CHANNELS (TABLA) ===========\n');

n_subj = length(subjects);
n_runs = 10;

D1_table = cell(n_subj, n_runs);

for s = 1:n_subj
    for run = 1:n_runs
        
        bad_ch = bad_channels_all_total{s, run};
        
        if isempty(bad_ch)
            D1_table{s, run} = '[]';
        else
            D1_table{s, run} = strtrim(sprintf('%d ', bad_ch));
        end
        
    end
end

col_names = arrayfun(@(r) sprintf('run%d', r), 1:n_runs, 'UniformOutput', false);
row_names = arrayfun(@(subj) sprintf('S%d', subj), subjects, 'UniformOutput', false);

T_D1 = cell2table(D1_table, ...
    'VariableNames', col_names);

% añadir columna subject
T_D1.subject = row_names';
T_D1 = movevars(T_D1, 'subject', 'Before', 1);

format compact
disp(T_D1);

% guardar bien
writetable(T_D1, 'D1_bad_channels.csv', 'Delimiter', ';');
%% =========================
% D2 → % GOOD TRIALS (TABLA)
%% =========================
fprintf('\n=========== D2: PORCENTAJE GOOD TRIALS ===========\n');

rows = {};
data_table = [];

for s = 1:length(subjects)
    
    subj = subjects(s);
    
    for c = 1:n_classes
        
        total_trials = 0;
        good_counts = zeros(1,length(channels_of_interest));
        
        for run = 1:10
            
            M = good_trials_matrix_total{s,run};
            labels = class_labels_total{s,run};
            
            if isempty(M)
                continue;
            end
            
            class_idx = find(labels == classes(c));
            
            if isempty(class_idx)
                continue;
            end
            
            total_trials = total_trials + length(class_idx);
            
            for ch = 1:length(channels_of_interest)
                good_counts(ch) = good_counts(ch) + ...
                    sum(M(class_idx, channels_of_interest(ch)));
            end
        end
        
        if total_trials > 0
            perc = good_counts / total_trials * 100;
        else
            perc = zeros(1,length(channels_of_interest));
        end
        
        rows{end+1,1} = sprintf('S%d - %s', subj, movement_names{c});
        data_table(end+1,:) = perc;
        
    end
end
data_table = round(data_table,2);
T_D2 = array2table(data_table,'VariableNames', channel_names);
T_D2.subject = rows;
T_D2 = movevars(T_D2, 'subject', 'Before', 1);

disp(T_D2);

% guardar
writetable(T_D2, 'D2_good_trials.csv', 'Delimiter',';');

%% =========================
% D3 → ERP INDIVIDUAL (SMOOTH + EJE COMO EJEMPLO)
%% =========================

fprintf('\n=========== D3: ERP INDIVIDUAL ===========\n');

for s = 1:length(subjects)
    
    subj = subjects(s);
    
    folder_name = sprintf('S%d_figures', subj);
    if ~exist(folder_name, 'dir')
        mkdir(folder_name);
    end
    
    for c = 1:n_classes
        
        ERP = squeeze(ERP_subject_all(s,c,:));
        
        if all(isnan(ERP))
            continue;
        end
        
        % 🔥 SMOOTH SOLO PARA PLOT
        ERP_plot = movmean(ERP, 20);
        
        % 🔥 CAMBIO DE EJE (como ejemplo)
        t_plot = t + 2;
        
        fig = figure('Visible','off');
        
        plot(t_plot, ERP_plot, 'LineWidth',1.5)
        grid on
        
        title(sprintf('%s (S%d)', movement_names{c}, subj))
        xlabel('Time (s)')
        ylabel('uV')
        
        % eventos
        xline(0,'--k','0 (warning)','LabelVerticalAlignment','bottom');
        xline(2,'--k','2 (imperative)','LabelVerticalAlignment','bottom');
        
        
        xlim([-0.5 8])
        
        filename = fullfile(folder_name, ...
            sprintf('S%d_%s.png', subj, movement_names{c}));
        
        saveas(fig, filename);
        close(fig);
        
    end
end
%% =========================
% D3 → GRAND AVERAGE (SMOOTH + EJE COMO EJEMPLO)
%% =========================

fprintf('\n=========== D3: GRAND AVERAGE ===========\n');

if ~exist('GrandAverage_figures','dir')
    mkdir('GrandAverage_figures');
end

ERP_grand = squeeze(mean(ERP_subject_all, 1, 'omitnan'));

for c = 1:n_classes
    
    ERP = squeeze(ERP_grand(c,:));
    
    if all(isnan(ERP))
        continue;
    end
    
    % 🔥 SMOOTH
    ERP_plot = movmean(ERP, 20);
    
    % 🔥 CAMBIO DE EJE
    t_plot = t + 2;
    
    fig = figure('Visible','off');
    
    plot(t_plot, ERP_plot, 'LineWidth',2)
    grid on
    
    title(sprintf('Grand Average - %s', movement_names{c}))
    xlabel('Time (s)')
    ylabel('uV')
    
    % eventos
    xline(0,'--k','0 (warning)','LabelVerticalAlignment','bottom');
    xline(2,'--k','2 (imperative)','LabelVerticalAlignment','bottom');
    
    xlim([-0.5 8])
    
    filename = fullfile('GrandAverage_figures', ...
        sprintf('Grand_%s.png', movement_names{c}));
    
    saveas(fig, filename);
    close(fig);
    
end