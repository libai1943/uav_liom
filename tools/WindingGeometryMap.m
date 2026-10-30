function WindingGeometryMap()
% Same saved reference, equal initialization charge, randomized method order.
% Stage1 rechecks the exploratory case; stage2 uses previously untested seeds.
stage=3;
root=fileparts(fileparts(mfilename('fullpath')));cd(fullfile(root,'tmp'));addpath(fullfile(root,'code_search'),'C:\casadi');maxNumCompThreads(1);StartOSQP(RevisionConfig());
folder=fullfile(root,'results','winding_geometry_map');if ~isfolder(folder),mkdir(folder);end
jobs=struct([]);settings=[];
for N=[3,5,7],for Tf=[20,24,28],settings(end+1,:)=[N,Tf,2.2];end,end
for width=[2.4,2.6,2.8],settings(end+1,:)=[5,24,width];end
for k=1:size(settings,1)
 c=RevisionConfig();c.numAgents=settings(k,1);c.seed=6102;c.horizon=settings(k,2);c.intervals=round(c.horizon/.2);c.guideResolution=.325;width=settings(k,3);
 s=revision.windingScene(c,'baffles',3,width);
 for method=circshift({'adaptive','rsc_iter'},[0,mod(k,2)])
  job=struct('id',sprintf('WM_%02d',k),'sceneId',sprintf('WM_%02d',k),'family','baffles','turns',3,'width',width,'cfg',c,'scene',s,'repeat',1,'method',method{1});
  if isempty(jobs),jobs=job;else,jobs(end+1)=job;end
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
 rows(end+1,:)={job.id,job.cfg.numAgents,job.cfg.horizon,job.width,job.cfg.seed,job.repeat,job.method,result.success,result.successWithinBudget,result.planningSeconds,result.cpuSeconds,result.outerIterations,result.solveCount,result.failureStage};
 writetable(cell2table(rows,'VariableNames',{'Case','N','Tf','Width','Seed','Repeat','Method','Accepted','WithinBudget','Wall_s','CPU_s','OuterIterations','QPSolves','FailureStage'}),fullfile(folder,'summary.csv'));
end
fid=fopen(fullfile(folder,'completed.json'),'w');fprintf(fid,'%s',jsonencode(struct('completed',true,'attempts',numel(jobs),'sharedReference',true,'budgetIncludesCommonReference',true,'heldOutSeeds',false,'designPurpose','Exploratory physical-parameter map around the previously identified geometry')));fclose(fid);
end
