function profile = optimizeCharging(spm, battParams, chrgParams, optParams, method)
% OPTIMIZECHARGING  Optimal control for minimum-time battery charging.
%
%   Formulates and solves a constrained optimal control problem:
%
%     Minimize:   T_f  (total charging time)
%     Subject to:
%       SPM dynamics  (solid-phase diffusion ODEs)
%       V(t) <= V_max
%       theta_neg_surf(t) <= theta_plating
%       0 <= I(t) <= I_max
%       SOC(T_f) >= SOC_target
%
%   Methods:
%     'pseudospectral' - Gauss-Lobatto collocation (default)
%     'collocation'    - direct trapezoidal collocation
%
%   profile = optimizeCharging(spm, battParams, chrgParams, optParams)
%   profile = optimizeCharging(spm, battParams, chrgParams, optParams, method)

    if nargin < 5, method = 'pseudospectral'; end

    p       = spm.params;
    Q_Ah    = battParams.cell.nominal_capacity_Ah;
    I_max   = p.I_max;
    V_max   = p.V_max;
    Nr      = spm.Nr;
    nState  = 2 * Nr;

    soc_target     = chrgParams.soc_target;
    theta_plating  = optParams.plating_threshold;
    N              = optParams.N_collocation;  % collocation nodes
    t_upper        = chrgParams.max_time_s;

    fprintf('  Optimal control (%s): N=%d nodes, I_max=%.2f A\n', ...
            method, N, I_max);

    switch lower(method)
        case 'pseudospectral'
            profile = pseudospectralOpt(spm, battParams, chrgParams, optParams);
        case 'collocation'
            profile = directCollocation(spm, battParams, chrgParams, optParams);
        otherwise
            warning('Unknown method "%s"; using pseudo-spectral.', method);
            profile = pseudospectralOpt(spm, battParams, chrgParams, optParams);
    end
end
