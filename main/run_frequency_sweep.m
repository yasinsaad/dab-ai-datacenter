%% RUN_FREQUENCY_SWEEP  Switching-frequency sweep of the 800 V / 48 V DAB converter
%
% Runs the Simulink model at each switching frequency, extracts
% steady-state currents, and computes the analytical loss breakdown,
% efficiency, and magnetic volume. Ends with summary plots
% (main/plot_sweep_results.m).
%
% Per frequency point:
%   1. Size the series (leakage) inductance Lk for the peak power.
%   2. Simulate the converter (closed-loop phase-shift control in Simulink).
%   3. Take the last 20 % of each logged current as steady state.
%   4. Compute losses: conduction, cable, gate drive, inductor DC,
%      switching (with ZVS check), body diode, transformer.
%   5. Estimate magnetic volume (inductor + transformer).
%
% Requires:  MATLAB + Simulink, models/DAB_sweep_model.slx
% Outputs (workspace):
%   results          struct of per-frequency arrays (see "Initialize Data Arrays")
%   data_loss_body*  body-diode loss per frequency [W]
% Outputs (files):
%   results/current_plots_<HV>-<LV>.pdf
%       Output current vs time, one page per frequency, to check that each
%       run reached steady state. One file per device pair; rerunning a
%       pair replaces only that pair's file.
%
% To compare device pairs, change device_hv / device_lv below, run the
% sweep, and save `results` to results/data/.
% Frequencies where the simulation crashes are reported and removed from
% `results` before plotting.

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
repo_root = setup_paths();

%% --- 1. CONFIGURATION ---
model_name = 'DAB_sweep_model';
device_hv = 'SiC_1200V';           % HV bridge: 'SiC_1200V' (see get_semiconductor_params)
device_lv = 'GaN';                 % LV bridge: 'GaN' or 'Si_60V'
freq_steps = (40:10:250) * 1e3;    % Hz, sweep points (40-250 kHz in 10 kHz steps, as in the paper)
num_sweep = length(freq_steps);
sim_time = 0.3;                    % s, Simulink stop time per point

%% --- 2. PARAMETERS ---
% Power ratings, devices, passives, transformer and the variables the
% Simulink model reads: see config/dab_parameters.m
dab_parameters

% --- Initialize Data Arrays ---
results.freq = zeros(1, num_sweep);            % Hz
results.eff_analytical = zeros(1, num_sweep);  % %
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
results.Volume_T = zeros(1, num_sweep);        % transformer
results.Volume_Total = zeros(1, num_sweep);    % inductor + transformer

% Body-diode losses [W]
data_loss_body = zeros(1, num_sweep);
data_loss_body_h = zeros(1, num_sweep);
data_loss_body_l = zeros(1, num_sweep);

% Steady-state check file for this device pair (replaced on each run)
current_plot_file = fullfile(repo_root, 'results', sprintf('current_plots_%s-%s.pdf', device_hv, device_lv));
if exist(current_plot_file, 'file'), delete(current_plot_file); end

fprintf('Starting Sweep (Target: %.1f kW)...\n', power.target/1e3);

%% --- 3. MAIN SWEEP LOOP ---
for i = 1:num_sweep
    f_sw_curr = freq_steps(i);     % read by the Simulink model
    T = 1 / f_sw_curr;             % read by the Simulink model (PWM period, T/1000 sample time)

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
    [P_sw_h_unit, zvs_h, t_req_h, ~] = calculate_switching_zvs(source.Vin, I_sw_ss_h, f_sw_curr, inductor.Lk, semi.hv, semi.hv.timing.t_dead);
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

    exportgraphics(gcf, current_plot_file, ...
        'Append', true, ...
        'ContentType','image');
    close
end

%% --- 4. REMOVE CRASHED POINTS ---
% A crashed simulation leaves its column at zero (freq == 0).
ok = results.freq ~= 0;
if any(~ok)
    fprintf('Removed %d crashed point(s): %s kHz\n', nnz(~ok), mat2str(freq_steps(~ok)/1e3));
end
result_fields = fieldnames(results);
for k = 1:numel(result_fields)
    results.(result_fields{k}) = results.(result_fields{k})(:, ok);
end
data_loss_body   = data_loss_body(ok);
data_loss_body_h = data_loss_body_h(ok);
data_loss_body_l = data_loss_body_l(ok);
clear ok result_fields k

%% --- 5. PLOTTING RESULTS ---
plot_sweep_results
