%% PLOT_COMPARISON  Compare two sweep results (SiC-Si vs SiC-GaN) on shared axes.
%
% Workspace inputs (loaded from results/data/ if not already defined):
%   results1 : SiC-Si sweep    (results/data/SiC-Si_sweep_40-150kHz.mat)
%   results2 : SiC-GaN sweep   (results/data/SiC-GaN_sweep_40-250kHz.mat)
% Each is a `results` struct saved by main/run_frequency_sweep.m.
%
% Produces 5 figures: efficiency (Fig. 2 of the TENCON paper), total loss
% (Fig. 3), combined loss breakdown (not in the paper; Fig. 4 comes from
% plot_sweep_results.m), magnetic volume (Fig. 5), and volume-efficiency
% scatter (Fig. 6). Save them with savefigs.
%
% Note: the set(groot, ...) calls change plot defaults for the whole
% MATLAB session.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
repo_root = setup_paths();
if ~exist('results1', 'var')
    tmp = load(fullfile(repo_root, 'results', 'data', 'SiC-Si_sweep_40-150kHz.mat'), 'results');
    results1 = tmp.results;
end
if ~exist('results2', 'var')
    tmp = load(fullfile(repo_root, 'results', 'data', 'SiC-GaN_sweep_40-250kHz.mat'), 'results');
    results2 = tmp.results;
end
clear tmp

% Global Line Properties
set(groot, 'defaultLineLineWidth', 1.5);

