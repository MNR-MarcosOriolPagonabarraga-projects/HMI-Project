function [] = plot_channels(channels)
    spacing = mean(channels,"all");
    hold on;
    for i = 1:length(channels(:,1))
        plot(channels(i, :) + spacing*i*20)
    end
end