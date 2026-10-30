function result=RunRevisionCase(c)
if nargin<1, c=RevisionConfig(); end
root=fileparts(mfilename('fullpath')); addpath(root); maxNumCompThreads(1);
s=bu3d.scene(c); folder=fullfile(c.outputRoot,['single_',datestr(now,'yyyymmdd_HHMMSSFFF')]); mkdir(folder);
manifest=revision.sourceManifest(root); save(fullfile(folder,'settings.mat'),'s','c','manifest');
diary(fullfile(folder,'console.txt')); cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
result=revision.run(s,c,'adaptive'); save(fullfile(folder,'result.mat'),'result','s','c','manifest');
revision.plotCase(result,s,c,folder);
fprintf('Fixed flight horizon: %.3f s. Planning CPU: %.3f s. Planning wall: %.3f s.\n',...
    c.horizon,result.cpuSeconds,result.planningSeconds);
fprintf('Saved: %s\n',folder);
end
