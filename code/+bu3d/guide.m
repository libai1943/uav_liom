function route=guide(start,goal,s,c)
% Small 26-connected A*; only static geometry, no sequential multi-UAV plan.
m=c.radius+c.clearance+c.vmax*(c.horizon/c.intervals)/2+.05;
if clearLine(start,goal,s,m), route=[start,goal]; return; end
axes=cell(1,3);
for d=1:3, axes{d}=s.bounds(1,d)+m:c.guideResolution:s.bounds(2,d)-m; end
[X,Y,Z]=ndgrid(axes{:}); nodes=[X(:),Y(:),Z(:)]; dims=size(X);
free=true(size(X(:)));
for b=1:size(s.obstacles,1)
    free=free&~(all(nodes>=s.obstacles(b,1:3)-m,2)&all(nodes<=s.obstacles(b,4:6)+m,2));
end
ids=find(free); [~,order]=sort(sum((nodes(ids,:)-start').^2,2)); sid=[];
for k=order', if clearLine(start,nodes(ids(k),:)',s,m), sid=ids(k); break; end, end
[~,order]=sort(sum((nodes(ids,:)-goal').^2,2)); gid=[];
for k=order', if clearLine(goal,nodes(ids(k),:)',s,m), gid=ids(k); break; end, end
if isempty(sid)||isempty(gid), error('BU3D:Guide','A* endpoint connection failed.'); end
g=inf(size(free)); f=g; parent=zeros(size(free)); closed=false(size(free));
g(sid)=0; f(sid)=norm(nodes(sid,:)-goal');
[dx,dy,dz]=ndgrid(-1:1,-1:1,-1:1); off=[dx(:),dy(:),dz(:)]; off(all(off==0,2),:)=[];
while true
    [best,id]=min(f); if ~isfinite(best), error('BU3D:Guide','A* found no static route.'); end
    if id==gid, break; end
    f(id)=Inf; closed(id)=true; [ix,iy,iz]=ind2sub(dims,id);
    ijk=[ix iy iz]+off; ijk=ijk(all(ijk>=1&ijk<=dims,2),:);
    next=sub2ind(dims,ijk(:,1),ijk(:,2),ijk(:,3));
    next=next(free(next)&~closed(next));
    candidate=g(id)+sqrt(sum((nodes(next,:)-nodes(id,:)).^2,2));
    improve=candidate<g(next); next=next(improve); candidate=candidate(improve);
    if isempty(next), continue; end
    legal=clearLines(nodes(id,:)',nodes(next,:)',s,m)'; next=next(legal); candidate=candidate(legal);
    parent(next)=id; g(next)=candidate; f(next)=candidate+sqrt(sum((nodes(next,:)-goal').^2,2));
end
path=gid; while path(1)~=sid, path=[parent(path(1)),path]; end %#ok<AGROW>
route=[start,nodes(path,:)',goal]; shortened=route(:,1); k=1;
while k<size(route,2)
    j=size(route,2);
    while j>k+1 && ~clearLine(route(:,k),route(:,j),s,m), j=j-1; end
    shortened(:,end+1)=route(:,j); k=j; %#ok<AGROW>
end
route=shortened;
end
function ok=clearLine(p,q,s,m)
ok=bu3d.pointClear(p,s,m)&&bu3d.pointClear(q,s,m); if ~ok, return; end
ok=clearLines(p,q,s,m);
end
function ok=clearLines(p,qs,s,m)
% Vectorized slab test, including diagonal grid edges near AABB corners.
M=size(qs,2); ok=true(1,M); delta=qs-p;
for b=1:size(s.obstacles,1)
    lo=s.obstacles(b,1:3)'-m; hi=s.obstacles(b,4:6)'+m;
    ta=zeros(1,M); tb=ones(1,M);
    for d=1:3
        parallel=abs(delta(d,:))<1e-12; moving=~parallel;
        if p(d)<lo(d)||p(d)>hi(d), ta(parallel)=Inf; end
        t1=(lo(d)-p(d))./delta(d,moving); t2=(hi(d)-p(d))./delta(d,moving);
        ta(moving)=max(ta(moving),min(t1,t2)); tb(moving)=min(tb(moving),max(t1,t2));
    end
    ok=ok&ta>tb;
end
end
