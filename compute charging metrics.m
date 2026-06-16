function metrics = computeChargingMetrics(simOut, battParams)
% COMPUTECHARGINGMETRICS  Compute performance metrics from SPM simulation.
%
%   metrics = computeChargingMetrics(simOut, battParams)
%
%   Inputs:
%     simOut     - output struct from runSPM
%     battParams - cell parameter struct
%
%   Output metrics:
%     chargingTime_min    - total time to reach SOC_target (minutes)
%     finalSOC            - final state of charge [0,1]
%     maxVoltage_V        - peak terminal voltage (V)
%     maxTemp_C           - peak core temperature (°C)
%     coulombicEfficiency - charge delivered / charge input [0,1]
%     energyEfficiency    - energy to cell / energy from source [0,1]
%     avgCRate            - average C-rate during CC phase
%     maxPlatingRisk      - max theta_neg_surf (plating indicator)
%     chargingTime_to80pct- minutes to reach 80% SOC

    t   = simOut.time;
    I   = simOut.current;
    V   = simOut.voltage;
    soc = simOut.soc;
    T   = simOut.temperature;
    Q   = battParams.cell.nominal_capacity_Ah;

    %% ── Charging time ─────────────────────────────────────────────────────
    idx_end = find(I > 0.01, 1, 'last');
    if isempty(idx_end), idx_end = numel(t); end
    metrics.chargingTime_min = t(idx_end) / 60;

    %% ── Time to 80% SOC ──────────────────────────────────────────────────
    idx_80 = find(soc >= 0.80, 1, 'first');
    if ~isempty(idx_80)
        metrics.chargingTime_to80pct = t(idx_80) / 60;
    else
        metrics.chargingTime_to80pct = Inf;
    end

    %% ── Final SOC ─────────────────────────────────────────────────────────
    metrics.finalSOC = soc(end);

    %% ── Voltage ───────────────────────────────────────────────────────────
    metrics.maxVoltage_V = max(V);
    metrics.minVoltage_V = min(V);

    %% ── Temperature ───────────────────────────────────────────────────────
    metrics.maxTemp_C  = max(T) - 273.15;
    metrics.minTemp_C  = min(T) - 273.15;
    metrics.riseTemp_C = (max(T) - T(1));   % temperature rise in °C (K equiv.)

    %% ── Coulombic efficiency ──────────────────────────────────────────────
    dt = gradient(t);
    Q_in  = trapz(t, I);                  % total charge input (As)
    Q_out = (soc(end) - soc(1)) * Q * 3600;  % useful charge (As)
    metrics.coulombicEfficiency = min(1, Q_out / max(Q_in, eps));

    %% ── Energy efficiency ─────────────────────────────────────────────────
    E_in   = trapz(t, I .* V);            % energy input (J)
    E_ocv  = trapz(t, I .* simOut.theta_pos_surf .* 0);  % placeholder
    % Use voltage-based estimate
    V_nom  = battParams.cell.nominal_voltage_V;
    E_stored = Q_out * V_nom;
    metrics.energyEfficiency = min(1, E_stored / max(E_in, eps));

    %% ── Average C-rate ────────────────────────────────────────────────────
    cc_mask = I > 0.5 * max(I);
    metrics.avgCRate = mean(I(cc_mask)) / Q;

    %% ── Plating risk ──────────────────────────────────────────────────────
    metrics.maxPlatingRisk = max(simOut.theta_neg_surf);
    metrics.platingRiskFlag = metrics.maxPlatingRisk > battParams.degradation.plating_threshold;
end
