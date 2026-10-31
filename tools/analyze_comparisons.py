from pathlib import Path
import csv,json,sys,hashlib
R=Path(__file__).resolve().parents[1];sys.path.insert(0,str(R/'python_packages'))
from scipy.io import loadmat
import numpy as np
P=R/'paper';O=P/'clean/data_revision'
A=B=C=R/'results/comparisons';E=R/'results/entry_budget'

def rows(folder):return list(csv.DictReader((folder/'summary.csv').open(encoding='utf-8-sig')))
assert (C/'completed.json').exists() and (E/'completed.json').exists()
new=[x for x in rows(C) if x['Method'] in ['asco','nlp']];entry=rows(E);assert len(new)==20 and len(entry)==30
selected=[x for x in rows(A) if x['Method'] in ['adaptive','rsc_iter']]+[x for x in rows(B) if x['Method']=='scp']+new
ids=['C01','C03','C05','C25','C27','C29','W6102','W7202','N15','N20'];methods=['adaptive','rsc_iter','asco','nlp','scp']
lookup={(x['Case'],x['Method']):x for x in selected};assert len(lookup)==50

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
   if x['info']['backend']=='none':
    assert method in ['asco','nlp'] and x['info']['status']=='BUILD_BUDGET' and not d['result']['success'],(case,method,x['info'])
    continue
   assert x['info']['backend'] in ['ipopt','osqp'],(case,method,x['info']['backend'])
   if x['info']['backend']=='ipopt':assert method in ['asco','nlp'] and x['info']['linearSolver']=='ma57'
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
 r'\caption{Task-matched planning times in seconds, including recorded initialization. The hard entry uses 3 s; nonlinear subproblems use Ipopt/ma57. A cross denotes no accepted motion; $\dagger$ denotes an accepted motion returned after the nominal 30 s budget. Each entry is one recorded execution.\label{tab:external}}',
 r'\small\begin{tabularx}{\fulllength}{Ycrrrrr}\toprule',r'Task & $N$ & \textbf{LIOM (proposed)} & Hard RSC & ASCO-3D & Direct NLP & SCP-3D\\\midrule']
for case in ids:
 lines.append(label(case)+' & '+lookup[case,'adaptive']['N']+' & '+' & '.join(timecell(lookup[case,m],m=='adaptive') for m in methods)+r'\\')
lines += [r'\bottomrule\end{tabularx}',r'\end{adjustwidth}\end{table}'];(O/'external_table.tex').write_text('\n'.join(lines)+'\n')
# Case interpretation is written from the verified current outcome table.
lines=[r'\begin{table}[htbp]',r'\begin{adjustwidth}{-\extralength}{0cm}',
 r'\caption{Hard-entry budget ablation. Each cell gives total planning time in seconds and QP calls. All three settings share the recorded reference and a 30 s total budget, with rotated execution order. $\times$ marks no accepted motion and $\dagger$ marks late acceptance.\label{tab:entry-budget}}',
 r'\small\begin{tabularx}{\fulllength}{Yrrr}\toprule',r'Task & 1 s entry: time / QPs & \textbf{3 s entry: time / QPs} & 5 s entry: time / QPs\\\midrule']
for case in ids:
 cells=[]
 for budget in [1,3,5]:
  row=entry_lookup[case,budget];cells.append(timecell(row)+' / '+row['QPs'])
 lines.append(label(case)+' & '+' & '.join(cells)+r'\\')
lines += [r'\bottomrule\end{tabularx}',r'\end{adjustwidth}\end{table}'];(O/'entry_budget_table.tex').write_text('\n'.join(lines)+'\n')
entrytext=r'''The hard-entry ablation compares 1, 3, and 5 s on the same ten tasks, keeping the common reference and total 30 s budget fixed. Table~\ref{tab:entry-budget} reports full planning times and QP calls, including any subsequent recovery.'''
(O/'entry_budget_narrative.tex').write_text(entrytext+'\n'+r'\input{data_revision/entry_budget_table}'+'\n')
report=dict(nonlinear_attempts=20,entry_budget_attempts=30,external_attempts=50,
 same_inputs_verified=True,only_entry_budget_varies=True,ma57_nonlinear_verified=True,all_qps_osqp=True,
 accepted_physical_checks_verified=True,recommended_entry_seconds=3,comparison_entry_seconds=3,
 external=audit,entry=entry)
(R/'results/comparison_audit.json').write_text(json.dumps(report,indent=2))
with (C/'comparison_summary.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(selected[0]));w.writeheader();w.writerows(lookup[c,m] for c in ids for m in methods)
print(json.dumps({k:v for k,v in report.items() if k not in ['external','entry']},indent=2))
