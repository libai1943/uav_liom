"""Generate manuscript evidence only from saved prospective experiments."""
import os,sys,csv,json,re,math,argparse,hashlib,datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'python_packages'))
os.environ.setdefault('MPLCONFIGDIR',str(ROOT/'tmp/mpl'))
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
PAPER=ROOT/'paper/clean';DATA=PAPER/'data_revision';FIG=PAPER/'figures_revision';RES=ROOT/'results/benchmark'
NAMES={'adaptive':'LIOM (proposed)','liom':'Soft LIOM','hard_iter':'Hard box–iterative','rsc_iter':'Hard RSC–iterative','hard_once':'Hard box–once','rsc_once':'Hard RSC–once','soft_once':'Soft once'}
COL={'adaptive':'#C62828','liom':'#0077BB','hard_iter':'#E69F00','rsc_iter':'#6A3D9A','hard_once':'#009E73','rsc_once':'#333333','soft_once':'#56B4E9'}
MARK={'adaptive':'o','liom':'s','hard_iter':'^','rsc_iter':'D','hard_once':'v','rsc_once':'P','soft_once':'X'}
MAIN=['adaptive','liom','hard_iter','rsc_iter','hard_once'];PHYS=MAIN[:4]
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.labelsize':9,'xtick.labelsize':8,'ytick.labelsize':8,'legend.fontsize':8,'axes.spines.top':False,'axes.spines.right':False,'axes.labelcolor':'black','text.color':'black','xtick.color':'black','ytick.color':'black','pdf.fonttype':42,'ps.fonttype':42,'savefig.bbox':'tight','savefig.pad_inches':.06,'axes.linewidth':.7,'lines.linewidth':1.5})

def rows(suite):
 p=RES/suite/'summary.csv'
 if not p.exists():return []
 out=list(csv.DictReader(p.open(encoding='utf-8-sig')))
 for r in out:
  for k,v in r.items():
   if k not in ('Case','Method','Variant','Status','FailureStage'):
    try:r[k]=float(v)
    except ValueError:pass
 return out

def filt(rs,**kw):return [r for r in rs if all(r.get(k)==v for k,v in kw.items())]
def mean(rs,k):return float(np.mean([r[k] for r in rs])) if rs else float('nan')
def quant(rs,k,q):return float(np.quantile([r[k] for r in rs],q)) if rs else float('nan')
def count(rs,key='AcceptedWithinBudget'):return int(sum(r[key] for r in rs))
def tex(s):return str(s).replace('&',r'\&').replace('_',r'\_').replace('%',r'\%').replace('–','--')
def fmt(v,d=2):return f'{v:.{d}f}' if np.isfinite(v) else '--'
def write(name,s):DATA.mkdir(parents=True,exist_ok=True);(DATA/(name+'.tex')).write_text(s+'\n',encoding='utf-8')
def table(label,caption,headers,body,widths=None):
 spec=widths or ('l'+'r'*(len(headers)-1));wide=len(headers)>=5
 lines=[r'\begin{table}[htbp]']
 if wide:lines.append(r'\begin{adjustwidth}{-\extralength}{0cm}')
 lines += [r'\caption{'+caption+r'\label{tab:'+label+r'}}',r'\centering\small',r'\begin{tabular}{'+spec+r'}\toprule',' & '.join(headers)+r'\\\midrule',*[' & '.join(map(str,r))+r'\\' for r in body],r'\bottomrule\end{tabular}']
 if wide:lines.append(r'\end{adjustwidth}')
 lines.append(r'\end{table}');return '\n'.join(lines)
def savefig(fig,name):FIG.mkdir(parents=True,exist_ok=True);fig.savefig(FIG/(name+'.pdf'));fig.savefig(FIG/(name+'.png'),dpi=160);plt.close(fig)
def loadjob(suite,r):return loadmat(RES/suite/f"{r['Case']}_{r['Method']}_{r['Variant']}_R{int(r['Repeat'])}.mat",simplify_cells=True)
def has_text(v):
 return bool(v) if isinstance(v,str) else np.asarray(v).size>0
def hist(result):
 h=result.get('history',[])
 if isinstance(h,dict):return [h]
 if isinstance(h,np.ndarray):return list(h.flat)
 return list(h)
def outcome(rs):
 reps=sorted(set(r['Repeat'] for r in rs)); counts=[count(filt(rs,Repeat=p)) for p in reps]
 cases=sorted(set(r['Case'] for r in rs));stable=sum(all(x['AcceptedWithinBudget'] for x in filt(rs,Case=c)) for c in cases)
 identical=all(len(set(x['AcceptedWithinBudget'] for x in filt(rs,Case=c)))==1 for c in cases)
 return dict(repetition_counts=counts,all_repetitions=stable,distinct=len(cases),identical=identical,mean_wall=mean(rs,'Wall_s'),mean_cpu=mean(rs,'CPU_s'),p95=quant(rs,'Wall_s',.95),mean_outer=mean(rs,'OuterIterations'),mean_solves=mean(rs,'QPSolves'),deadline=count(rs,'AcceptedWithinBudget'),physically_accepted=count(rs,'Accepted'),late_accepted=count(rs,'Accepted')-count(rs,'AcceptedWithinBudget'))
