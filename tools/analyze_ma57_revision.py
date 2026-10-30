from pathlib import Path
import csv,json,sys,hashlib
R=Path(__file__).resolve().parents[1];sys.path.insert(0,str(R/'python_packages'))
from scipy.io import loadmat
import numpy as np
P=R/'paper/revision_ma57_20261031';O=P/'clean/data_revision'
A=R/'results/external_20261031_formal';B=R/'results/external_20261031_verified';C=R/'results/external_ma57_20261031_formal';E=R/'results/entry_budget_20261031'
def rows(folder):return list(csv.DictReader((folder/'summary.csv').open(encoding='utf-8-sig')))
assert (C/'completed.json').exists() and (E/'completed.json').exists()
new=rows(C);entry=rows(E);assert len(new)==20 and len(entry)==30
selected=[x for x in rows(A) if x['Method'] in ['adaptive','rsc_iter']]+[x for x in rows(B) if x['Method']=='scp']+new
ids=['C01','C03','C05','C25','C27','C29','W6102','W7202','N15','N20'];methods=['adaptive','rsc_iter','asco','nlp','scp']
lookup={(x['Case'],x['Method']):x for x in selected};assert len(lookup)==50
for item in json.loads((R/'comparisons_ma57_20261031/frozen_sources.json').read_text()):
 assert hashlib.sha256((R/item['path']).read_bytes()).hexdigest()==item['sha256']
audit=[]
def check_result(d):
 result=d['result']
 if result['success']:
  v=result['validation'];assert v['success'] and v['integrationIdentityError']<=1e-9 and v['controlIdentityError']<=1e-9
  assert v['endpointViolation']<=1e-9 and v['nodalEndpointVelocityViolation']<=1e-9
  assert v['minimumPairDistance']>=2*d['c']['radius']+d['c']['clearance']-d['c']['validationTolerance']
  assert v['maxSpeed']<=d['c']['vmax']+d['c']['validationTolerance'] and v['maxAcceleration']<=d['c']['amax']+d['c']['validationTolerance']
 assert bool(result['successWithinBudget'])==(bool(result['success']) and result['planningSeconds']<=d['c']['totalBudget'])
 h=result['history'];return [h] if isinstance(h,dict) else list(h)
for case in ids:
 baseline=None
 for method in methods:
  folder=C if method in ['asco','nlp'] else B if method=='scp' else A
  path=folder/f'{case}_{method}.mat';d=loadmat(path,simplify_cells=True);h=check_result(d)
  if baseline is None:baseline=d
  for key in ['starts','exits','v0','vf','bounds','obstacles']:assert np.array_equal(d['s'][key],baseline['s'][key])
  for key in ['P','V','seconds']:assert np.array_equal(d['result']['reference'][key],baseline['result']['reference'][key])
  for key in ['horizon','intervals','vmax','amax','radius','clearance','motionPolytope','totalBudget','smoothWeight','acceptanceBounds','validationTolerance']:
   assert np.array_equal(d['c'][key],baseline['c'][key]),(case,method,key)
  for x in h:
   if x['info']['backend']=='ipopt':assert x['info']['linearSolver']=='ma57'
   elif method in ['adaptive','rsc_iter','scp']:assert x['info']['backend']=='osqp'
  audit.append(dict(lookup[case,method],source=path.relative_to(R).as_posix(),backends=[x['info']['backend'] for x in h],statuses=[x['info']['status'] for x in h]))
entry_lookup={(x['Case'],int(x['EntryBudget'])):x for x in entry};assert len(entry_lookup)==30
for case in ids:
 baseline=None
 for budget in [1,3,5]:
  d=loadmat(E/f'{case}_entry{budget}.mat',simplify_cells=True);h=check_result(d)
  assert d['c']['fastPathSeconds']==budget and all(x['info']['backend']=='osqp' for x in h)
  if baseline is None:baseline=d
  for key in ['P','V','seconds']:assert np.array_equal(d['result']['reference'][key],baseline['result']['reference'][key])
  for key in d['c']:
   if key!='fastPathSeconds':assert np.array_equal(d['c'][key],baseline['c'][key]),(case,key)
def label(case):return {'W6102':'Winding A','W7202':'Winding B','N15':'15-UAV','N20':'20-UAV'}.get(case,case)
def timecell(row,bold=False):
 x=f'{float(row["Wall"]):.2f}'
 if row['Accepted']=='0':x=r'$\times$\,'+x
 elif row['WithinBudget']=='0':x+=r'$^{\dagger}$'
 return r'\textbf{'+x+'}' if bold else x
lines=[r'\begin{table}[htbp]',r'\begin{adjustwidth}{-\extralength}{0cm}',
 r'\caption{Task-matched planning times in seconds, including recorded initialization. LIOM uses the original 1 s hard entry in this comparison; the nonlinear columns are rerun with Ipopt/ma57. A cross denotes no accepted motion; $\dagger$ denotes an accepted motion returned after the nominal 30 s budget. Each entry is one recorded execution.\label{tab:external}}',
 r'\small\begin{tabularx}{\fulllength}{Ycrrrrr}\toprule',r'Task & $N$ & \textbf{LIOM (1 s)} & Hard RSC & ASCO-3D & Direct NLP & SCP-3D\\\midrule']
