%% DAB_FREQ_SWEEP  Switching-frequency sweep of the 800 V / 48 V DAB converter
%
% Runs the Simulink model at each switching frequency, extracts
% steady-state currents, and computes the analytical loss breakdown,
% efficiency, and magnetic volume. Ends with summary plots.
%
% Per frequency point:
%   1. Size the series (leakage) inductance Lk for the peak power.
%   2. Simulate the converter (closed-loop phase-shift control in Simulink).
%   3. Take the last 20 % of each logged current as steady state.
%   4. Compute losses: conduction, cable, gate drive, inductor DC,
%      switching (with ZVS check), body diode, transformer.
%   5. Estimate magnetic volume (inductor + transformer).
%
% Requires:  MATLAB + Simulink, models/DAB_freq_sweep_sim.slx
% Outputs (workspace):
%   results          struct of per-frequency arrays (see "Initialize Data Arrays")
%   data_loss_body*  body-diode loss per frequency [W]
% Outputs (files):
%   results/current_plots.pdf  output current vs time for every frequency.
%                              Pages are appended, so delete the file
%                              before a new run.
%
% To compare device pairs, change the get_semiconductor_params call,
% run the sweep, and save `results` to results/data/.

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
repo_root = setup_paths();

%% --- 1. CONFIGURATION ---
model_name = 'DAB_freq_sweep_sim';
power.target = 25000;              % W, nominal output power (25 kW)
headroom_factor = 1.3;             % Lk is sized for 1.3 x nominal = 32.5 kW
freq_steps = (160:10:280) * 1e3;   % Hz, sweep points (160-280 kHz in 10 kHz steps)
num_sweep = length(freq_steps);
sim_time = 0.3;                    % s, Simulink stop time per point
max_power = headroom_factor*power.target;

%% --- 2. PARAMETERS ---

% A. Semiconductor profiles (HV bridge, LV bridge).
%    Options: 'SiC_1200V' | 'Si_60V' | 'GaN'  (see get_semiconductor_params).
%    Dead time is set inside get_semiconductor_params.
[semi.hv, semi.lv] = get_semiconductor_params('SiC_1200V', 'GaN');

% B. Passives
passives.Rs = 1e6;                 % ohm, snubber resistance
passives.hv.R_cab = 5e-3;   passives.hv.L_cab = 2e-6;   passives.hv.C_bulk = 470e-6;   % HV cable R [ohm], L [H], DC-link C [F]
passives.lv.R_cab = 0.1e-3; passives.lv.L_cab = 100e-9; passives.lv.C_bulk = 4e-3;     % LV cable R [ohm], L [H], DC-link C [F]

% C. Transformer
trans.V1 = 16; trans.V2 = 1; trans.n = trans.V2/trans.V1;   % turns ratio 16:1 (V1 also used as primary turns)
trans.power = max_power;

% D. Source / load
source.Vin = 800; source.Vout = 48;     % V

% Magnetizing branch of the Simulink transformer block.
% Lm and Rm are set very high, so the magnetizing branch is effectively
% open. Rm is constant (not updated during the sweep).
trans.Lm = 1e6;                    % H
trans.Rm = 1e6;                    % ohm

% DC winding resistances for the Simulink transformer block, scaled from
% the AC resistances below (Krismer DAB model).
trans.R1 = 0.075;                  % ohm, primary
trans.R2 = 6e-6;                   % ohm, secondary

% Core geometry for the transformer loss model: E 140/68/40 core
trans.coreVolume = 5.00045e-3;     % m^3
trans.coreArea = 1.585e-3;         % m^2

% Steinmetz parameters for SIFERRIT N97, fitted from the datasheet loss curves
trans.Ks    = 1.96e4;              % core-loss density at 25 kHz, 100 mT
trans.alpha = 1.15;                % frequency exponent
trans.beta  = 2.32;                % flux-density exponent
trans.C_wave = 1.25;               % square-wave correction factor

