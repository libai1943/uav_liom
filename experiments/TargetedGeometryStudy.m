function TargetedGeometryStudy()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'code'),'C:\casadi'); maxNumCompThreads(1);
folder=fullfile(root,'results','targeted_geometry'); if ~isfolder(folder), mkdir(folder); end
jobs=struct([]); id=0;
for N=[5,8,10]
 for level=[2,3]
  for seed=5101:5103
   id=id+1;c=RevisionConfig();c.numAgents=N;c.scenario='passage';c.seed=seed;c.horizon=16;c.intervals=80;
   s=revision.physicalScene(c,level);
   for method={'adaptive','rsc_iter'}
    j=struct('id',sprintf('G%02d',id),'cfg',c,'scene',s,'method',method{1},'level',level);
    if isempty(jobs), jobs=j; else, jobs(end+1)=j; end
   end
  end
 end
end
save(fullfile(folder,'design.mat'),'jobs','-v7'); rows={};
for k=1:numel(jobs)
 job=jobs(k);file=fullfile(folder,[job.id,'_',job.method,'.mat']);
 if isfile(file), d=load(file,'result');result=d.result;else,WaitForQuietCPU();result=revision.run(job.scene,job.cfg,job.method);save(file,'job','result','-v7');end
 rows(end+1,:)={job.id,job.cfg.numAgents,job.level,job.cfg.seed,job.method,result.success,result.successWithinBudget,result.planningSeconds,result.outerIterations,result.failureStage};
 writetable(cell2table(rows,'VariableNames',{'Case','N','Level','Seed','Method','Accepted','WithinBudget','Wall_s','OuterIterations','FailureStage'}),fullfile(folder,'summary.csv'));
end
end