% Global Axes Properties (Fonts and text)
set(groot, 'defaultAxesFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 10);

% Global Figure Properties (Background color)
set(groot, 'defaultFigureColor', 'w');

% Optional: Default export properties (requires R2020a+)
set(groot, 'defaultFigurePaperPositionMode', 'auto');

%% Convert frequencies to kHz for readability
freq1_kHz = results1.freq / 1e3; 
freq2_kHz = results2.freq / 1e3; 

%% Plot 1: Efficiency vs Frequency
figure('Name', 'Efficiency vs Frequency', 'Color', 'w');
hold on;
plot(freq1_kHz, results1.eff_analytical, '-o', 'LineWidth', 2, 'DisplayName', 'SiC-Si');
plot(freq2_kHz, results2.eff_analytical, '--s', 'LineWidth', 2, 'DisplayName', 'SiC-GaN');
xlabel('Frequency (kHz)'); xlim tight;
ylabel('Efficiency (%)');
title('Efficiency vs Frequency');
legend('Location', 'best');
grid on;
hold off;

%% Plot 2: Total Loss vs Frequency
figure('Name', 'Total Loss vs Frequency', 'Color', 'w');
hold on;
plot(freq1_kHz, results1.loss_total, '-o', 'LineWidth', 2, 'DisplayName', 'SiC-Si Total Loss');
plot(freq2_kHz, results2.loss_total, '--s', 'LineWidth', 2, 'DisplayName', 'SiC-GaN Total Loss');
xlabel('Frequency (kHz)'); xlim tight;
ylabel('Total Loss (W)');
title('Total System Loss vs Frequency');
legend('Location', 'best');
grid on;
hold off;

%% Plot 3: Individual Losses vs Frequency
figure('Name', 'Loss Breakdown vs Frequency', 'Color', 'w');
hold on;
% Same color per loss component; line style separates the device pairs.
% Breakdown rows: 1 conduction, 2 cable, 3 gate drive, 4 switching,
%                 5 body diode, 6 transformer, 7 inductor DC
c = lines(7); 

% SiC-Si (Solid lines, 'x' marker)
plot(freq1_kHz, results1.breakdown(1, :), '-x', 'Color', c(1,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-Si: Conduction');
plot(freq1_kHz, results1.breakdown(2, :), '-x', 'Color', c(2,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-Si: Cable');
plot(freq1_kHz, results1.breakdown(3, :), '-x', 'Color', c(3,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-Si: Gate Drive');
plot(freq1_kHz, results1.breakdown(4, :), '-x', 'Color', c(4,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-Si: Switching');
plot(freq1_kHz, results1.breakdown(5, :), '-x', 'Color', c(5,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-Si: Body Diode');
plot(freq1_kHz, results1.breakdown(7, :), '-x', 'Color', c(6,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-Si: Inductor DC');
plot(freq1_kHz, results1.breakdown(6, :), '-x', 'Color', c(7,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-Si: Transformer');

% SiC-GaN (Dashed lines, square marker)
plot(freq2_kHz, results2.breakdown(1, :), '--s', 'Color', c(1,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-GaN: Conduction');
plot(freq2_kHz, results2.breakdown(2, :), '--s', 'Color', c(2,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-GaN: Cable');
plot(freq2_kHz, results2.breakdown(3, :), '--s', 'Color', c(3,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-GaN: Gate Drive');
plot(freq2_kHz, results2.breakdown(4, :), '--s', 'Color', c(4,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-GaN: Switching');
plot(freq2_kHz, results2.breakdown(5, :), '--s', 'Color', c(5,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-GaN: Body Diode');
plot(freq2_kHz, results2.breakdown(7, :), '--s', 'Color', c(6,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-GaN: Inductor DC');
plot(freq2_kHz, results2.breakdown(6, :), '--s', 'Color', c(7,:), 'LineWidth', 1.5, 'DisplayName', 'SiC-GaN: Transformer');

xlabel('Frequency (kHz)'); xlim tight;
ylabel('Loss (W)');
title('Individual Loss Components vs Frequency');
legend('Location', 'eastoutside'); 
grid on;
hold off;

%% Plot 4: Magnetic volume vs frequency
figure('Name', 'Volume vs Frequency', 'Color', 'w');
hold on;
% SiC-Si
plot(freq1_kHz, results1.Volume_L, '-o', 'Color', '#0072BD', 'LineWidth', 1.5, 'DisplayName', 'SiC-Si: Inductor Vol');
plot(freq1_kHz, results1.Volume_T, '-s', 'Color', '#D95319', 'LineWidth', 1.5, 'DisplayName', 'SiC-Si: Transformer Vol');
plot(freq1_kHz, results1.Volume_Total, '-k^', 'LineWidth', 2, 'DisplayName', 'SiC-Si: Total Volume');
% SiC-GaN
plot(freq2_kHz, results2.Volume_L, '--o', 'Color', '#0072BD', 'LineWidth', 1.5, 'DisplayName', 'SiC-GaN: Inductor Vol');
plot(freq2_kHz, results2.Volume_T, '--s', 'Color', '#D95319', 'LineWidth', 1.5, 'DisplayName', 'SiC-GaN: Transformer Vol');
plot(freq2_kHz, results2.Volume_Total, '--k^', 'LineWidth', 2, 'DisplayName', 'SiC-GaN: Total Volume');

xlabel('Frequency (kHz)'); xlim tight;
ylabel('Volume'); % m^3
title('Magnetic Component Volume vs Frequency');
legend('Location', 'best');
grid on;
hold off;

%% Plot 5: Volume vs efficiency, colored by frequency
figure('Name', 'Pareto Front', 'Color', 'w');
hold on;

% Process SiC-Si
valid_idx1 = results1.Volume_Total > 0;
vol_data1 = results1.Volume_Total(valid_idx1);
eff_data1 = results1.eff_analytical(valid_idx1);
freq_data1 = freq1_kHz(valid_idx1);

if ~isempty(vol_data1)
    scatter(vol_data1, eff_data1, 70, freq_data1, 'filled', 'o', 'MarkerEdgeColor', 'k', 'DisplayName', 'SiC-Si');
end

% Process SiC-GaN
valid_idx2 = results2.Volume_Total > 0;
vol_data2 = results2.Volume_Total(valid_idx2);
eff_data2 = results2.eff_analytical(valid_idx2);
freq_data2 = freq2_kHz(valid_idx2);

if ~isempty(vol_data2)
    scatter(vol_data2, eff_data2, 70, freq_data2, 'filled', 's', 'MarkerEdgeColor', 'k', 'DisplayName', 'SiC-GaN');
end

% Formatting for Pareto Front
if ~isempty(vol_data1) || ~isempty(vol_data2)
    cb = colorbar;
    cb.Label.String = 'Switching Frequency (kHz)';
    colormap(jet); 
    
    xlabel('Total Magnetic Volume');
    ylabel('Efficiency (%)');
    title('Pareto Front: Magnetic Sizing vs Efficiency');
    legend('Location', 'best');
    grid on;
else
    fprintf('Skipping Pareto plot: Both volume arrays are empty or zero.\n');
end
hold off;