% Winding AC resistances (Krismer, p. 311)
trans.Rac1 =  149e-3;              % ohm, primary
trans.Rac2 = 1e-5;                 % ohm, secondary

% --- Initialize Data Arrays ---
results.freq = zeros(1, num_sweep);            % Hz
results.eff_analytical = zeros(1, num_sweep);  % %
results.eff_worst_case = zeros(1, num_sweep);  % unused (worst-case model disabled)
results.loss_total = zeros(1, num_sweep);      % W
results.breakdown = zeros(7, num_sweep);       % W, rows: see results.breakdown assignment below

results.coreLoss   = zeros(1, num_sweep);      % W
results.copperLoss  = zeros(1, num_sweep);     % W
results.totalTransformerLoss = zeros(1, num_sweep);  % W
results.Lk = zeros(1, num_sweep);              % H

% Current metrics
results.I_rms_h = zeros(1, num_sweep);         % A, HV bridge RMS
results.I_rms_l = zeros(1, num_sweep);         % A, LV bridge RMS
results.I_sw_ss_h = zeros(1, num_sweep);       % A, HV peak (used as switching-instant current)
results.I_sw_ss_l = zeros(1, num_sweep);       % A, LV peak

results.t_req_h = zeros(1, num_sweep);         % s, ZVS transition time needed, HV
results.t_req_l = zeros(1, num_sweep);         % s, ZVS transition time needed, LV

% Magnetic sizing [m^3]
results.Volume_L = zeros(1, num_sweep);        % inductor
results.Volume_Trans = zeros(1, num_sweep);    % unused; the loop fills results.Volume_T
results.Volume_Total = zeros(1, num_sweep);    % inductor + transformer

% Body-diode losses [W]
data_loss_body = zeros(1, num_sweep);
data_loss_body_h = zeros(1, num_sweep);
data_loss_body_l = zeros(1, num_sweep);

% --- Push parameters to the base workspace for the Simulink model ---
assignin('base', 'R_on_h', semi.hv.Ron);  assignin('base', 'R_on_l', semi.lv.Ron);
assignin('base', 'R_d_h',  semi.hv.Rd);   assignin('base', 'R_d_l',  semi.lv.Rd);
assignin('base', 'V_f_h',  semi.hv.Vf);   assignin('base', 'V_f_l',  semi.lv.Vf);
assignin('base', 'Q_g_h',  semi.hv.Qg);   assignin('base', 'Q_g_l',  semi.lv.Qg);
assignin('base', 'V_gs_h', semi.hv.V_dr_on); assignin('base', 'V_gs_l', semi.lv.V_dr_on);
assignin('base', 'R_cab_h', passives.hv.R_cab); assignin('base', 'L_cab_h', passives.hv.L_cab);
assignin('base', 'C_bulk_h',passives.hv.C_bulk);
assignin('base', 'R_cab_l', passives.lv.R_cab); assignin('base', 'L_cab_l', passives.lv.L_cab);
assignin('base', 'C_bulk_l',passives.lv.C_bulk);
assignin('base', 'R_s',     passives.Rs);

fprintf('Starting Sweep (Target: %.1f kW)...\n', power.target/1e3);

