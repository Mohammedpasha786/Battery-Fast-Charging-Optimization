function degradation = capacityFadeModel(simOut, battParams, nCycles)
% CAPACITYFADEMODEL  Empirical capacity fade model for Li-ion cells.
%
%   Computes capacity retention, resistance growth, and cycle life
%   prediction based on simulated cycle stress factors:
%   temperature, depth of discharge, and high-C-rate exposure.
%
%   Model (semi-empirical, based on NMC degradation literature):
%     Q_loss(n) = A * exp(-Ea / R / T) * (I_rms / I_ref)^z * n^0.5
%     R_growth  = B * n^0.5
%
%   degradation = capacityFadeModel(simOut, battParams, nCycles)
%
%   Inputs:
%     simOut     - output from runSPM (per-cycle simulation)
%     battParams - cell parameters
%     nCycles    - number of cycles to project
%
%   Output:
%     degradation.capacity_retention  [nCycles x 1]  fraction [0,1]
%     degradation.R_growth            [nCycles x 1]  Ohm
%     degradation.soh                 [nCycles x 1]  state of health (%)
%     degradation.cycle_life_80pct    cycles to 80% capacity (estimated)

    R_gas = 8.314;
    p     = battParams.cell;
    dp    = battParams.degradation;

    Ea    = dp.activation_energy_J_mol;     % activation energy for fade
    A_fac = dp.fade_prefactor;              % pre-exponential factor
    z_exp = dp.current_exponent;            % exponent on I_rms/I_ref
    I_ref = p.nominal_capacity_Ah;          % 1C reference current (A)
    B_R   = dp.resistance_growth_factor;

    % Per-cycle stress factors
    T_avg  = mean(simOut.temperature);
    I_rms  = sqrt(mean(simOut.current.^2));

    k_fade = A_fac * exp(-Ea / R_gas / T_avg) * (I_rms / I_ref)^z_exp;
    k_R    = B_R * exp(-Ea / R_gas / T_avg);

    % Fade law: Q_loss(n) ≈ k_fade * n^0.5  (square-root law for SEI growth)
    n_vec = (1:nCycles)';
    Q_loss = k_fade * n_vec.^0.5;         % fractional capacity loss
    Q_loss = min(Q_loss, 0.5);            % cap at 50% loss

    degradation.cycle              = n_vec;
    degradation.capacity_retention = 1 - Q_loss;
    degradation.soh                = (1 - Q_loss) * 100;
    degradation.R_growth           = p.internal_resistance_Ohm + k_R * n_vec.^0.5;
    degradation.Q_loss_pct         = Q_loss * 100;

    % Estimate cycle life to 80% capacity
    idx_80 = find(degradation.capacity_retention <= 0.80, 1, 'first');
    if isempty(idx_80)
        degradation.cycle_life_80pct = Inf;
    else
        degradation.cycle_life_80pct = idx_80;
    end

    fprintf('  Degradation: k_fade=%.2e/cycle, cycle life (80%%): %d cycles\n', ...
            k_fade, degradation.cycle_life_80pct);
end
