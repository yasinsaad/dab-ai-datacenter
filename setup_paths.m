function repo_root = setup_paths()
% SETUP_PATHS  Add the repository folders to the MATLAB path.
%
%   repo_root = setup_paths()
%
%   Adds main/, models/, utils/ and every subfolder of functions/ to the
%   path so the scripts can find the Simulink model, helper functions and
%   each other from any working directory. Every script in main/ calls
%   this first. After calling it once, scripts can be run by name
%   (e.g. DAB_freq_sweep, plot_comparison).
%
%   Output:
%       repo_root : absolute path of the repository root (char)

    repo_root = fileparts(mfilename('fullpath'));

    addpath(fullfile(repo_root, 'main'));
    addpath(fullfile(repo_root, 'models'));
    addpath(fullfile(repo_root, 'utils'));
    addpath(genpath(fullfile(repo_root, 'functions')));
end
