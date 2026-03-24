function processed_fs = resolve_processed_fs(raw_fs, decimation_factor)
    processed_fs = raw_fs / decimation_factor;

    if abs(processed_fs - round(processed_fs)) > 1e-9
        error(['Decimation factor %g yields a non-integer sampling rate of %.12g Hz from raw_fs=%g. ' ...
            'ICLabel requires EEG.srate to be integer-valued. Choose a decimation factor that divides raw_fs exactly.'], ...
            decimation_factor, processed_fs, raw_fs);
    end

    processed_fs = round(processed_fs);
end
