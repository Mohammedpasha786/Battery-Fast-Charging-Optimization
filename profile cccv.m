function profile = profileCCCV(chrgParams, battParams)
% PROFILECCCV  Generate a Constant Current – Constant Voltage charging profile.
%
%   profile = profileCCCV(chrgParams, battParams)
%
%   Stages:
%     CC phase: charge at I_cc = C_rate × Q  until V = V_max
%     CV phase: hold V_max, current tapers exponentially until I < I_cutoff
%
%   Output:
%     profile.time     [Nt x 1]  time vector (s)
%     profile.current  [Nt x 1]  current (A, positive = charging)
%     profile.label    string identifier

    Q      = battParams.cell.nominal_capacity_Ah;       % Ah
    C_rate = chrgParams.cccv.cc_rate_C;                 % C-rate (e.g. 1.0)
    I_cc   = C_rate * Q;                                % CC current (A)
    I_cut  = chrgParams.cccv.cutoff_current_C * Q;      % CV cutoff current (A)
    t_max  = chrgParams.max_time_s;
    dt     = chrgParams.dt_s;

    t  = (0:dt:t_max)';
    I  = zeros(size(t));
    Nt = numel(t);

    % Estimate CC duration as 70% of total time
    t_cc_end = t_max * 0.65;

    for k = 1:Nt
        if t(k) <= t_cc_end
            I(k) = I_cc;
        else
            % Exponential CV taper
            tau = (t_max - t_cc_end) / 3.5;
            I_val = I_cc * exp(-(t(k) - t_cc_end) / tau);
            if I_val < I_cut
                I(k:end) = 0;
                break;
            end
            I(k) = I_val;
        end
    end

    profile.time    = t;
    profile.current = I;
    profile.label   = sprintf('CC-CV (%.1fC)', C_rate);
    profile.type    = 'cccv';
    profile.C_rate  = C_rate;

    fprintf('  CC-CV profile: I_cc=%.2f A (%.1fC) → CV taper → cutoff %.3f A\n', ...
            I_cc, C_rate, I_cut);
end
