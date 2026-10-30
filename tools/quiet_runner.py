"""Serial low-load experiment coordinator; waiting is outside planning timers."""
from pathlib import Path
import argparse,ctypes,datetime,hashlib,json,os,subprocess,sys,threading,time,traceback
ROOT=Path(__file__).resolve().parents[1];TMP=ROOT/'tmp';RES=ROOT/'results'
TMP.mkdir(exist_ok=True);RES.mkdir(exist_ok=True)
class FT(ctypes.Structure):_fields_=[('lo',ctypes.c_uint32),('hi',ctypes.c_uint32)]
def ticks():
 a,b,c=FT(),FT(),FT();assert ctypes.windll.kernel32.GetSystemTimes(ctypes.byref(a),ctypes.byref(b),ctypes.byref(c))
 val=lambda x:(x.hi<<32)|x.lo
 return val(a),val(b)+val(c)
def cpu(interval=1):
 a=ticks();time.sleep(interval);b=ticks();total=b[1]-a[1]
 return 100*max(0,1-(b[0]-a[0])/max(1,total))
def put(path,obj):
 temp=path.with_suffix(path.suffix+'.tmp');temp.write_text(json.dumps(obj,indent=2),encoding='utf-8');os.replace(temp,path)
def permission():
 try:
  p=json.loads((TMP/'other_tasks_clear.json').read_text());return p.get('allowed',False) and time.time()-p['checked_unix']<1800
 except (OSError,ValueError,KeyError):return False
def gate(seconds):
 low=0;start=time.time()
 while low<seconds:
  busy=cpu();allowed=permission();low=low+1 if allowed and busy<=12 else 0
  put(TMP/'gate_status.json',dict(allowed=allowed,cpu_percent=round(busy,2),quiet_seconds=low,required_seconds=seconds,updated=time.time()))
 with (RES/'load_gate.csv').open('a',encoding='utf-8') as f:f.write(f'{time.time():.3f},{time.time()-start:.3f},{busy:.3f},{seconds}\n')
def source_manifest():
 paths=[]
 for folder in ['code','experiments','comparisons']:
  paths+=list((ROOT/folder).rglob('*.m'))
 paths+=[ROOT/'RunMe.m',ROOT/'RunExperiments.m',ROOT/'tools/osqp_worker.py',ROOT/'tools/quiet_runner.py']
 return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}
def state(stage,**more):
 file=RES/'pipeline_state.json'
 try:d=json.loads(file.read_text())
 except (OSError,ValueError):d={}
 d.update(stage=stage,updated=datetime.datetime.now().isoformat(timespec='seconds'),**more);put(file,d)
def alive(pid):
 k=ctypes.windll.kernel32;k.OpenProcess.restype=ctypes.c_void_p
 h=k.OpenProcess(0x1000,False,pid)
 if not h:return False
 code=ctypes.c_uint32();ok=k.GetExitCodeProcess(ctypes.c_void_p(h),ctypes.byref(code));k.CloseHandle(ctypes.c_void_p(h))
 return bool(ok and code.value==259)
def run():
 lock=TMP/'quiet_runner.pid'
 if lock.exists() and alive(int(lock.read_text())):raise RuntimeError('Another coordinator is already running')
 lock.write_text(str(os.getpid()))
 for key in ['OMP_NUM_THREADS','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS']:os.environ[key]='1'
 for key in ['TEMP','TMP']:os.environ[key]=str(TMP)
 os.environ['PYTHONUTF8']='1';os.environ['PYTHONDONTWRITEBYTECODE']='1';os.environ['UAV_PYTHON']=sys.executable
 os.environ['PYTHONPATH']=str(ROOT/'python_packages')+os.pathsep+os.environ.get('PYTHONPATH','')
 (TMP/'managed_timing').write_text('CPU and other-task gating enabled.\n')
 freeze=RES/'source_manifest.json';current=source_manifest()
 if freeze.exists():assert json.loads(freeze.read_text())==current,'Source changed after freezing'
 else:put(freeze,current)
 try:
  state('waiting_for_low_load',runner_pid=os.getpid(),source_frozen=True)
  gate(300)
  stop=threading.Event()
  def monitor():
   with (RES/'cpu_telemetry.csv').open('a',encoding='utf-8') as f:
    while not stop.is_set():
     value=cpu(2);f.write(f'{time.time():.3f},{value:.3f}\n');f.flush()
  thread=threading.Thread(target=monitor,daemon=True);thread.start()
  def execute(command,log,phase):
   assert source_manifest()==current,'Frozen numerical source mismatch'
   state(phase,runner_pid=os.getpid())
   with (RES/log).open('a',encoding='utf-8') as f:
    cp=subprocess.Popen(command,cwd=ROOT,env=os.environ,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    state(phase,runner_pid=os.getpid(),child_pid=cp.pid);code=cp.wait()
   if code:raise RuntimeError(f'{phase} returned {code}; see {log}')
  matlab=os.environ.get('UAV_MATLAB',r'D:/Program Files/MATLAB/R2021b/bin/matlab.exe')
  execute([matlab,'-batch',"maxNumCompThreads(1); RunExperiments"],'planning_console.txt','serial_experiments')
  execute([sys.executable,'-u',str(ROOT/'simulation/run_tracking.py')],'tracking_console.txt','tracking')
  execute([sys.executable,'-u',str(ROOT/'tools/winding_evidence.py')],'winding_figures_console.txt','figures')
  execute([sys.executable,'-u',str(ROOT/'tools/analyze_revision.py')],'analysis_console.txt','analysis')
  stop.set();thread.join(timeout=3)
  state('ready_for_manuscript_sync',runner_pid=os.getpid(),child_pid=None)
 except Exception:
  state('needs_attention',error=traceback.format_exc(),runner_pid=os.getpid());raise
 finally:lock.unlink(missing_ok=True)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--gate',action='store_true');p.add_argument('--seconds',type=int,default=2);p.add_argument('--sample',action='store_true');a=p.parse_args()
 if a.sample:print(json.dumps({'cpu_percent':cpu(),'permission':permission()}))
 elif a.gate:gate(a.seconds)
 else:run()
