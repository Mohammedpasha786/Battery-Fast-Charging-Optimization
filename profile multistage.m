function profile = profileMultiStage(chrgParams, battParams, nStages)
% PROFILEMULTISTAGE  Generate an N-stage constant-current fast-charging profile.
%   Each stage applies a progressively lower C-rate with time-based transitions
%   and a final CV taper.
%
%   profile = profileMultiStage(chrgParams, battParams, nStages)
%
%   Default nStages = 4 (e.g. 3C → 2C → 1C → 0.5C → CV taper)
%
%   References:
%     Liu et al. (2019) — multi-stage CC fast charging for NMC cells
%     Tanim et al. (2017) — stepped-current protocols for reduced degradation

    if nargin < 3, nStages = 4; end
    nStages = min(max(nStages, 2), 6);  % clamp [2,6]

    Q    = battParams.cell.nominal_capacity_Ah;
    t_max= chrgParams.max_time_s;
    dt   = chrgParams.dt_s;

    % C-rates for each stage (from config, or auto-generate decreasing ramp)
    ms = chrgParams.multistage;
    if numel(ms.C_rates) >= nStages
        C_rates = ms.C_rates(1:nStages);
    else
        C_max = ms.C_rates(1);
        C_min = 0.3;
        C_rates = linspace(C_max, C_min, nStages);
    end

    t     = (0:dt:t_max)';
    I     = zeros(size(t));
    Nt    = numel(t);

    % Time boundaries for each stage (equal duration, excluding CV tail)
    cv_fraction = 0.20;          % last 20% of time is CV taper
    t_cv_start  = t_max * (1 - cv_fraction);
    t_stages    = t_max * (1 - cv_fraction);
    boundaries  = linspace(0, t_stages, nStages+1);

    for k = 1:Nt
        if t(k) >= t_cv_start
            % CV taper
            tau   = t_max * cv_fraction / 3.5;
            I_val = C_rates(end) * Q * exp(-(t(k) - t_cv_start) / tau);
            I_cut = 0.05 * Q;
            if I_val < I_cut
                I(k:end) = 0;
                break;
            end
            I(k) = I_val;
        else
            % Find which CC stage
            stageIdx = sum(t(k) >= boundaries(1:end-1));
            stageIdx = min(max(stageIdx, 1), nStages);
            I(k) = C_rates(stageIdx) * Q;
        end
    end

    profile.time    = t;
    profile.current = I;
    profile.label   = sprintf('%d-Stage CC (%.1f→%.1f C)', nStages, C_rates(1), C_rates(end));
    profile.type    = 'multistage';
    profile.nStages = nStages;
    profile.C_rates = C_rates;

    fprintf('  %d-stage CC profile: C-rates = [%s] C\n', ...
            nStages, num2str(C_rates, '%.1f  '));
end
