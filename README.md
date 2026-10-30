# Fixed-horizon multi-UAV cooperative trajectory optimization

This repository contains the implementation and experimental design for the Electronics manuscript. A 3 s hard-QP entry is followed, when needed, by penalty-based corridor recovery and acceptance-driven refinement. All QPs use OSQP. Nonlinear ASCO and direct-NLP comparisons use Ipopt/ma57.

## Run an example

Install the Python packages in `requirements.txt`, set `UAV_PYTHON` to that Python executable, and run `matlab -batch "RunMe"` from this directory. The example saves its configuration, returned motion, checks and figures. Flight duration and computation time are reported separately.

## Reproduce the experiments

Run `matlab -batch "RunExperiments"`. The fixed design comprises crossing, passage, obstacle-field and winding tasks, team/grid scaling, parameter and mechanism ablations, matched nonlinear/SCP comparisons, and the 1/3/5 s entry-budget study. Attempts are saved individually and completed records can be resumed. All outcomes are retained. Run one solver process at a time.

The tested platform uses MATLAB R2021b and Python. For nonlinear comparisons, install CasADi 3.6.1 and an Ipopt-compatible licensed HSL ma57 library; adjust `C:/casadi` in the entry scripts for the local installation. The OSQP service uses localhost port 19278. `simulation/` contains the MuJoCo rigid-body model and tracking controller. Tracking runs entirely in software.

The experiment dataset is being regenerated under a controlled low-load schedule. The synchronized dataset and manuscript materials will be attached when verification is complete.
