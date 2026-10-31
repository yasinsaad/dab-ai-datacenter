# DAB Converter Design and Optimization

MATLAB/Simulink code for the paper *Design and Optimization of High-Power Dual Active Bridge Converter for AI Data Center Applications* (TENCON 2026), by Yasin Hasan Saad, Mohammad Saadman Saquib, and Sahib Rahman Khan, Department of EEE, Islamic University of Technology.

The code sweeps the switching frequency of an 800 V → 48 V, 25 kW dual active bridge (DAB) converter, computes an analytical loss breakdown and magnetic volume at each frequency, and compares two device pairs:

| Pair | HV bridge (800 V) | LV bridge (48 V) |
|---|---|---|
| SiC-Si | Infineon AIMBG120R030M1 (1200 V SiC) | Vishay SQJQ160E (60 V Si) |
| SiC-GaN | Infineon AIMBG120R030M1 (1200 V SiC) | 100 V eGaN FET, 6 in parallel |

Topology: [`docs/DAB_topology.pdf`](docs/DAB_topology.pdf).

## Requirements

- MATLAB and Simulink R2022b to R2025b. The models were saved in R2022b, and they use the Specialized Power Systems library, which MathWorks removed in R2026a.
- Simscape Electrical (provides that library)

## Quick start

From any folder in MATLAB:

```matlab
run('path/to/dab_codes/main/run_frequency_sweep.m')
```

The `run_*` and `plot_*` scripts in `main/` add the repo folders to the path themselves. If you run single sections (Ctrl+Enter) instead of the whole file, run `setup_paths` once from the repo root first.

## Reproducing the paper figures

All paper figures can be regenerated from the saved data in `results/data/`, without re-simulating. Run `setup_paths` once from the repo root, then:

| Paper figure | Command | Saved copy in `results/figures/paper/` |
|---|---|---|
| Fig. 1, topology | — | `docs/DAB_topology.pdf` |
| Figs. 2, 3, 5, 6 | `plot_comparison` | `fig2_…`, `fig3_…`, `fig5_…`, `fig6_…` |
| Fig. 4(a) | `load results/data/SiC-GaN_sweep_40-250kHz.mat`, then `plot_sweep_results` | `fig4a_loss_breakdown_SiC-GaN.pdf` |
| Fig. 4(b) | `load results/data/SiC-Si_sweep_40-150kHz.mat`, then `plot_sweep_results` | `fig4b_loss_breakdown_SiC-Si.pdf` |
| Fig. 7 | `plot_steady_state_waveforms` (writes the PDF itself, replacing the saved copy) | `fig7_steady_state_SiC-GaN_140kHz.pdf` |