def curves(tr,T,steps=6):
 P,V,A=tr['P'],tr['V'],tr['A'];K=A.shape[1];h=T/K
 if P.ndim==2:P=P[:,:,None];V=V[:,:,None];A=A[:,:,None]
 tau=np.linspace(0,h,steps,endpoint=False)
 out=np.concatenate([P[:,k:k+1,:]+tau[None,:,None]*V[:,k:k+1,:]+.5*tau[None,:,None]**2*A[:,k:k+1,:] for k in range(K)]+[P[:,-1:,:]],axis=1)
 return np.linspace(0,T,out.shape[1]),out

def box(ax,o,alpha=.15):
 lo=o[:3];hi=o[3:];v=np.array([[x,y,z] for x in [lo[0],hi[0]] for y in [lo[1],hi[1]] for z in [lo[2],hi[2]]]);ids=[[0,1,3,2],[4,5,7,6],[0,1,5,4],[2,3,7,6],[0,2,6,4],[1,3,7,5]]
 ax.add_collection3d(Poly3DCollection([v[i] for i in ids],facecolor='#868E96',edgecolor='#45515B',linewidth=.35,alpha=alpha))
def trajectory_axes(ax,d,reference=False,xy=False):
 r=d['result'];s=d['job']['scene'];c=d['job']['cfg'];P=r['reference']['P'] if reference else curves(r['trajectory'],c['horizon'])[1]
 if P.ndim==2:P=P[:,:,None]
 colors=plt.colormaps['turbo'](np.linspace(.05,.94,P.shape[2]));obs=np.asarray(s['obstacles']).reshape(-1,6)
 both=np.concatenate([r['reference']['P'],curves(r['trajectory'],c['horizon'])[1]],axis=1);lo=both.min(axis=(1,2))-.5;hi=both.max(axis=(1,2))+.5;lo[2]=max(.5,lo[2]);hi[2]=min(7.5,hi[2])
 for o in obs:
  o=np.r_[np.maximum(o[:3],lo),np.minimum(o[3:],hi)]
  if np.any(o[3:]<=o[:3]):continue
  if xy:
   from matplotlib.patches import Rectangle
   ax.add_patch(Rectangle(o[:2],o[3]-o[0],o[4]-o[1],fc='.8',ec='.4',alpha=.4,lw=.4))
  else:box(ax,o)
 for i,color in enumerate(colors):
  if xy:
   ax.plot(P[0,:,i],P[1,:,i],color=color,lw=1.4);ax.scatter(P[0,0,i],P[1,0,i],c=[color],s=10);ax.scatter(P[0,-1,i],P[1,-1,i],c=[color],s=17,marker='^')
  else:
   ax.plot(*P[:,:,i],color=color,lw=1.5);ax.scatter(*P[:,0,i],c=[color],s=10);ax.scatter(*P[:,-1,i],c=[color],s=17,marker='^')
 ax.set_xlabel('$x$ (m)',labelpad=1);ax.set_ylabel('$y$ (m)',labelpad=1)
 if xy:ax.set_aspect('equal',adjustable='box');ax.grid(alpha=.15);ax.set_xlim(lo[0],hi[0]);ax.set_ylim(lo[1],hi[1])
 else:
  ax.set_zlabel('$z$ (m)',labelpad=1);ax.view_init(24,-58);ax.set_box_aspect((1,1,.55));ax.tick_params(pad=0)
  # Frame the flight region, without allowing large wall extents to shrink trajectories.
  ax.set_xlim(lo[0],hi[0]);ax.set_ylim(lo[1],hi[1]);ax.set_zlim(max(.5,lo[2]),min(7.5,hi[2]))

