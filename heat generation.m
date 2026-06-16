function Q_gen = heatGeneration(I, T, spm, thermParams)
% HEATGENERATION  Compute total heat generation rate in a Li-ion cell.
%
%   Q_gen = heatGeneration(I, T, spm, thermParams)
%
%   Inputs:
%     I    - applied current (A), positive = charge
%     T    - cell temperature (K)
%     spm  - SPM struct (contains R_int)
%     thermParams - thermal parameters
%
%   Output:
%     Q_gen - total heat generation rate (W)
%
%   Components:
%     Q_ohmic    = I^2 * R_int(T)          [irreversible Joule heating]
%     Q_entropic = I * T * dU/dT            [reversible entropic heat]
%     Q_total    = Q_ohmic + Q_entropic
%
%   Temperature-dependent resistance (Arrhenius):
%     R(T) = R_ref * exp(Ea/R * (1/T - 1/T_ref))

    p    = spm.params;
    R_gas= p.R_gas;
    T_ref= p.T_ref;

    %% ── Temperature-dependent internal resistance (Arrhenius) ────────────
    Ea_R  = thermParams.activation_energy_R_J_mol;   % activation energy for R
    R_T   = p.R_int * exp(Ea_R / R_gas * (1/T - 1/T_ref));

    %% ── Ohmic (irreversible) heat ─────────────────────────────────────────
    Q_ohmic = I^2 * R_T;

    %% ── Entropic (reversible) heat ───────────────────────────────────────
    % dU/dT estimated empirically (-0.0002 to -0.001 V/K for graphite/NMC)
    dUdT_pos = thermParams.dUdT_positive_V_K;   % V/K (typically negative)
    dUdT_neg = thermParams.dUdT_negative_V_K;   % V/K

    dUdT_cell = dUdT_pos - dUdT_neg;
    Q_entropic = I * T * dUdT_cell;

    %% ── Contact / SEI resistance heat (optional small term) ──────────────
    Q_contact = 0;
    if isfield(thermParams, 'R_contact_Ohm')
        Q_contact = I^2 * thermParams.R_contact_Ohm;
    end

    Q_gen = Q_ohmic + Q_entropic + Q_contact;
end
