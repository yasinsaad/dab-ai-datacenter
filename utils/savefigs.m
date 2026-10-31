function savefigs(outDir)
% SAVEFIGS  Export every open figure to a vector PDF named after its title.
%
%   savefigs()        saves to results/figures/SiC-GaN/
%   savefigs(outDir)  saves to outDir (created if missing)
%
%   File name = axes title with spaces replaced by '_' and characters
%   that are illegal in file names removed. Figures without a title are
%   saved as Figure_<n>.pdf. Existing files are overwritten.

    if nargin < 1 || isempty(outDir)
        repo_root = fileparts(fileparts(mfilename('fullpath')));
        outDir = fullfile(repo_root, 'results', 'figures', 'SiC-GaN');
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    figHandles = findall(groot, 'Type', 'figure');

    for i = 1:numel(figHandles)
        fig = figHandles(i);

        % Uncomment to export at full-screen aspect ratio:
        %set(fig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
        %drawnow;

        ax = fig.CurrentAxes;
        if isempty(ax) || isempty(ax.Title.String)
            baseName = sprintf('Figure_%d', fig.Number);
        else
            % Multi-line titles arrive as cell arrays
            rawTitle = ax.Title.String;
            if iscell(rawTitle), rawTitle = strjoin(rawTitle, '_'); end

            % Remove characters not allowed in file names: \ / : * ? " < > |
            baseName = regexprep(rawTitle, '[\\/:\*\?"<>|]', '');
            baseName = strrep(baseName, ' ', '_');
        end

        fileName = fullfile(outDir, [baseName, '.pdf']);

        % Vector content, transparent background
        exportgraphics(fig, fileName, 'ContentType', 'vector', 'BackgroundColor', 'none');
    end
end