%% --- 3. MAIN SWEEP LOOP ---
for i = 1:num_sweep
    f_sw_curr = freq_steps(i);     % read by the Simulink model
    T = 1 / f_sw_curr;

    %% A. Series inductance Lk and its DC resistance
    inductor = get_inductor_params(source, trans, f_sw_curr, max_power);

    %% B. Phase-shift control
    % Not computed here: the Simulink model runs closed-loop control.

    %% C. Run simulation
    try
        simOut = sim(model_name,'StopTime',num2str(sim_time));
    catch ME
        fprintf('\n[SIMULATION CRASH at %.1f kHz]\n', f_sw_curr/1e3);
        disp(ME.message);
        continue;
    end

    %% D. Extract logged currents ("To Workspace" blocks)
    try
        I_raw_h = simOut.I_raw_h.Data; I_raw_l = simOut.I_raw_l.Data;
        I_raw_in = simOut.I_raw_in.Data; I_raw_out = simOut.I_raw_out.Data;
    catch
        error('Variable Name Mismatch: Check "To Workspace" block names!');
    end

    % Steady state: keep samples after 80 % of the run (last 20 %)
    idx = floor(length(I_raw_h) * 0.8);
    I_ss_h = I_raw_h(idx:end); I_ss_l = I_raw_l(idx:end);
    I_ss_in = I_raw_in(idx:end); I_ss_out = I_raw_out(idx:end);

    % RMS currents
    I_rms_h = rms(I_ss_h); I_rms_l = rms(I_ss_l);
    I_rms_in = rms(I_ss_in); I_rms_out = rms(I_ss_out);

    % Peak bridge currents, used as the switching-instant current.
    % This overestimates the commutation current; the exact value is the
    % instantaneous bridge current at the commutation moment.
    I_sw_ss_h = max(abs(I_ss_h));
    I_sw_ss_l = max(abs(I_ss_l));

    % --- 1. Conduction and passive losses ---
    % 4 switches per bridge
    power.loss.conduction = 4*(I_rms_h^2 * semi.hv.Ron) + 4*(I_rms_l^2 * semi.lv.Ron);
    power.loss.cable  = 2*(I_rms_in^2 * passives.hv.R_cab) + 2*(I_rms_out^2 * passives.lv.R_cab);
    power.loss.gateDrive = (4 * semi.hv.Qg * semi.hv.V_dr_on * f_sw_curr) + ...
             (4 * semi.lv.Qg * semi.lv.V_dr_on * f_sw_curr);
    power.loss.inductorDC = I_rms_in^2 * inductor.Rdc;

    % --- 2. Switching losses (analytical, with ZVS energy + timing check) ---
    % HV side
    [P_sw_h_unit, zvs_h, t_req_h, E_rat_h] = calculate_switching_zvs(source.Vin, I_sw_ss_h, f_sw_curr, inductor.Lk, semi.hv, semi.hv.timing.t_dead);
    % LV side: Lk referred to the secondary (multiply by n^2)
    [P_sw_l_unit, zvs_l, t_req_l, ~] = calculate_switching_zvs(source.Vout, I_sw_ss_l, f_sw_curr, inductor.Lk * (trans.n^2), semi.lv, semi.lv.timing.t_dead);

    P_sw_total = 4 * P_sw_h_unit + 4 * P_sw_l_unit;   % per-switch loss x 4 switches per bridge

    % --- 3. Body-diode / reverse-conduction loss during dead time ---
    % t_req_* is the time the switch node needs to slew between rails;
    % only the rest of the dead time counts as diode conduction.
    [P_body, P_body_h, P_body_l, info] = calculate_body_diode_losses( ...
        I_sw_ss_h, I_sw_ss_l, semi.hv.Vf, semi.lv.Vf, f_sw_curr, ...
        semi.hv.timing.t_dead, semi.lv.timing.t_dead, ...
        zvs_h, zvs_l, ...
        t_req_h, t_req_l);
    data_loss_body(i)   = P_body;
    data_loss_body_h(i) = P_body_h;
    data_loss_body_l(i) = P_body_l;

    % --- 4. Transformer losses (core + copper) ---
    [P_core, P_cu, P_trans, B_pk, k_fe] = calculate_transformer_losses( ...
        f_sw_curr, source.Vin, I_rms_in, I_rms_out, ...
        trans.coreVolume, trans.coreArea, trans.V1, ...
        trans.Ks, trans.alpha, trans.beta, ...
        trans.Rac1, trans.Rac2, trans.C_wave);

    results.coreLoss(i) = P_core;
    results.copperLoss(i) = P_cu;
    results.totalTransformerLoss(i) = P_trans;
    results.Lk(i) = inductor.Lk;

    % --- Store results ---
    power.delivered = source.Vout*I_rms_out;
    power.supplied = source.Vin*I_rms_in;
    results.freq(i) = f_sw_curr;
    results.loss_total(i) = power.loss.conduction + power.loss.cable + power.loss.gateDrive + P_sw_total + P_body + P_trans +power.loss.inductorDC;
    results.eff_analytical(i) = 100 * power.delivered / (power.delivered+results.loss_total(i));

    % Breakdown rows: 1 conduction, 2 cable, 3 gate drive, 4 switching,
    %                 5 body diode, 6 transformer, 7 inductor DC
    results.breakdown(:, i) = [power.loss.conduction; power.loss.cable; power.loss.gateDrive; P_sw_total; P_body; P_trans; power.loss.inductorDC];

    results.I_rms_h(i) = I_rms_h;
    results.I_rms_l(i) = I_rms_l;
    results.I_sw_ss_h(i) = I_sw_ss_h;
    results.I_sw_ss_l(i) = I_sw_ss_l;

    results.t_req_h(i) = t_req_h;
    results.t_req_l(i) = t_req_l;

    % Magnetic volume [m^3]
    [results.Volume_L(i), results.Volume_T(i), results.Volume_Total(i),~] = dab_size_calc(f_sw_curr, source.Vin, inductor.Lk, max(I_ss_h));
    fprintf('%.1f kHz | Lk:%.1fuH | I_sw: %.1fA | Eff: %.2f%% | ZVS: H:%d L:%d\n', ...
       f_sw_curr/1e3, inductor.Lk/1e-6, I_sw_ss_l, results.eff_analytical(i), zvs_h, zvs_l);

    % Output current vs time, one page per frequency.
    % Dashed lines: target current, start of the steady-state window.
    plot(simOut.tout,I_raw_out); hold on;
    yline(power.target/source.Vout,'--');
    xline(simOut.tout(idx), '--');
    hold off;
    title(sprintf("%.2f kHz", f_sw_curr*1e-3));

    exportgraphics(gcf, fullfile(repo_root, "results", "current_plots.pdf"), ...
        'Append', true, ...
        'ContentType','image');
    close