To regenerate the Fig. 7 data itself (needs Simulink), run `run_steady_state_waveforms`. It simulates `DAB_waveform_model` at 140 kHz, saves the last 30 µs to `results/data/SiC_1200V-GaN_140kHz_steady_state.mat` (the paper's file is not overwritten), and prints the difference from the paper's data.

`plot_comparison`, `plot_pareto_front` and `plot_steady_state_waveforms` load their data from `results/data/` unless the expected variables already exist in the workspace. `savefigs` exports all open figures to `results/figures/` (or `savefigs(folder)`), named after their titles.

`plot_pareto_front` draws the Pareto front lines for both device pairs. It is not used in the TENCON paper.

## Workflow

```
run_frequency_sweep.m ──► results (struct) ──► save to results/data/*.mat
        │                                        │
        │ per frequency:                         ├─► plot_sweep_results.m (one pair)
        │  1. size Lk for 1.3 × 25 kW            ├─► plot_comparison.m (both pairs)
        │  2. simulate (Simulink, closed loop)   └─► plot_pareto_front.m
        │  3. steady-state currents (last 20 %)
        │  4. loss models + ZVS check
        │  5. magnetic volume
        ▼
results/current_plots_<HV>-<LV>.pdf (output current per frequency, to check steady state)

run_steady_state_waveforms.m ──► results/data/<HV>-<LV>_<f>kHz_steady_state.mat ──► plot_steady_state_waveforms.m

Both run_* scripts take their converter parameters from config/dab_parameters.m.
```

The default sweep is 40–250 kHz in 10 kHz steps, as in the paper (the paper's SiC-Si data covers 40–150 kHz). Each point simulates 0.3 s. If a simulation crashes, the sweep prints the frequency, skips it, and removes it from `results` at the end.

To produce a sweep for a different device pair, change these lines at the top of `main/run_frequency_sweep.m` (or `run_steady_state_waveforms.m`):

```matlab
device_hv = 'SiC_1200V';
device_lv = 'GaN';        % or 'Si_60V'
```

Then save the workspace `results` struct to `results/data/`. Converter parameters (power, passives, transformer) are in `config/dab_parameters.m`.

After each sweep, open `results/current_plots_<HV>-<LV>.pdf` (e.g. `current_plots_SiC_1200V-GaN.pdf`) and check that the output current settles on the target (horizontal dashed line) before the steady-state window starts (vertical dashed line) on every page. Each device pair has its own file; rerunning a pair replaces only that file.

## Repository layout

```
dab_codes/
├── setup_paths.m                       adds main/, config/, models/, functions/, utils/ to the path
├── config/
│   └── dab_parameters.m               converter parameters shared by both run_* scripts
├── main/                              scripts you run
│   ├── run_frequency_sweep.m          frequency sweep: simulation + loss analysis
│   ├── run_steady_state_waveforms.m   one operating point, saves waveforms (Fig. 7 data)
│   ├── plot_sweep_results.m           plots for one device pair (called by the sweep)
│   ├── plot_comparison.m              SiC-Si vs SiC-GaN plots
│   ├── plot_pareto_front.m            volume-efficiency Pareto fronts
│   └── plot_steady_state_waveforms.m  3x2 steady-state waveform figure (Fig. 7)
├── models/
│   ├── DAB_sweep_model.slx            DAB circuit; logs one HV and one LV switch current and the DC currents
│   └── DAB_waveform_model.slx         same circuit plus 3 voltage probes and an
│                                      inductor-current probe
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
│   ├── data/                     saved sweep results and steady-state waveforms (.mat)
│   └── figures/paper/            figures used in the paper, named by figure number
└── docs/
    ├── DAB_AI_Data_Center_paper.pdf   paper (pre-publication version)
    └── DAB_topology.pdf               circuit schematic
```

## Data files

In `results/data/`:

| File | Contents |
|---|---|
| `SiC-Si_sweep_40-150kHz.mat` | `results`, `power` from the SiC-Si sweep, 40–150 kHz |
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
| `I_rms_h`, `I_rms_l` | A | RMS current of one HV / LV switch (`Mosfet7` / `Mosfet4` in the model) |
| `I_sw_ss_h`, `I_sw_ss_l` | A | HV / LV switch peak current, used as the switching current |
| `t_req_h`, `t_req_l` | s | time the switch node needs to complete a ZVS transition |
| `Volume_L`, `Volume_T`, `Volume_Total` | m³ | inductor, transformer, total magnetic volume |

## Loss models

| Loss | Model | Function |
|---|---|---|
| Conduction | 4 · I_rms,switch² · R_on per bridge | `run_frequency_sweep.m` |
| Cable | 2 · I_rms,DC² · R_cable per side | `run_frequency_sweep.m` |
| Gate drive | 4 · Q_g · V_drive · f_sw per bridge | `run_frequency_sweep.m` |
| Inductor DC | I_rms,in² · R_dc (DC input current), R_dc from ETD44 geometry | `get_inductor_params.m` |
| Switching | Analytical turn-on / turn-off / recovery model (Energies 2022, 15, 8262). Turn-on and recovery loss are zero when ZVS holds (enough inductor energy **and** transition finishes within the dead time) | `calculate_switching_zvs.m` |
| Body diode | V_f · I · (dead time − transition time) · 4 · f_sw, ZVS cases only | `calculate_body_diode_losses.m` |
| Transformer | Steinmetz core loss (SIFERRIT N97, E 140/68/40 core) with square-wave factor, plus I²·R_ac copper loss with the DC input/output currents (R_ac from the Krismer DAB model) | `calculate_transformer_losses.m` |

## Notes

- The plot scripts call `set(groot, ...)`, which changes plot defaults for the rest of the MATLAB session.
