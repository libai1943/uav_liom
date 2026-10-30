function AuditPairedWinding(folder)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'code_search'),'C:\casadi');files=dir(fullfile(folder,'*_adaptive.mat'));rows={};
for k=1:numel(files)
 a=load(fullfile(files(k).folder,files(k).name),'job','result');id=a.job.id;fp=fullfile(folder,[id,'_rsc_iter.mat']);if ~isfile(fp),continue;end
 b=load(fp,'job','result');adv=a.result.successWithinBudget&&~b.result.successWithinBudget;phi=NaN;dual=NaN;certified=false;
 if adv&&~isempty(b.result.history)
  e=b.result.history{1};m=revision.model(b.result.reference,e.corridors,b.job.scene,b.job.cfg,'rsc',[b.job.cfg.kinematicPenalty,b.job.cfg.slackPenalty]);
  certificate=revision.phaseOne(m,b.job.cfg);save(fullfile(folder,[id,'_initial_hardRSC_phaseI.mat']),'m','certificate','-v7');phi=certificate.minimumScaledViolation;
  if isfield(certificate,'dualBound'),dual=certificate.dualBound;certified=certificate.numericallySupportedInfeasibility;end
 end
 same=false;if ~isempty(a.result.reference)&&~isempty(b.result.reference),same=isequaln(a.result.reference.P,b.result.reference.P)&&isequaln(a.result.reference.V,b.result.reference.V);end
 rows(end+1,:)={id,a.job.cfg.seed,a.job.repeat,a.result.successWithinBudget,b.result.successWithinBudget,adv,same,phi,dual,certified};
end
if ~isempty(rows),writetable(cell2table(rows,'VariableNames',{'Case','Seed','Repeat','Adaptive','HardRSC','AdaptiveAdvantage','IdenticalReference','PhaseI','DualBound','SupportedInitialInfeasibility'}),fullfile(folder,'comparative_audit.csv'));end
end
