ELECTRONICS MAJOR REVISION: LOCAL REPRODUCTION MATERIALS

This package contains the tested research implementation and its complete saved
outcomes. It is prepared for author-controlled sharing; no public repository or
DOI has been created. The accompanying manuscript distinguishes observed task
acceptance from a guarantee of planning success.

1. Packages
   CODE: MATLAB planning code, Python OSQP service, experiment definitions,
   analysis scripts, and MuJoCo rigid-body/controller simulation.
   DATA: all completed main, physical, horizon, scaling, sensitivity,
   initialization, motion-envelope, acceptance-feedback, targeted-passage,
   solver-audit, and winding-study outcomes, including unsuccessful attempts.
   LATEX: Electronics clean/marked sources and PDFs, reviewer response,
   original source used to generate the redline, and scientific figures.
   Each archive includes a SHA-256 file manifest; archive hashes are separate.

2. Environment
   Tested on Windows with MATLAB R2021b and Python. Exact Python versions are
   recorded in requirements.txt. Set UAV_PYTHON to the Python executable whose
   environment contains these packages. MATLAB is supplied by the user.
   All planning QPs are solved by OSQP. Independent infeasibility diagnostics
   use HiGHS linear programming. CasADi with its HiGHS plugin is optional for
   the MATLAB phase-I audit; the Python winding audit uses SciPy's HiGHS LP.
   No commercial MATLAB/Python installation or external reference-paper PDF
   is bundled. The tested source snapshot and hashes accompany the results.

3. First example (fresh MATLAB batch)
   From the extracted root, install dependencies in a Python virtual environment:
       python -m venv .venv
       .venv\Scripts\python.exe -m pip install -r requirements.txt
   PowerShell:
       $env:UAV_PYTHON = (Resolve-Path '.venv/Scripts/python.exe').Path
       matlab -batch "maxNumCompThreads(1); addpath('code'); cd('code'); RunMe"
   The service starts automatically on localhost port 19277 and stays available
   to this project. Use one planning process at a time. If another extracted
   copy owns the port, close that worker or choose a different osqpPort.
   Worker startup is excluded from measured planning time; setup and data
   exchange within planning are included. The total budget is nominal: a
   stage may finish beyond it. Comparison success additionally requires an
   accepted motion returned within 30 s. Late valid motions remain recorded.

4. Winding recovery example (another fresh MATLAB batch)
       matlab -batch "maxNumCompThreads(1); RunWindingExample"
   This reproduces the selected winding-counterflow case with the same cached
   reference charged to both methods. Flight duration is 24 s. Planning time
   is a separate measured quantity. The root script saves both successes and
   failures and creates plots for accepted motions. Hardware load can affect
   time-limited outcomes; the saved paired repetitions are the reported data.

5. Frozen experiments and analysis
   From code/, RunMajorRevision runs eight predefined suites serially. It resumes
   completed attempts and refuses a mismatched source manifest. To recompute
   from scratch, extract CODE into a separate clean directory without DATA.
   Do not overwrite or edit an existing frozen run. The DATA archive extracts
   into results/ for direct analysis of the reported records.
   tools/TargetedGeometryStudy.m and tools/OsqpNumericalAudit.m run additional
   tests; configure the CasADi path for the optional MATLAB LP diagnostics.
   The paired winding scripts retain exploration, frozen new-seed tests, and
   the physical parameter map as distinct studies. Their local experiment
   settings and sources are included with the raw records.
   After all experiment records are present:
       python simulation/run_tracking.py
       python tools/winding_evidence.py
       python tools/analyze_revision.py
       python tools/finalize_narrative.py
   Tracking uses every accepted main-method motion from repetition 1 and a
   predefined larger-team/winding selection. Both nominal and disturbed
   conditions use the same controller. No hardware flight is claimed.
   Analyzer checks completeness, duplicate keys, acceptance flags, and source
   hashes before producing final manuscript data. Some raw JSON diagnostics
   use Infinity for an inapplicable obstacle distance; the consolidated audit
   uses JSON null for nonfinite values.

6. Data interpretation
   A scene, a repeated timed attempt, an outer round, and a QP call are different
   units. Do not count the three main timing repetitions as independent scenes.
   MAT files retain configuration, reference, candidate/history, motion,
   physical checks, failure reasons, and stage times. Summary CSV files are
   indices, not replacements for those records. Root-level pilot records and
   simulator_checks/ retain development diagnostics; these are separate from
   the frozen formal suites used for manuscript statistics. Full verification checks every
   UAV pair, including pairs omitted by safe screening during optimization.
   Winding search and the physical map are exploratory; the separately frozen
   twelve new layouts are a distinct check. All attempted outcomes are retained.

7. Documents and public sharing
   Compile manuscript.tex in each LaTeX directory with the supplied MDPI class
   and a TeX distribution including algorithm2e and the packages in the source.
   The marked source contains blue additions, red deletions, and framed changed
   displays. Paper figure files are vector PDFs with PNG previews.
   The supplied marked TeX compiles directly. Regenerating the redline uses
   tools/build_marked.py and latexdiff; configure the local Perl/latexdiff
   paths if moving to another computer. The code license is an author decision before public release. This local
   package does not silently select an open-source license or publish anything.
   Refer to the final release manifest for PDF QA status and archive hashes.
