function EEG = run_ica_and_clean(EEG)
    % Runs Infomax ICA and uses ICLabel to subtract eye and muscle artifacts [cite: 24, 110, 113]
    
    % 1. Calculate rank to prevent crashes (due to rejected channels)
    dataRank = rank(double(EEG.data));
    
    % 2. Run ICA
    fprintf('Running ICA...\n');
    EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1, 'pca', dataRank);
    
    % 3. Run ICLabel to classify components [cite: 113]
    EEG = iclabel(EEG);
    
    % 4. Identify bad components (Threshold > 0.7 for Eyes or Muscle) [cite: 116]
    % ICLabel classes: 1:Brain, 2:Muscle, 3:Eye, 4:Heart, 5:Line Noise, 6:Channel Noise, 7:Other
    probabilities = EEG.etc.ic_classification.ICLabel.classifications;
    bad_components = find(probabilities(:, 2) > 0.7 | probabilities(:, 3) > 0.7);
    
    if isempty(bad_components)
        fprintf('ICA: No major artifact components found above threshold.\n');
    else
        fprintf('ICA: Subtracting %d bad components.\n', length(bad_components));
        % Subtract bad components and reconstruct signal
        EEG = pop_subcomp(EEG, bad_components, 0);
    end
    EEG = eeg_checkset(EEG);
end