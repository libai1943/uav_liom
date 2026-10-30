% One reproducible revision case; RunMajorRevision runs the frozen batches.
c=RevisionConfig(); StartOSQP(c);
result=RunRevisionCase(c);
if ~result.success, error('REV:PlanningFailure','Planning attempt failed: %s',result.status); end
