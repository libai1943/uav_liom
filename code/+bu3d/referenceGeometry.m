function report=referenceGeometry(P,s,c,dt)
% Conservative continuous safety bound on the dense SFM simulation.
% At most dt/2 from a sample; ||v|| <= vmax during every simulation step.
pair=Inf; obstacle=Inf; world=Inf;
for i=1:c.numAgents
    p=P(:,:,i);
    world=min([world;reshape(p-s.bounds(1,:)'-c.radius,[],1);reshape(s.bounds(2,:)'-c.radius-p,[],1)]);
    for b=1:size(s.obstacles,1)
        gap=max(max(s.obstacles(b,1:3)'-p,p-s.obstacles(b,4:6)'),0);
        obstacle=min(obstacle,min(sqrt(sum(gap.^2,1)))-c.radius);
    end
    for j=i+1:c.numAgents
        pair=min(pair,min(sqrt(sum((p-P(:,:,j)).^2,1))));
    end
end
report=struct('minimumSamplePair',pair,'minimumSampleObstacleClearance',obstacle,...
    'pairLowerBound',pair-c.vmax*dt,'obstacleLowerBound',obstacle-c.vmax*dt/2,...
    'workspaceLowerBound',world-c.vmax*dt/2);
report.success=report.pairLowerBound>=2*c.radius+c.clearance&&...
    report.obstacleLowerBound>=c.clearance&&report.workspaceLowerBound>=0;
end
