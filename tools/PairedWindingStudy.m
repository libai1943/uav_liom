function PairedWindingStudy(stage)
% Same saved reference, equal initialization charge, randomized method order.
% Stage1 rechecks the exploratory case; stage2 uses previously untested seeds.
if nargin<1,stage=1;end
root=fileparts(fileparts(mfilename('fullpath')));cd(fullfile(root,'tmp'));addpath(fullfile(root,'code_search'),'C:\casadi');maxNumCompThreads(1);StartOSQP(RevisionConfig());
folder=fullfile(root,'results',sprintf('winding_paired_stage%d',stage));if ~isfolder(folder),mkdir(folder);end
jobs=struct([]);
if stage==1,seeds=6102;repeats=1:3;methods={'adaptive','liom','rsc_iter'};else,seeds=7201:7212;repeats=1;methods={'adaptive','rsc_iter'};end
for seed=seeds
 c=RevisionConfig();c.numAgents=5;c.seed=seed;c.horizon=24;c.intervals=120;c.guideResolution=.325;
 s=revision.windingScene(c,'baffles',3,2.2);
 for repeat=repeats
  for method=circshift(methods,[0,mod(seed+repeat,numel(methods))])
   job=struct('id',sprintf('PW%d_S%d_R%d',stage,seed,repeat),'sceneId',sprintf('PW_S%d',seed),'family','baffles','turns',3,'width',2.2,'cfg',c,'scene',s,'repeat',repeat,'method',method{1});
   if isempty(jobs),jobs=job;else,jobs(end+1)=job;end
  end
 end
end
file=fullfile(folder,'design.mat');if isfile(file),old=load(file,'jobs');assert(isequaln(old.jobs,jobs),'Design changed');else,save(file,'jobs','-v7');copyfile(fullfile(root,'code_search'),fullfile(folder,'source'));end
rows={};diary(fullfile(folder,'console.txt'));cleanup=onCleanup(@()diary('off'));
for k=1:numel(jobs)
 job=jobs(k);file=fullfile(folder,[job.id,'_',job.method,'.mat']);
 if isfile(file),d=load(file,'result');result=d.result;
 else
  fprintf('\nPAIRED WINDING %d/%d %s %s\n',k,numel(jobs),job.id,job.method);
  fid=fopen(fullfile(folder,'pending.json'),'w');fprintf(fid,'%s',jsonencode(struct('index',k,'total',numel(jobs),'id',job.id,'method',job.method)));fclose(fid);
  rf=fullfile(folder,[job.sceneId,'_common_reference.mat']);
  if isfile(rf),d=load(rf,'reference','initializationError');reference=d.reference;initializationError=d.initializationError;
  else
   reference=[];initializationError=[];try,reference=revision.initialize(job.scene,job.cfg);catch err,initializationError=struct('identifier',err.identifier,'message',err.message);end
   save(rf,'reference','initializationError','job','-v7');
  end
  if isempty(initializationError),result=revision.run(job.scene,job.cfg,job.method,reference);
  else
   result=struct('method',job.method,'success',false,'successWithinBudget',false,'planningSeconds',NaN,'cpuSeconds',NaN,'outerIterations',0,'solveCount',0,'failureStage','initialization','exception',initializationError,'history',{{}},'reference',[]);
  end
  save(file,'job','result','-v7');
 end
 rows(end+1,:)={job.id,job.cfg.seed,job.repeat,job.method,result.success,result.successWithinBudget,result.planningSeconds,result.cpuSeconds,result.outerIterations,result.solveCount,result.failureStage};
 writetable(cell2table(rows,'VariableNames',{'Case','Seed','Repeat','Method','Accepted','WithinBudget','Wall_s','CPU_s','OuterIterations','QPSolves','FailureStage'}),fullfile(folder,'summary.csv'));
end
fid=fopen(fullfile(folder,'completed.json'),'w');fprintf(fid,'%s',jsonencode(struct('completed',true,'attempts',numel(jobs),'sharedReference',true,'budgetIncludesCommonReference',true,'heldOutSeeds',stage==2)));fclose(fid);
end
