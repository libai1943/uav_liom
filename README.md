# Fixed-horizon multi-UAV cooperative trajectory optimization

This repository contains the implementation and experimental design for the Electronics manuscript. A 3 s hard-QP entry is followed, when needed, by penalty-based corridor recovery and acceptance-driven refinement. All QPs use OSQP. Nonlinear ASCO and direct-NLP comparisons use Ipopt/ma57.

## Run an example

Install the Python packages in `requirements.txt`, set `UAV_PYTHON` to that Python executable, and run `matlab -batch "RunMe"` from this directory. The example saves its configuration, returned motion, checks and figures. Flight duration and computation time are reported separately.

## Reproduce the experiments

Run `matlab -batch "RunExperiments"`. The fixed design comprises crossing, passage, obstacle-field and winding tasks, team/grid scaling, parameter and mechanism ablations, matched nonlinear/SCP comparisons, and the 1/3/5 s entry-budget study. Attempts are saved individually and completed records can be resumed. All outcomes are retained. Run one solver process at a time.

The tested platform uses MATLAB R2021b and Python. For nonlinear comparisons, install CasADi 3.6.1 and an Ipopt-compatible licensed HSL ma57 library; adjust `C:/casadi` in the entry scripts for the local installation. The OSQP service uses localhost port 19278. `simulation/` contains the MuJoCo rigid-body model and tracking controller. Tracking runs entirely in software.

## Data and analysis

Download `UAV_Experiment_Source.zip` and every `UAV_Experiment_Data_Part*.zip` from the [experiment release](https://github.com/libai1943/uav_liom/releases/tag/electronics-experiments-2026-10-31). Extract all archives into one directory. The release includes all attempted outcomes, including unsuccessful and late attempts, raw per-attempt records, scenario definitions, timing records, tracking histories, and generated figures/tables. `EXPERIMENT_MANIFEST.json` and `SHA256SUMS.txt` identify the files and checksums.

After `RunExperiments` finishes, run the following commands serially with the configured Python environment:

```text
python simulation/run_tracking.py
python tools/winding_mechanism_audit.py
python tools/winding_evidence.py
python tools/analyze_revision.py
python tools/analyze_comparisons.py
```

The nominal hard-entry allowance is 3 s. The 1/3/5 s settings are explicit ablation arms. Physical flight horizons are fixed independently of the 30 s nominal computation budget. Per-attempt flags distinguish accepted motions within budget, late accepted motions, and attempts without an accepted motion. The experiments include 1,412 planning, numerical-audit, and comparison records plus 70 software tracking runs; repeated executions are identified separately from distinct physical tasks.

HSL binaries and third-party solver distributions are not redistributed. Install the required licensed ma57 library locally before running the nonlinear comparisons. The source and data archives contain the implementation and observations for this study.
