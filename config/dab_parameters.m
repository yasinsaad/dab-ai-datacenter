%% DAB_PARAMETERS  Converter parameters shared by the simulation scripts.
%
% Script (not a function): run it after setting device_hv and device_lv.
% It defines, in the calling workspace:
%   power, headroom_factor, max_power   power ratings
%   semi, passives, trans, source       parameter structs
% and the scalar variables the Simulink models read (R_on_h, ..., R_s).
%
% Variables the Simulink models read from the base workspace:
%   set here:       trans.V1/V2/R1/R2/Lm/Rm/power, source.Vin/Vout,
%                   power.target, R_on_*, R_d_*, V_f_*, R_cab_*, L_cab_*,
%                   C_bulk_*, R_s
%   set per run by the calling script:
%                   f_sw_curr     switching frequency [Hz]
%                   T             switching period 1/f_sw_curr [s]; the
%                                 models use it for the PWM period and the
%                                 T/1000 solver sample time
%                   inductor.Lk, inductor.Rdc   from get_inductor_params
%
% Used by: main/run_frequency_sweep.m, main/run_steady_state_waveforms.m

% Power ratings
power.target = 25000;              % W, nominal output power (25 kW)
headroom_factor = 1.3;             % Lk is sized for 1.3 x nominal = 32.5 kW
max_power = headroom_factor*power.target;

% A. Semiconductor profiles (HV bridge, LV bridge).
%    Dead time is set inside get_semiconductor_params.
[semi.hv, semi.lv] = get_semiconductor_params(device_hv, device_lv);

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

% --- Push parameters to the base workspace for the Simulink model ---
assignin('base', 'R_on_h', semi.hv.Ron);  assignin('base', 'R_on_l', semi.lv.Ron);
assignin('base', 'R_d_h',  semi.hv.Rd);   assignin('base', 'R_d_l',  semi.lv.Rd);   % MOSFET block 'Rd' = internal-diode resistance
assignin('base', 'V_f_h',  semi.hv.Vf);   assignin('base', 'V_f_l',  semi.lv.Vf);
assignin('base', 'R_cab_h', passives.hv.R_cab); assignin('base', 'L_cab_h', passives.hv.L_cab);
assignin('base', 'C_bulk_h',passives.hv.C_bulk);
assignin('base', 'R_cab_l', passives.lv.R_cab); assignin('base', 'L_cab_l', passives.lv.L_cab);
assignin('base', 'C_bulk_l',passives.lv.C_bulk);
assignin('base', 'R_s',     passives.Rs);
