function s=physicalScene(c,level)
% Random task instances selected before observing any method outcome.
rng(c.seed,'twister'); N=c.numAgents;
s=struct('bounds',[-8 -8 .5;8 8 7.5],'obstacles',zeros(0,6),...
    'starts',zeros(3,N),'exits',zeros(3,N),'v0',zeros(3,N),'vf',zeros(3,N));
if strcmp(c.scenario,'crossing')
    theta=2*pi*(0:N-1)/N+.02*tanh(randn(1,N));
    heights=3.7+.22*randn(1,N); rotation=.04*tanh(randn(1,N));
    s.starts=[6*cos(theta);6*sin(theta);heights];
    s.exits=[-6*cos(theta+rotation);-6*sin(theta+rotation);heights+.12*randn(1,N)];
else
    side=ceil(sqrt(N)); [y,z]=ndgrid(linspace(-2,2,side),linspace(2,6,side));
    yz=[reshape(y(1:N),1,[]);reshape(z(1:N),1,[])];
    s.starts=[-6*ones(1,N);yz+.025*randn(2,N)];
    s.exits=[6*ones(1,N);yz(:,randperm(N))+.025*randn(2,N)];
    if strcmp(c.scenario,'passage')
        widths=[3.2,2.6,2.0]; w=widths(level)/2; cy=.10*randn; cz=4+.10*randn;
        s.obstacles=[-.35 -8 .5 .35 cy-w 7.5;-.35 cy+w .5 .35 8 7.5;...
            -.35 cy-w .5 .35 cy+w cz-w;-.35 cy-w cz+w .35 cy+w 7.5];
    else
        for b=1:4
            center=[-3+1.5*(b-1),(-1)^b*(.7+.15*randn),3.8+.4*randn];
            half=[.35,.4+.12*level,.5+.12*level]; s.obstacles(b,:)=[center-half,center+half];
        end
    end
end
s.directions=(s.exits-s.starts)./vecnorm(s.exits-s.starts); s.desired=s.exits;
s.name=c.scenario; s.seed=c.seed; s.level=level;
for i=1:N
    assert(bu3d.pointClear(s.starts(:,i),s,c.radius+c.clearance),'REV:InvalidTask','Unsafe start.');
    assert(bu3d.pointClear(s.exits(:,i),s,c.radius+c.clearance),'REV:InvalidTask','Unsafe goal.');
    for j=1:i-1
        assert(norm(s.starts(:,i)-s.starts(:,j))>=2*c.radius+c.clearance,'REV:InvalidTask','Overlapping starts.');
        assert(norm(s.exits(:,i)-s.exits(:,j))>=2*c.radius+c.clearance,'REV:InvalidTask','Overlapping goals.');
    end
end
end
