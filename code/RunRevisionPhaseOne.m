function RunRevisionPhaseOne()
root=fileparts(mfilename('fullpath')); addpath(root,'C:\casadi'); maxNumCompThreads(1);
base=RevisionConfig(); out=fullfile(base.outputRoot,'independent_feasibility'); if ~isfolder(out), mkdir(out); end
cases=BuAblationCases(); rows={};
for k=[14 20 26]
    for horizon=[8 9 10 12]
        c=base; c.numAgents=cases(k).cfg.numAgents; c.seed=cases(k).cfg.seed;
        c.horizon=horizon; s=cases(k).scene;
        for poly={'cube','hull14','hull26'}
            c.motionPolytope=poly{1}; file=fullfile(out,sprintf('C%02d_T%d_%s.mat',k,horizon,poly{1}));
            try
                ref=revision.initialize(s,c); corr=bu3d.corridors(ref,s,c);
                m=revision.model(ref,corr,s,c,'hard',[1000 1000]); report=revision.phaseOne(m,c);
                save(file,'report','m','c','s','-v7');
                rows(end+1,:)={k,horizon,poly{1},report.status,report.minimumScaledViolation}; %#ok<AGROW>
            catch err
                report=struct('status',err.identifier,'message',err.message); save(file,'report','c','s');
                rows(end+1,:)={k,horizon,poly{1},err.identifier,NaN}; %#ok<AGROW>
            end
        end
    end
end
writetable(cell2table(rows,'VariableNames',{'Case','Tf','MotionPolytope','Status','PhaseOneViolation'}),fullfile(out,'summary.csv'));
if ~isfolder(base.backupRoot), mkdir(base.backupRoot); end
copyfile(out,fullfile(base.backupRoot,'independent_feasibility'));
end
