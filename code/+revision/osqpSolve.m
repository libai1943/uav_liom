function [answer,transport]=osqpSolve(m,c,scale)
% Persistent local worker avoids Python startup per QP. All I/O is timed.
persistent client serial
if isempty(serial), serial=0; end
if isempty(client)
    client=tcpclient('127.0.0.1',c.osqpPort,'Timeout',60); configureTerminator(client,'LF');
end
clock=tic; serial=serial+1;
if ~isfolder(c.osqpExchange), mkdir(c.osqpExchange); end
path=fullfile(c.osqpExchange,sprintf('qp_%d_%08d.mat',feature('getpid'),serial));
H=m.H/scale; g=m.g/scale; C=m.C; lower=m.lower; upper=m.upper; lb=m.lb; ub=m.ub; x0=m.x0;
tolerance=c.qpTolerance; maxIterations=c.qpMaxIterations; timeLimit=max(.01,c.maxCpuSeconds);
Fp=[m.F,sparse(size(m.F,1),m.nx-2*m.n)]; F=Fp(:,m.free); fshift=Fp(:,m.fixed)*m.fixedValues;
slackIds=find(m.free>2*m.n); soft=m.soft; relativeCount=m.relativeCount;
defectLimit=c.normalizedDefectTolerance*c.numAgents*c.intervals*(m.h/c.referenceStep)^2;
slackLimit=c.meanSlackTolerance*max(1,m.relativeCount);
if strcmp(c.recoveryCriterion,'aggregate'), defectLimit=c.discreteInfeasibilityTolerance; slackLimit=c.slackSumTolerance; end
hardTolerance=c.qpCandidateTolerance; feasibilityStop=c.qpFeasibilityStop; rho=c.osqpRho; if ~m.soft, rho=c.osqpHardRho; end; chunk=c.osqpChunk;
save(path,'F','fshift','slackIds','soft','relativeCount','defectLimit','slackLimit','hardTolerance','feasibilityStop','rho','chunk','H','g','C','lower','upper','lb','ub','x0','tolerance','maxIterations','timeLimit','-v6');
writeline(client,jsonencode(struct('path',path))); answer=jsondecode(readline(client));
if isfield(answer,'error'), error('REV:OSQPWorker','%s',answer.error); end
out=load(answer.output,'x'); answer.x=out.x;
delete(path); delete(answer.output);
transport=max(0,toc(clock)-answer.setupSeconds-answer.solveSeconds);
end
