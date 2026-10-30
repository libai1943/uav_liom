from pathlib import Path
import sys, json, hashlib, csv
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'python_packages'))
from scipy.io import loadmat
OUT=ROOT/'results/external_20261031_formal'
assert (OUT/'completed.json').exists(), 'Formal study incomplete'
rows=list(csv.DictReader((OUT/'summary.csv').open(encoding='utf-8-sig')))
assert len(rows)==50 and len({(x['Case'],x['Method']) for x in rows})==50
NORM=ROOT/'results/normscp_20261031'
assert (NORM/'completed.json').exists()
rows += list(csv.DictReader((NORM/'summary.csv').open(encoding='utf-8-sig')))
assert len(rows)==60
hashes=json.loads((ROOT/'comparisons_20261031/source_hashes.json').read_text(encoding='utf-8-sig'))
for item in hashes:
 assert hashlib.sha256(Path(item['File']).read_bytes()).hexdigest().lower()==item['SHA256'].lower(),item['File']
methods=['adaptive','rsc_iter','asco','nlp','scp_norm'];ids=['C01','C03','C05','C25','C27','C29','W6102','W7202','N15','N20']
lookup={(x['Case'],x['Method']):x for x in rows};audit=[]
for case in ids:
 inputs=[]
 for method in methods+['scp']:
  base=NORM if method=='scp_norm' else OUT
  d=loadmat(base/f'{case}_{method}.mat',simplify_cells=True);r=d['result'];c=d['c'];s=d['s']
  inputs.append((s,c,r['reference']))
  if bool(r['success']):
   assert r['validation']['success'] and r['validation']['integrationIdentityError']<1e-9
   assert r['validation']['endpointViolation']<1e-9
  history=r['history'];history=[history] if isinstance(history,dict) else list(history)
  backends=[h['info']['backend'] for h in history]
  assert all(x=='osqp' for x in backends) if method in ['adaptive','rsc_iter','scp','scp_norm'] else all(x in ['osqp','ipopt','none'] for x in backends)
  audit.append({'case':case,'method':method,'accepted':bool(r['success']),'within_budget':bool(r['successWithinBudget']),'wall':float(r['planningSeconds']),'cpu':float(r['cpuSeconds']),'status':r['status'],'solves':int(r['solveCount']),'backends':backends,'statuses':[h['info']['status'] for h in history]})
 import numpy as np
 for s,c,ref in inputs[1:]:
  for key in ['starts','exits','v0','vf','bounds','obstacles']:assert np.array_equal(s[key],inputs[0][0][key]),(case,key)
  for key in ['P','V','seconds']:assert np.array_equal(ref[key],inputs[0][2][key]),(case,key)
  for key in ['horizon','intervals','vmax','amax','radius','clearance','motionPolytope','totalBudget']:assert np.array_equal(c[key],inputs[0][1][key]),(case,key)
(ROOT/'results/external_20261031_audit.json').write_text(json.dumps({'attempts':audit,'same_inputs_verified':True,'frozen_source_verified':True,'all_accepted_identity_checks_passed':True},indent=2))
lines=[r'\begin{table}[htbp]',r'\begin{adjustwidth}{-\extralength}{0cm}',r'\caption{Paired task-matched comparisons: total planning time in seconds. A cross denotes no accepted motion; $\dagger$ marks an accepted motion returned after the nominal 30 s budget. Actual times include the common recorded initialization charge. Each cell is one execution with the same saved reference and initialization charge.\label{tab:external}}',r'\small\begin{tabularx}{\fulllength}{lcrrrrr}\toprule',r'Task & $N$ & \textbf{Proposed} & Hard RSC & ASCO-3D & Direct NLP & SCP-3D\\\midrule']
for case in ids:
 entries=[]
 for method in methods:
  row=lookup[case,method];val=f'{float(row["Wall"]):.2f}'
  if row['Accepted']=='0':val=r'$\times$\,'+val
  elif row['WithinBudget']=='0':val+=r'$^{\dagger}$'
  if method=='adaptive':val=r'\textbf{'+val+'}'
  entries.append(val)
 label={'W6102':'Winding A','W7202':'Winding B','N15':'15-UAV','N20':'20-UAV'}.get(case,case)
 lines.append(label+' & '+lookup[case,'adaptive']['N']+' & '+' & '.join(entries)+r'\\')
lines += [r'\bottomrule\end{tabularx}',r'\end{adjustwidth}\end{table}']
(ROOT/'paper/revision_20261031/clean/data_revision/external_table.tex').write_text('\n'.join(lines)+'\n')
print(json.dumps(audit,indent=2))
