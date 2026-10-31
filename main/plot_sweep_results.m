%% PLOT_SWEEP_RESULTS  Plots for one device pair: efficiency, total loss,
% loss breakdown, magnetic volume, and volume-efficiency scatter.
%
% Called at the end of main/run_frequency_sweep.m. To plot saved data:
%   load results/data/SiC-Si_sweep_40-150kHz.mat      % defines `results`
%   run main/plot_sweep_results.m
%
% Workspace input:
%   results : struct from main/run_frequency_sweep.m
%
% Fig. 4(a)/(b) of the TENCON paper is the loss-breakdown figure from
% this script, for SiC-GaN and SiC-Si.

if ~exist('results', 'var')
    error('plot_sweep_results: load a `results` struct first (see header).');
end

freq_kHz = results.freq / 1e3;

% Plot 1: Efficiency vs frequency
figure('Name', 'Efficiency vs Frequency', 'Color', 'w');
plot(freq_kHz, results.eff_analytical, '-o', 'LineWidth', 2);
xlabel('Frequency (kHz)'); xlim tight;
ylabel('Efficiency (%)');
title('Efficiency vs Frequency');
grid on;

%% Plot 2: Total loss vs frequency
figure('Name', 'Total Loss vs Frequency', 'Color', 'w');
plot(freq_kHz, results.loss_total, '-o', 'LineWidth', 2, 'Color', '#D95319', 'DisplayName', "SiC-GaN");
xlabel('Frequency (kHz)'); xlim tight;
ylabel('Total Loss (W)');
title('Total System Loss vs Frequency');
grid on;
hold on;

%% Plot 3: Loss components vs frequency
figure('Name', 'Loss Breakdown vs Frequency', 'Color', 'w');
hold on;
plot(freq_kHz, results.breakdown(1, :), '-x', 'LineWidth', 1.5, 'DisplayName', 'Conduction Loss');
plot(freq_kHz, results.breakdown(2, :), '-x', 'LineWidth', 1.5, 'DisplayName', 'Cable Loss');
plot(freq_kHz, results.breakdown(3, :), '-x', 'LineWidth', 1.5, 'DisplayName', 'Gate Drive Loss');
plot(freq_kHz, results.breakdown(4, :), '-x', 'LineWidth', 1.5, 'DisplayName', 'Switching Loss');
plot(freq_kHz, results.breakdown(5, :), '-x', 'LineWidth', 1.5, 'DisplayName', 'Body Diode Loss');
plot(freq_kHz, results.breakdown(7, :), '-x', 'LineWidth', 1.5, 'DisplayName', 'Inductor DC Loss');
plot(freq_kHz, results.breakdown(6, :), '-x', 'LineWidth', 1.5, 'DisplayName', 'Transformer Loss');
hold off;

xlabel('Frequency (kHz)'); xlim tight;
ylabel('Loss (W)');
title('Individual Loss Components vs Frequency');
legend('Location', 'best');
grid on;

%% Plot 4: Magnetic volume vs frequency
figure('Name', 'Volume vs Frequency', 'Color', 'w');
hold on;
plot(freq_kHz, results.Volume_L, '-o', 'LineWidth', 1.5, 'DisplayName', 'Inductor Volume');
plot(freq_kHz, results.Volume_T, '-s', 'LineWidth', 1.5, 'DisplayName', 'Transformer Volume');
plot(freq_kHz, results.Volume_Total, '-k^', 'LineWidth', 2, 'DisplayName', 'Total Volume');
hold off;

xlabel('Frequency (kHz)'); xlim tight;
ylabel('Volume'); % m^3
title('Magnetic Component Volume vs Frequency');
legend('Location', 'best');
grid on;

%% Plot 5: Magnetic volume vs efficiency, colored by frequency
% (main/plot_pareto_front.m draws the Pareto front lines)
valid_idx = results.Volume_Total > 0;      % skip failed points
vol_data = results.Volume_Total(valid_idx);
eff_data = results.eff_analytical(valid_idx);
freq_data = freq_kHz(valid_idx);

if ~isempty(vol_data)
    figure('Name', 'Pareto Front', 'Color', 'w');
    hold on;

    % All points, colored by frequency
    scatter(vol_data, eff_data, 70, freq_data, 'filled', 'MarkerEdgeColor', 'k');

    cb = colorbar;
    cb.Label.String = 'Switching Frequency (kHz)';
    colormap(jet);

    xlabel('Total Magnetic Volume');
    ylabel('Efficiency (%)');
    title('Pareto Front: Magnetic Sizing vs Efficiency');
    grid on;
    hold off;
else
    fprintf('Skipping Pareto plot: results.Volume_Total array is empty or zero.\n');
end
