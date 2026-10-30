function EntryBudgetStudy()
% Same physical tasks/references; vary only the hard-entry solver allowance.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'code'));addpath(fullfile(root,'code_search'));
clear revision.osqpSolve;StartOSQP(RevisionConfig());
out=fullfile(root,'results','entry_budget_20261031');if ~isfolder(out),mkdir(out);end
files={'osqp_revision_v6/main/C01_adaptive_default_R1.mat','osqp_revision_v6/main/C03_adaptive_default_R1.mat',...
 'osqp_revision_v6/main/C05_adaptive_default_R1.mat','osqp_revision_v6/main/C25_adaptive_default_R1.mat',...
 'osqp_revision_v6/main/C27_adaptive_default_R1.mat','osqp_revision_v6/main/C29_adaptive_default_R1.mat',...
 'winding_paired_stage1/PW1_S6102_R1_adaptive.mat','winding_paired_stage2/PW2_S7202_R1_adaptive.mat',...
 'osqp_revision_v6/scaling/N15_K060_S4101_adaptive_default_R1.mat','osqp_revision_v6/scaling/N20_K060_S4101_adaptive_default_R1.mat'};
ids={'C01','C03','C05','C25','C27','C29','W6102','W7202','N15','N20'};budgets=[1,3,5];
save(fullfile(out,'design.mat'),'files','ids','budgets');rows=struct([]);
for k=1:numel(files)
 source=load(fullfile(root,'results',files{k}));s=source.job.scene;reference=source.result.reference;
 order=mod((0:2)+k-1,3)+1;
 for j=order
  c=source.job.cfg;c.fastPathSeconds=budgets(j);
  key=sprintf('%s_entry%d',ids{k},budgets(j));dest=fullfile(out,[key,'.mat']);
  writeJson(fullfile(out,'pending.json'),struct('case',ids{k},'entryBudget',budgets(j),'started',datestr(now,30)));
  if isfile(dest),prior=load(dest,'result');result=prior.result;
  else
   fprintf('\nENTRY STUDY %s cap=%ds N%d K%d\n',ids{k},budgets(j),c.numAgents,c.intervals);
   result=revision.run(s,c,'adaptive',reference);
   metadata=struct('source',files{k},'caseId',ids{k},'entryBudget',budgets(j),'timestamp',datestr(now,30));
   save(dest,'result','metadata','c','s','-v7');
  end
  entered=false;entryAccepted=false;returned='none';firstStatus='not called';firstSolve=0;
  for a=1:numel(result.history)
   item=result.history{a};entered=entered||strcmp(item.phase,'soft');
   if a==1,entryAccepted=strcmp(item.phase,'rsc')&&item.accepted;firstStatus=item.info.status;firstSolve=item.info.solveSeconds;end
   if item.accepted,returned=item.phase;end
  end
  row=struct('Case',ids{k},'EntryBudget',budgets(j),'N',c.numAgents,'K',c.intervals,...
   'Accepted',result.success,'WithinBudget',result.successWithinBudget,'Wall',result.planningSeconds,...
   'CPU',result.cpuSeconds,'QPs',result.solveCount,'Rounds',result.outerIterations,...
   'EntryAccepted',entryAccepted,'EnteredRecovery',entered,'ReturnedPhase',returned,...
   'FirstSolveSeconds',firstSolve,'FirstStatus',firstStatus,'Status',result.status);
  rows=[rows;row]; %#ok<AGROW>
  writetable(struct2table(rows),fullfile(out,'summary.csv'));
 end
end
writeJson(fullfile(out,'completed.json'),struct('completed',datestr(now,30),'attempts',numel(rows)));
fprintf('ENTRY BUDGET STUDY COMPLETE %d attempts\n',numel(rows));
end
function writeJson(path,value)
f=fopen(path,'w');assert(f>=0);cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(value));
end
