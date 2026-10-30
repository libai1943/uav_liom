function s=scene(c)
% Three reproducible families; assignment/physics do not depend on method.
rng(c.seed,'twister'); N=c.numAgents;
s.bounds=[-15 -15 .5;15 15 7.5]; s.obstacles=zeros(0,6);
s.starts=zeros(3,N); s.exits=zeros(3,N); s.directions=zeros(3,N);
if strcmp(c.scenario,'crossing')
    angles=2*pi*(0:N-1)/N+.08*randn(1,N);
    for i=1:N
        d=[cos(angles(i));sin(angles(i));0]; z=3.8+.4*randn;
        s.starts(:,i)=-7*d+[0;0;z];
        s.exits(:,i)=4*d+[0;0;z]; s.directions(:,i)=d;
    end
else
    side=ceil(sqrt(N)); [y,z]=ndgrid(linspace(-1.5,1.5,side),linspace(2.3,5.3,side));
    yz=[reshape(y(1:N),1,N);reshape(z(1:N),1,N)]; permutation=randperm(N);
    s.starts=[-7*ones(1,N);yz]; s.exits=[4*ones(1,N);yz(:,permutation)];
    s.starts(2:3,:)=s.starts(2:3,:)+.04*randn(2,N);
    s.directions=repmat([1;0;0],1,N);
    if strcmp(c.scenario,'passage')
        % Full aperture width/height; the normal single-case default is unchanged.
        width=2.8; if isfield(c,'passageWidth'), width=c.passageWidth; end
        assert(width>0&&width<6,'Invalid aperture width.');
        cy=.15*randn; cz=3.8+.1*randn; w=width/2;
        s.obstacles=[-.35 -15 .5 .35 cy-w 7.5;-.35 cy+w .5 .35 15 7.5;...
            -.35 cy-w .5 .35 cy+w cz-w;-.35 cy-w cz+w .35 cy+w 7.5];
    elseif strcmp(c.scenario,'obstacles')
        for k=1:4
            center=[-4+1.7*k,(-1)^k*.9+.2*randn,3.8+.5*randn];
            scale=1; if isfield(c,'obstacleScale'), scale=c.obstacleScale; end
            assert(scale>0,'Invalid obstacle scale.');
            half=scale*[.35,.5,.6]; s.obstacles(k,:)=[center-half,center+half];
        end
    else
        error('BU3D:Scene','Unknown scene family %s.',c.scenario);
    end
end
s.desired=s.exits;
s.v0=c.cruiseSpeed*s.directions; s.vf=s.v0;
s.name=c.scenario; s.seed=c.seed;
for i=1:N
    assert(bu3d.pointClear(s.starts(:,i),s,c.radius+c.clearance),'Unsafe start.');
    assert(bu3d.pointClear(s.exits(:,i),s,c.radius+c.clearance),'Unsafe goal.');
    for j=1:i-1
        assert(norm(s.starts(:,i)-s.starts(:,j))>2*c.radius+c.clearance,'Overlapping starts.');
        assert(norm(s.exits(:,i)-s.exits(:,j))>2*c.radius+c.clearance,'Overlapping goals.');
    end
end
end
