from pathlib import Path
import sys,json,csv,hashlib
R=Path(__file__).resolve().parents[1];sys.path.insert(0,str(R/'python_packages'))
from scipy.io import loadmat
import numpy as np
A=R/'results/external_20261031_formal';B=R/'results/external_20261031_verified'
assert (A/'completed.json').exists() and (B/'completed.json').exists()
old=list(csv.DictReader((A/'summary.csv').open(encoding='utf-8-sig')));new=list(csv.DictReader((B/'summary.csv').open(encoding='utf-8-sig')))
assert len(old)==50 and len(new)==20
rows=[x for x in old if x['Method'] not in ['asco','scp']]+new
methods=['adaptive','rsc_iter','asco','nlp','scp'];ids=['C01','C03','C05','C25','C27','C29','W6102','W7202','N15','N20']
assert len(rows)==len({(x['Case'],x['Method']) for x in rows})==50
for item in json.loads((R/'comparisons_20261031/verified_source_hashes.json').read_text(encoding='utf-8-sig')):
 assert hashlib.sha256((R/'comparisons_20261031'/item['File'].replace('\\','/').split('/comparisons_20261031/',1)[1]).read_bytes()).hexdigest().lower()==item['SHA256'].lower()
lookup={(x['Case'],x['Method']):x for x in rows};audit=[]
for case in ids:
 inputs=[]
 for method in methods:
  folder=B if method in ['asco','scp'] else A
  d=loadmat(folder/f'{case}_{method}.mat',simplify_cells=True);r=d['result'];c=d['c'];s=d['s'];ref=r['reference']
  inputs.append((s,c,ref))
  if r['success']:
   assert r['validation']['success'] and r['validation']['integrationIdentityError']<1e-9 and r['validation']['endpointViolation']<1e-9
  history=r['history'];history=[history] if isinstance(history,dict) else list(history)
  backends=[x['info']['backend'] for x in history]
  if method in ['adaptive','rsc_iter','scp']:assert all(x=='osqp' for x in backends)
  else:assert all(x in ['osqp','ipopt','none'] for x in backends)
  audit.append(dict(lookup[case,method],source=str((folder/f'{case}_{method}.mat').relative_to(R)),backends=backends,statuses=[x['info']['status'] for x in history]))
 for s,c,ref in inputs[1:]:
  for key in ['starts','exits','v0','vf','bounds','obstacles']:assert np.array_equal(s[key],inputs[0][0][key]),(case,key)
  for key in ['P','V','seconds']:assert np.array_equal(ref[key],inputs[0][2][key]),(case,key)
  for key in ['horizon','intervals','vmax','amax','radius','clearance','motionPolytope','totalBudget']:assert np.array_equal(c[key],inputs[0][1][key]),(case,key)
report={'attempts':audit,'selected_attempts':50,'all_saved_stage_attempts':70,'same_inputs_verified':True,'frozen_sources_verified':True,'accepted_identity_checks_verified':True,'selection':'All ASCO and SCP rows use verified reruns. All unchanged adaptive/RSC/direct-NLP rows use formal phase. No outcome-based row selection.'}
(R/'results/external_20261031_audit.json').write_text(json.dumps(report,indent=2))
with (B/'selected_comparison.csv').open('w',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(lookup[c,m] for c in ids for m in methods)
lines=[r'\begin{table}[htbp]',r'\begin{adjustwidth}{-\extralength}{0cm}',r'\caption{Task-matched planning times in seconds, including a common recorded initialization charge. A cross denotes no accepted motion; $\dagger$ denotes an accepted motion returned after the nominal 30 s budget. Each entry is one execution of the final implementation.\label{tab:external}}',r'\small\begin{tabularx}{\fulllength}{Ycrrrrr}\toprule',r'Task & $N$ & \textbf{Proposed} & Hard RSC & ASCO-3D & Direct NLP & SCP-3D\\\midrule']
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
(R/'paper/revision_20261031/clean/data_revision/external_table.tex').write_text('\n'.join(lines)+'\n')
print(json.dumps(audit,indent=2))
