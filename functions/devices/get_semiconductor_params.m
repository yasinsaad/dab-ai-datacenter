function [hv_params, lv_params] = get_semiconductor_params(type_hv, type_lv)
% GET_SEMICONDUCTOR_PARAMS  Datasheet parameter structs for the HV and LV bridge devices.
%
% Usage:
%   [semi.hv, semi.lv] = get_semiconductor_params('SiC_1200V', 'Si_60V');
%
% Inputs:
%   type_hv, type_lv : device name, one of
%       'SiC' | 'SiC_1200V'        Infineon AIMBG120R030M1, 1200 V CoolSiC MOSFET
%       'Si'  | 'Si_LV' | 'Si_60V' Vishay SQJQ160E, 60 V Si MOSFET
%       'GaN' | 'GaN_100V'         100 V eGaN FET, 6 in parallel
%
% Outputs (struct fields, SI units):
%   Ron, Vf                  on-resistance [ohm], reverse-conduction drop [V]
%   Rd                       external gate resistor from the datasheet [ohm].
%                            Note: the Simulink models use R_d_h / R_d_l
%                            (= Rd) as the MOSFET block's internal-diode
%                            resistance, not as a gate resistor.
%   Rg                       internal gate resistance [ohm]
%   Qg, Qgs, Qgd (, Qoss)    charges [C]
%   Ciss, Crss, Coss         capacitances [F]
%   V_dr_on, V_dr_off        gate-drive levels [V]
%   V_gs_th, V_plateau       threshold and Miller-plateau voltage [V]
%   diode.*                  reverse-recovery reference data (trr, Irm, Io, di/dt)
%   t_RV, t_FI               turn-off voltage-rise / current-fall times [s]
%   isMOSFET, isGaN          flags (not used by the current loss functions)
%   timing.t_dead            dead time [s] from estimate_dead_time_from_device

    hv_params = load_device_profile(type_hv);
    lv_params = load_device_profile(type_lv);
end

