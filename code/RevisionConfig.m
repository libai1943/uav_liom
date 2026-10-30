function c=RevisionConfig()
% Shared planning settings for the manuscript experiments.
c=BuConfig(); c.randomizeSeed=false; c.makePlots=false;
c.implementationVersion='fixed_horizon_recovery';
c.qpBackend='osqp'; c.qpTolerance=1e-6; c.qpMaxIterations=20000;
c.osqpPort=19278; c.osqpExchange=fullfile(fileparts(fileparts(mfilename('fullpath'))),'tmp','osqp');
c.referenceFallback=true; c.hardFirstSeconds=.75; c.qpFeasibilityStop=true;
c.osqpRho=.001; c.osqpHardRho=10; c.osqpChunk=250;
c.fastPathSeconds=3; c.qpCandidateTolerance=1e-3; c.minDefectTolerance=1e-8; c.validationRecovery=true;
c.motionPolytope='hull14'; c.acceptanceBounds='euclidean';
c.recoveryCriterion='normalized';
% D/(N*K)*(h_ref/h)^2 has units m^2; calibrated to the original 5-UAV, K=60 grid.
c.referenceStep=.2; c.normalizedDefectTolerance=1e-3/(5*60);
c.meanSlackTolerance=1e-4; % m per active relative box; physical clearance checked separately
c.exactFinish=true; c.maxOuter=12; c.totalBudget=30;
c.initializer='sfm'; c.relocationGuides=true;
c.sfmTangentialFraction=.5; % pilot-selected geometric symmetry breaking; .25 and 1 remain in sensitivity tests
c.qpObjectiveScale='max'; % positive whole-objective scaling leaves its minimizer unchanged
c.experimentTag='benchmark';
c.outputRoot=fullfile(fileparts(fileparts(mfilename('fullpath'))),'results','benchmark');
c.backupRoot=fullfile(fileparts(fileparts(mfilename('fullpath'))),'results','mirror');
end
