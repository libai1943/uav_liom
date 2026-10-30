function OsqpNumericalAudit()
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'code'),'C:\casadi');maxNumCompThreads(1);
folder=fullfile(root,'results','osqp_numerical_audit');if ~isfolder(folder),mkdir(folder);end
base=RevisionConfig();cases=BuAblationCases();rows={};
for k=[4 14 26]
 c=base;c.numAgents=cases(k).cfg.numAgents;s=cases(k).scene;ref=revision.initialize(s,c);corr=bu3d.corridors(ref,s,c);
 for kind={'soft','hard','rsc'}
  m=revision.model(ref,corr,s,c,kind{1},[c.kinematicPenalty,c.slackPenalty]);
  for mode={'candidate','strict','strict_tight'}
   c.maxCpuSeconds=30;c.qpFeasibilityStop=strcmp(mode{1},'candidate');c.qpTolerance=1e-6;
   if strcmp(mode{1},'strict_tight'),c.qpTolerance=1e-7;end
   file=fullfile(folder,sprintf('%s_%s_%s.mat',cases(k).id,kind{1},mode{1}));
   if isfile(file),d=load(file,'info');info=d.info;else,WaitForQuietCPU();[candidate,info]=revision.qp(m,c);save(file,'m','c','candidate','info','-v7');end
   rows(end+1,:)={cases(k).id,kind{1},mode{1},c.qpTolerance,info.status,info.violation,info.objective,info.buildSeconds,info.solveSeconds,info.solverIterations};
   writetable(cell2table(rows,'VariableNames',{'Case','QP','Mode','Tolerance','Status','MaxViolation','Objective','Setup_s','Solve_s','Iterations'}),fullfile(folder,'summary.csv'));
  end
  certificate=revision.phaseOne(m,c);save(fullfile(folder,sprintf('%s_%s_phaseI.mat',cases(k).id,kind{1})),'m','c','certificate','-v7');
 end
end
end
