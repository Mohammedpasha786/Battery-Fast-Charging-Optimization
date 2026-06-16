function profile = pseudospectralOpt(spm, battParams, chrgParams, optParams)
% PSEUDOSPECTRALOPT  Pseudo-spectral (Gauss-Lobatto) optimal control for
%   minimum-time battery charging using the Single Particle Model.
%
%   Discretizes the continuous-time OCP using Gauss-Lobatto collocation
%   points on a normalized time domain tau in [-1, 1], then solves
%   the resulting NLP with fmincon.
%
%   Reference: Perez et al. (2017) J. Electrochem. Soc.

    p      = spm.params;
    Nr     = spm.Nr;
    nX     = 2 * Nr;          % state dimension
    N      = optParams.N_collocation;
    I_max  = p.I_max;
    V_max  = p.V_max;
    theta_plating = optParams.plating_threshold;
    soc_target    = chrgParams.soc_target;

    %% ── Gauss-Lobatto nodes and differentiation matrix ───────────────────
    [tau, D] = gaussLobattoNodes(N);    % tau in [-1,1], D [N x N]

    % Optimization variables: [t_f; I(1..N); X(1..N, 1..nX)] (flattened)
    nI  = N;
    nXv = N * nX;
    nVar= 1 + nI + nXv;

    %% ── Initial guess (linear SOC ramp, constant current) ────────────────
    t_f0 = chrgParams.max_time_s * 0.6;
    I0   = repmat(I_max * 0.8, N, 1);
    x0_init = spm.x0;
    X0   = repmat(x0_init', N, 1);

    z0   = [t_f0; I0; X0(:)];

    %% ── Variable bounds ──────────────────────────────────────────────────
    lb = [0;         zeros(N,1);    repmat(zeros(nX,1), N, 1)];
    ub = [t_f0*1.5;  I_max*ones(N,1); repmat(Inf(nX,1), N, 1)];

    %% ── Solve NLP with fmincon ───────────────────────────────────────────
    opts = optimoptions('fmincon', ...
        'Algorithm',          'interior-point', ...
        'Display',            'iter-detailed', ...
        'MaxFunctionEvaluations', optParams.max_func_evals, ...
        'MaxIterations',       optParams.max_iterations, ...
        'OptimalityTolerance', optParams.optimality_tol, ...
        'ConstraintTolerance', optParams.constraint_tol, ...
        'SpecifyObjectiveGradient',  false, ...
        'SpecifyConstraintGradient', false);

    fprintf('  Solving NLP (%d vars, fmincon interior-point)...\n', nVar);

    [z_opt, fval, exitflag] = fmincon( ...
        @(z) objective(z),            ...
        z0, [], [], [], [],           ...
        lb, ub,                        ...
        @(z) constraints(z, spm, tau, D, N, nX, I_max, V_max, theta_plating, soc_target), ...
        opts);

    fprintf('  NLP exitflag=%d, t_f=%.1f s (%.1f min)\n', ...
            exitflag, z_opt(1), z_opt(1)/60);

    %% ── Extract profile ───────────────────────────────────────────────────
    t_f  = z_opt(1);
    I_opt= z_opt(2:N+1);

    % Map from Gauss-Lobatto tau to physical time
    t_gl = (tau + 1) / 2 * t_f;    % [0, t_f]

    % Upsample to uniform grid for runSPM
    dt   = chrgParams.dt_s;
    t_uniform = (0:dt:t_f)';
    I_uniform = interp1(t_gl, I_opt, t_uniform, 'linear', I_opt(end));
    I_uniform = max(0, min(I_max, I_uniform));

    profile.time    = t_uniform;
    profile.current = I_uniform;
    profile.label   = sprintf('Pseudo-spectral Opt (N=%d)', N);
    profile.type    = 'pseudospectral';
    profile.t_f_opt = t_f;
    profile.exitflag= exitflag;
end


%% ── Objective: minimize t_f ──────────────────────────────────────────────
function J = objective(z)
    J = z(1);   % t_f is decision variable 1
end


%% ── Constraints ──────────────────────────────────────────────────────────
function [c, ceq] = constraints(z, spm, tau, D, N, nX, I_max, V_max, theta_plating, soc_target)
    p   = spm.params;
    Nr  = spm.Nr;
    t_f = z(1);
    I   = z(2:N+1);
    X   = reshape(z(N+2:end), N, nX);   % [N x nX]

    % ── Collocation (defect) constraints ──────────────────────────────────
    % dX/dt = (2/t_f) * D * X   (chain rule from tau to t)
    ceq = zeros(N, nX);
    Xdot_colloc = (2/t_f) * (D * X);   % [N x nX]

    for k = 1:N
        Xdot_model = spmDynamics(0, X(k,:)', I(k), spm)';
        ceq(k,:) = Xdot_colloc(k,:) - Xdot_model;
    end
    ceq = [ceq(:); X(1,:)' - spm.x0];   % initial condition

    % ── Inequality constraints ────────────────────────────────────────────
    c_V = zeros(N, 1);
    c_plating = zeros(N, 1);

    for k = 1:N
        theta_pos = X(k, Nr)   / p.cs_max_pos;
        theta_neg = X(k, 2*Nr) / p.cs_max_neg;
        V_term    = spm.ocvPos(theta_pos) - spm.ocvNeg(theta_neg) - I(k)*p.R_int;
        c_V(k)       = V_term - V_max;          % V <= V_max
        c_plating(k) = theta_neg - theta_plating; % theta_neg <= threshold
    end

    % Terminal SOC constraint
    theta_neg_f  = X(end, 2*Nr) / p.cs_max_neg;
    theta0_neg   = spm.params.cs_max_neg * 0.05 / p.cs_max_neg;
    theta100_neg = spm.params.cs_max_neg * 0.90 / p.cs_max_neg;
    soc_f = (theta_neg_f - theta0_neg) / (theta100_neg - theta0_neg);
    c_soc = soc_target - soc_f;  % SOC >= soc_target  → -(SOC - soc_target) <= 0

    c = [c_V; c_plating; c_soc];
end


%% ── Gauss-Lobatto nodes and differentiation matrix ───────────────────────
function [tau, D] = gaussLobattoNodes(N)
% Compute N Gauss-Lobatto points on [-1,1] and Chebyshev differentiation matrix.
    j   = (0:N-1)';
    tau = -cos(pi * j / (N-1));   % Chebyshev nodes

    % Chebyshev differentiation matrix (standard formula)
    D = zeros(N);
    c = ones(N,1); c(1) = 2; c(N) = 2;
    for i = 1:N
        for k = 1:N
            if i ~= k
                D(i,k) = c(i)/c(k) * (-1)^(i+k) / (tau(i) - tau(k));
            end
        end
    end
    % Diagonal
    for i = 1:N
        D(i,i) = -sum(D(i, [1:i-1, i+1:N]));
    end
end
