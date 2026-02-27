function [clean_channels, removed_idx] = discard_bad_channels(channels)
    threshold = 0.5;
    trim_percent = 10;
    % Find the indices
    removed_idx = get_bad_channels(channels, threshold, trim_percent);
    
    % Remove them from the matrix
    clean_channels = channels;
    clean_channels(removed_idx, :) = [];
    
    % Print summary to console
    fprintf('Removed %d bad channels: [%s]\n', length(removed_idx), num2str(removed_idx'));
end