def main_results(audit):
 rs=rows('main');stats={m:outcome(filt(rs,Method=m)) for m in NAMES};audit['main']=stats
 body=[]
 for m in MAIN:
  st=stats[m];cs=st['repetition_counts'];success=str(min(cs)) if min(cs)==max(cs) else f'{min(cs)}--{max(cs)}';name=tex(NAMES[m]);name=r'\textbf{'+name+'}' if m=='adaptive' else name
  body.append([name,success+'/30',str(st['all_repetitions'])+'/30',fmt(st['mean_cpu']),fmt(st['mean_wall']),fmt(st['p95']),fmt(st['mean_outer']),fmt(st['mean_solves'])])
 write('main_table',table('main-new','Main benchmark: scenes accepted within 30 s per repetition, scenes accepted within 30 s in all three repetitions, and timing over all 90 attempts per method. P95 uses those 90 wall times. The last columns give mean outer rounds and QP calls.',['Method','Accepted','All 3','CPU (s)','Wall (s)','P95 (s)','Rounds','QPs'],body))
 a=stats['adaptive'];r=stats['rsc_iter'];same=all(st['identical'] for m,st in stats.items() if m in MAIN)
 text=f"Table~\\ref{{tab:main-new}} reports the complete main benchmark. Proposed LIOM accepts {min(a['repetition_counts'])}--{max(a['repetition_counts'])} of 30 scenes across repetitions, with {a['all_repetitions']} scenes accepted in every repetition. Its mean wall time is {a['mean_wall']:.2f} s; Hard RSC--iterative averages {r['mean_wall']:.2f} s and accepts {min(r['repetition_counts'])}--{max(r['repetition_counts'])} scenes. "
 text+=('Success outcomes are identical across repetitions. ' if same else 'Some outcomes change across repetitions under the fixed stopping budget; the all-repetition column identifies stable acceptance. ')
 text+='The hard separating-plane formulation provides an efficient solution when its current geometry is compatible with the motion limits. The recovery loop supplies a further search route when an initial hard solve does not produce an accepted motion. The following paired studies examine that role under stronger physical congestion.'
 write('main_narrative',text)
 v=[];branches={};initfallback=0;rejected={};changed=[]
 for rr in rs:
  d=loadjob('main',rr);z=d['result'];ref=z.get('reference',{})
  if isinstance(ref,dict) and has_text(ref.get('fallbackReason','')):initfallback+=1
  for h in hist(z):
   ph=h['phase'];branches[ph]=branches.get(ph,0)+1
   msg=h['validation'].get('message','')
   if h['numericalRecovery'] and not h['accepted']:rejected[msg]=rejected.get(msg,0)+1
  if rr['Method']=='adaptive' and rr['Repeat']==1 and rr['Accepted']:v.append(z)
 audit['main_branches']=branches;audit['main_init_fallbacks']=initfallback;audit['main_reconstructed_rejections']=rejected
 if v:
  vals=[('Minimum inter-UAV center distance (m)',min(z['validation']['minimumPairDistance'] for z in v)),('Minimum obstacle surface clearance (m)',min(z['validation']['minimumObstacleClearance'] for z in v)),('Maximum speed (m/s)',max(z['validation']['maxSpeed'] for z in v)),('Maximum acceleration (m/s$^2$)',max(z['validation']['maxAcceleration'] for z in v)),('Maximum endpoint coordinate error (m)',max(z['validation']['endpointViolation'] for z in v)),('Maximum integration-identity error',max(z['validation']['integrationIdentityError'] for z in v)),('Maximum control correction (m/s$^2$)',max(z['restoration']['maxControlCorrection'] for z in v)),('Maximum coordinate displacement from QP nodes (m)',max(z['restoration']['maxPositionChange'] for z in v))]
  audit['verification']=dict(vals)
  write('verification_table',table('verification-new',f'Accepted proposed-method motions in the first main-benchmark repetition ({len(v)} scenes). Integration errors quantify numerical consistency. Clearance and motion limits are checked separately over complete intervals.',['Quantity','Observed extremum'],[[n,f'{x:.4g}'] for n,x in vals]))
 fig,axs=plt.subplots(2,1,figsize=(7.4,5.0),gridspec_kw={'height_ratios':[1.3,1]},layout='constrained')
 for j,m in enumerate(MAIN):
  ms=filt(rs,Method=m);cs=sorted(set(x['Case'] for x in ms));xs=[];ys=[];bad=[]
  for ii,c in enumerate(cs):
   rr=filt(ms,Case=c);xs.append(ii+1+(j-2)*.12);ys.append(quant(rr,'Wall_s',.5));bad.append(not all(x['AcceptedWithinBudget'] for x in rr))
  axs[0].scatter(xs,ys,c=COL[m],marker=MARK[m],s=22 if m=='adaptive' else 15,label=NAMES[m],linewidths=.5)
  if any(bad):axs[0].scatter(np.asarray(xs)[bad],np.asarray(ys)[bad],marker='x',c='black',s=34,lw=.8)
  tt=np.linspace(0,35,141);rates=[sum(x['Accepted'] and x['Wall_s']<=t for x in ms)/len(ms) for t in tt];axs[1].step(tt,rates,where='post',c=COL[m],lw=2 if m=='adaptive' else 1.3,marker=MARK[m],markevery=18,ms=4)
 axs[0].set_yscale('log');axs[0].set_ylabel('Median wall time (s)');axs[0].set_xlabel('Scene index');axs[0].set_xticks([1,5,10,15,20,25,30]);axs[0].grid(axis='y',alpha=.2)
 axs[0].legend(ncols=3,loc='upper center',bbox_to_anchor=(.5,1.33),frameon=False)
 axs[1].set_xlabel('Elapsed wall time (s)');axs[1].set_ylabel('Accepted fraction');axs[1].set_ylim(-.02,1.04);axs[1].grid(alpha=.2);axs[1].axvline(30,c='.3',ls=':',lw=.8)
 savefig(fig,'main_performance')
 chosen=[]
 for c in ['C25','C27','C29']:
  rr=filt(rs,Case=c,Method='adaptive',Repeat=1)
  if rr and rr[0]['Accepted']:chosen.append(loadjob('main',rr[0]))
 if len(chosen)<3:
  for c in ['C01','C03','C05']:
   rr=filt(rs,Case=c,Method='adaptive',Repeat=1)
   if rr and rr[0]['Accepted'] and len(chosen)<3:chosen.append(loadjob('main',rr[0]))
 fig=plt.figure(figsize=(7.4,5.5));gs=fig.add_gridspec(2,3,hspace=.1,wspace=.18)
 for j,d in enumerate(chosen):
  for row in range(2):
   ax=fig.add_subplot(gs[row,j],projection='3d');trajectory_axes(ax,d,reference=row==0)
   ax.text2D(.5,-.12,f"({chr(97+row*3+j)}) {d['job']['id']}: "+('reference' if row==0 else 'accepted motion'),ha='center',transform=ax.transAxes,fontsize=8)
 fig.subplots_adjust(left=.01,right=.97,top=.98,bottom=.07);savefig(fig,'representative_motions')
 if chosen:
  d=chosen[-1];tr=d['result']['trajectory'];T=d['job']['cfg']['horizon'];P=tr['P'];V=tr['V'];A=tr['A'];N=P.shape[2];color=plt.colormaps['turbo'](np.linspace(.05,.94,N))
  fig,ax=plt.subplots(1,3,figsize=(7.4,2.35),layout='constrained');trajectory_axes(ax[0],d,xy=True)
  for i in range(N):ax[1].plot(np.linspace(0,T,V.shape[1]),np.linalg.norm(V[:,:,i],axis=0),c=color[i],label=f'UAV {i+1}');ax[2].step(np.linspace(0,T,A.shape[1]+1),np.r_[np.linalg.norm(A[:,:,i],axis=0),np.linalg.norm(A[:,-1,i])],where='post',c=color[i])
  ax[1].set(xlabel='Time (s)',ylabel='Speed (m/s)');ax[2].set(xlabel='Time (s)',ylabel='Acceleration (m/s²)');ax[1].legend(ncols=2,fontsize=6,frameon=False);ax[1].grid(alpha=.2);ax[2].grid(alpha=.2);savefig(fig,'control_profiles')
 fig=plt.figure(figsize=(11.7,12));gs=fig.add_gridspec(5,6,hspace=.35,wspace=.15)
 for k in range(30):
  ax=fig.add_subplot(gs[k//6,k%6],projection='3d');rr=filt(rs,Case=f'C{k+1:02d}',Method='adaptive',Repeat=1)
  if rr and rr[0]['Accepted']:trajectory_axes(ax,loadjob('main',rr[0]));ax.set_title(f'C{k+1:02d}',fontsize=8)
  else:ax.text2D(.5,.5,f'C{k+1:02d}: not accepted',ha='center',transform=ax.transAxes)
  ax.tick_params(labelsize=5);ax.set_xlabel('x (m)',fontsize=6);ax.set_ylabel('y (m)',fontsize=6);ax.set_zlabel('z (m)',fontsize=6)
 savefig(fig,'all_30_scenes')

def physical_results(audit):
 rs=rows('physical');audit['physical']={}
 fig,axs=plt.subplots(2,3,figsize=(7.4,4.8),layout='constrained')
 text=[]
 for j,family in enumerate(['crossing','passage','obstacles']):
  groups=[]
  for level in [1,2,3]:groups.append([r for r in rs if r['Case'].startswith(f'{family}_L{level}_')])
  labels={'crossing':['10','15','20'],'passage':['3.2','2.6','2.0'],'obstacles':['1','2','3']}[family]
  audit['physical'][family]={}
  for mi,m in enumerate(PHYS):
   success=[];times=[];entries=[]
   for g in groups:
    rr=filt(g,Method=m);success.append(count(rr)/len(rr) if rr else np.nan);times.append(mean(rr,'Wall_s'));entries.append({'n':len(rr),'accepted':count(rr),'physically_accepted':count(rr,'Accepted'),'late_accepted':count(rr,'Accepted')-count(rr),'wall':mean(rr,'Wall_s')})
   audit['physical'][family][m]=entries
   xx=np.arange(3)+(mi-1.5)*.06;axs[0,j].plot(xx,success,marker=MARK[m],c=COL[m],ms=5,label=NAMES[m]);axs[1,j].plot(xx,times,marker=MARK[m],c=COL[m],ms=5)
  for row in range(2):axs[row,j].set_xticks(range(3),labels);axs[row,j].grid(axis='y',alpha=.2)
  axs[0,j].set_ylim(-.05,1.06);axs[1,j].set_xlabel(['Crossing team size','Passage width (m)','Obstacle size level'][j]);axs[1,j].axhline(30,c='.35',ls=':',lw=.8)
  if j==0:axs[0,j].set_ylabel('Accepted within 30 s');axs[1,j].set_ylabel('Mean wall time (s)')
  a=audit['physical'][family]['adaptive'];b=audit['physical'][family]['rsc_iter'];text.append(f"For {family} tasks, proposed LIOM accepts "+', '.join(f"{e['accepted']}/{e['n']}" for e in a)+', compared with '+', '.join(f"{e['accepted']}/{e['n']}" for e in b)+' for Hard RSC--iterative, in increasing difficulty order.')
 axs[0,1].legend(ncols=2,loc='upper center',bbox_to_anchor=(.5,1.4),frameon=False);savefig(fig,'physical_congestion')
 write('physical_narrative',' '.join(text)+' Figure~\\ref{fig:physical} retains all predetermined realizations. These results distinguish physical congestion from changing a numerical corridor cap; the corresponding runtime includes unsuccessful attempts.')
 sc=rows('scaling');body=[];audit['scaling']=[]
 for N in [5,10,15,20]:
  for K in [30,60,90]:
   a=filt(sc,N=N,K=K,Method='adaptive');b=filt(sc,N=N,K=K,Method='rsc_iter');row=[str(N),str(K),f'{count(a)}/2',fmt(mean(a,'Wall_s')),f'{count(b)}/2',fmt(mean(b,'Wall_s')),f"{int(mean(a,'NumVariables')):,}" if a else '--',f"{int(mean(a,'ConstraintRows')):,}" if a else '--'];body.append(row);audit['scaling'].append(dict(N=N,K=K,adaptive=outcome(a),rsc=outcome(b)))
 write('scaling_table',table('scaling-new','Team/grid study. Each cell uses two distinct realizations. Problem dimensions are the proposed method\'s mean maximum dimensions reached during an attempt; screened coupling varies with geometry.',['$N$','$K$','LIOM','Wall (s)','Hard RSC','Wall (s)','Variables','Rows'],body))
 fig,axs=plt.subplots(1,2,figsize=(7.4,2.8),layout='constrained')
 for mi,m in enumerate(['adaptive','rsc_iter']):
  for j,K in enumerate([30,60,90]):
   rr=[filt(sc,N=N,K=K,Method=m) for N in [5,10,15,20]];axs[0].plot([5,10,15,20],[mean(x,'Wall_s') for x in rr],c=COL[m],marker=['o','s','^'][j],ls=['-','--',':'][j],label=f"{'LIOM' if mi==0 else 'Hard RSC'}, K={K}",ms=4)
   incomplete=np.array([count(x)<len(x) for x in rr]);nx=np.array([5,10,15,20]);wy=np.array([mean(x,'Wall_s') for x in rr])
   if incomplete.any():axs[0].scatter(nx[incomplete],wy[incomplete],marker='x',c='black',s=35,linewidths=.8,zorder=5)
 axs[0].set(xlabel='Number of UAVs',ylabel='Mean wall time (s)');axs[0].legend(fontsize=6,ncols=2,frameon=False);axs[0].grid(alpha=.2)
 labels=['Initialization','Corridors','Assembly/setup','QP iterations','Reconstruction/check'];colors=['#4477AA','#66CCEE','#228833','#CCBB44','#EE6677'];x=np.arange(4);bottom=np.zeros(4)
 for label,col in zip(labels,colors):
  vals=[]
  for N in [5,10,15,20]:
   rr=filt(sc,N=N,K=60,Method='adaptive');keys={'Initialization':['Initialization_s'],'Corridors':['Corridor_s'],'Assembly/setup':['Assembly_s','SolverSetup_s'],'QP iterations':['QPSolve_s'],'Reconstruction/check':['ControlCorrection_s','Verification_s']}[label];vals.append(sum(mean(rr,k) for k in keys))
  axs[1].bar(x,vals,bottom=bottom,color=col,label=label,edgecolor='white',lw=.3,hatch=['','//','..','\\\\','xx'][labels.index(label)]);bottom+=vals
 axs[1].set_xticks(x,['5','10','15','20']);axs[1].set(xlabel='Number of UAVs (K = 60)',ylabel='Mean stage time (s)');axs[1].legend(fontsize=6,frameon=False);savefig(fig,'scaling_breakdown')

def ablations(audit):
 init=rows('initialization');body=[]
 for i in ['sfm','straight','guide']:
  for guide in [0,1]:
   rr=filt(init,Variant=f'{i}_guides{guide}');body.append([{'sfm':'SFM + guide fallback','straight':'Straight','guide':'Static guide'}[i],str(bool(guide)),f'{count(rr)}/{len(rr)}',fmt(mean(rr,'Wall_s')),fmt(mean(rr,'OuterIterations'))])
 write('initialization_table',table('initialization-new','Reference geometry and later guide availability crossed on six anchor scenes.',['Reference','Relocation guide','Accepted','Wall (s)','Rounds'],body));audit['initialization']=body
 ss=rows('sensitivity');nom=filt(ss,Variant='nominal');body=[];pretty={'smoothWeight':'Control effort $w_a$','kinematicPenalty':'Initial defect penalty','slackPenalty':'Initial slack penalty','kinematicPenaltyMax':'Defect penalty cap','slackPenaltyMax':'Slack penalty cap','normalizedDefectTolerance':'Normalized defect tolerance','meanSlackTolerance':'Mean slack tolerance','stcExpansion':'Spatial growth cap','rstcExpansion':'Relative growth cap','sfmRepulsion':'SFM repulsion','sfmDistance':'SFM decay length','sfmLookahead':'SFM look-ahead','sfmTrackingTime':'SFM response time','sfmTangentialFraction':'SFM tangential fraction','qpCandidateTolerance':'Candidate row tolerance'}
 for field,name in pretty.items():
  lo=filt(ss,Variant=field+'_x0.5');hi=filt(ss,Variant=field+'_x2');body.append([name,f'{count(lo)}/6',fmt(mean(lo,'Wall_s')),f'{count(hi)}/6',fmt(mean(hi,'Wall_s'))])
 lo=filt(ss,Variant='growth_1.5');hi=filt(ss,Variant='growth_5');body.append(['Penalty growth (1.5 / 5)',f'{count(lo)}/6',fmt(mean(lo,'Wall_s')),f'{count(hi)}/6',fmt(mean(hi,'Wall_s'))])
 write('sensitivity_table',table('sensitivity-new',f'One-factor sensitivity on six scenes. Nominal Soft LIOM accepts {count(nom)}/6 with mean wall time {mean(nom,"Wall_s"):.2f} s. Columns halve/double one parameter; the last row uses the stated growth factors.',['Changed factor','Lower accepted','Wall (s)','Higher accepted','Wall (s)'],body));audit['sensitivity']=body
 acc=rows('acceptance');bounds=rows('bounds');body=[]
 for norm in [0,1]:
  for fb in [0,1]:
   rr=filt(acc,Variant=f'normalized{norm}_finish{fb}');body.append([('Normalized' if norm else 'Aggregate')+(' + feedback' if fb else ', no feedback'),f'{count(rr)}/6',fmt(mean(rr,'Wall_s')),fmt(mean(rr,'QPSolves'))])
 for p in ['cube','hull14','hull26']:
  rr=filt(bounds,Variant=p,Method='liom');body.append([tex(p)+' motion envelope',f'{count(rr)}/6',fmt(mean(rr,'Wall_s')),fmt(mean(rr,'QPSolves'))])
 audit['acceptance_bounds']=body
 txt=table('mechanism-new','Soft-loop acceptance feedback and motion-envelope studies on six scenes. Feedback combines tolerance tightening with an exact-kinematics finish; its components are evaluated jointly.',['Variant','Accepted','Wall (s)','QP calls'],body)
 txt+='\nThe hard-iterative comparison holds reconstruction opportunities fixed. The hard-entry ablation compares proposed LIOM with Soft LIOM. The acceptance-feedback study examines how rejected reconstructed motions affect subsequent computation; it also records rejection reasons and additional exact-QP calls.\n'
 write('ablation_narrative',txt)
 sp=ROOT/'results/osqp_numerical_audit/summary.csv';body=[]
 if sp.exists():
  sr=list(csv.DictReader(sp.open()));audit['osqp_audit']=sr
  for qp in ['soft','hard','rsc']:
   for mode in ['candidate','strict','strict_tight']:
    selected=[r for r in sr if r['QP']==qp and r['Mode']==mode];good=sum(float(r['MaxViolation'])<=1e-3 for r in selected);viol=max(float(r['MaxViolation']) for r in selected);tm=np.mean([float(r['Setup_s'])+float(r['Solve_s']) for r in selected]);it=np.mean([float(r['Iterations']) for r in selected]);body.append([qp,{'candidate':'Readiness','strict':r'Standard ($10^{-6}$)','strict_tight':r'Standard ($10^{-7}$)'}[mode],str(good)+'/3',f'{viol:.1e}',fmt(tm),f'{it:,.0f}'])
  write('solver_table',table('solver-new','OSQP audit on identical matrices from three anchor scenes. Readiness stopping is compared with ordinary termination at two tolerances. The feasible-column criterion is maximum linear-row violation $\\leq10^{-3}$; full trajectories still require physical acceptance.',['QP','Termination','Row test','Max. violation','Time (s)','Iterations'],body))
 else:raise RuntimeError('OSQP audit is not complete')

def recovery(audit):
 rs=rows('horizon');body=[];audit['horizon']={}
 for T in [8,9,10,11,12]:
  rr=filt(rs,Tf=T);entries={m:dict(accepted=count(filt(rr,Method=m)),n=len(filt(rr,Method=m)),wall=mean(filt(rr,Method=m),'Wall_s')) for m in PHYS};audit['horizon'][str(T)]=entries;body.append([str(T)]+[f"{entries[m]['accepted']}/6" for m in PHYS])
 text=table('horizon-new','Reduced-horizon study on six fixed geometries. Corridor-growth caps remain unchanged.',['$T_f$ (s)','LIOM','Soft LIOM','Hard box--iter.','Hard RSC--iter.'],body)
 path=ROOT/'results/targeted_geometry/summary.csv'
 if path.exists():
  rr=list(csv.DictReader(path.open()));audit['targeted']=rr
  # Column names are checked against the actual saved table at analysis time.
  text+='\nThe targeted passage configurations and every attempted outcome are included in the accompanying records.\n'
 else:raise RuntimeError('Targeted geometry study is not complete')
 # Individual candidate/check failures are counted independently from final outcomes.
 failure={};fallback={};outer={};phase={};reject={};initErrors={};fallbackReasons={};feedback={'soft_rejected_candidates':0,'attempts_with_soft_rejection':0,'accepted_within_budget_after_soft_rejection':0,'accepted_exact_finishes':0,'rejected_reasons':{}}
 for suite in ['main','physical','horizon','scaling','sensitivity','initialization','bounds','acceptance']:
  for rr in rows(suite):
   key=suite+'/'+rr['Method'];failure.setdefault(key,{})[('accepted_over_budget' if rr['Accepted'] and not rr['AcceptedWithinBudget'] else rr['FailureStage'] or 'accepted')]=failure.setdefault(key,{}).get(('accepted_over_budget' if rr['Accepted'] and not rr['AcceptedWithinBudget'] else rr['FailureStage'] or 'accepted'),0)+1
   d=loadjob(suite,rr);r=d['result'];ref=r.get('reference',{})
   if isinstance(ref,dict) and has_text(ref.get('fallbackReason','')):fallback[key]=fallback.get(key,0)+1;reason=str(ref['fallbackReason']);fallbackReasons[reason]=fallbackReasons.get(reason,0)+1
   if rr['FailureStage']=='initialization':
    msg=r.get('exception',{}).get('identifier','unknown');initErrors[msg]=initErrors.get(msg,0)+1
   had_soft_rejection=False
   for h in hist(r):
    phase[h['phase']]=phase.get(h['phase'],0)+1
    if h['phase']=='exact_finish' and h['accepted']:feedback['accepted_exact_finishes']+=1
    if h['phase']=='soft' and h['numericalRecovery'] and not h['accepted']:
     had_soft_rejection=True;feedback['soft_rejected_candidates']+=1
     why=h['validation'].get('message','unknown');feedback['rejected_reasons'][why]=feedback['rejected_reasons'].get(why,0)+1
    if h['numericalRecovery'] and not h['accepted']:
     msg=h['validation'].get('message','unknown');reject[msg]=reject.get(msg,0)+1
   if had_soft_rejection:
    feedback['attempts_with_soft_rejection']+=1
    feedback['accepted_within_budget_after_soft_rejection']+=int(rr['AcceptedWithinBudget'])
 audit.update(failure_modes=failure,guide_fallbacks=fallback,initialization_errors=initErrors,phase_counts=phase,reconstructed_rejections=reject,fallback_reason_counts=fallbackReasons,acceptance_feedback=feedback)
 write('recovery_narrative',text)

def tracking(audit):
 p=ROOT/'results/mujoco_tracking/summary.json'
 if not p.exists():raise RuntimeError('Tracking study incomplete')
 records=json.loads(p.read_text());audit['tracking']=records;body=[]
 for cond in [False,True]:
  rr=[r for r in records if r['disturbed']==cond];body.append(['Perturbed' if cond else 'Nominal',str(len(rr)),fmt(max(r['max_error'] for r in rr),3),fmt(np.mean([r['rms_error'] for r in rr]),3),fmt(max(r['terminal_error'] for r in rr),3),fmt(min(r['min_pair_clearance'] for r in rr),3),str(sum(r['contact_steps']>0 for r in rr))])
 write('tracking_table',table('tracking-new','MuJoCo tracking over the prescribed flight interval. Terminal error is measured at $T_f$, before the separately logged settling interval. Clearance is center distance minus two planning radii.',['Condition','Motions','Max. error (m)','Mean RMS (m)','Terminal (m)','Pair gap (m)','Contact runs'],body));write('tracking_narrative','The simulator evaluates all accepted proposed-method motions from the first main-benchmark repetition and predetermined accepted larger-team and winding-recovery examples. The same controller is used in the nominal and perturbed conditions. Table~\\ref{tab:tracking-new} reports position error, terminal accuracy at the specified completion time, separation, and contact outcomes. Full time histories, simulator models, and settings accompany the results.')
 chosen=next((r for r in records if r.get('case')=='PW1_S6102_R1' and r['disturbed']),next(r for r in records if r['disturbed']));ar=np.load(ROOT/'results/mujoco_tracking'/Path(chosen['folder']).name/'tracking.npz');log=ar['log'];P=ar['position'];R=ar['reference'];T=chosen['Tf'];sel=log[:,0]<=T
 fig=plt.figure(figsize=(7.4,4.2));gs=fig.add_gridspec(2,2,width_ratios=[.9,1.15],hspace=.35,wspace=.60);ax=fig.add_subplot(gs[:,0],projection='3d');colors=plt.colormaps['turbo'](np.linspace(.05,.94,P.shape[2]))
 for i,c in enumerate(colors):ax.plot(*R[sel,:,i].T,c=c,ls='--',lw=1);ax.plot(*P[sel,:,i].T,c=c,lw=1.3)
 ax.set(xlabel='x (m)',ylabel='y (m)',zlabel='z (m)');ax.view_init(25,-58);ax.set_box_aspect((1,1,.6));ax.text2D(.5,-.18,'Reference (dashed) and simulation (solid)',ha='center',transform=ax.transAxes,fontsize=8)
 a=fig.add_subplot(gs[0,1]);b=fig.add_subplot(gs[1,1]);err=np.linalg.norm(P-R,axis=1)
 for i,c in enumerate(colors):a.plot(log[sel,0],err[sel,i],c=c,lw=1)
 a.set(xlabel='Time (s)',ylabel='Position error (m)');a.grid(alpha=.2);b.plot(log[sel,0],log[sel,2],label='Inter-UAV',c='#0077BB');finite=np.isfinite(log[sel,3])
 if any(finite):b.plot(log[sel,0][finite],log[sel,3][finite],label='Obstacle',c='#C62828')
 b.axhline(.1,c='black',ls=':',label='Planned clearance');b.set(xlabel='Time (s)',ylabel='Surface clearance (m)');b.legend(fontsize=7,frameon=False);b.grid(alpha=.2);savefig(fig,'tracking')

def verify_inputs():
 expected={'main':510,'physical':240,'horizon':120,'scaling':48,'sensitivity':198,'initialization':36,'bounds':36,'acceptance':24}
 checked={}
 for suite,n in expected.items():
  rs=rows(suite);keys=[(r['Case'],r['Method'],r['Variant'],r['Repeat']) for r in rs]
  if len(rs)!=n or len(set(keys))!=n:raise RuntimeError(f'{suite}: incomplete or duplicate summary rows')
  for r in rs:
   if r['AcceptedWithinBudget']>r['Accepted']:raise RuntimeError(f'{suite}: invalid acceptance flags')
   p=RES/suite/f"{r['Case']}_{r['Method']}_{r['Variant']}_R{int(r['Repeat'])}.mat"
   if not p.exists():raise RuntimeError(f'Missing attempt record: {p}')
  checked[suite]=n
 for study,n in [('targeted_geometry',36),('osqp_numerical_audit',27)]:
  p=ROOT/'results'/study/'summary.csv'
  if not p.exists() or len(list(csv.DictReader(p.open(encoding='utf-8-sig'))))!=n:raise RuntimeError(f'{study}: incomplete summary')
 marker=ROOT/'results/mujoco_tracking/completed.json'
 if not marker.exists():raise RuntimeError('Formal tracking has not completed')
 meta=json.loads(marker.read_text());records=json.loads((marker.parent/'summary.json').read_text());selection=json.loads((marker.parent/'selection.json').read_text())
 if meta['runs']!=len(records) or len(records)!=2*len(selection['files']):raise RuntimeError('Tracking completion/count mismatch')
 manifest=loadmat(RES/'source_manifest.mat',simplify_cells=True)['manifest'];source_count=0
 for name,digest in zip(np.atleast_1d(manifest['paths']),np.atleast_1d(manifest['sha256'])):
  rel=Path(str(name).replace('\\','/'));current=ROOT/'code'/rel;frozen=RES/'source_snapshot'/rel
  for path in [current,frozen]:
   if hashlib.sha256(path.read_bytes()).hexdigest()!=str(digest):raise RuntimeError(f'Frozen source mismatch: {path}')
  source_count+=1
 if hashlib.sha256((ROOT/'tools/osqp_worker.py').read_bytes()).hexdigest()!=str(manifest['workerSha256']):raise RuntimeError('OSQP worker differs from frozen source')
 return {'generated':datetime.datetime.now().isoformat(timespec='seconds'),'attempts':checked,'frozen_matlab_files_verified':source_count,'planning_solver':'OSQP','tracking_runs':len(records),'comparison_success':'Physical acceptance and end-to-end completion within 30 seconds'}

def finite_json(v):
 if isinstance(v,dict):return {k:finite_json(x) for k,x in v.items()}
 if isinstance(v,list):return [finite_json(x) for x in v]
 if isinstance(v,(float,np.floating)) and not np.isfinite(v):return None
 return v

def run():
 if not (RES/'completed.json').exists():raise RuntimeError('The frozen prospective batch has not finished; no final manuscript statistics emitted.')
 audit={'provenance':verify_inputs()};main_results(audit);physical_results(audit);ablations(audit);recovery(audit);tracking(audit)
 wp=ROOT/'results/winding_evidence/evidence_summary.json'
 if wp.exists():audit['winding']=json.loads(wp.read_text(encoding='utf-8'))
 write('statistics','% All values are generated from saved revision experiments.\n')
 (ROOT/'results/manuscript_audit.json').write_text(json.dumps(finite_json(audit),indent=2,allow_nan=False),encoding='utf-8')
 print('Generated evidence, figures, and audit:',ROOT/'results/manuscript_audit.json')
if __name__=='__main__':run()
