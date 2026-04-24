% Get all open figure handles
figHandles = findall(groot, 'Type', 'figure');

for i = 1:numel(figHandles)
    fig = figHandles(i);
    
    % Force figure to fullscreen to capture intended aspect ratio
    %set(fig, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
    %drawnow; % Force update to ensure geometry is applied
    
    % Retrieve title from the current axes
    ax = fig.CurrentAxes;
    if isempty(ax) || isempty(ax.Title.String)
        baseName = sprintf('Figure_%d', fig.Number);
    else
        % Handle cell arrays (multi-line titles) and sanitize
        rawTitle = ax.Title.String;
        if iscell(rawTitle), rawTitle = strjoin(rawTitle, '_'); end
        
        % Remove characters prohibited by filesystems (e.g., \, /, :, *, ?, ", <, >, |)
        baseName = regexprep(rawTitle, '[\\/:\*\?"<>|]', '');
        baseName = strrep(baseName, ' ', '_'); % Replace spaces for CLI compatibility
    end
    
    % Define full filename
    fileName = ['Results/SiC-GaN/', baseName, '.pdf'];
    
    % Export with vector content and minimum margins
    exportgraphics(fig, fileName, 'ContentType', 'vector', 'BackgroundColor', 'none');
end