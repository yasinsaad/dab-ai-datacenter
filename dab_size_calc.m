function [V_L, V_T, V_total, info] = dab_size_calc(f, Vin, Lk, Ipk)

% INPUTS:
%   f      : switching frequency [Hz]
%   Vin    : primary DC voltage [V]
%   Lk     : total DAB power-transfer inductance referred to primary [H]
%            (already calculated elsewhere)
%   Ipk    : peak current from Simulink [A]
%
% OUTPUTS:
%   V_L     : minimum required inductor gap volume [m^3]
%   V_T     : estimated transformer core volume [m^3] (heuristic)
%   V_total : total estimated magnetic volume [m^3]
%   info    : diagnostic structure
%
% NOTES:
%   1) Closed-loop control adjusts phase shift in Simulink, not here.
%   2) This function evaluates magnetic size using existing Lk and Ipk.
%   3) Transformer area uses square-wave flux law:
%         Bpk = Vin / (4*f*Np*Ae)
%   4) V_L is minimum gap volume from magnetic energy density.
%   5) V_T is heuristic unless replaced with manufacturer core data.

    % ---------------------------------------------------------------------
    % Design assumptions
    % ---------------------------------------------------------------------
    mu0    = 4*pi*1e-7;   % H/m
    Bmax_L = 0.30;        % T, chosen peak flux for inductor design
    Bmax_T = 0.30;        % T, chosen peak flux for transformer design
    Np     = 16;          % fixed primary turns
    kT     = 6.0;         % heuristic transformer geometry factor

    % ---------------------------------------------------------------------
    % Basic checks
    % ---------------------------------------------------------------------
    if f <= 0
        error('Switching frequency f must be > 0.');
    end
    if Vin <= 0
        error('Vin must be > 0.');
    end
    if Lk <= 0
        error('Lk must be > 0.');
    end
    if Ipk < 0
        error('Ipk must be >= 0.');
    end

    % ---------------------------------------------------------------------
    % 1) Inductor energy requirement
    % ---------------------------------------------------------------------
    E_L = 0.5 * Lk * Ipk^2;   % [J]

    % Minimum gap volume from magnetic energy density:
    % E = (B^2 / (2*mu0)) * Vgap  =>  Vgap = 2*mu0*E / B^2
    V_L = (2 * mu0 * E_L) / (Bmax_L^2);

    % ---------------------------------------------------------------------
    % 2) Transformer core area for square-wave excitation
    % ---------------------------------------------------------------------
    % Bpk = Vin / (4*f*Np*Ae)  =>  Ae = Vin / (4*f*Np*Bmax_T)
    Ae_T = Vin / (4 * f * Np * Bmax_T);

    % Rough transformer core volume estimate
    V_T = kT * Ae_T^(3/2);

    % ---------------------------------------------------------------------
    % 3) Total estimated magnetic volume
    % ---------------------------------------------------------------------
    V_total = V_L + V_T;

    % ---------------------------------------------------------------------
    % Diagnostics
    % ---------------------------------------------------------------------
    info = struct();
    info.mu0 = mu0;
    info.Lk = Lk;
    info.Ipk = Ipk;
    info.E_L = E_L;
    info.Ae_T = Ae_T;
    info.Np = Np;
    info.Bmax_L = Bmax_L;
    info.Bmax_T = Bmax_T;
    info.note1 = 'Closed-loop PID in Simulink adjusts the phase shift.';
    info.note2 = 'This function only evaluates magnetic size from Lk and Ipk.';
    info.note3 = 'V_L is minimum gap volume, not full inductor core bulk volume.';
    info.note4 = 'V_T is heuristic unless replaced by manufacturer core data.';
end
