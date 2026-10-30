function ref=referenceProfile(paths,s,c)
% Piecewise-linear scalar velocity; exact trapezoidal arc-length integration.
K=c.intervals; h=c.horizon/K; N=c.numAgents; t=(0:K)*h;
% Maximum admissible nodal trapezoid; uniform scaling fits the route length.
% Linear interpolation of speed gives bounded piecewise-constant acceleration.
shape=min(c.vmax,min(c.amax*t,c.amax*(c.horizon-t))); shape([1,end])=0;
integral=sum(.5*h*(shape(1:end-1)+shape(2:end)));
ref.P=zeros(3,K+1,N); ref.V=ref.P; profiles=struct([]);
for i=1:N
    route=paths{i};
    % Arrived agents can contribute repeated positions. Remove zero-length
    % geometric edges before interpolation; retain the path and its endpoints.
    keep=[true,vecnorm(diff(route,1,2))>1e-12]; route=route(:,keep);
    arc=[0,cumsum(vecnorm(diff(route,1,2)))]; L=arc(end);
    assert(L>1e-10,'BU3D:ZeroPath','Start and goal must differ.');
    speed=(L/integral)*shape; q=[0,cumsum(.5*h*(speed(1:end-1)+speed(2:end)))]; q(end)=L;
    acceleration=diff(speed)/h;
    assert(max(speed)<=c.vmax+1e-12&&max(abs(acceleration))<=c.amax+1e-12,...
        'BU3D:ReferenceTimeLaw','Path length %.4f m is infeasible for the common 1-D time law at T=%.2f s.',L,c.horizon);
    ref.P(:,:,i)=interp1(arc,route',q,'linear')';
    for k=1:K+1
        edge=find(arc<=q(k)+1e-12,1,'last'); edge=min(edge,numel(arc)-1);
        direction=(route(:,edge+1)-route(:,edge))/(arc(edge+1)-arc(edge));
        ref.V(:,k,i)=speed(k)*direction;
    end
    ref.P(:,1,i)=s.starts(:,i); ref.P(:,end,i)=s.exits(:,i);
    ref.V(:,1,i)=0; ref.V(:,end,i)=0;
    entry=struct('length',L,'distance',q,'speed',speed,'acceleration',acceleration,...
        'maxSpeed',max(speed),'maxAcceleration',max(abs(acceleration)));
    if isempty(profiles), profiles=entry; else, profiles(i)=entry; end %#ok<AGROW>
end
ref.A=diff(ref.V,1,2)/h; ref.scalarProfiles=profiles;
end
