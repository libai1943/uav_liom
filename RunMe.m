% One-click recommended example. All planning QPs use OSQP.
root=fileparts(mfilename('fullpath')); addpath(root,fullfile(root,'code'));
maxNumCompThreads(1); c=RecommendedConfig();
clear revision.osqpSolve
StartOSQP(c); result=RunRevisionCase(c);
if ~result.success
    error('REV:NoAcceptedMotion','No accepted motion; complete outcome saved.');
end
