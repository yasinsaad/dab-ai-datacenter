%% RUN_STEADY_STATE_WAVEFORMS  Simulate one operating point and save its steady-state waveforms.
%
% Runs models/DAB_waveform_model.slx (the sweep model plus voltage and
% inductor-current probes) at one switching frequency and saves the last
% few switching periods of six signals. This is the data behind Fig. 7
% of the TENCON paper (SiC-GaN, 140 kHz).
%
% Requires:  MATLAB + Simulink
% Output:
%   results/data/<HV>-<LV>_<f>kHz_steady_state.mat with
%     t_80                  time [s]
%     v_in_80               HV DC-link voltage, across the bulk capacitor [V]
%     i_in_80               DC input current [A]
%     v_l_80,   i_l_80      series-inductor voltage [V] / current [A]
%     v_out_80              LV DC-link voltage [V]
%     i_out_80              DC output current [A]
%   Variable names match those plot_steady_state_waveforms.m expects.
%
% The paper's data is in results/data/SiC-GaN_140kHz_steady_state.mat.
% This script writes a separate file and, for the paper's operating
% point, prints how far the new data is from the paper's.
%
% To plot the new data:
%   load results/data/SiC_1200V-GaN_140kHz_steady_state.mat
%   plot_steady_state_waveforms

clear; clc; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
repo_root = setup_paths();

%% --- 1. CONFIGURATION ---
model_name = 'DAB_waveform_model';
device_hv = 'SiC_1200V';           % HV bridge (see get_semiconductor_params)
device_lv = 'GaN';                 % LV bridge: 'GaN' or 'Si_60V'
f_sw_curr = 140e3;                 % Hz, switching frequency (read by the model)
sim_time = 0.3;                    % s, Simulink stop time (same as the sweep)
window_s = 30e-6;                  % s, saved window at the end of the run
                                   % (30 us = 4.2 periods at 140 kHz, as in Fig. 7)

%% --- 2. PARAMETERS ---
dab_parameters                     % config/dab_parameters.m
T = 1 / f_sw_curr;                 % s, read by the model (PWM period, T/1000 sample time)
inductor = get_inductor_params(source, trans, f_sw_curr, max_power);   % read by the model

%% --- 3. SIMULATE ---
fprintf('Simulating %s-%s at %.1f kHz...\n', device_hv, device_lv, f_sw_curr/1e3);
simOut = sim(model_name, 'StopTime', num2str(sim_time));

%% --- 4. EXTRACT THE STEADY-STATE WINDOW ---
% All six signals are logged as timeseries; use their own time vector and
% check that they share it.
signals = {'V_raw_in', 'I_raw_in', 'V_raw_Ind', 'I_raw_Ind', 'V_raw_out', 'I_raw_out'};
t = simOut.I_raw_Ind.Time;
for k = 1:numel(signals)
    if ~isequal(simOut.(signals{k}).Time, t)
        error('%s is logged on a different time grid. Check the "To Workspace" blocks.', signals{k});
    end
end

% Keep samples in the last window_s seconds (half-sample tolerance)
keep = t >= t(end) - window_s - T/2000;

t_80     = t(keep);
v_in_80  = simOut.V_raw_in.Data(keep);
i_in_80  = simOut.I_raw_in.Data(keep);
v_l_80   = simOut.V_raw_Ind.Data(keep);
i_l_80   = simOut.I_raw_Ind.Data(keep);
v_out_80 = simOut.V_raw_out.Data(keep);
i_out_80 = simOut.I_raw_out.Data(keep);

%% --- 5. SAVE ---
out_file = fullfile(repo_root, 'results', 'data', ...
    sprintf('%s-%s_%gkHz_steady_state.mat', device_hv, device_lv, f_sw_curr/1e3));
save(out_file, 't_80', 'v_in_80', 'i_in_80', 'v_l_80', 'i_l_80', 'v_out_80', 'i_out_80');
fprintf('Saved %d samples (%.1f us) to %s\n', numel(t_80), 1e6*(t_80(end) - t_80(1)), out_file);

%% --- 6. COMPARE WITH THE PAPER DATA (SiC-GaN, 140 kHz only) ---
paper_file = fullfile(repo_root, 'results', 'data', 'SiC-GaN_140kHz_steady_state.mat');
if strcmp(device_hv, 'SiC_1200V') && strcmp(device_lv, 'GaN') && f_sw_curr == 140e3 && exist(paper_file, 'file')
    ref = load(paper_file);
    names = {'t_80', 'v_in_80', 'i_in_80', 'v_l_80', 'i_l_80', 'v_out_80', 'i_out_80'};
    fprintf('\nComparison with %s:\n', paper_file);
    if numel(ref.t_80) ~= numel(t_80)
        fprintf('  Different lengths: paper %d samples, new %d samples.\n', numel(ref.t_80), numel(t_80));
    else
        for k = 1:numel(names)
            new = eval(names{k});
            fprintf('  %-9s max |new - paper| = %.3g  (paper range %.3g to %.3g)\n', ...
                    names{k}, max(abs(new(:) - ref.(names{k})(:))), min(ref.(names{k})), max(ref.(names{k})));
        end
    end
end
