function [] = plot_channels(channels)
    spacing = mean(channels,"all");
    figure;
    hold on;
    for i = 1:length(channels(:,1))
        disp(i)
        plot(channels(i, :) + spacing*i*20)
    end
end