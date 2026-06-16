function [dT_core, dT_surface] = thermalModel(T_core, T_surface, I, spm, thermParams)
% THERMALMODEL  Two-state lumped thermal model for a cylindrical Li-ion cell.
%
%   Models heat conduction from cell core to surface and convective
%   cooling from surface to ambient. Based on Bernardi et al. (1985).
%
%   dT_core/dt    = (Q_gen - (T_core - T_surface)/R_c) / C_core
%   dT_surface/dt = ((T_core - T_surface)/R_c - (T_surface - T_amb)/R_u) / C_surface
%
%   Inputs:
%     T_core     - core temperature (K)
%     T_surface  - surface temperature (K)
%     I          - applied current (A, positive = charging)
%     spm        - SPM struct (for internal resistance and OCV)
%     thermParams- thermal parameters struct from thermal_params.yaml
%
%   Outputs:
%     dT_core    - d(T_core)/dt (K/s)
%     dT_surface - d(T_surface)/dt (K/s)

    tp  = thermParams;
    T_amb = tp.T_ambient_K;

    % Thermal resistances and capacitances
    R_c  = tp.R_core_K_W;      % core-to-surface resistance (K/W)
    R_u  = tp.R_surface_K_W;   % surface-to-ambient resistance (K/W)
    C_c  = tp.C_core_J_K;      % core heat capacity (J/K)
    C_s  = tp.C_surface_J_K;   % surface heat capacity (J/K)

    % Heat generation
    Q_gen = heatGeneration(I, T_core, spm, thermParams);

    % Thermal ODEs
    dT_core    = (Q_gen - (T_core - T_surface) / R_c) / C_c;
    dT_surface = ((T_core - T_surface) / R_c - (T_surface - T_amb) / R_u) / C_s;
end