end


%% --- 4. PLOTTING RESULTS ---
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

%% Plot 5: Pareto front, magnetic volume vs efficiency
valid_idx = results.Volume_Total > 0;      % skip failed points
vol_data = results.Volume_Total(valid_idx);
eff_data = results.eff_analytical(valid_idx);
freq_data = freq_kHz(valid_idx);

if ~isempty(vol_data)
    % A point is Pareto-optimal if no other point has both lower (or equal)
    % volume and higher (or equal) efficiency, with at least one strict.
    is_pareto = true(size(vol_data));
    for i = 1:length(vol_data)
        for j = 1:length(vol_data)
            if i ~= j
                if (vol_data(j) <= vol_data(i)) && (eff_data(j) >= eff_data(i)) && ...
                   ((vol_data(j) < vol_data(i)) || (eff_data(j) > eff_data(i)))
                    is_pareto(i) = false;
                    break;
                end
            end
        end
    end

    % Pareto points sorted by volume (for drawing the front)
    pareto_indices = find(is_pareto);
    [vol_pareto, sort_idx] = sort(vol_data(pareto_indices));
    eff_pareto = eff_data(pareto_indices(sort_idx));

    figure('Name', 'Pareto Front', 'Color', 'w');
    hold on;

    % All points, colored by frequency
    scatter(vol_data, eff_data, 70, freq_data, 'filled', 'MarkerEdgeColor', 'k');
    % Uncomment to draw the Pareto front:
    %plot(vol_pareto, eff_pareto, 'k--', 'LineWidth', 1.5);

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
