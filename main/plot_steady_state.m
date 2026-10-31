%% PLOT_STEADY_STATE  Steady-state waveforms (SiC-GaN, 140 kHz) in a 3x2 grid.
%
% Workspace inputs (loaded from
% results/data/SiC-GaN_140kHz_steady_state.mat if not already defined):
%   t_80                 time [s]
%   v_in_80,  i_in_80    input voltage [V] / current [A]
%   v_l_80,   i_l_80     inductor voltage [V] / current [A]
%   v_out_80, i_out_80   output voltage [V] / current [A]
% The "_80" suffix marks the steady-state window (after 80 % of the run).
%
% Output: results/figures/paper/fig7_steady_state_SiC-GaN_140kHz.pdf
% (Fig. 7 of the TENCON paper).
%
% Note: the set(groot, ...) calls change plot defaults for the whole
% MATLAB session.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
repo_root = setup_paths();
if ~exist('t_80', 'var')
    load(fullfile(repo_root, 'results', 'data', 'SiC-GaN_140kHz_steady_state.mat'));
end

% Global Line Properties
set(groot, 'defaultLineLineWidth', 1.2); % Slightly thinner lines for smaller plots

% Global Axes Properties (Fonts and text scaled for single column)
set(groot, 'defaultAxesFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 8); % 8pt minimum for legibility in 3.5in width

% Global Figure Properties (Background color)
set(groot, 'defaultFigureColor', 'w');

% Figure size: uncomment the Units/Position arguments for a fixed
% 7.16 x 4.5 in (IEEE double-column) figure.
figure('Name', 'Steady-State Waveforms')%, 'Units', 'inches', 'Position', [1, 1, 7.16, 4.5]);

% Use tiledlayout for maximum space efficiency (requires R2019b+)
t = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Row 1: Input Stage ---
ax1 = nexttile;
plot(t_80, v_in_80, 'Color', '#0072BD');
%title('Input Voltage (V_{in})', 'FontSize', 9);
ylabel('V_{in} (V)'); ylim([600 900]);
grid on;

ax2 = nexttile;
plot(t_80, i_in_80, 'Color', '#D95319');
%title('Input Current (I_{in})', 'FontSize', 9);
ylabel('I_{in} (A)'); ylim([0 40]);
grid on;

% --- Row 2: Inductor Stage ---
ax3 = nexttile;
plot(t_80, v_l_80, 'Color', '#0072BD');
%title('Inductor Voltage (V_L)', 'FontSize', 9);
ylabel('V_L (V)');
grid on;

ax4 = nexttile;
plot(t_80, i_l_80, 'Color', '#D95319');
%title('Inductor Current (I_L)', 'FontSize', 9);
ylabel('I_L (A)'); 
grid on;

% --- Row 3: Output Stage ---
ax5 = nexttile;
plot(t_80, v_out_80, 'Color', '#0072BD');
%title('Output Voltage (V_{out})', 'FontSize', 9);
xlabel('Time'); ylabel('V_{out} (V)'); ylim([10 55]);
grid on;

ax6 = nexttile;
plot(t_80, i_out_80, 'Color', '#D95319');
%title('Output Current (I_{out})', 'FontSize', 9);
xlabel('Time'); ylabel('I_{out} (A)'); ylim([400 600]);
grid on;

xticklabels(ax1, {});
xticklabels(ax2, {});
xticklabels(ax3, {});
xticklabels(ax4, {});
xticklabels(ax5, {});
xticklabels(ax6, {});

% Link all x-axes so zooming is synchronized
linkaxes([ax1, ax2, ax3, ax4, ax5, ax6], 'x');

% Overall Title (Optional: You may want to remove this and use the LaTeX caption instead to save space)
title(t, 'SiC-GaN Waveforms (140 kHz)', 'FontName', 'Times New Roman', 'FontWeight', 'bold', 'FontSize', 10);
% Export as a vector PDF
exportgraphics(gcf, fullfile(repo_root, 'results', 'figures', 'paper', 'fig7_steady_state_SiC-GaN_140kHz.pdf'), 'ContentType', 'vector');