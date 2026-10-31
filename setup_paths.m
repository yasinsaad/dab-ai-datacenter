function repo_root = setup_paths()
% SETUP_PATHS  Add the repository folders to the MATLAB path.
%
%   repo_root = setup_paths()
%
%   Adds models/, utils/ and every subfolder of functions/ to the path so
%   the scripts in main/ can find the Simulink model and helper functions
%   from any working directory. Every script in main/ calls this first.
%
%   Output:
%       repo_root : absolute path of the repository root (char)

    repo_root = fileparts(mfilename('fullpath'));

    addpath(fullfile(repo_root, 'models'));
    addpath(fullfile(repo_root, 'utils'));
    addpath(genpath(fullfile(repo_root, 'functions')));
end
