"""Six-DOF multirotor tracking in MuJoCo. No physical-flight claim.
Four bounded rotor forces, motor lag, inertia, gravity, drag, and contact geometry.
"""
import os,sys,json,argparse,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'python_packages'))
os.environ.setdefault('MPLCONFIGDIR',str(ROOT/'tmp/mpl'))
import numpy as np
import mujoco
from scipy.io import loadmat
PARAM=dict(mass=1.,inertia=[.006,.006,.010],arm=.14,rotor_max=5.,motor_tau=.02,
           drag=.04,dt=.002,kp=9.,kd=6.,ki=2.,kR=.8,kw=.16,yaw_torque=.015)
def model_xml(starts,obstacles,radius,disturbed=False):
    N=starts.shape[1];a=PARAM['arm'];mass=PARAM['mass']*(1.1 if disturbed else 1.)
    tau=PARAM['motor_tau']*(1.5 if disturbed else 1.)
    bodies=[];acts=[]
    for i in range(N):
        p=' '.join(map(str,starts[:,i]));color=f'{.2+.6*(i%3==0)} {.2+.6*(i%3==1)} {.2+.6*(i%3==2)} 1'
        sites=[]
        for j,(x,y) in enumerate([(a,a),(-a,a),(-a,-a),(a,-a)]):
            sites.append(f'<site name="r{i}_{j}" pos="{x} {y} 0" size=".035" rgba="{color}"/>')
            acts.append(f'<general name="m{i}_{j}" site="r{i}_{j}" gear="0 0 1 0 0 {PARAM["yaw_torque"]*(-1)**j}" dyntype="filterexact" dynprm="{tau}" ctrllimited="true" ctrlrange="0 {PARAM["rotor_max"]}"/>')
        bodies.append(f'<body name="uav{i}" pos="{p}"><freejoint/><inertial pos="0 0 0" mass="{mass}" diaginertia=".006 .006 .010"/><geom name="footprint{i}" type="sphere" size="{radius}" rgba="{color}"/>'+''.join(sites)+'</body>')
    for j,o in enumerate(np.asarray(obstacles).reshape(-1,6)):
        center=(o[:3]+o[3:])/2;half=(o[3:]-o[:3])/2
        bodies.append(f'<geom name="obstacle{j}" type="box" pos="'+ ' '.join(map(str,center))+'" size="'+' '.join(map(str,half))+'" rgba=".5 .52 .55 1"/>')
    return '<mujoco model="cooperative_multirotor"><option timestep=".002" gravity="0 0 -9.81" integrator="implicitfast"/><visual><global offwidth="1600" offheight="1000"/></visual><worldbody><light pos="0 0 15"/><geom type="plane" size="25 25 .1" rgba=".92 .92 .92 1"/>'+''.join(bodies)+'</worldbody><actuator>'+''.join(acts)+'</actuator></mujoco>'
def desired(P,V,A,T,t):
    K=A.shape[1];h=T/K;k=min(K-1,max(0,int(t/h)));tau=min(h,max(0,t-k*h))
    if t>=T:return P[:,-1,:],V[:,-1,:],np.zeros_like(A[:,0,:])
    return P[:,k,:]+tau*V[:,k,:]+.5*tau*tau*A[:,k,:],V[:,k,:]+tau*A[:,k,:],A[:,k,:]
