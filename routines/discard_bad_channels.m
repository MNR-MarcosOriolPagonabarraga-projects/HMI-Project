function [clean_channels, removed_idx, details] = discard_bad_channels(channels, cfg)
    [removed_idx, details] = get_bad_channels(channels, cfg);
    clean_channels = channels;
    clean_channels(removed_idx, :) = [];

    fprintf('Removed %d bad channels: [%s]\n', numel(removed_idx), num2str(removed_idx'));
end