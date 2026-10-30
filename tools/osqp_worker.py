"""Local, persistent OSQP service; transport overhead remains in planning wall time."""
import os, sys, json, socketserver, time, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'python_packages'))
os.environ.setdefault('OMP_NUM_THREADS','1')
os.environ.setdefault('OPENBLAS_NUM_THREADS','1')
import numpy as np
import scipy.sparse as sp
from scipy.io import loadmat, savemat
import osqp
class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        for line in self.rfile:
            try:
                req=json.loads(line)
                if req.get('ping'):
                    reply={'version':osqp.__version__,'root':str(ROOT)}
                else:
                    path=Path(req['path']).resolve()
                    if not path.is_relative_to(ROOT): raise ValueError('Exchange path outside project')
                    start=time.perf_counter(); cpu=time.process_time(); d=loadmat(path)
                    H=sp.csc_matrix(d['H']); C=sp.csc_matrix(d['C']); n=H.shape[0]
                    A=sp.vstack([C,sp.eye(n,format='csc')],format='csc')
                    l=np.r_[d['lower'].ravel(),d['lb'].ravel()]; u=np.r_[d['upper'].ravel(),d['ub'].ravel()]
                    qp=osqp.OSQP()
                    qp.setup(P=sp.triu(H,format='csc'),q=d['g'].ravel(),A=A,l=l,u=u,
                        verbose=False,eps_abs=float(d['tolerance'].item()),eps_rel=float(d['tolerance'].item()),
                        max_iter=int(d['chunk'].item()),time_limit=float(d['timeLimit'].item()),rho=float(d['rho'].item()),
                        polishing=True,adaptive_rho_interval=50,check_termination=25)
                    qp.warm_start(x=d['x0'].ravel())
                    setup=time.perf_counter()-start; ts=time.perf_counter(); iterations=0; outcome=None
                    cap=float(d['timeLimit'].item()); maxiter=int(d['maxIterations'].item())
                    while True:
                        z=qp.solve(raise_error=False); iterations+=z.info.iter
                        w=z.x; finite=w is not None and np.isfinite(w).all() and abs(w).max()<1e6
                        if finite:
                            violation=max(0.,float(np.max(l-A@w)),float(np.max(A@w-u)))
                            defect=float(np.square(d['F']@w+d['fshift'].ravel()).sum())
                            ids=d['slackIds'].astype(int).ravel()-1
                            slack=float(np.maximum(w[ids],0).sum())
                            recovered=not bool(d['soft'].item()) or (defect<=float(d['defectLimit'].item()) and slack<=float(d['slackLimit'].item()))
                            if bool(d['feasibilityStop'].item()) and violation<=float(d['hardTolerance'].item()) and recovered:
                                outcome='feasible candidate'; break
                        if z.info.status_val in (1,2,3,4,5,6,9): break
                        remain=cap-(time.perf_counter()-ts)-setup
                        if remain<=.002 or iterations>=maxiter: break
                        qp.update_settings(time_limit=remain)
                    elapsed=time.perf_counter()-ts
                    reply={'status':outcome or z.info.status,'success':outcome is not None or z.info.status_val in (1,2),
                        'iterations':iterations,'setupSeconds':setup,'solveSeconds':elapsed,
                        'cpuSeconds':time.process_time()-cpu,'primalResidual':z.info.prim_res,
                        'dualResidual':z.info.dual_res,'version':osqp.__version__}
                    out=path.with_suffix('.out.mat'); savemat(out,{'x':z.x,'y':z.y})
                    reply['output']=str(out)
                self.wfile.write((json.dumps(reply)+'\n').encode()); self.wfile.flush()
            except Exception as exc:
                self.wfile.write((json.dumps({'error':str(exc),'traceback':traceback.format_exc()})+'\n').encode()); self.wfile.flush()
class Server(socketserver.TCPServer): allow_reuse_address=True
if __name__=='__main__':
    port=int(sys.argv[1]) if len(sys.argv)>1 else 19277
    print('OSQP',osqp.__version__,'ready on localhost',port,flush=True)
    with Server(('127.0.0.1',port),Handler) as server: server.serve_forever()
