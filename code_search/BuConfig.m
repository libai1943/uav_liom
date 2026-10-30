function c = BuConfig()
% Bu TITS architecture: direct time grid, hard STC, soft RSTC, LIOM.
% Fixed-time, fixed-endpoint rest-to-rest planning with acceleration effort.
c.numAgents=5; c.seed=7; c.randomizeSeed=false;
c.scenario='crossing'; c.intervals=60; c.horizon=12;
c.radius=.25; c.clearance=.10; c.vmax=4; c.amax=3;
c.cruiseSpeed=0; c.smoothWeight=.05; c.task='rest_to_rest';
c.stcExpansion=1.5; c.rstcExpansion=1.2; c.expandStep=.15;
c.kinematicPenalty=1000; c.slackPenalty=1000; c.penaltyGrowth=2;
c.kinematicPenaltyMax=1e5; c.slackPenaltyMax=1e5;
c.maxOuter=30;
% Exactly two unweighted recovery criteria; no maximum-velocity-defect gate.
c.discreteInfeasibilityTolerance=1e-3; c.slackSumTolerance=1e-3;
c.acceptancePolicy='two_unweighted_recovery_terms';
c.validationTolerance=2e-5; c.maxCpuSeconds=5; c.totalBudget=30;
c.implementationVersion='rest_to_rest_trapezoidal_clock_20260921_v2';
% An initializer is not the returned trajectory. Let LIOM recover a reference
% that fails the conservative SFM certificate; final safety checks stay hard.
c.referenceSafetyPolicy='diagnostic_only';
c.sfmDt=.02; c.sfmSpeed=2; c.sfmRepulsion=4; c.sfmDistance=.35;
c.sfmObstacleRepulsion=4; c.sfmLookahead=.35; c.sfmTrackingTime=.3;
c.sfmMaxDuration=30; c.sfmPairBuffer=.8;
c.guideResolution=.65; c.guard=1e-5;
c.sfmTangentialFraction=.25; % reciprocal, geometry-based symmetry breaking
c.sfmGoalTaper=.75;
c.executionTolerance=1e-9; % identity/endpoint audit of the reconstructed output
c.methods={'full'}; % Single-case default; RunBuAblationStudy runs the comparisons.
c.makePlots=true; c.figureVisible='on';
c.outputRoot=fullfile(fileparts(mfilename('fullpath')),'results','bu3d');
end
