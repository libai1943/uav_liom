import sys,os,json,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'python_packages'));sys.path.insert(0,str(ROOT/'simulation'))
import numpy as np
from scipy.io import loadmat
from multirotor import simulate,PARAM
import mujoco
OUT=ROOT/'results/mujoco_tracking';OUT.mkdir(parents=True,exist_ok=True)
def tests():
 P=np.tile(np.array([0.,0,3.])[:,None],(1,3));V=np.zeros_like(P);A=np.zeros((3,2));s={'obstacles':np.zeros((0,6))}
 metric,_,_=simulate(P,V,A,1.,s,.25);assert metric['max_error']<1e-8,metric
 K=100;h=.04;A=np.zeros((3,K,1));A[0,:50,0]=.25;A[0,50:,0]=-.25;P=np.zeros((3,K+1,1));V=np.zeros_like(P);P[2,0,0]=3
 for k in range(K):P[:,k+1,:]=P[:,k,:]+h*V[:,k,:]+.5*h*h*A[:,k,:];V[:,k+1,:]=V[:,k,:]+h*A[:,k,:]
 metric,_,_=simulate(P,V,A,4.,s,.25);assert metric['max_error']<.25,metric
 nominal=metric;metric,_,_=simulate(P,V,A,4.,s,.25,disturbed=True);assert metric['max_error']<.25,metric
 (OUT/'controller_checks.json').write_text(json.dumps({'nominal_maneuver':nominal,'perturbed_maneuver':metric,'parameters':PARAM},indent=2));print('Independent controller tests passed.',flush=True)
def run():
 tests();paths=[]
 for p in sorted((ROOT/'results/benchmark/main').glob('C*_adaptive_default_R1.mat')):
  if loadmat(p,simplify_cells=True)['result']['success']:paths.append(p)
 selected=set()
 for p in sorted((ROOT/'results/benchmark/physical').glob('*_adaptive_default_R1.mat')):
  d=loadmat(p,simplify_cells=True);key=(d['job']['scene']['name'],d['job']['cfg']['numAgents'])
  if d['result']['success'] and key not in selected:paths.append(p);selected.add(key)
 for rel in ['winding_repeated/PW1_S6102_R1_adaptive.mat','winding_layouts/PW2_S7202_R1_adaptive.mat']:
  p=ROOT/'results'/rel
  if p.exists() and loadmat(p,simplify_cells=True)['result']['success']:paths.append(p)
 (OUT/'selection.json').write_text(json.dumps({'rule':'All accepted main adaptive R1 motions and first accepted physical motion per family/team size; plus the representative winding recovery and fresh-seed recovery; both conditions; no selection on tracking outcome.','files':list(map(str,paths))},indent=2))
 records=[]
 for p in paths:
  d=loadmat(p,simplify_cells=True);job=d['job'];c=job['cfg'];tr=d['result']['trajectory']
  for disturbed in [False,True]:
   out=OUT/(job['id']+('_perturbed' if disturbed else '_nominal'));out.mkdir(parents=True,exist_ok=True);done=out/'metrics.json'
   if done.exists():metric=json.loads(done.read_text())
   else:
    start=time.time();metric,arrays,xml=simulate(tr['P'],tr['V'],tr['A'],c['horizon'],job['scene'],c['radius'],disturbed)
    metric.update(case=job['id'],folder=str(out),source=str(p),simulation_wall_s=time.time()-start)
    done.write_text(json.dumps(metric,indent=2));np.savez_compressed(out/'tracking.npz',**arrays);(out/'model.xml').write_text(xml);(out/'settings.json').write_text(json.dumps({'parameters':PARAM,'mujoco_version':mujoco.__version__,'planner_source':str(p)},indent=2))
   records.append(metric);(OUT/'summary.json').write_text(json.dumps(records,indent=2));print(json.dumps(metric),flush=True)
 (OUT/'completed.json').write_text(json.dumps({'completed':True,'runs':len(records)}))
if __name__=='__main__':run()
