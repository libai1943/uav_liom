function FinalExternalSelftest()
r=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(r,'code'));addpath(fullfile(r,'comparisons_20261031'));addpath('C:/casadi');
c=RevisionConfig();c.numAgents=2;c.intervals=20;c.horizon=8;StartOSQP(c);
s=struct('starts',[-1,-1;-2,2;1,1],'exits',[1,1;-2,2;1,1],...
 'v0',zeros(3,2),'vf',zeros(3,2),'bounds',[-10,-10,0;10,10,5],'obstacles',zeros(0,6));
t=linspace(0,1,c.intervals+1);ref=struct('P',zeros(3,c.intervals+1,2),'V',zeros(3,c.intervals+1,2),'seconds',0,'cpuSeconds',0);
for i=1:2
 ref.P(:,:,i)=s.starts(:,i)+(s.exits(:,i)-s.starts(:,i)).*(3*t.^2-2*t.^3);
 ref.V(:,:,i)=(s.exits(:,i)-s.starts(:,i)).*(6*t-6*t.^2)/c.horizon;
end
opts=c;opts.availableSeconds=10;
[qp,qi]=external_v2.subproblem(ref,s,opts,'asco',[100,101],struct('linearSolver','mumps'));
assert(strcmp(qi.backend,'osqp')&&qi.finite&&qi.maxConstraintViolation<1e-3);
[motion,~]=bu3d.executable(qp,s,c);check=bu3d.validate(motion,s,c);assert(check.success);
[nonlinear,ni]=external_v2.subproblem(ref,s,opts,'nlp',[-inf,inf],struct('linearSolver','mumps'));
assert(strcmp(ni.backend,'ipopt')&&ni.finite&&ni.maxConstraintViolation<1e-5);
[motion,~]=bu3d.executable(nonlinear,s,c);check=bu3d.validate(motion,s,c);assert(check.success);
assert(abs(ni.optimizedObjective-qi.optimizedObjective)<1e-5);
[sc,si]=normscp.subproblem(ref,s,opts,'scp',[-inf,inf],struct('linearSolver','mumps'));
assert(strcmp(si.backend,'osqp')&&si.finite&&si.maxConstraintViolation<1e-3);
[motion,~]=bu3d.executable(sc,s,c);check=bu3d.validate(motion,s,c);assert(check.success);
assert(abs(si.optimizedObjective-qi.optimizedObjective)<1e-5);
save(fullfile(r,'results','final_external_selftest_20261031.mat'),'c','s','ref','qi','ni','si','check');
fprintf('SELFTEST PASS: hard kinematics; same hull14; QP=OSQP NLP=Ipopt; analytic effort %.9f vs %.9f\n',qi.optimizedObjective,ni.optimizedObjective);
end
