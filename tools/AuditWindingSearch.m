function AuditWindingSearch(folder)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'code'),'C:\casadi');
files=dir(fullfile(folder,'*_adaptive.mat'));rows={};
for k=1:numel(files)
 a=load(fullfile(files(k).folder,files(k).name),'job','result');id=a.job.id;
 fp=fullfile(folder,[id,'_rsc_iter.mat']);sp=fullfile(folder,[id,'_liom.mat']);if ~isfile(fp)||~isfile(sp),continue;end
 h=load(fp,'job','result');s=load(sp,'job','result');adv=a.result.successWithinBudget&&~h.result.successWithinBudget;softadv=s.result.successWithinBudget&&~h.result.successWithinBudget;
 phi=NaN;dual=NaN;supported=false;
 if (adv||softadv)&&~isempty(h.result.history)
  entry=h.result.history{1};m=revision.model(h.result.reference,entry.corridors,h.job.scene,h.job.cfg,'rsc',[h.job.cfg.kinematicPenalty,h.job.cfg.slackPenalty]);
  certificate=revision.phaseOne(m,h.job.cfg);save(fullfile(folder,[id,'_initial_hardRSC_phaseI.mat']),'m','certificate','-v7');
  phi=certificate.minimumScaledViolation;if isfield(certificate,'dualBound'),dual=certificate.dualBound;supported=certificate.numericallySupportedInfeasibility;end
 end
 rows(end+1,:)={id,a.result.successWithinBudget,s.result.successWithinBudget,h.result.successWithinBudget,adv,softadv,phi,dual,supported};
end
if ~isempty(rows),writetable(cell2table(rows,'VariableNames',{'Case','Adaptive','SoftLIOM','HardRSC','AdaptiveAdvantage','SoftAdvantage','PhaseI','DualBound','SupportedInitialInfeasibility'}),fullfile(folder,'comparative_audit.csv'));end
end
