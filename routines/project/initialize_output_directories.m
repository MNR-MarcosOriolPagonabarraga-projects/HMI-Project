function initialize_output_directories(output_dirs)
    for dir_idx = 1:numel(output_dirs)
        output_dir = output_dirs{dir_idx};
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
    end
end
