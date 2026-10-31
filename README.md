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

## Reproducing the paper figures

All paper figures can be regenerated from the saved data in `results/data/`, without re-simulating. Run `setup_paths` once from the repo root, then:

| Paper figure | Command | Saved copy in `results/figures/paper/` |
|---|---|---|
| Fig. 1, topology | — | `docs/DAB_topology.pdf` |
| Figs. 2, 3, 5, 6 | `plot_comparison` | `fig2_…`, `fig3_…`, `fig5_…`, `fig6_…` |
| Fig. 4(a) | `load results/data/SiC-GaN_sweep_40-250kHz.mat`, then `plot_sweep_results` | `fig4a_loss_breakdown_SiC-GaN.pdf` |
| Fig. 4(b) | `load results/data/SiC-Si_sweep.mat`, then `plot_sweep_results` | `fig4b_loss_breakdown_SiC-Si.pdf` |
| Fig. 7 | `plot_steady_state` (writes the PDF itself) | `fig7_steady_state_SiC-GaN_140kHz.pdf` |

`plot_comparison`, `plot_pareto_front` and `plot_steady_state` load their data from `results/data/` unless the expected variables already exist in the workspace. `savefigs` exports all open figures to `results/figures/` (or `savefigs(folder)`), named after their titles.

`plot_pareto_front` draws the Pareto front lines for both device pairs. It is not used in the TENCON paper.

## Workflow

```
DAB_freq_sweep.m ──► results (struct) ──► save to results/data/*.mat
        │                                        │
        │ per frequency:                         ├─► plot_sweep_results.m (one pair)
        │  1. size Lk for 1.3 × 25 kW            ├─► plot_comparison.m (both pairs)
        │  2. simulate (Simulink, closed loop)   └─► plot_pareto_front.m
        │  3. steady-state currents (last 20 %)
        │  4. loss models + ZVS check
        │  5. magnetic volume
        ▼
results/current_plots_<HV>-<LV>.pdf (output current per frequency, to check steady state)
```

The default sweep is 40–250 kHz in 10 kHz steps, as in the paper (the paper's SiC-Si data covers 40–150 kHz). Each point simulates 0.3 s. If a simulation crashes, the sweep prints the frequency, skips it, and removes it from `results` at the end.

To produce a sweep for a different device pair, change these lines at the top of `main/DAB_freq_sweep.m`:

```matlab
device_hv = 'SiC_1200V';
device_lv = 'GaN';        % or 'Si_60V'
```

Then save the workspace `results` struct to `results/data/`.

After each sweep, open `results/current_plots_<HV>-<LV>.pdf` (e.g. `current_plots_SiC_1200V-GaN.pdf`) and check that the output current settles before the steady-state window (second dashed line) on every page. Each device pair has its own file; rerunning a pair replaces only that file.

## Repository layout

```
dab_codes/
├── setup_paths.m                 adds main/, models/, functions/, utils/ to the path
├── main/                         scripts you run
│   ├── DAB_freq_sweep.m          frequency sweep: simulation + loss analysis
│   ├── plot_sweep_results.m      plots for one device pair (called by the sweep)
│   ├── plot_comparison.m         SiC-Si vs SiC-GaN plots
│   ├── plot_pareto_front.m       volume-efficiency Pareto fronts
│   └── plot_steady_state.m       3x2 steady-state waveform figure
├── models/
│   ├── DAB_freq_sweep_sim.slx    DAB model used by the sweep
│   └── DAB_freq_sweep_sim_ver.slx  same circuit with 4 extra voltage/current
│                                   probes; used for the Fig. 7 waveforms
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
│   └── figures/paper/            figures used in the paper, named by figure number
└── docs/
    ├── DAB_AI_Data_Center_paper.pdf   paper (pre-publication version)
    └── DAB_topology.pdf               circuit schematic
```

## Data files

In `results/data/`:

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

- The plot scripts call `set(groot, ...)`, which changes plot defaults for the rest of the MATLAB session.
