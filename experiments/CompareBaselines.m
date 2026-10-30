function CompareBaselines()
mode='matched';
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'code'));addpath(fullfile(root,'comparisons'));addpath('C:/casadi');
clear revision.osqpSolve; StartOSQP(RevisionConfig());out=fullfile(root,'results','comparisons');if ~isfolder(out),mkdir(out);end
files={'benchmark/main/C01_adaptive_default_R1.mat','benchmark/main/C03_adaptive_default_R1.mat',...
 'benchmark/main/C05_adaptive_default_R1.mat','benchmark/main/C25_adaptive_default_R1.mat',...
 'benchmark/main/C27_adaptive_default_R1.mat','benchmark/main/C29_adaptive_default_R1.mat',...
 'winding_repeated/PW1_S6102_R1_adaptive.mat','winding_layouts/PW2_S7202_R1_adaptive.mat',...
 'benchmark/scaling/N15_K060_S4101_adaptive_default_R1.mat','benchmark/scaling/N20_K060_S4101_adaptive_default_R1.mat'};
ids={'C01','C03','C05','C25','C27','C29','W6102','W7202','N15','N20'};
methods={'adaptive','rsc_iter','asco','nlp','scp'};
save(fullfile(out,'design.mat'),'files','ids','methods');
rows=struct([]);
for k=1:numel(files)
 source=load(fullfile(root,'results',files{k}));c=source.job.cfg;s=source.job.scene;reference=source.result.reference;
 assert(~isempty(reference)&&isfield(reference,'seconds'),'Missing common reference');
 order=mod((0:numel(methods)-1)+k-1,numel(methods))+1;
 for j=order
  method=methods{j};key=[ids{k},'_',method];dest=fullfile(out,[key,'.mat']);
  pending=struct('case',ids{k},'method',method,'caseIndex',k,'started',datestr(now,30));writeJson(fullfile(out,'pending.json'),pending);
  if isfile(dest),prior=load(dest,'result');result=prior.result;
  else
   WaitForQuietCPU();
   fprintf('\nCASE %s METHOD %s N%d K%d ref %.3fs\n',ids{k},method,c.numAgents,c.intervals,reference.seconds);
   if ismember(method,{'adaptive','rsc_iter'}),result=revision.run(s,c,method,reference);
   elseif strcmp(method,'scp'),result=scp.run(s,c,method,reference);
   else,result=baselines.run(s,c,method,reference);end
   metadata=struct('source',files{k},'caseId',ids{k},'referenceChargedSeconds',reference.seconds,'timestamp',datestr(now,30),'nonlinearLinearSolver','ma57');
   save(dest,'result','metadata','c','s','-v7');
  end
  row=struct('Case',ids{k},'Method',method,'N',c.numAgents,'K',c.intervals,'Horizon',c.horizon,...
   'Accepted',result.success,'WithinBudget',result.successWithinBudget,'Wall',result.planningSeconds,...
   'CPU',result.cpuSeconds,'Solves',result.solveCount,'Status',result.status,'Cost',result.cost);
  rows=[rows;row]; %#ok<AGROW>
  writetable(struct2table(rows),fullfile(out,'summary.csv'));
 end
end
writeJson(fullfile(out,'completed.json'),struct('completed',datestr(now,30),'attempts',numel(rows),'methods',{methods}));
fprintf('EXTERNAL %s COMPLETE %d attempts\n',mode,numel(rows));
end
function writeJson(path,value)
f=fopen(path,'w');assert(f>=0);cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(value));
end
