# Multi-UAV cooperative trajectory optimization

Research materials for **Feasibility Recovery for Fixed-Horizon Multi-UAV Cooperative Flight Trajectory Optimization in High-Conflict Regions**, Electronics major revision.

## Current version

- New runs: **3 s hard-QP entry**, followed by relaxed recovery when needed.
- Archived main, scaling, winding and external-comparison runs retain their **1 s entry**. They have not been relabeled or recomputed as 3 s runs.
- Every actual QP uses **OSQP**. Nonlinear ASCO and direct-NLP comparisons use **Ipopt/ma57**.
- The complete 1/3/5 s entry ablation has 30 attempts on ten fixed tasks with common references and a 30 s nominal total budget. All outcomes are retained.
- MuJoCo tracking is a **software closed-loop rigid-body simulation**.

## Download the complete materials

Use the [versioned release](https://github.com/libai1943/uav_liom/releases/tag/revision-2026-10-31-ma57). GitHub's automatic source ZIP contains this repository tree; the raw data are separate release assets:

| Asset | Contents |
|---|---|
| `UAV_Revision_Data_20261030.zip` | Complete earlier main, physical, scaling, sensitivity, initialization, acceptance, winding, solver-audit and tracking records (about 1.14 GiB) |
| `UAV_External_Data_20261031.zip` | All 76 historical external-comparison attempts, including development/MUMPS records and the selected OSQP comparisons |
| `UAV_MA57_Entry_Data_20261031.zip` | All 20 ma57 reruns, all 30 entry-budget attempts, original logs, self-test, audits and recommended-entry smoke test |
| `UAV_Revision_Code_MA57_20261031.zip` | Complete source and dependencies/instructions, including frozen versions |
| `Electronics_Revision_LaTeX_MA57_20261031.zip` | Clean/marked/reply LaTeX, figures, PDFs and submitted baseline for the redline |
| Three standalone PDFs | Clean manuscript, blue/red marked manuscript, and response to 33 reviewer comments |

Extract code and all three data ZIPs into the **same root**. Paths inside data archives already begin with `results/`. SHA-256 checksums and per-file manifests accompany the release. Failed and late attempts remain in the records. Recommended configuration selection is supported by the entry-budget table; no universal runtime or success guarantee is inferred.

## One-click example

The tested environment was Windows, MATLAB R2021b and Python. Install `requirements.txt` in a Python environment and set `UAV_PYTHON` to its executable. Run from the repository root:

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:UAV_PYTHON = (Resolve-Path '.venv/Scripts/python.exe').Path
matlab -batch "RunMe"
```

Root `RunMe.m` loads `RecommendedConfig.m` (3 s). The frozen `code/RevisionConfig.m` keeps 1 s for historical reproduction. The example saves all settings, numerical results, validation and plots under `results/recommended_3s/`. Flight time and planning time are printed separately. Use **one planning MATLAB process at a time**; the local OSQP worker uses port 19277.

## Reproduce the new experiments

For nonlinear comparisons install the CasADi 3.6.1 MATLAB distribution with an Ipopt build that can load a licensed HSL **ma57** library. The study scripts use `C:/casadi`; adjust that local path for your installation. HSL and MATLAB binaries are not included.

```matlab
addpath('comparisons_ma57_20261031');
Ma57Selftest;
clear revision.osqpSolve
Ma57Study('formal');
```

The self-test checks analytical objective agreement and actual solver routing. The nonlinear implementation explicitly requests ma57; it does not silently fall back to MUMPS. The study loads the saved common scenes/references from the data archives. Existing completed records are resumed. Use a separate clean copy if recomputing, preserving the distributed records.

```matlab
addpath('studies_entry_budget_20261031'); EntryBudgetStudy;
```

The entry study rotates 1/3/5 s order and changes only the entry allowance. To regenerate its tables and verify shared inputs:

```powershell
python tools/analyze_ma57_revision.py
```

Historical `comparisons_20261031/` implementations and MUMPS records are retained for provenance. They are **not** the current nonlinear baseline. `code/RunMajorRevision.m` reproduces the frozen broad suite; `RunWindingExample.m` reproduces the archived winding comparison. `simulation/` contains the full MuJoCo model and controller. `tools/analyze_revision.py`, `tools/winding_evidence.py` and the simulation scripts generate the research figures from saved records.

## Paper and review response

The current sources are in `paper/revision_ma57_20261031/`; PDFs are also under `manuscripts/`. Both manuscript versions have **39 references with identical numbering**. The abstract explains the two recovery layers; detailed computations and paired outcomes are in the body. Compile `clean/manuscript.tex` first, run `build_marked.py`, then compile `marked/manuscript.tex` and `response/main.tex`. The marked generator uses `paper/revision_blue/` as its submitted-source baseline.

`README_PRIOR_CODE_DATA.txt` and older README files preserve historical instructions; this README describes the current entry points and solver policy. See `NOTICE.txt` for dependency and license notices.
