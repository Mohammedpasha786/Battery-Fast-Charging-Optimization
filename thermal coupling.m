function thermal = thermalCoupling(simOut, thermParams)
% THERMALCOUPLING  Post-process and analyze thermal data from SPM simulation.
%
%   thermal = thermalCoupling(simOut, thermParams)
%
%   Inputs:
%     simOut     - output struct from runSPM (with .temperature field)
%     thermParams- thermal parameters struct
%
%   Output:
%     thermal    - struct with:
%                    .T_core_K    [N x 1]  core temperature (K)
%                    .T_surface_K [N x 1]  surface temperature (K)
%                    .T_core_C    [N x 1]  core temperature (°C)
%                    .maxTemp_C           maximum core temperature
%                    .deltaT_C            max core-to-surface gradient
%                    .thermalRunaway      logical flag
%                    .Q_gen       [N x 1]  heat generation rate (W)

    T_lim = thermParams.limits.T_max_K;
    T_amb = thermParams.T_ambient_K;

    T_core = simOut.temperature;
    T_surf = simOut.T_surface;

    thermal.T_core_K    = T_core;
    thermal.T_surface_K = T_surf;
    thermal.T_core_C    = T_core - 273.15;
    thermal.T_surface_C = T_surf - 273.15;

    thermal.maxTemp_C   = max(T_core) - 273.15;
    thermal.minTemp_C   = min(T_core) - 273.15;
    thermal.deltaT_C    = max(T_core - T_surf);

    % Thermal runaway flag (if temp exceeds safety limit)
    thermal.thermalRunaway = any(T_core > T_lim);

    if thermal.thermalRunaway
        warning('THERMAL RUNAWAY DETECTED: T_max=%.1f°C > T_limit=%.1f°C', ...
                thermal.maxTemp_C, T_lim - 273.15);
    end

    fprintf('  Thermal: T_max=%.1f°C | ΔT_core-surf=%.1f°C | Runaway=%s\n', ...
            thermal.maxTemp_C, thermal.deltaT_C, mat2str(thermal.thermalRunaway));
end
