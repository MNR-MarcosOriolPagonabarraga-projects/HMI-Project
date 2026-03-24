function plot_channels(channels, time_vector_sec, channel_labels, title_text)
    if nargin < 2 || isempty(time_vector_sec)
        time_vector_sec = 1:size(channels, 2);
    end

    if nargin < 3 || isempty(channel_labels)
        channel_labels = arrayfun(@(idx) sprintf('Ch %d', idx), 1:size(channels, 1), 'UniformOutput', false);
    end

    if nargin < 4
        title_text = '';
    end

    channel_span = max(channels, [], 2) - min(channels, [], 2);
    spacing = max(median(channel_span), eps) * 3;

    hold on;
    y_ticks = zeros(size(channels, 1), 1);

    for channel_idx = 1:size(channels, 1)
        offset = (size(channels, 1) - channel_idx) * spacing;
        plot(time_vector_sec, channels(channel_idx, :) + offset, 'LineWidth', 1);
        y_ticks(channel_idx) = offset;
    end

    hold off;
    [sorted_ticks, sort_idx] = sort(y_ticks, 'ascend');
    sorted_labels = channel_labels(sort_idx);
    set(gca, 'YTick', sorted_ticks, 'YTickLabel', sorted_labels);
    xlabel('Time (s)');
    ylabel('Channel');
    title(title_text);
    grid on;
    box off;
end