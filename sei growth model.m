function sei = seiGrowthModel(simOut, battParams, nCycles)
% SEIGROWTHMODEL  Solid-Electrolyte Interphase (SEI) film growth model.
%
%   Models capacity loss and resistance increase due to SEI growth on the
%   graphite anode. SEI thickness grows as a square-root function of time
%   (diffusion-limited growth mechanism).
%
%   Model:
%     d(delta_sei)/dt = k_sei / (2 * delta_sei) * exp(-Ea / R / T)
%     => delta_sei(t) = sqrt(k_sei * t * exp(-Ea/R/T))
%
%   Capacity loss due to Li+ consumed in SEI:
%     Q_loss_sei = F * a_s * delta_sei * c_sei * L_electrode * A
%
%   Resistance increase:
%     R_sei = delta_sei / kappa_sei / A_electrode
%
%   sei = seiGrowthModel(simOut, battParams, nCycles)

    R_gas = 8.314;
    p     = battParams.cell;
    sp    = battParams.sei;

    k_sei    = sp.growth_rate_m2_s;         % SEI growth rate constant
    Ea_sei   = sp.activation_energy_J_mol;  % activation energy
    c_sei    = sp.Li_concentration_mol_m3;  % Li concentration in SEI
    kappa    = sp.conductivity_S_m;         % SEI ionic conductivity
    A_elec   = p.electrode_area_m2;

    T_avg = mean(simOut.temperature);
    t_cycle = simOut.time(end);   % seconds per cycle

    % SEI thickness per cycle (cumulative)
    t_total = t_cycle * (1:nCycles)';
    delta_sei = sqrt(k_sei * t_total .* exp(-Ea_sei / R_gas / T_avg));   % metres

    % Capacity loss (mol Li consumed → Ah lost)
    n_pos_params = battParams.electrodes;
    a_s = n_pos_params.negative.specific_interfacial_area_m2_m3;
    L   = n_pos_params.negative.electrode_thickness_m;
    F   = 96485;

    Q_loss_sei = F * a_s * delta_sei * c_sei * L * A_elec / 3600;  % Ah

    sei.cycle          = (1:nCycles)';
    sei.thickness_nm   = delta_sei * 1e9;   % convert to nm
    sei.Q_loss_Ah      = Q_loss_sei;
    sei.Q_loss_pct     = Q_loss_sei / p.nominal_capacity_Ah * 100;
    sei.R_sei_Ohm      = delta_sei / (kappa * A_elec);
    sei.capacity_retention = 1 - sei.Q_loss_Ah / p.nominal_capacity_Ah;

    fprintf('  SEI after %d cycles: δ=%.1f nm, Q_loss=%.2f%%\n', ...
            nCycles, sei.thickness_nm(end), sei.Q_loss_pct(end));
end
