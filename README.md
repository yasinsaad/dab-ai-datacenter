# DAB Converter Design and Optimization

MATLAB/Simulink code for the paper *Design and Optimization of High-Power Dual Active Bridge Converter for AI Data Center Applications* (TENCON 2026), by Yasin Hasan Saad, Mohammad Saadman Saquib, and Sahib Rahman Khan, Department of EEE, Islamic University of Technology.

The code sweeps the switching frequency of an 800 V → 48 V, 25 kW dual active bridge (DAB) converter, computes an analytical loss breakdown and magnetic volume at each frequency, and compares two device pairs:

| Pair | HV bridge (800 V) | LV bridge (48 V) |
|---|---|---|
| SiC-Si | Infineon AIMBG120R030M1 (1200 V SiC) | Vishay SQJQ160E (60 V Si) |
| SiC-GaN | Infineon AIMBG120R030M1 (1200 V SiC) | 100 V eGaN FET, 6 in parallel |

Topology: [`docs/DAB_topology.pdf`](docs/DAB_topology.pdf).

## Requirements

- MATLAB R2021a or later (uses `exportgraphics`, `tiledlayout`, `xline`/`yline`)
- Simulink and Simscape Electrical (the model uses the Specialized Power Systems library)

## Quick start

From any folder in MATLAB:

```matlab
run('path/to/dab_codes/main/DAB_freq_sweep.m')
```

Each script in `main/` adds the repo folders to the path on its own. If you run single sections (Ctrl+Enter) instead of the whole file, run `setup_paths` once from the repo root first.

To plot the saved results without re-simulating:

```matlab
run main/plot_comparison.m      % SiC-Si vs SiC-GaN, 5 figures
run main/plot_pareto_front.m    % volume vs efficiency, both pairs
run main/plot_steady_state.m    % 140 kHz SiC-GaN waveforms
savefigs                        % export open figures to results/figures/SiC-GaN/
savefigs('results/figures/merged')   % or any other folder
```

The plot scripts load data from `results/data/` unless the expected variables already exist in the workspace.

## Workflow

```
DAB_freq_sweep.m ──► results (struct) ──► save to results/data/*.mat
        │                                        │
        │ per frequency:                         ├─► plot_comparison.m
        │  1. size Lk for 1.3 × 25 kW            ├─► plot_pareto_front.m
        │  2. simulate (Simulink, closed loop)   └─► merge_results.m (join split runs)
        │  3. steady-state currents (last 20 %)
        │  4. loss models + ZVS check
        │  5. magnetic volume
        ▼
results/current_plots.pdf (output current per frequency)
```

To produce a sweep for a different device pair, change this line in `main/DAB_freq_sweep.m`:

```matlab
[semi.hv, semi.lv] = get_semiconductor_params('SiC_1200V', 'GaN');   % or 'Si_60V'
```

Then save the workspace `results` struct to `results/data/`.

## Repository layout

```
dab_codes/
├── setup_paths.m                 adds models/, functions/, utils/ to the path
├── main/                         scripts you run
│   ├── DAB_freq_sweep.m          frequency sweep: simulation + loss analysis
│   ├── plot_comparison.m         SiC-Si vs SiC-GaN plots
│   ├── plot_pareto_front.m       volume-efficiency Pareto fronts
│   ├── plot_steady_state.m       3x2 steady-state waveform figure
│   └── merge_results.m           join results from split sweep runs
├── models/
│   ├── DAB_freq_sweep_sim.slx    DAB model used by the sweep
│   └── DAB_freq_sweep_sim_ver.slx  same model with extra voltage and
│                                   inductor-current logging
├── functions/
│   ├── devices/
│   │   ├── get_semiconductor_params.m      datasheet parameters per device
│   │   └── estimate_dead_time_from_device.m  dead time from gate charge
│   ├── losses/
│   │   ├── calculate_switching_zvs.m       switching loss + ZVS check
│   │   ├── calculate_body_diode_losses.m   dead-time reverse conduction
│   │   └── calculate_transformer_losses.m  Steinmetz core + copper loss
│   └── magnetics/
│       ├── get_inductor_params.m           series inductance Lk, Rdc
│       └── dab_size_calc.m                 inductor + transformer volume
├── utils/
│   └── savefigs.m                export open figures as vector PDFs
├── results/
│   ├── data/                     saved sweep results (.mat)
│   └── figures/                  exported plots (SiC-Si/, SiC-GaN/, merged/, steady_state/)
└── docs/
    ├── DAB_AI_Data_Center_paper.pdf   paper (pre-publication version)
    └── DAB_topology.pdf               circuit schematic
```

## Data files

| File | Contents |
|---|---|
| `SiC-Si_sweep.mat` | `results`, `power` from the SiC-Si sweep |
| `SiC-GaN_sweep_40-250kHz.mat` | `results` from the SiC-GaN sweep, 40–250 kHz |
| `SiC-GaN_140kHz_steady_state.mat` | `t_80`, `v_in_80`, `i_in_80`, `v_l_80`, `i_l_80`, `v_out_80`, `i_out_80` |

Main fields of `results` (one entry per frequency):

| Field | Unit | Meaning |
|---|---|---|
| `freq` | Hz | switching frequency |
| `eff_analytical` | % | efficiency from simulated output power and analytical losses |
| `loss_total` | W | sum of all loss components |
| `breakdown` | W | 7×N: conduction, cable, gate drive, switching, body diode, transformer, inductor DC |
| `coreLoss`, `copperLoss`, `totalTransformerLoss` | W | transformer losses |
| `Lk` | H | series inductance |
| `I_rms_h`, `I_rms_l` | A | HV / LV bridge RMS current |
| `I_sw_ss_h`, `I_sw_ss_l` | A | HV / LV peak current (used as switching current) |
| `t_req_h`, `t_req_l` | s | time the switch node needs to complete a ZVS transition |
| `Volume_L`, `Volume_T`, `Volume_Total` | m³ | inductor, transformer, total magnetic volume |

## Loss models

| Loss | Model | Function |
|---|---|---|
| Conduction | 4 · I_rms² · R_on per bridge | `DAB_freq_sweep.m` |
| Cable | 2 · I_rms² · R_cable per side | `DAB_freq_sweep.m` |
| Gate drive | 4 · Q_g · V_drive · f_sw per bridge | `DAB_freq_sweep.m` |
| Inductor DC | I_rms² · R_dc, R_dc from ETD44 geometry | `get_inductor_params.m` |
| Switching | Analytical turn-on / turn-off / recovery model (Energies 2022, 15, 8262). Turn-on and recovery loss are zero when ZVS holds (enough inductor energy **and** transition finishes within the dead time) | `calculate_switching_zvs.m` |
| Body diode | V_f · I · (dead time − transition time) · 4 · f_sw, ZVS cases only | `calculate_body_diode_losses.m` |
| Transformer | Steinmetz core loss (SIFERRIT N97, E 140/68/40 core) with square-wave factor, plus I²·R_ac copper loss (Krismer DAB model) | `calculate_transformer_losses.m` |

## Notes

- `results/current_plots.pdf` is appended to on every run. Delete it before a new sweep.
- `merge_results.m` assumes 31 merged points (`mask = 1:31`). Edit it for other run splits.
- The plot scripts call `set(groot, ...)`, which changes plot defaults for the rest of the MATLAB session.
