function report=validate(x,s,c)
% Independent all-pair continuous check of piecewise quadratic physical arcs.
% Does not trust active pairs, solver status or plotting samples. No time repair.
% Only a control-integrated, continuous-velocity output can pass this checker.
N=c.numAgents; K=c.intervals; h=c.horizon/K; tol=c.validationTolerance;
report=struct('success',false,'minimumPairDistance',Inf,'minimumObstacleClearance',Inf,...
    'maxSpeed',0,'maxAcceleration',0,'maxComponentSpeed',0,'maxComponentAcceleration',0,...
    'workspaceViolation',0,'endpointViolation',0,'nodalEndpointVelocityViolation',0,...
    'maxNodalComponentSpeed',0,'discreteInfeasibility',Inf);
if any(~isfinite([x.P(:);x.V(:)])), report.message='Nonfinite trajectory'; return; end
Ekin=diff(x.P,1,2)-.5*h*(x.V(:,1:end-1,:)+x.V(:,2:end,:));
report.discreteInfeasibility=sum(Ekin(:).^2);
report.integrationIdentityError=max(abs(Ekin(:)));
report.controlIdentityError=Inf;
if isfield(x,'A')
    er=diff(x.V,1,2)-h*x.A; report.controlIdentityError=max(abs(er(:)));
end
report.maxNodalComponentSpeed=max(abs(x.V(:)));
polys=zeros(3,3,K,N);
for i=1:N
    report.endpointViolation=max(report.endpointViolation,max(abs(x.P(:,1,i)-s.starts(:,i))));
    report.nodalEndpointVelocityViolation=max([report.nodalEndpointVelocityViolation;...
        abs(x.V(:,1,i)-s.v0(:,i));abs(x.V(:,end,i)-s.vf(:,i))]);
    report.endpointViolation=max([report.endpointViolation;abs(x.P(:,end,i)-s.exits(:,i))]);
    for k=1:K
        dv=x.V(:,k+1,i)-x.V(:,k,i);
        p=[x.P(:,k,i),x.P(:,k+1,i)-x.P(:,k,i)-.5*h*dv,.5*h*dv]; polys(:,:,k,i)=p;
        v0=p(:,2)/h; v1=(p(:,2)+2*p(:,3))/h; a=2*p(:,3)/h^2;
        report.maxSpeed=max([report.maxSpeed,norm(v0),norm(v1)]);
        report.maxComponentSpeed=max([report.maxComponentSpeed;abs(v0);abs(v1)]);
        report.maxAcceleration=max(report.maxAcceleration,norm(a)); report.maxComponentAcceleration=max([report.maxComponentAcceleration;abs(a)]);
        for axis=1:3
            us=[0;1;unitRoots([p(axis,2),2*p(axis,3)])]; vals=p(axis,1)+p(axis,2)*us+p(axis,3)*us.^2;
            report.workspaceViolation=max([report.workspaceViolation;s.bounds(1,axis)+c.radius-vals;vals-s.bounds(2,axis)+c.radius]);
        end
        for b=1:size(s.obstacles,1)
            lo=s.obstacles(b,1:3)'; hi=s.obstacles(b,4:6)'; breaks=[0;1];
            for axis=1:3
                breaks=[breaks;unitRoots([p(axis,1)-lo(axis),p(axis,2:3)]);unitRoots([p(axis,1)-hi(axis),p(axis,2:3)])]; %#ok<AGROW>
            end
            breaks=unique(sort(breaks)); minimum=Inf;
            for interval=1:numel(breaks)-1
                a0=breaks(interval); b0=breaks(interval+1); mid=(a0+b0)/2; pm=p*[1;mid;mid^2]; poly=zeros(3,3);
                for axis=1:3
                    if pm(axis)<lo(axis), poly(axis,:)=p(axis,:)-[lo(axis),0,0];
                    elseif pm(axis)>hi(axis), poly(axis,:)=p(axis,:)-[hi(axis),0,0]; end
                end
                q=squared(poly); stationary=unitRoots((1:4).*q(2:5)); stationary=stationary(stationary>=a0&stationary<=b0);
                for u=[a0;b0;stationary]'
                    pos=p*[1;u;u^2]; gap=max(max(lo-pos,pos-hi),0); minimum=min(minimum,norm(gap));
                end
            end
            report.minimumObstacleClearance=min(report.minimumObstacleClearance,minimum-c.radius);
        end
    end
end
for i=1:N-1
    for j=i+1:N
        for k=1:K
            p=polys(:,:,k,i)-polys(:,:,k,j); q=squared(p); us=[0;1;unitRoots((1:4).*q(2:5))];
            for u=us', report.minimumPairDistance=min(report.minimumPairDistance,norm(p*[1;u;u^2])); end
        end
    end
end
componentV=true; componentA=true;
if isfield(c,'acceptanceBounds'), assert(ismember(c.acceptanceBounds,{'componentwise','euclidean'}),'Unknown acceptance limit policy.'); end
if ~isfield(c,'acceptanceBounds')||strcmp(c.acceptanceBounds,'componentwise')
    componentV=report.maxNodalComponentSpeed<=c.vmax/sqrt(3)+tol;
    componentA=report.maxComponentAcceleration<=c.amax/sqrt(3)+tol;
end
checks=[report.minimumPairDistance>=2*c.radius+c.clearance-tol,...
    report.minimumObstacleClearance>=c.clearance-tol,report.workspaceViolation<=tol,...
    report.endpointViolation<=c.executionTolerance&&report.nodalEndpointVelocityViolation<=c.executionTolerance,...
    report.integrationIdentityError<=c.executionTolerance&&report.controlIdentityError<=c.executionTolerance,...
    componentV&&report.maxSpeed<=c.vmax+tol,...
    componentA&&report.maxAcceleration<=c.amax+tol];
labels={'pair collision','obstacle collision','workspace','fixed endpoint','integration identity','velocity bound','acceleration bound'};
report.success=all(checks); report.message=strjoin(labels(~checks),', ');
if report.success, report.message='PASS'; end
end
function q=squared(p)
q=zeros(1,5); for d=1:3, q=q+conv(p(d,:),p(d,:)); end
end
function u=unitRoots(coeff)
last=find(abs(coeff)>1e-13,1,'last'); if isempty(last)||last==1, u=zeros(0,1); return; end
r=roots(fliplr(coeff(1:last))); u=real(r(abs(imag(r))<1e-8&real(r)>0&real(r)<1));
end
