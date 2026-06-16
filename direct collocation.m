function profile = directCollocation(spm, battParams, chrgParams, optParams)
% DIRECTCOLLOCATION  Direct trapezoidal collocation for minimum-time
%   charging optimal control problem.
%
%   A simpler alternative to pseudo-spectral collocation:
%   - Uniform grid of N nodes over [0, t_f]
%   - Trapezoidal rule for dynamics constraints
%   - Solved with fmincon (interior-point)
%
%   profile = directCollocation(spm, battParams, chrgParams, optParams)

    p     = spm.params;
    Nr    = spm.Nr;
    nX    = 2 * Nr;
    N     = optParams.N_collocation;
    I_max = p.I_max;
    V_max = p.V_max;
    theta_plating = optParams.plating_threshold;
    soc_target    = chrgParams.soc_target;
    t_upper       = chrgParams.max_time_s;

    %% ── Decision variables: [t_f; I(1..N); X(1..N, 1..nX)] ─────────────
    nVar = 1 + N + N * nX;

    % Initial guess
    t_f0 = t_upper * 0.55;
    I0   = I_max * 0.7 * ones(N, 1);
    X0   = repmat(spm.x0', N, 1);
    z0   = [t_f0; I0; X0(:)];

    % Bounds
    lb = [0; zeros(N,1);    zeros(N*nX, 1)];
    ub = [t_upper; I_max*ones(N,1); Inf(N*nX, 1)];

    opts = optimoptions('fmincon', ...
        'Algorithm', 'interior-point', ...
        'Display', 'iter', ...
        'MaxFunctionEvaluations', optParams.max_func_evals, ...
        'MaxIterations', optParams.max_iterations, ...
        'OptimalityTolerance', optParams.optimality_tol);

    fprintf('  Solving direct collocation NLP (%d vars)...\n', nVar);

    [z_opt, ~, exitflag] = fmincon( ...
        @(z) z(1), z0, [], [], [], [], lb, ub, ...
        @(z) collocationConstraints(z, spm, N, nX, I_max, V_max, theta_plating, soc_target), ...
        opts);

    t_f  = z_opt(1);
    I_opt= z_opt(2:N+1);
    t_nodes = linspace(0, t_f, N)';

    dt  = chrgParams.dt_s;
    t_u = (0:dt:t_f)';
    I_u = interp1(t_nodes, I_opt, t_u, 'linear', 0);
    I_u = max(0, min(I_max, I_u));

    profile.time    = t_u;
    profile.current = I_u;
    profile.label   = sprintf('Direct Collocation (N=%d)', N);
    profile.type    = 'collocation';
    profile.t_f_opt = t_f;
    profile.exitflag= exitflag;

    fprintf('  Direct collocation: exitflag=%d, t_f=%.1f min\n', exitflag, t_f/60);
end


function [c, ceq] = collocationConstraints(z, spm, N, nX, I_max, V_max, theta_plating, soc_target)
    p   = spm.params;
    Nr  = spm.Nr;
    t_f = z(1);
    I   = z(2:N+1);
    X   = reshape(z(N+2:end), N, nX);

    dt  = t_f / (N-1);
    ceq = [];

    % Trapezoidal collocation: X(k+1) - X(k) = dt/2 * (f(k) + f(k+1))
    for k = 1:N-1
        fk  = spmDynamics(0, X(k,:)',   I(k),   spm)';
        fk1 = spmDynamics(0, X(k+1,:)', I(k+1), spm)';
        defect = X(k+1,:) - X(k,:) - dt/2 * (fk + fk1);
        ceq = [ceq, defect]; %#ok<AGROW>
    end
    ceq = [ceq, (X(1,:) - spm.x0')];  % initial condition

    % Inequality constraints
    c_V = zeros(N,1);
    c_th = zeros(N,1);
    for k = 1:N
        theta_pos = X(k, Nr)   / p.cs_max_pos;
        theta_neg = X(k, 2*Nr) / p.cs_max_neg;
        V_t = spm.ocvPos(theta_pos) - spm.ocvNeg(theta_neg) - I(k)*p.R_int;
        c_V(k)  = V_t - V_max;
        c_th(k) = theta_neg - theta_plating;
    end

    theta_neg_f = X(end, 2*Nr) / p.cs_max_neg;
    theta0  = 0.05; theta100 = 0.90;
    soc_f   = (theta_neg_f - theta0) / (theta100 - theta0);

    c = [c_V; c_th; soc_target - soc_f];
end
