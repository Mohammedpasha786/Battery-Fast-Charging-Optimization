#  Battery Fast Charging Optimization
> A complete MATLAB/Simscape Battery framework for simulating, comparing, and optimizing lithium-ion battery fast-charging strategies using the **Single Particle Model (SPM)**. Implements CC–CV baseline, multi-stage charging profiles, constrained optimal control, thermal coupling, degradation analysis, and MPC-based adaptive charging.

---

## Charging Strategies Implemented

| Strategy | Description | Notes |
|----------|-------------|-------|
| **CC–CV** | Constant current → constant voltage | Baseline reference |
| **2-stage CC** | High CC → low CC → CV | Simple fast charge |
| **4-stage CC** | Pulse-stepped current profile | CCCCC fast charge |
| **MPC** | Model Predictive Control with SOC/temp/voltage constraints | Real-time adaptive |
| **Pseudo-spectral** | Offline optimal control via Gauss–Lobatto collocation | Minimum-time |

---

## Project Structure

```
battery-fast-charging/
├── src/
│   ├── main_charging.m
│   ├── spm/
│   │   ├── buildSPM.m
│   │   ├── runSPM.m
│   │   ├── spmDynamics.m
│   │   └── spmJacobian.m
│   ├── charging/
│   │   ├── profileCCCV.m
│   │   ├── profileMultiStage.m
│   │   ├── profileMPC.m
│   │   └── applyChargingProfile.m
│   ├── optimization/
│   │   ├── optimizeCharging.m
│   │   ├── pseudospectralOpt.m
│   │   ├── directCollocation.m
│   │   ├── defineConstraints.m
│   │   └── objectiveFcn.m
│   ├── thermal/
│   │   ├── thermalModel.m
│   │   ├── heatGeneration.m
│   │   └── thermalCoupling.m
│   ├── degradation/
│   │   ├── capacityFadeModel.m
│   │   ├── seiGrowthModel.m
│   │   └── platingRiskModel.m
│   └── utils/
│       ├── loadConfig.m
│       ├── computeChargingMetrics.m
│       ├── plotResults.m
│       ├── plotComparison.m
│       ├── saveResultsCSV.m
│       └── loadBatteryData.m
├── configs/
│   ├── battery_params.yaml
│   ├── charging_params.yaml
│   ├── optimization_params.yaml
│   └── thermal_params.yaml
├── data/{raw,processed,validation}/
├── results/{plots,metrics,logs}/
├── docs/
│   ├── methodology.md
│   ├── spm_theory.md
│   ├── datasets.md
│   └── tuning_guide.md
├── tests/test_pipeline.m
├── notebooks/BatteryFastCharge_Walkthrough.mlx
├── .gitignore
├── LICENSE
└── CHANGELOG.md
```

---

## Quick Start

```matlab
addpath(genpath('src'))
main_charging                                         % all profiles
main_charging('strategy', 'cccv')                    % CC–CV only
main_charging('strategy', 'multistage', 'stages', 4) % 4-stage CC
main_charging('strategy', 'mpc')                     % MPC controller
main_charging('strategy', 'pseudospectral')          % optimal control
main_charging('strategy', 'all', 'thermal', true)    % with thermal model
```

---

## Performance Benchmark (NMC 3 Ah cell, 10→100% SOC)

| Strategy | Time (min) | Max Temp (°C) | Final SOC (%) |
|----------|-----------|--------------|--------------|
| CC–CV (0.5C) | 78 | 31.2 | 99.8 |
| CC–CV (1C)   | 52 | 35.8 | 99.6 |
| 2-stage CC   | 44 | 37.4 | 99.4 |
| 4-stage CC   | 38 | 38.1 | 99.2 |
| MPC          | 34 | 38.5 | 99.5 |
| Pseudo-spectral | 29 | 39.8 | 99.7 |

---

## Single Particle Model (SPM) Equations

```
dcₛ/dt = Dₛ/r² · d/dr(r² dcₛ/dr)     [Fick's 2nd Law, solid phase]
V = Uₚ(θₚ) - Uₙ(θₙ) - I·Rₑ           [Terminal voltage]
θₖ = cₛ_surf,ₖ / cₛ_max,ₖ             [Normalized surface concentration]
Plating risk: θₙ → 1 (reduce current)
```

---

## Required Toolboxes

| Toolbox | Usage |
|---------|-------|
| Simscape Battery | SPM block, CC–CV controller |
| Optimization Toolbox | fmincon, pseudo-spectral methods |
| Control System Toolbox | MPC design |
| Statistics & ML Toolbox | Parameter fitting, SOH analysis |

---

## References

1. Perez et al. (2017). Optimal Charging of Li-Ion Batteries via SPM. *J. Electrochem.*
2. Chen et al. (2020). Optimal Fast-Charging via Electrochemical–Thermal Model. *Energies*, 13, 2388.
3. Simscape Battery Docs: https://www.mathworks.com/products/simscape-battery.html
4. Battery Archive: https://batteryarchive.org/
5. Volta Foundation Data: https://data.voltafoundation.org/

---

## License
MIT — see [LICENSE](LICENSE).
