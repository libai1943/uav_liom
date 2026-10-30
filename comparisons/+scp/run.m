function result=run(s,c,method,reference)
% Fixed-task adaptation of original ASCO Algorithm 1--2, direct NLP, and SCP.
assert(strcmp(method,'scp'));
clock=tic;cpu0=cputime;offset=reference.seconds;cpuOffset=0;
if isfield(reference,'cpuSeconds'),cpuOffset=reference.cpuSeconds;end
result=struct('success',false,'status','NOT_RUN','history',{{}},'cost',NaN,'method',method,...
 'reference',reference,'initializationSeconds',offset,'assemblySeconds',0,'solveSeconds',0,...
 'verificationSeconds',0,'workerCpuSeconds',0,'solveCount',0,'failureStage','');
ref=reference;env=struct('linearSolver','mumps');
originalRadius=hypot(.25*(2.8+.96+.929),.5*1.942);ratio=c.radius/originalRadius;
low0=-4*ratio;range=[low0,2*ratio];steps=[3,1.3,.05]*ratio;
result.riskSettings=struct('radiusRatio',ratio,'initialRange',range,'steps',steps);
try
 for it=1:50
  remaining=c.totalBudget-offset-toc(clock);
  if remaining<=0,result.status='WALL_BUDGET';result.failureStage='budget';break;end
  opts=c;opts.availableSeconds=remaining;
  if strcmp(method,'asco'),opts.availableSeconds=min(5,remaining);end
  [candidate,info]=scp.subproblem(ref,s,opts,method,range,env);
  result.solveCount=result.solveCount+1;
  result.assemblySeconds=result.assemblySeconds+info.buildSeconds;
  result.solveSeconds=result.solveSeconds+info.solveSeconds;
  if isfield(info,'workerCpuSeconds'),result.workerCpuSeconds=result.workerCpuSeconds+info.workerCpuSeconds;end
  numerical=info.finite&&info.maxConstraintViolation<=c.qpCandidateTolerance;
  validation=struct('success',false,'message','hard-constraint gate failed');
  restoration=struct('maxControlCorrection',NaN,'maxPositionChange',NaN);
  if numerical
   checkClock=tic;[motion,restoration]=bu3d.executable(candidate,s,c);
   validation=bu3d.validate(motion,s,c);
   result.verificationSeconds=result.verificationSeconds+toc(checkClock);
  end
  item=struct('info',info,'riskRange',range,'numerical',numerical,'validation',validation,...
   'restoration',restoration,'candidate',candidate);
  result.history{end+1}=item;result.candidate=candidate;result.validation=validation;
  fprintf('  %-6s %d: %s/%s; collisions %d; violation %.3g; %.3fs; %s\n',...
   method,it,info.backend,info.status,info.collisionConstraints,info.maxConstraintViolation,...
   info.buildSeconds+info.solveSeconds,validation.message);
  if validation.success
   result.success=true;result.status='ACCEPTED';result.trajectory=motion;
   result.restoration=restoration;result.cost=c.smoothWeight*(c.horizon/c.intervals)*sum(motion.A(:).^2);break;
  end
  result.status=['NOT_ACCEPTED:',info.status];result.failureStage='hard_subproblem';
  if numerical,result.failureStage='continuous_validation';end
  if strcmp(method,'nlp'),break;end
  if strcmp(method,'asco')
   solved=numerical&&(ismember(info.status,{'Solve_Succeeded','Solved_To_Acceptable_Level','solved','solved inaccurate','feasible candidate'})||strcmp(info.backend,'osqp'));
   if solved
    ref=candidate;range=[max(low0,range(1)-steps(2)),range(2)+steps(3)];
   else
    range(1)=range(1)+steps(1); % Keep the last successful reference, as in ASCO.
   end
  elseif numerical
   moved=max(abs(candidate.P(:)-ref.P(:)));ref=candidate;
   if moved<1e-9,result.status='SCP_STALLED';break;end
  else
   break;
  end
 end
catch err
 result.status=['ERROR:',err.identifier];result.failureStage='program_or_solver';
 result.exception=struct('identifier',err.identifier,'message',err.message,'stack',err.stack);
 fprintf(2,'%s\n',getReport(err,'extended','hyperlinks','off'));
end
result.planningSeconds=toc(clock)+offset;
result.cpuSeconds=cputime-cpu0+cpuOffset+result.workerCpuSeconds;
result.successWithinBudget=result.success&&result.planningSeconds<=c.totalBudget;
result.horizon=c.horizon;
if result.success&&~result.successWithinBudget,result.status='ACCEPTED_OVER_BUDGET';end
fprintf('RESULT %s accepted=%d withinBudget=%d solves=%d wall=%.3f CPU=%.3f %s\n',...
 method,result.success,result.successWithinBudget,result.solveCount,result.planningSeconds,result.cpuSeconds,result.status);
end
