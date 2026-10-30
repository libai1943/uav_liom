function ref=initialize(s,c,kind)
% Geometric reference followed by the SAME admissible 1-D rest-to-rest law.
clock=tic; cpuClock=cputime; N=c.numAgents; paths=cell(N,1);
if strcmp(kind,'straight')
    for i=1:N, paths{i}=[s.starts(:,i),s.exits(:,i)]; end
    ref=bu3d.referenceProfile(paths,s,c); ref.guideSeconds=0;
    ref.rawP=ref.P; ref.rawV=ref.V; ref.rawTime=linspace(0,c.horizon,c.intervals+1);
    ref.simulatedDuration=0;
else
    tick=tic; guides=cell(N,1); arcs=cell(N,1); progress=zeros(1,N);
    for i=1:N
        guides{i}=bu3d.guide(s.starts(:,i),s.exits(:,i),s,c);
        arcs{i}=[0,cumsum(vecnorm(diff(guides{i},1,2)))];
    end
    guideSeconds=toc(tick); dt=c.sfmDt; P=s.starts; V=zeros(3,N);
    vc=c.vmax/sqrt(3); ac=c.amax/sqrt(3); arrived=false(1,N);
    maxSteps=ceil(c.sfmMaxDuration/dt); positions=zeros(3,maxSteps+1,N);
    positions(:,1,:)=reshape(P,3,1,N);
    for step=1:maxSteps
        A=zeros(3,N); repulsion=zeros(3,N);
        for i=1:N
            if arrived(i), continue; end
            route=guides{i}; ar=arcs{i}; best=Inf; along=progress(i);
            for edge=1:size(route,2)-1
                a=route(:,edge); d=route(:,edge+1)-a; len=ar(edge+1)-ar(edge);
                u=min(1,max(0,d'*(P(:,i)-a)/max(len^2,1e-20)));
                at=ar(edge)+u*len; if at<progress(i)-.1, continue; end
                distance=sum((a+u*d-P(:,i)).^2);
                if distance<best, best=distance; along=at; end
            end
            progress(i)=max(progress(i),along);
            target=interp1(ar,route',min(ar(end),progress(i)+c.sfmLookahead),'linear')';
            d=target-P(:,i); remaining=norm(s.exits(:,i)-P(:,i));
            speed=min(c.sfmSpeed,remaining/.6);
            preferred=speed*d/max(norm(d),c.sfmLookahead);
            A(:,i)=(preferred-V(:,i))/c.sfmTrackingTime;
            for b=1:size(s.obstacles,1)
                closest=min(max(P(:,i),s.obstacles(b,1:3)'),s.obstacles(b,4:6)');
                r=P(:,i)-closest; distance=norm(r);
                if distance<2&&distance>1e-10
                    safe=c.radius+c.clearance+c.vmax*(c.horizon/c.intervals)/2+c.guard;
                    repulsion(:,i)=repulsion(:,i)+c.sfmObstacleRepulsion*exp(min(15,(safe-distance)/c.sfmDistance))*r/distance;
                end
            end
        end
        lower=P-s.bounds(1,:)'-c.radius; upper=s.bounds(2,:)'-c.radius-P;
        repulsion=repulsion+c.sfmObstacleRepulsion*(exp(min(15,(1.2-lower)/c.sfmDistance))-exp(min(15,(1.2-upper)/c.sfmDistance)));
        for i=1:N-1
            for j=i+1:N
                r=P(:,i)-P(:,j); distance=norm(r);
                if distance<3&&distance>1e-10
                    radial=r/distance; side=cross([0;0;1],radial);
                    force=c.sfmRepulsion*exp(min(15,(2*c.radius+c.clearance+c.sfmPairBuffer-distance)/c.sfmDistance));
                    f=force*(radial+c.sfmTangentialFraction*side);
                    repulsion(:,i)=repulsion(:,i)+f; repulsion(:,j)=repulsion(:,j)-f;
                end
            end
        end
        % Goal-dependent taper removes a repulsive equilibrium at a safe goal.
        % It depends on task geometry, never the UAV identifier.
        taper=min(1,vecnorm(P-s.exits)/c.sfmGoalTaper).^2;
        A=A+repulsion.*taper;
        A=min(ac,max(-ac,A)); A=min((vc-V)/dt,max((-vc-V)/dt,A)); A(:,arrived)=0;
        P=P+dt*V+.5*dt^2*A; V=V+dt*A;
        for i=1:N
            if ~arrived(i)&&norm(P(:,i)-s.exits(:,i))<.10&&norm(V(:,i))<.15
                arrived(i)=true; P(:,i)=s.exits(:,i); V(:,i)=0;
            end
        end
        positions(:,step+1,:)=reshape(P,3,1,N);
        if all(arrived), break; end
    end
    if ~all(arrived)
        error('BU3D:SFMTimeout','Rest-to-rest SFM failed to reach all goals in %.1f s; missing %s.',step*dt,mat2str(find(~arrived)));
    end
    for i=1:N
        route=positions(:,1:step+1,i);
        % Store the simulated geometric polyline. referenceProfile applies
        % a common-horizon scalar law independently to each route length.
        paths{i}=route;
        paths{i}(:,1)=s.starts(:,i); paths{i}(:,end)=s.exits(:,i);
    end
    ref=bu3d.referenceProfile(paths,s,c); ref.guides=guides; ref.guideSeconds=guideSeconds;
    ref.rawP=ref.P; ref.rawV=ref.V; ref.rawTime=linspace(0,c.horizon,c.intervals+1);
    ref.simulatedDuration=step*dt; ref.simulationP=positions(:,1:step+1,:);
end
ref.geometry=bu3d.referenceGeometry(ref.rawP,s,c,c.horizon/c.intervals);
ref.seconds=toc(clock); ref.cpuSeconds=cputime-cpuClock; ref.kind=kind;
end
