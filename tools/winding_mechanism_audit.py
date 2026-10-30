"""Independent LP diagnosis. All planning QPs remain OSQP."""
import os,sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'python_packages'));os.environ['OMP_NUM_THREADS']='1';os.environ['OPENBLAS_NUM_THREADS']='1'
import numpy as np
from scipy.io import loadmat
from scipy import sparse
from scipy.optimize import linprog
from contextlib import nullcontext
FOLDER=ROOT/'results/winding_fine_stage1';OUT=ROOT/'results/winding_evidence';OUT.mkdir(exist_ok=True)
m=loadmat(FOLDER/'W1_006_initial_hardRSC_phaseI.mat',simplify_cells=True)['m'];n=len(m['free']);C=m['C'].tocsr();lo=m['lower'];hi=m['upper'];lb=m['lb'];ub=m['ub']
job=loadmat(FOLDER/'W1_006_rsc_iter.mat',simplify_cells=True)['job'];N=int(job['cfg']['numAgents']);K=int(job['cfg']['intervals']);Q=K+1;E=int(m['relativeCount']);facets=(m['fullC'].shape[0]-E-3*N*K)//(N*(Q+K));assert facets==24,facets
full_indices=np.flatnonzero(np.asarray(abs(m['fullC'].tocsr()[:,np.asarray(m['free'],int)-1]).sum(axis=1)).ravel()>0);assert len(full_indices)==C.shape[0]
relative_start=facets*N*(Q+K);relative=(full_indices>=relative_start)&(full_indices<relative_start+E);dynamics=full_indices>=relative_start+E

def phase(mask):
 a=C[mask];low=lo[mask];upp=hi[mask];norms=np.maximum(1,np.sqrt(np.asarray(a.multiply(a).sum(axis=1)).ravel()));a=sparse.diags(1/norms)@a;low=low/norms;upp=upp/norms
 iu=np.isfinite(upp);il=np.isfinite(low);b=np.r_[upp[iu],-low[il]];aa=sparse.vstack([a[iu],-a[il]]).tocsc();aa=sparse.hstack([aa,-np.ones((len(b),1))],format='csc')
 with nullcontext():
  z=linprog(np.r_[np.zeros(n),1.],A_ub=aa,b_ub=b,bounds=list(zip(np.r_[lb,0],np.r_[ub,np.inf])),method='highs',options={'time_limit':60,'dual_feasibility_tolerance':1e-9,'primal_feasibility_tolerance':1e-9,'threads':1})
 report={'success':bool(z.success),'status':int(z.status),'message':z.message,'minimum_scaled_violation':float(z.fun) if z.success else None,'rows':int(a.shape[0])}
 if z.success:report['primal_violation']=float(max(0,np.max(aa@z.x-b)))
 return report
out={'source':'W1_006 initial hard RSC matrix; same fixed task and spatial boxes','full':phase(np.ones(C.shape[0],bool)),'without_relative_rows':phase(~relative),'without_kinematic_equalities':phase(~dynamics),'N':N,'K':K,'facets':facets,'relative_rows':E}
(OUT/'mechanism_lp_audit.json').write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2))
