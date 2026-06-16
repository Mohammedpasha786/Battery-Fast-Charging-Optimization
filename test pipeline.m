addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')));

fprintf('=================================================\n');
fprintf('  Battery Fast Charging — Unit Tests\n');
fprintf('=================================================\n\n');

nPass = 0; nFail = 0;

%% ── Load config ───────────────────────────────────────────────────────────
battParams  = loadConfig('../configs/battery_params.yaml');
chrgParams  = loadConfig('../configs/charging_params.yaml');
thermParams = loadConfig('../configs/thermal_params.yaml');
optParams   = loadConfig('../configs/optimization_params.yaml');

%% ── Test 1: buildSPM ─────────────────────────────────────────────────────
fprintf('[Test 1] buildSPM\n');
spm = buildSPM(battParams);
assertOK('SPM has .Nr field',       isfield(spm, 'Nr'));
assertOK('SPM has .x0 field',       isfield(spm, 'x0'));
assertOK('x0 length = 2*Nr',        numel(spm.x0) == 2*spm.Nr);
assertOK('OCV positive is function', isa(spm.ocvPos, 'function_handle'));
assertEq('Nr = configured value',    spm.Nr, battParams.spm.Nr_nodes);

%% ── Test 2: spmDynamics ─────────────────────────────────────────────────
fprintf('[Test 2] spmDynamics\n');
dxdt = spmDynamics(0, spm.x0, 1.5, spm);   % 1.5A charging current
assertOK('dxdt same size as x0',    numel(dxdt) == numel(spm.x0));
assertOK('dxdt is finite',          all(isfinite(dxdt)));
assertOK('dxdt near zero at rest',  max(abs(spmDynamics(0, spm.x0, 0, spm))) < 1e-6);

%% ── Test 3: profileCCCV ─────────────────────────────────────────────────
fprintf('[Test 3] profileCCCV\n');
profile_cccv = profileCCCV(chrgParams, battParams);
assertOK('CC-CV has .time',    isfield(profile_cccv, 'time'));
assertOK('CC-CV has .current', isfield(profile_cccv, 'current'));
assertOK('Current >= 0',       all(profile_cccv.current >= 0));
assertOK('Time starts at 0',   profile_cccv.time(1) == 0);
assertOK('Max current <= I_max', max(profile_cccv.current) <= battParams.limits.current_max_A + 1e-6);

%% ── Test 4: profileMultiStage ────────────────────────────────────────────
fprintf('[Test 4] profileMultiStage\n');
profile_ms = profileMultiStage(chrgParams, battParams, 4);
assertOK('Multi-stage has .type = multistage', strcmp(profile_ms.type, 'multistage'));
assertOK('Multi-stage current >= 0', all(profile_ms.current >= 0));
assertEq('Multi-stage nStages', profile_ms.nStages, 4);

%% ── Test 5: runSPM (short simulation) ────────────────────────────────────
fprintf('[Test 5] runSPM (5-minute simulation)\n');
short_profile.time    = (0:1:300)';   % 5 minutes at 1s
short_profile.current = 3.0 * ones(301, 1);  % 1C = 3A
try
    out = runSPM(spm, short_profile, battParams, false, []);
    assertOK('runSPM returns .soc',     isfield(out, 'soc'));
    assertOK('runSPM returns .voltage', isfield(out, 'voltage'));
    assertOK('SOC increased',           out.soc(end) > out.soc(1));
    assertOK('Voltage in valid range',  all(out.voltage >= battParams.limits.voltage_min_V - 0.5 & ...
                                           out.voltage <= battParams.limits.voltage_max_V + 0.1));
    assertOK('No NaN in voltage',       all(isfinite(out.voltage)));
catch ME
    recordFail(sprintf('runSPM failed: %s', ME.message));
end

%% ── Test 6: computeChargingMetrics ───────────────────────────────────────
fprintf('[Test 6] computeChargingMetrics\n');
if exist('out','var')
    metrics = computeChargingMetrics(out, battParams);
    assertOK('Metrics has chargingTime_min',    isfield(metrics, 'chargingTime_min'));
    assertOK('Metrics has finalSOC',            isfield(metrics, 'finalSOC'));
    assertOK('finalSOC in [0,1]',              metrics.finalSOC >= 0 && metrics.finalSOC <= 1);
    assertOK('coulombicEfficiency in [0,1]',   metrics.coulombicEfficiency >= 0 && metrics.coulombicEfficiency <= 1.01);
    assertOK('maxTemp_C > ambient (25°C)',      metrics.maxTemp_C >= 25 - 0.1);
end

%% ── Test 7: thermalModel ─────────────────────────────────────────────────
fprintf('[Test 7] thermalModel\n');
T0 = 298.15;
[dTcore, dTsurf] = thermalModel(T0, T0, 3.0, spm, thermParams);
assertOK('dTcore is finite',  isfinite(dTcore));
assertOK('dTsurf is finite',  isfinite(dTsurf));
assertOK('dTcore > 0 when charging', dTcore > 0);

%% ── Test 8: capacityFadeModel ────────────────────────────────────────────
fprintf('[Test 8] capacityFadeModel\n');
if exist('out', 'var')
    deg = capacityFadeModel(out, battParams, 200);
    assertOK('Degradation has .soh',        isfield(deg, 'soh'));
    assertOK('SOH starts near 100%',        deg.soh(1) > 98);
    assertOK('SOH decreases over cycles',   deg.soh(end) < deg.soh(1));
    assertOK('Capacity retention in [0,1]', all(deg.capacity_retention >= 0 & deg.capacity_retention <= 1));
end

%% ── Summary ──────────────────────────────────────────────────────────────
fprintf('\n=================================================\n');
fprintf('  Results: %d passed | %d failed\n', nPass, nFail);
fprintf('=================================================\n');
if nFail == 0
    fprintf('  All tests passed.\n');
else
    fprintf('  %d test(s) failed — review output above.\n', nFail);
end


%% ── Helpers ──────────────────────────────────────────────────────────────
function assertOK(label, cond)
    if cond
        fprintf('  PASS: %s\n', label);
        nPass = nPass + 1;
    else
        fprintf('  FAIL: %s\n', label);
        nFail = nFail + 1;
    end
end

function assertEq(label, actual, expected, tol)
    if nargin < 4, tol = 0; end
    if abs(actual - expected) <= tol
        fprintf('  PASS: %s\n', label);
        nPass = nPass + 1;
    else
        fprintf('  FAIL: %s (got %g, expected %g)\n', label, actual, expected);
        nFail = nFail + 1;
    end
end

function recordFail(msg)
    fprintf('  FAIL: %s\n', msg);
    nFail = nFail + 1;
end