def vee(M):return np.array([M[2,1],M[0,2],M[1,0]])
def simulate(P,V,A,T,scene,radius,disturbed=False,render_path=None):
    if P.ndim==2:P=P[:,:,None];V=V[:,:,None];A=A[:,:,None]
    N=P.shape[2];dt=PARAM['dt'];xml=model_xml(P[:,0,:],scene['obstacles'],radius,disturbed)
    model=mujoco.MjModel.from_xml_string(xml);data=mujoco.MjData(model)
    data.act[:]=PARAM['mass']*9.81/4;data.ctrl[:]=data.act;mujoco.mj_forward(model,data)
    ids=[model.body(f'uav{i}').id for i in range(N)];integ=np.zeros((3,N));previous=[np.eye(3) for _ in range(N)]
    arm=PARAM['arm'];mix=np.array([[1,1,1,1],[arm,arm,-arm,-arm],[-arm,arm,arm,-arm],[.015,-.015,.015,-.015]])
    inverse=np.linalg.inv(mix);obs=np.asarray(scene['obstacles']).reshape(-1,6);logs=[];positions=[];refs=[];velocities=[];quats=[];motors=[]
    phase=np.random.default_rng(2026).uniform(0,2*np.pi,(3,N));contact_steps=0;image_done=False
    for step in range(int(round((T+2)/dt))+1):
        t=step*dt;pr,vr,ar=desired(P,V,A,T,t)
        actual=np.stack([data.xpos[b].copy() for b in ids],axis=1);vel=np.stack([data.qvel[6*i:6*i+3].copy() for i in range(N)],axis=1)
        error=pr-actual;integ=np.clip(integ+dt*error,-1.,1.)
        for i,b in enumerate(ids):
            R=data.xmat[b].reshape(3,3);omega=data.qvel[6*i+3:6*i+6]
            force=PARAM['mass']*(ar[:,i]+PARAM['kp']*error[:,i]+PARAM['kd']*(vr[:,i]-vel[:,i])+PARAM['ki']*integ[:,i]+np.array([0,0,9.81]))
            z=force/np.linalg.norm(force);y=np.cross(z,[1.,0,0]);y=y/np.linalg.norm(y);Rd=np.column_stack([np.cross(y,z),y,z])
            wd=np.clip(vee(previous[i].T@Rd-Rd.T@previous[i])/(2*dt),-8,8);previous[i]=Rd
            er=vee(Rd.T@R-R.T@Rd)/2;ew=omega-R.T@Rd@wd
            torque=-PARAM['kR']*er-PARAM['kw']*ew+np.cross(omega,np.array(PARAM['inertia'])*omega)
            thrust=max(0,force@R[:,2]);data.ctrl[4*i:4*i+4]=np.clip(inverse@np.r_[thrust,torque],0,PARAM['rotor_max'])
            wind=.15*np.sin(1.5*t+phase[:,i]) if disturbed else 0.
            data.xfrc_applied[b,:3]=-PARAM['drag']*vel[:,i]+wind
        pair=min((np.linalg.norm(actual[:,i]-actual[:,j])-2*radius for i in range(N) for j in range(i)),default=np.inf)
        oc=min((np.linalg.norm(np.maximum(np.maximum(o[:3]-actual[:,i],actual[:,i]-o[3:]),0))-radius for o in obs for i in range(N)),default=np.inf)
        logs.append([t,float(np.linalg.norm(error,axis=0).max()),pair,oc,data.ncon]);positions.append(actual);refs.append(pr);velocities.append(vel);quats.append(data.qpos.reshape(N,7)[:,3:].copy());motors.append(data.act.copy())
        if t<=T and data.ncon:contact_steps+=1
        if render_path and not image_done and t>=T*.5:
            renderer=mujoco.Renderer(model,height=1000,width=1600);cam=mujoco.MjvCamera();cam.lookat[:]=[0,0,3.5];cam.distance=23;cam.azimuth=125;cam.elevation=-25;renderer.update_scene(data,camera=cam)
            from PIL import Image
            Image.fromarray(renderer.render()).save(render_path);renderer.close();image_done=True
        mujoco.mj_step(model,data)
    logs=np.asarray(logs);positions=np.asarray(positions);refs=np.asarray(refs);flight=logs[:,0]<=T+1e-9;error=np.linalg.norm(positions-refs,axis=1)
    result=dict(max_error=float(error[flight].max()),rms_error=float(np.sqrt((error[flight]**2).mean())),terminal_error=float(error[np.argmin(abs(logs[:,0]-T))].max()),settled_error=float(error[-1].max()),min_pair_clearance=float(logs[flight,2].min()),min_obstacle_clearance=float(logs[flight,3].min()),contact_steps=contact_steps,disturbed=disturbed,N=N,Tf=T)
    return result,dict(log=logs,position=positions,reference=refs,velocity=np.asarray(velocities),quaternion=np.asarray(quats),rotor_force=np.asarray(motors)),xml
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--input');parser.add_argument('--output',required=True);parser.add_argument('--disturbed',action='store_true');parser.add_argument('--render',action='store_true');parser.add_argument('--hover-test',action='store_true');args=parser.parse_args();out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
    if args.hover_test:
        P=np.tile(np.array([0.,0,3.])[:,None],(1,3));V=np.zeros_like(P);A=np.zeros((3,2));T=1.;scene={'obstacles':np.zeros((0,6))};radius=.25
    else:
        d=loadmat(args.input,simplify_cells=True);result=d.get('result',d.get('r'));job=d.get('job',{});scene=job.get('scene',d.get('s'));cfg=job.get('cfg',d.get('c'));trajectory=result['trajectory'];P=trajectory['P'];V=trajectory['V'];A=trajectory['A'];T=cfg['horizon'];radius=cfg['radius']
    metric,arrays,xml=simulate(P,V,A,T,scene,radius,args.disturbed,str(out/'simulator.png') if args.render else None)
    (out/'model.xml').write_text(xml);(out/'metrics.json').write_text(json.dumps(metric,indent=2));(out/'settings.json').write_text(json.dumps(dict(parameters=PARAM,mujoco=mujoco.__version__,source=args.input),indent=2));np.savez_compressed(out/'tracking.npz',**arrays);print(json.dumps(metric),flush=True)
    if args.hover_test:assert metric['max_error']<1e-8,'Hover equilibrium test failed'
