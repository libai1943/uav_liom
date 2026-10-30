function RunExperiments()
% Complete fixed experimental design; serial execution and per-attempt saving.
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'code'),fullfile(root,'code','tests'),fullfile(root,'comparisons'),fullfile(root,'experiments'),'C:/casadi');
maxNumCompThreads(1);clear revision.osqpSolve;StartOSQP(RevisionConfig());
selfTestRevision;clear revision.osqpSolve;SelfTestBaselines;
clear revision.osqpSolve;RunMajorRevision;
TargetedGeometryStudy;OsqpNumericalAudit;
clear revision.osqpSolve;WindingStudy(1);
clear revision.osqpSolve;WindingStudy(2);
clear revision.osqpSolve;WindingGeometryMap;
AuditPairedWinding(fullfile(root,'results','winding_repeated'));
AuditPairedWinding(fullfile(root,'results','winding_layouts'));
clear revision.osqpSolve;CompareBaselines;
clear revision.osqpSolve;EntryBudgetStudy;
end
