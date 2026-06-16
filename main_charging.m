%  Simulate and compare Li-ion charging strategies using SPM
%
%  Usage:
%    >> main_charging
%    >> main_charging('strategy','cccv')
%    >> main_charging('strategy','multistage','stages',4)
%    >> main_charging('strategy','mpc')
%    >> main_charging('strategy','pseudospectral')
%    >> main_charging('strategy','all','thermal',true)
%
%  Required: Simscape Battery, Optimization Toolbox, Control System Toolbox
% =========================================================================

function main_charging(varargin)

clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

fprintf('=======================================================\n');
fprintf('  Battery Fast Charging Optimization\n');
fprintf('  Single Particle Model (SPM) | Simscape Battery\n');
fprintf('=======================================================\n\n');

%% ── Arguments ────────────────────────────────────────────────────────────
p = inputParser;
addParameter(p, 'strategy',  'all',      @ischar);
addParameter(p, 'stages',    4,          @isnumeric);
addParameter(p, 'thermal',   false,      @islogical);
addParameter(p, 'degrade',   false,      @islogical);
addParameter(p, 'nCycles',   1,          @isnumeric);
addParameter(p, 'configDir', './configs/', @ischar);
addParameter(p, 'outputDir', './results/', @ischar);
parse(p, varargin{:});
cfg = p.Results;

%% ── Load config ──────────────────────────────────────────────────────────
battParams = loadConfig(fullfile(cfg.configDir, 'battery_params.yaml'));
chrgParams = loadConfig(fullfile(cfg.configDir, 'charging_params.yaml'));
thermParams= loadConfig(fullfile(cfg.configDir, 'thermal_params.yaml'));
optParams  = loadConfig(fullfile(cfg.configDir, 'optimization_params.yaml'));

fprintf('[Config] Cell: %s | %.1f Ah | %.1f V nominal\n', ...
    battParams.cell.chemistry, battParams.cell.nominal_capacity_Ah, ...
    battParams.cell.nominal_voltage_V);

%% ── Build SPM ────────────────────────────────────────────────────────────
fprintf('\n[Stage 1] Building Single Particle Model...\n');
spm = buildSPM(battParams);

%% ── Run strategies ────────────────────────────────────────────────────────
results = struct();
strategies = resolveStrategies(cfg.strategy);

for s = 1:numel(strategies)
    strat = strategies{s};
    fprintf('\n[Stage 2] Strategy: %s\n', upper(strat));
    try
        switch lower(strat)
            case 'cccv'
                profile = profileCCCV(chrgParams, battParams);
            case 'multistage'
                profile = profileMultiStage(chrgParams, battParams, cfg.stages);
            case 'mpc'
                profile = profileMPC(spm, battParams, chrgParams, thermParams);
            case 'pseudospectral'
                profile = optimizeCharging(spm, battParams, chrgParams, optParams);
            otherwise
                warning('Unknown strategy: %s', strat); continue;
        end

        tic;
        out = runSPM(spm, profile, battParams, cfg.thermal, thermParams);
        out.runtime = toc;
        out.profile = profile;

        if cfg.degrade
            out.degradation = capacityFadeModel(out, battParams, cfg.nCycles);
        end

        out.metrics = computeChargingMetrics(out, battParams);
        results.(strat) = out;
        printMetrics(strat, out.metrics);

    catch ME
        warning('Strategy %s failed: %s', strat, ME.message);
    end
end

%% ── Output ───────────────────────────────────────────────────────────────
fprintf('\n[Stage 3] Saving results...\n');
if ~isempty(fieldnames(results))
    plotComparison(results, chrgParams, cfg.outputDir);
    saveResultsCSV(results, fullfile(cfg.outputDir, 'metrics', 'performance_summary.csv'));
end
fprintf('Done. Results: %s\n', cfg.outputDir);
end

function strats = resolveStrategies(s)
    if strcmpi(s,'all')
        strats = {'cccv','multistage','mpc','pseudospectral'};
    else
        strats = {lower(s)};
    end
end

function printMetrics(strat, m)
    fprintf('  %-18s | Time: %5.1f min | SOC: %.1f%% | Tmax: %.1f°C | Eff: %.1f%%\n', ...
        upper(strat), m.chargingTime_min, m.finalSOC*100, m.maxTemp_C, m.coulombicEfficiency*100);
end
