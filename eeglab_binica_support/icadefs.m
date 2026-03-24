% Local override for BINICA support without spaces in the binary path.

support_dir = fileparts(mfilename('fullpath'));
eeglab_path = which('eeglab');

if ~isempty(eeglab_path)
    original_icadefs = fullfile(fileparts(eeglab_path), 'functions', 'sigprocfunc', 'icadefs.m');
    if exist(original_icadefs, 'file') == 2
        run(original_icadefs);
    end
end

ICABINARY = fullfile(support_dir, 'ica_linux');
SC = fullfile(support_dir, 'binica.sc');
