"""Reproducible figures and summary from saved winding experiments."""
import os,sys,json,csv
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'python_packages'));sys.path.insert(0,str(ROOT/'tools'));os.environ['MPLCONFIGDIR']=str(ROOT/'tmp/mpl')
import numpy as np
from scipy.io import loadmat
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
from analyze_revision import trajectory_axes,curves,hist
OUT=ROOT/'results/winding_evidence';OUT.mkdir(exist_ok=True)
source=ROOT/'results/winding_repeated/PW1_S6102_R1_adaptive.mat';d=loadmat(source,simplify_cells=True);r=d['result'];s=d['job']['scene'];c=d['job']['cfg'];assert r['success']
t,p=curves(r['trajectory'],c['horizon'],12);obs=np.asarray(s['obstacles']).reshape(-1,6)
fig=plt.figure(figsize=(10.5,7.2));gs=fig.add_gridspec(2,2,height_ratios=[1.35,1],left=.075,right=.98,bottom=.10,top=.98,wspace=.24,hspace=.42)
a=fig.add_subplot(gs[0,0],projection='3d');b=fig.add_subplot(gs[0,1]);trajectory_axes(a,d);trajectory_axes(b,d,xy=True)
a.text2D(.5,-.13,'(a) Recovered continuous motion',transform=a.transAxes,ha='center',fontsize=10);b.text(.5,-.27,'(b) Alternating narrow openings: top view',transform=b.transAxes,ha='center',fontsize=10)
cax=fig.add_subplot(gs[1,0]);hh=[h for h in hist(r) if h['phase']=='soft'];x=np.arange(1,len(hh)+1);q=np.array([h['info']['normalizedD']/h['defectTolerance'] for h in hh]);ss=np.array([h['info']['meanSlack']/c['meanSlackTolerance'] for h in hh]);cax.semilogy(x,q,'o-',c='#BB3311',label='Kinematic defect / tolerance');cax.semilogy(x,ss,'s-',c='#0077BB',label='Relative slack / tolerance');cax.axhline(1,c='black',ls='--',lw=.9);cax.set(xlabel='Recovery QP',ylabel='Normalized recovery quantity',xticks=x);cax.grid(alpha=.2);cax.legend(frameon=False,fontsize=8.5);cax.text(.5,-.28,'(c) Recorded recovery quantities',transform=cax.transAxes,ha='center')
dax=fig.add_subplot(gs[1,1]);pairs=np.stack([np.linalg.norm(p[:,:,i]-p[:,:,j],axis=0) for i in range(p.shape[2]) for j in range(i)]);pair=pairs.min(axis=0);clear=np.full(len(t),np.inf)
for o in obs:
 gap=np.maximum(np.maximum(o[:3,None,None]-p,p-o[3:,None,None]),0);clear=np.minimum(clear,np.linalg.norm(gap,axis=0).min(axis=1)-c['radius'])
dax.plot(t,pair,c='#0077BB',label='Minimum pair distance');dax.plot(t,clear,c='#AA3377',label='Obstacle surface clearance');dax.axhline(2*c['radius']+c['clearance'],c='#0077BB',ls='--',lw=.9);dax.axhline(c['clearance'],c='#AA3377',ls=':',lw=1.3);dax.set(xlabel='Flight time (s)',ylabel='Distance (m)',xlim=(0,c['horizon']),ylim=(0,max(2.6,float(np.quantile(pair,.95))*1.1)));dax.grid(alpha=.2);dax.legend(frameon=False,fontsize=8.5);dax.text(.5,-.28,'(d) Clearances along the accepted motion',transform=dax.transAxes,ha='center')
fig.savefig(OUT/'winding_recovery_case.pdf',bbox_inches='tight');fig.savefig(OUT/'winding_recovery_case.png',dpi=180,bbox_inches='tight');plt.close(fig)
summary={'illustrative_source':str(source),'validation':r['validation'],'restoration':r['restoration'],'paired':{}}
for tag,folder in [('repeat','winding_repeated'),('fresh','winding_layouts'),('map','winding_geometry_map')]:
 path=ROOT/'results'/folder/'summary.csv'
 if not path.exists():continue
 rows=list(csv.DictReader(path.open(encoding='utf-8-sig')));stats={}
 for method in sorted(set(x['Method'] for x in rows)):
  rr=[x for x in rows if x['Method']==method];stats[method]={'attempts':len(rr),'accepted':sum(int(x['Accepted']) for x in rr),'within_budget':sum(int(x['WithinBudget']) for x in rr),'mean_wall_s':float(np.nanmean([float(x['Wall_s']) for x in rr]))}
 key='paired';summary[key][tag]={'methods':stats,'complete':(path.parent/'completed.json').exists()}
 ap=path.parent/'comparative_audit.csv'
 if ap.exists():summary[key][tag]['comparative_audit']=list(csv.DictReader(ap.open(encoding='utf-8-sig')))
