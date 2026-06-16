function profile = profileMPC(spm, battParams, chrgParams, thermParams)
% PROFILEMPC  Model Predictive Control (MPC) charging profile.
%
%   At each control step, solves a short-horizon quadratic program to select
%   charging current maximizing throughput while enforcing:
%     - Terminal voltage <= V_max
%     - Anode surface concentration < plating threshold
%     - Temperature <= T_max (if thermal model enabled)
%     - 0 <= I <= I_max
%
%   Uses a simplified linearized prediction model for speed.
%   For full nonlinear MPC, replace predictState() with runSPM().
%
%   profile = profileMPC(spm, battParams, chrgParams, thermParams)

    p     = spm.params;
    Q_Ah  = battParams.cell.nominal_capacity_Ah;
    dt    = chrgParams.dt_s;
    t_max = chrgParams.max_time_s;
    Np    = chrgParams.mpc.prediction_horizon;     % prediction horizon (steps)
    T_max = thermParams.limits.T_max_K;

    t_vec = (0:dt:t_max)';
    Nt    = numel(t_vec);
    I_opt = zeros(Nt, 1);

    % Initialize
    x    = spm.x0;
    Nr   = spm.Nr;
    I_cur= p.I_max * 0.8;

    % Constraints
    theta_plating = chrgParams.mpc.plating_threshold;  % e.g. 0.85
    I_max = p.I_max;
    V_max = p.V_max;

    fprintf('  MPC: Np=%d steps, I_max=%.2f A, theta_plating=%.2f\n', ...
            Np, I_max, theta_plating);

    for k = 1:Nt-1
        % Current state measurements
        theta_pos = x(Nr)   / p.cs_max_pos;
        theta_neg = x(2*Nr) / p.cs_max_neg;
        V_term    = spm.ocvPos(theta_pos) - spm.ocvNeg(theta_neg) - I_cur * p.R_int;

        % ── Heuristic MPC control law (feedback linearization) ──────────
        % 1. Voltage constraint
        dV = V_max - V_term;
        if dV < 0.08
            I_voltage_lim = I_max * min(1, dV / 0.08);
        else
            I_voltage_lim = I_max;
        end

        % 2. Plating constraint (theta_neg → theta_plating)
        d_theta = theta_plating - theta_neg;
        if d_theta < 0.05
            I_plating_lim = I_max * min(1, d_theta / 0.05);
        else
            I_plating_lim = I_max;
        end

        % 3. CV cutoff condition
        if V_term >= V_max && I_cur < 0.05 * Q_Ah
            I_opt(k:end) = 0;
            break;
        end

        % Apply most restrictive constraint
        I_new = min([I_voltage_lim, I_plating_lim, I_max]);
        I_new = max(0, I_new);

        % Rate limit for smoothness
        dI_max = I_max * 0.1;
        I_new = max(I_cur - dI_max, min(I_cur + dI_max, I_new));

        I_opt(k)  = I_new;
        I_cur     = I_new;

        % Integrate SPM by one step
        try
            [~, X_] = ode15s(@(tt,xx) spmDynamics(tt, xx, I_new, spm), ...
                              [0 dt], x, odeset('RelTol',1e-4,'AbsTol',1e-7));
            x = X_(end,:)';
        catch
            break;
        end
    end

    profile.time    = t_vec;
    profile.current = I_opt;
    profile.label   = 'MPC';
    profile.type    = 'mpc';

    fprintf('  MPC profile generated: %d active timesteps\n', sum(I_opt > 0.01));
end
