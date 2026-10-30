% Reproduce the verified winding-counterflow example with identical inputs.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code_search'));StartOSQP(RevisionConfig());maxNumCompThreads(1);
c=RevisionConfig();c.numAgents=5;c.seed=6102;c.horizon=24;c.intervals=120;c.guideResolution=.325;
s=revision.windingScene(c,'baffles',3,2.2);reference=revision.initialize(s,c);
folder=fullfile(root,'results',['winding_example_',datestr(now,'yyyymmdd_HHMMSS')]);mkdir(folder);save(fullfile(folder,'settings.mat'),'s','c','reference','-v7');
diary(fullfile(folder,'console.txt'));fprintf('Fixed flight duration: %.3f s; planning budget: %.1f s per method.\n',c.horizon,c.totalBudget);
for method={'adaptive','rsc_iter'}
 result=revision.run(s,c,method{1},reference);save(fullfile(folder,[method{1},'.mat']),'s','c','reference','result','-v7');
 if result.success
  plotFolder=fullfile(folder,method{1});mkdir(plotFolder);revision.plotCase(result,s,c,plotFolder);
  fprintf('%s: flight %.3fs, planning %.3fs, clearance PASS, effort %.6g.\n',method{1},c.horizon,result.planningSeconds,result.cost);
 end
end
fprintf('Saved all outcomes: %s\n',folder);diary off
