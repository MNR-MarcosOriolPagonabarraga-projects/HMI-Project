function setup_project_paths(binica_support_dir)
    if exist(binica_support_dir, 'dir')
        addpath(binica_support_dir);
    end
end