(OUT/'evidence_summary.json').write_text(json.dumps(summary,indent=2,default=lambda x:np.asarray(x).tolist()));print({k:{a:b['methods'] for a,b in v.items()} for k,v in summary.items() if k in ('exploratory','paired')})

mapfile=ROOT/'results/winding_geometry_map/summary.csv'
if (mapfile.parent/'completed.json').exists():
 from matplotlib.colors import ListedColormap,BoundaryNorm
 from matplotlib.patches import Patch
 rows=list(csv.DictReader(mapfile.open(encoding='utf-8-sig')))
 def state(N,Tf,width):
  rr=[x for x in rows if float(x['N'])==N and float(x['Tf'])==Tf and abs(float(x['Width'])-width)<1e-8];ok={x['Method']:bool(int(x['WithinBudget'])) for x in rr}
  assert len(ok)==2,(N,Tf,width)
  if ok['adaptive'] and ok['rsc_iter']:return 2
  if ok['adaptive']:return 1
  if ok['rsc_iter']:return 3
  return 0
 cmap=ListedColormap(['#EEEEEE','#D55E00','#56B4E9','#CC79A7']);norm=BoundaryNorm([-.5,.5,1.5,2.5,3.5],4);symbols=['x','L','B','R']
 fig=plt.figure(figsize=(8.4,3.35));gs=fig.add_gridspec(1,2,width_ratios=[1,1.3],left=.09,right=.98,bottom=.28,top=.91,wspace=.35)
 ax=fig.add_subplot(gs[0,0]);z=np.array([[state(N,T,2.2) for T in [20,24,28]] for N in [3,5,7]]);ax.imshow(z,cmap=cmap,norm=norm,origin='lower',aspect='equal')
 for y in range(3):
  for x in range(3):ax.text(x,y,symbols[z[y,x]],ha='center',va='center',fontweight='bold',fontsize=14,color='black')
 ax.set(xticks=[0,1,2],xticklabels=['20','24','28'],yticks=[0,1,2],yticklabels=['3','5','7'],xlabel='Fixed flight horizon (s)',ylabel='Number of UAVs');ax.set_title('Opening width: 2.2 m',fontsize=10)
 bx=fig.add_subplot(gs[0,1]);z=np.array([[state(5,24,w) for w in [2.2,2.4,2.6,2.8]]]);bx.imshow(z,cmap=cmap,norm=norm,aspect='equal')
 for x in range(4):bx.text(x,0,symbols[z[0,x]],ha='center',va='center',fontweight='bold',fontsize=14,color='black')
 bx.set(xticks=range(4),xticklabels=['2.2','2.4','2.6','2.8'],yticks=[],xlabel='Physical opening width (m)');bx.set_title('Five UAVs; fixed flight horizon: 24 s',fontsize=10)
 labels=['x: Neither accepted','L: Proposed only','B: Both accepted','R: Hard RSC only'];fig.legend([Patch(fc=cmap(i),ec='black',lw=.4) for i in range(4)],labels,loc='lower center',bbox_to_anchor=(.5,.015),ncol=2,frameon=False,fontsize=9)
 fig.savefig(OUT/'physical_recovery_map.pdf',bbox_inches='tight');fig.savefig(OUT/'physical_recovery_map.png',dpi=180,bbox_inches='tight');plt.close(fig)
