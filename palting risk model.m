function risk = platingRiskModel(simOut, spm, battParams)
% PLATINGRISKMODEL  Assess lithium plating risk during fast charging.
%
%   Lithium plating occurs when the anode potential drops below 0 V vs Li/Li+,
%   meaning metallic lithium deposits on the graphite surface instead of
%   intercalating — a major safety and degradation concern.
%
%   SPM-based indicator (simplified):
%     theta_neg_surf → 1  (surface concentration approaching saturation)
%       => higher probability of negative electrode potential → 0 V
%
%   A full plating indicator compares solid and liquid phase potentials
%   at the anode/separator interface (requires full DFN model).
%   Here we use theta_neg as a practical substitute per the project brief.
%
%   risk = platingRiskModel(simOut, spm, battParams)
%
%   Output:
%     risk.theta_neg_surf    [N x 1]  normalized anode surface concentration
%     risk.plating_indicator [N x 1]  0 = safe, 1 = plating onset
%     risk.plating_risk_pct          % of charging time at risk
%     risk.max_theta_neg             maximum theta_neg reached
%     risk.first_risk_time_s         time when plating risk first appears

    thresh = battParams.degradation.plating_threshold;

    theta_neg = simOut.theta_neg_surf;
    t         = simOut.time;

    % Plating indicator: sigmoid function approaching 1 near threshold
    risk.theta_neg_surf    = theta_neg;
    risk.plating_indicator = 1 ./ (1 + exp(-50 * (theta_neg - thresh)));

    % Percentage of time at risk (theta_neg > threshold)
    at_risk = theta_neg > thresh;
    risk.plating_risk_pct  = sum(at_risk) / numel(theta_neg) * 100;
    risk.max_theta_neg     = max(theta_neg);

    idx_first = find(at_risk, 1, 'first');
    if isempty(idx_first)
        risk.first_risk_time_s = Inf;
    else
        risk.first_risk_time_s = t(idx_first);
    end

    if risk.plating_risk_pct > 5
        fprintf('  ⚠ Plating risk: %.1f%% of charge time | max θ_neg=%.3f (threshold=%.3f)\n', ...
                risk.plating_risk_pct, risk.max_theta_neg, thresh);
    else
        fprintf('  ✓ Low plating risk: %.1f%% of charge time | max θ_neg=%.3f\n', ...
                risk.plating_risk_pct, risk.max_theta_neg);
    end
end
