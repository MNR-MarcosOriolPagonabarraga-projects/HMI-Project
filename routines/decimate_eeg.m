function decimated_data = decimate_eeg(channels, factor)
    if factor == 1
        decimated_data = channels;
        return;
    end

    if factor < 1 || mod(factor, 1) ~= 0
        error('Decimation factor must be a positive integer.');
    end

    decimated_data = resample(channels', 1, factor)';
end
