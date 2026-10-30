function [candidate,info]=qp(m,c)
% All convex planning QPs use the dedicated OSQP backend.
assert(strcmp(c.qpBackend,'osqp'),'REV:Backend','Only OSQP is supported.');
clock=tic; cpu0=cputime; n=numel(m.free); candidate=[];
info=struct('status','NOT_RUN','solverSuccess',false,'finite',false,'violation',Inf,...
    'D',Inf,'S',Inf,'normalizedD',Inf,'meanSlack',Inf,'buildSeconds',0,'solveSeconds',0,...
    'cpuSeconds',0,'variables',n,'rows',size(m.C,1),'nonzeros',nnz(m.C)+nnz(m.H),...
    'solverIterations',NaN,'backend',c.qpBackend,'objective',NaN);
if m.inconsistent, info.status='INCONSISTENT_FIXED_ROW'; return; end
scale=1;
if strcmp(c.qpObjectiveScale,'max'), scale=max([1;abs(nonzeros(m.H));abs(m.g)]); end
    [answer,transport]=revision.osqpSolve(m,c,scale);
    info.buildSeconds=answer.setupSeconds+transport; info.solveSeconds=answer.solveSeconds;
    stats=struct('return_status',answer.status,'success',answer.success,'iter_count',answer.iterations);
    z=struct('x',answer.x); info.workerCpuSeconds=answer.cpuSeconds;
info.cpuSeconds=cputime-cpu0;
if isfield(info,'workerCpuSeconds'), info.cpuSeconds=info.cpuSeconds+info.workerCpuSeconds; end
info.status=stats.return_status; info.solverSuccess=stats.success; info.solverStatistics=stats;
if isfield(stats,'iter_count')&&stats.iter_count>=0, info.solverIterations=stats.iter_count; end
if isfield(stats,'qp_iteration_count'), info.solverIterations=stats.qp_iteration_count; end
w=nan(m.nx,1); w(m.free)=full(z.x); w(m.fixed)=m.fixedValues;
info.finite=all(isfinite(w))&&max(abs(w))<1e10;
if ~info.finite, return; end
cv=m.fullC*w;
info.violation=max([0;m.fullLb-w;w-m.fullUb;m.fullLower-cv;cv-m.fullUpper]);
ev=m.F*w(1:2*m.n); info.D=sum(ev.^2); slack=w(2*m.n+1:end); info.S=sum(max(0,slack));
info.normalizedD=info.D/(c.numAgents*c.intervals)*(c.referenceStep/m.h)^2;
info.meanSlack=info.S/max(1,m.relativeCount);
info.objective=.5*w'*m.fullH*w+m.fullg'*w;
candidate=struct('P',reshape(w(1:m.n),3,c.intervals+1,c.numAgents),...
    'V',reshape(w(m.n+1:2*m.n),3,c.intervals+1,c.numAgents),'slack',slack);
candidate.A=diff(candidate.V,1,2)/m.h;
end
