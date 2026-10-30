% One-click cooperative trajectory planning with a 3 s hard entry.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'));
maxNumCompThreads(1);c=RevisionConfig();clear revision.osqpSolve
StartOSQP(c);result=RunRevisionCase(c);
if ~result.success,error('PLAN:NoAcceptedMotion','No accepted motion. Outcome saved.');end