for case in ids:
 lines.append(label(case)+' & '+lookup[case,'adaptive']['N']+' & '+' & '.join(timecell(lookup[case,m],m=='adaptive') for m in methods)+r'\\')
lines += [r'\bottomrule\end{tabularx}',r'\end{adjustwidth}\end{table}'];(O/'external_table.tex').write_text('\n'.join(lines)+'\n')
findings=r'''Table~\ref{tab:external} reports the ma57 comparison. LIOM completes C01, C03, C05, and C25 in 1.29--3.14 s. In C27, LIOM returns an accepted motion in 24.35 s, while ASCO, hard RSC, and SCP complete the same task in 8.61, 7.55, and 5.41 s. The ma57 direct-NLP solve also accepts C27, in 27.79 s. These results show how the direct hard path and the recovery path distribute computation across tasks.

Winding A combines three alternating openings with opposing traffic. LIOM and iterative hard RSC return accepted motions in 26.36 and 25.14 s in this comparison. ASCO's candidate motions continue to fail collision checks when its budget is exhausted; SCP reports infeasibility for its initial tangent problem. The hard-RSC result supplements the earlier repetitions in Section~\ref{sec:winding}. The positive phase-I certificate identifies an incompatible initial local problem, and later reconstruction can reach a feasible corridor configuration. In Winding B, LIOM produces a physically accepted motion at 31.92 s; the ma57 baselines and the other hard comparisons return no accepted motion in their recorded attempts. The late LIOM output is marked explicitly in the table.

For the 15-UAV task, LIOM, hard RSC, and SCP complete in 27.49, 29.97, and 19.91 s. Direct NLP returns an accepted motion after its nominal budget, and ASCO ends without an accepted motion. At 20 UAVs, hard RSC completes in 27.70 s and LIOM returns an accepted motion at 30.12 s. Symbolic construction consumes the remaining budget in the two winding direct-NLP tasks and the 20-UAV direct-NLP task. The source records separate construction, numerical solution, and physical checking.
'''
(O/'external_findings.tex').write_text(findings)
lines=[r'\begin{table}[htbp]',r'\begin{adjustwidth}{-\extralength}{0cm}',
 r'\caption{Hard-entry budget ablation. Each cell gives total planning time in seconds and QP calls. All three settings share the recorded reference and a 30 s total budget, with rotated execution order. $\times$ marks no accepted motion and $\dagger$ marks late acceptance.\label{tab:entry-budget}}',
 r'\small\begin{tabularx}{\fulllength}{Yrrr}\toprule',r'Task & 1 s entry: time / QPs & \textbf{3 s entry: time / QPs} & 5 s entry: time / QPs\\\midrule']
for case in ids:
 cells=[]
 for budget in [1,3,5]:
  row=entry_lookup[case,budget];cells.append(timecell(row)+' / '+row['QPs'])
 lines.append(label(case)+' & '+' & '.join(cells)+r'\\')
lines += [r'\bottomrule\end{tabularx}',r'\end{adjustwidth}\end{table}'];(O/'entry_budget_table.tex').write_text('\n'.join(lines)+'\n')
entrytext=r'''A separate entry-budget study varies the initial hard-QP allowance between 1, 3, and 5 s on the ten tasks used in Table~\ref{tab:external}. All other settings and the total planning budget remain fixed. Table~\ref{tab:entry-budget} reports the complete runs, including recovery after the entry solve. In C29, the 3 s entry returns directly and reduces total time from 19.27 to 3.63 s and QP calls from five to one. The 3 s setting also returns accepted 15- and 20-UAV motions within budget in this study. Giving the initial hard problem 5 s reduces the time available for subsequent recovery: Winding A then returns its accepted motion after the total budget. The 3 s allowance offers a useful compromise and is recommended for new runs. The earlier benchmark and scaling records retain their original 1 s allowance; their recorded times are unchanged.
\input{data_revision/entry_budget_table}
'''
(O/'entry_budget_narrative.tex').write_text(entrytext)
report=dict(ma57_rerun_attempts=20,entry_budget_attempts=30,selected_external_attempts=50,
 same_inputs_verified=True,only_entry_budget_varies=True,ma57_nonlinear_verified=True,all_qps_osqp=True,
 accepted_physical_checks_verified=True,recommended_entry_seconds=3,archived_comparison_entry_seconds=1,
 external=audit,entry=entry)
(R/'results/ma57_revision_audit.json').write_text(json.dumps(report,indent=2))
with (C/'selected_comparison.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(selected[0]));w.writeheader();w.writerows(lookup[c,m] for c in ids for m in methods)
print(json.dumps({k:v for k,v in report.items() if k not in ['external','entry']},indent=2))
