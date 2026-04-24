% --- CONSOLIDATED PARETO FRONT: SCATTER WITH FRONTIER LINES ---
figure('Name', 'Consolidated Pareto Front', 'Color', 'w');
hold on;

% ==========================================
% 1. Process SiC-GaN Data
% ==========================================
valid_idx_GaN = results_GaN.Volume_Total > 0;
vol_GaN = results_GaN.Volume_Total(valid_idx_GaN).*1e6;
eff_GaN = results_GaN.eff_analytical(valid_idx_GaN);
freq_GaN = results_GaN.freq(valid_idx_GaN)./1e3;

% Identify Pareto points for SiC-GaN (Minimize Vol, Maximize Eff)
is_par_GaN = true(size(vol_GaN));
for i = 1:length(vol_GaN)
    for j = 1:length(vol_GaN)
        if i ~= j && (vol_GaN(j) <= vol_GaN(i)) && (eff_GaN(j) >= eff_GaN(i)) && ...
           ((vol_GaN(j) < vol_GaN(i)) || (eff_GaN(j) > eff_GaN(i)))
            is_par_GaN(i) = false;
            break;
        end
    end
end

% Sort points to draw a clean line
[vol_par_GaN, sort_idx_GaN] = sort(vol_GaN(is_par_GaN));
eff_par_GaN_temp = eff_GaN(is_par_GaN);
eff_par_GaN = eff_par_GaN_temp(sort_idx_GaN);

% ==========================================
% 2. Process SiC-Si Data
% ==========================================
valid_idx_Si = results_Si.Volume_Total > 0;
vol_Si = results_Si.Volume_Total(valid_idx_Si).*1e6;
eff_Si = results_Si.eff_analytical(valid_idx_Si);
freq_Si = results_Si.freq(valid_idx_Si)./1e3;

% Identify Pareto points for SiC-Si
is_par_Si = true(size(vol_Si));
for i = 1:length(vol_Si)
    for j = 1:length(vol_Si)
        if i ~= j && (vol_Si(j) <= vol_Si(i)) && (eff_Si(j) >= eff_Si(i)) && ...
           ((vol_Si(j) < vol_Si(i)) || (eff_Si(j) > eff_Si(i)))
            is_par_Si(i) = false;
            break;
        end
    end
end

% Sort points to draw a clean line
[vol_par_Si, sort_idx_Si] = sort(vol_Si(is_par_Si));
eff_par_Si_temp = eff_Si(is_par_Si);
eff_par_Si = eff_par_Si_temp(sort_idx_Si);

% ==========================================
% 3. Plotting
% ==========================================
% Scatter all points (Hollow for GaN, Filled for Si)
scatter(vol_GaN, eff_GaN, 90, freq_GaN, 'o', 'LineWidth', 1.5); 
scatter(vol_Si, eff_Si, 50, freq_Si, 's', 'filled', 'MarkerEdgeColor', 'k');

% Draw Frontier Lines (Black so they stand out over the colormap)
plot(vol_par_GaN, eff_par_GaN, 'k-', 'LineWidth', 2);  % Solid line for GaN
plot(vol_par_Si, eff_par_Si, 'k--', 'LineWidth', 2);   % Dashed line for Si

% ==========================================
% 4. Global Formatting & Shared Colormap
% ==========================================
cb = colorbar;
cb.Label.String = 'Switching Frequency (kHz)';
colormap(jet); 

xlabel('Total Magnetic Volume (cm^3)'); % Added units for completeness
ylabel('Efficiency (%)');
grid on;

% Custom Legend (Includes the line style and marker style)
h_leg_GaN = plot(nan, nan, 'ko-', 'MarkerSize', 8, 'LineWidth', 1.5);
h_leg_Si = plot(nan, nan, 'ks--', 'MarkerFaceColor', [0.5 0.5 0.5], 'MarkerSize', 8, 'LineWidth', 1.5);
legend([h_leg_GaN, h_leg_Si], {'SiC-GaN Frontier', 'SiC-Si Frontier'}, 'Location', 'southwest');

hold off;