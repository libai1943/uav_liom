function selfTestRevision()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root,'C:\casadi'); rng(11);
c=RevisionConfig(); c.qpFeasibilityStop=false; c.numAgents=2; c.intervals=20; c.horizon=12; c.motionPolytope='hull26';
[U,b,v]=revision.motionPolytope('hull26');
assert(max(max(U*v'-b))<1e-10); assert(max(abs(vecnorm(v,2,2)-1))<1e-12);
for d=1:3, ax=zeros(3,1); ax(d)=1; assert(all(U*ax<=b+1e-10)); end
weights=rand(size(v,1),100); weights=weights./sum(weights,1); points=v'*weights;
assert(max(vecnorm(points))<=1+1e-12);
[U14,b14,v14]=revision.motionPolytope('hull14');
assert(size(v14,1)==14&&size(U14,1)==24);
assert(max(max(U14*v14'-b14))<1e-10);
% The lighter polytope contains every corner of the original velocity cube.
[xx,yy,zz]=ndgrid([-1 1]/sqrt(3)); corners=[xx(:),yy(:),zz(:)]';
assert(max(max(U14*corners-b14))<1e-10);
s=struct('starts',[-3 -3;-2 2;3 3],'exits',[3 3;-2 2;3 3],...
    'v0',zeros(3,2),'vf',zeros(3,2),'bounds',[-8 -8 0;8 8 7],'obstacles',zeros(0,6));
c.initializer='straight'; c.relocationGuides=false; ref=revision.initialize(s,c);
corr=bu3d.corridors(ref,s,c); m=revision.model(ref,corr,s,c,'soft',[1000 1000]);
w=[ref.P(:);ref.V(:);zeros(m.nx-2*m.n,1)]; ev=m.F*w(1:2*m.n); a=m.B*w(1:2*m.n);
formula=c.smoothWeight*m.h*sum(a.^2)+1000/m.h*sum(ev.^2);
assert(abs(.5*w'*m.fullH*w+m.fullg'*w-formula)<1e-7*max(1,formula));
c.qpBackend='osqp'; hard=revision.model(ref,corr,s,c,'hard',[1000 1000]);
[candidate,info]=revision.qp(hard,c); assert(info.finite&&info.violation<2e-5,info.status);
[out,restore]=bu3d.executable(candidate,s,c); check=bu3d.validate(out,s,c);
assert(check.success,check.message); assert(restore.endpointError<1e-9);
h=c.horizon/c.intervals;H=[h*ones(1,c.intervals);h*h*(c.intervals-.5:-1:.5)];
aExact=H'*((H*H')\[0;6]);expected=2*c.smoothWeight*h*sum(aExact.^2);
actual=c.smoothWeight*h*sum(out.A(:).^2);
assert(abs(actual-expected)<1e-7*max(1,expected));
fprintf('OSQP analytic control-effort check PASS: %.10g, expected %.10g\n',actual,expected);
% Positive case at an axial speed above vmax/sqrt(3) is physically valid.
c.intervals=4; c.horizon=4; c.numAgents=1; c.vmax=4; c.amax=3;
s.starts=[0;0;3]; s.exits=[6;0;3]; s.v0=zeros(3,1); s.vf=zeros(3,1);
vtest=[0 3 3 0 0;zeros(2,5)]; dummy=struct('P',zeros(3,5),'V',vtest);
[motion,~]=bu3d.executable(dummy,s,c); check=bu3d.validate(motion,s,c); assert(check.success,check.message);
bad=motion; bad.P(1,3)=bad.P(1,3)+.01; check=bu3d.validate(bad,s,c); assert(~check.success);
bad=motion; bad.V(1,3)=10; check=bu3d.validate(bad,s,c); assert(~check.success);
% Coincident path samples must not produce an undefined tangent.
c.numAgents=1; c.intervals=20; c.horizon=12;
paths={[s.starts,s.starts,s.exits,s.exits]}; ref=bu3d.referenceProfile(paths,s,c); assert(all(isfinite(ref.V(:))));
c.horizon=.5; failed=false;
try, bu3d.referenceProfile(paths,s,c); catch err, failed=strcmp(err.identifier,'BU3D:ReferenceTimeLaw'); end
assert(failed,'Scalar time-law capacity must reject an infeasible reference.');
% An independent phase-I LP must distinguish an inconsistent pair of rows.
tiny=struct('free',1,'C',sparse([1;1]),'lower',[1;-Inf],'upper',[Inf;0],...
    'lb',0,'ub',2,'inconsistent',false);
certificate=revision.phaseOne(tiny,c);
assert(abs(certificate.minimumScaledViolation-.5)<1e-7);
assert(certificate.numericallySupportedInfeasibility);
fprintf('OSQP REVISION TESTS PASSED\n');
end