function p = load_device_profile(type)

    switch type

       case {'SiC', 'SiC_1200V'}
            % Infineon AIMBG120R030M1 CoolSiC 1200 V MOSFET

            % Conduction
            p.Ron = 30e-3;          % ohm, Table 4 max/typ range around 30-38 mOhm
            p.Vf  = 3.95;           % V, Table 6 typ at 27 A, 25 C and 800V

            % Gate network
            p.Rd = 2.0;             % ohm, chosen external gate resistor in the table
            p.Rg = 2.6;             % ohm, Table 4 internal gate resistance

            % Charges all given at 800V
            p.Qg  = 57e-9;          % C, Table 4 total gate charge
            p.Qgs = 15e-9;          % C, plateau gate charge
            p.Qgd = 10e-9;          % C, gate-drain charge

            % Capacitances at 800V
            p.Ciss = 1738e-12;      % F
            p.Crss = 4.4e-12;       % F
            p.Coss = 82e-12;        % F
            p.Eoss = 34e-6;         % J at 800 V, if you want to use Eoss-based ZVS later

            % Drive logic
            p.V_dr_on   = 20;       % V
            p.V_dr_off  = 0;       % V, recommended in datasheet 
            p.V_gs_th   = 4.4;      % V, typical threshold
            p.V_plateau = 8;      % V, took from the graph of Vgs and Qg

            % Body diode / reverse conduction
            p.diode.trr_ref  = 26e-9;      % Not given , estimated from 2* Qfr/Ifrm
            p.diode.Irm_ref  = 13.5;       % A, Table 6 forward recovery peak current
            p.diode.Io_ref   = 27;         % A, Table 6 test current
            p.diode.didt_ref = 2000e6;     % A/s = 2000 A/us

            % Turn-off transition times, used by calculate_switching_zvs
            p.t_RV = 7.6e-9;        % s, voltage rise time
            p.t_FI = 8.5e-9;        % s, current fall time

            % Flags
            p.isMOSFET = true;
            p.isGaN    = false;

        case {'Si', 'Si_LV', 'Si_60V'}
            % Vishay SQJQ160E 60 V N-channel MOSFET

            % Conduction
            p.Ron = 0.55e-3;        % ohm, typical RDS(on) at 10 V
            p.Vf  = 0.7;            % V, typical body diode forward voltage

            % Gate network
            p.Rd = 1.0;             % ohm, external gate resistor used in test
            p.Rg = 1.4;             % ohm, max internal gate resistance given in table

            % Charges
            p.Qg  = 183e-9;         % C, typical total gate charge
            p.Qgs = 53e-9;          % C, typical gate-source charge
            p.Qgd = 42e-9;          % C, typical gate-drain charge

            % Capacitances taken from the graph at 48V
            p.Ciss = 12000e-12;     % F, 
            p.Crss = 70e-12;       % F,
            p.Coss = 2200e-12;      % F, 
            p.Eoss = 4.218e-6;      % J
            % Drive logic
            p.V_dr_on   = 10;       % V
            p.V_dr_off  = 0;       % V, design choice
            p.V_gs_th   = 3;      % V, max threshold
            p.V_plateau = 5;      % V, engineering estimate

            % Body diode
            p.diode.trr_ref  = 88e-9;     % s, max reverse recovery time
            p.diode.Irm_ref  = 2.7;        % A, typical
            p.diode.Io_ref   = 15;         % A, test current
            p.diode.didt_ref = 100e6;      % A/s = 100 A/us
            p.t_RV = 28.8e-9;       % s
            p.t_FI = 30.4e-9;       % s
            % Flags
            p.isMOSFET = true;
            p.isGaN    = false;

        case {'GaN', 'GaN_100V'}
            % 100 V eGaN FET 6 in parallel so Id is 87A
            % Single-device values x 6 (charges, capacitances) or / 6 (Ron).
            % Update these values if you are specifically using EPC2218 or EPC2367.

            % Conduction
            p.Ron = 2.33e-4;        % ohm, 1.4 mOhm / 6, from the RDS vs VGS graph (60 A, scaled to 80 A)
            p.Vf  = 1.4;            % V, reverse conduction drop estimate

            % Gate network
            p.Rd = 2.0;             % ohm, chosen external gate resistor
            p.Rg = 0.6;             % ohm, internal gate resistance

            % Charges(typical at 50V)
            p.Qg  = 1.02e-7;          % C 17e-9*6
            p.Qgs = 3.18e-8;         % C  5.3e-9*6
            p.Qgd = 1.44e-8;         % C  2.4e-9*6
            p.Qoss = 3e-7;         % C from Qoss and Vds graph  50e-9*6
            p.Qrr  = 0;             % C

            % Capacitances (typical) taken at 50V close to our 48V verified from C v Vds graph
            p.Ciss = 1.302e-8;      % F 2170e-12*6
            p.Crss = 4.8e-11;         % F8e-12*6
            p.Coss = 3.54e-9;       % F  590e-12*6

            % Drive logic
            p.V_dr_on   = 5;        % V
            p.V_dr_off  = 0;        % V
            p.V_gs_th   = 1.1;      % V, typical value from table
            p.V_plateau = 2.5;      % V, from vgs vs qg graph
            % Reverse conduction placeholder
            % GaN FETs have no body diode; reverse current flows through the
            % channel, so Qrr, trr and Irm are ~0. Io and di/dt are set to 1
            % to avoid division by zero in calculate_switching_zvs.

            p.diode.trr_ref  = 0;
            p.diode.Irm_ref  = 0;
            p.diode.Io_ref   = 1;
            p.diode.didt_ref = 1;

            % Limits
            p.Vds_max = 100;        % V
            p.Id_max  = 606;        % A 101*6
            p.t_RV = 3.75e-9;       % s
            p.t_FI = 2.81e-9;       % s

            % Flags       
            p.isMOSFET = true;   % GaN FET is a field-effect transistor; flag is informational
            p.isGaN    = true;

        otherwise
            error('Unknown Semiconductor Type: %s', type);
    end
    % Fixed dead time from device turn-off only (no operating point)
    p.timing.t_dead = estimate_dead_time_from_device(p);
end
