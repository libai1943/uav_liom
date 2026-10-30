function NormSCPStudy()
r=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(r,'code'));addpath(fullfile(r,'code_search'));addpath(fullfile(r,'comparisons_20261031'));addpath('C:/casadi');
assert(isfile(fullfile(r,'results','external_20261031_formal','completed.json')),'Finish formal serial batch first.');
design=load(fullfile(r,'results','external_20261031_formal','design.mat'));StartOSQP(RevisionConfig());
out=fullfile(r,'results','normscp_20261031');if ~isfolder(out),mkdir(out);end
save(fullfile(out,'design.mat'),'design');rows=struct([]);
for k=1:numel(design.files)
 d=load(fullfile(r,'results',design.files{k}));c=d.job.cfg;s=d.job.scene;reference=d.result.reference;
 dest=fullfile(out,[design.ids{k},'_scp_norm.mat']);
 if isfile(dest),a=load(dest,'result');result=a.result;
 else
  fprintf('\nNORM SCP %s N%d K%d\n',design.ids{k},c.numAgents,c.intervals);
  result=normscp.run(s,c,'scp',reference);
  metadata=struct('source',design.files{k},'caseId',design.ids{k},'formulation','norm tangent, IROS 2012 Eq.17');
  save(dest,'result','metadata','c','s','-v7');
 end
 row=struct('Case',design.ids{k},'Method','scp_norm','N',c.numAgents,'K',c.intervals,'Horizon',c.horizon,...
 'Accepted',result.success,'WithinBudget',result.successWithinBudget,'Wall',result.planningSeconds,...
 'CPU',result.cpuSeconds,'Solves',result.solveCount,'Status',result.status,'Cost',result.cost);
 rows=[rows;row];writetable(struct2table(rows),fullfile(out,'summary.csv')); %#ok<AGROW>
end
fid=fopen(fullfile(out,'completed.json'),'w');fprintf(fid,'%s',jsonencode(struct('attempts',numel(rows),'completed',datestr(now,30))));fclose(fid);
fprintf('NORM SCP COMPLETE %d attempts\n',numel(rows));
end
