function s=windingScene(c,family,turns,width)
rng(c.seed,'twister');N=c.numAgents;lo=[-8 -8 .5];hi=[8 8 7.5];s=struct('bounds',[lo;hi],'obstacles',zeros(0,6),'starts',zeros(3,N),'exits',zeros(3,N),'v0',zeros(3,N),'vf',zeros(3,N));
left=ceil(N/2);groups={1:left,left+1:N};
for g=1:2
 ids=groups{g};n=numel(ids);if n==0,continue;end
 yz=zeros(2,n);for j=1:n,yz(:,j)=[(-1)^j*1.15;2.6+1.1*floor((j-1)/2)];end
 yz=yz+.035*randn(2,n);x=-6;if g==2,x=6;end
 s.starts(:,ids)=[x*ones(1,n);yz];s.exits(:,ids)=[-x*ones(1,n);yz(:,randperm(n))+.025*randn(2,n)];
end
xs=linspace(-3.5,3.5,turns);
for b=1:turns
 cy=(-1)^b*1.65+.06*randn;cz=4+(-1)^b*.7;w=width/2;x=xs(b);
 s.obstacles(end+1,:)=[x-.2 lo(2) lo(3) x+.2 cy-w hi(3)];s.obstacles(end+1,:)=[x-.2 cy+w lo(3) x+.2 hi(2) hi(3)];
 if strcmp(family,'portals')
  zh=1.45;s.obstacles(end+1,:)=[x-.2 cy-w lo(3) x+.2 cy+w cz-zh];s.obstacles(end+1,:)=[x-.2 cy-w cz+zh x+.2 cy+w hi(3)];
 end
end
s.directions=(s.exits-s.starts)./vecnorm(s.exits-s.starts);s.desired=s.exits;s.name=family;s.seed=c.seed;
for i=1:N
 assert(bu3d.pointClear(s.starts(:,i),s,c.radius+c.clearance)&&bu3d.pointClear(s.exits(:,i),s,c.radius+c.clearance),'Unsafe endpoint');
 for j=1:i-1,assert(norm(s.starts(:,i)-s.starts(:,j))>=2*c.radius+c.clearance&&norm(s.exits(:,i)-s.exits(:,j))>=2*c.radius+c.clearance,'Overlapping endpoints');end
end
end
