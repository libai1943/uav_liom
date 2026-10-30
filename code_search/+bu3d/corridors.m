function out=corridors(ref,s,c,buildRelative)
% Six-face AABB expansion, batched over reference nodes (Bu's source style).
if nargin<4, buildRelative=true; end
N=c.numAgents; Q=c.intervals+1; h=c.horizon/c.intervals; t=(0:Q-1)*h;
padding=zeros(Q,N);
for i=1:N
    rate=min(c.vmax,min(norm(s.v0(:,i))+c.amax*t,norm(s.vf(:,i))+c.amax*(c.horizon-t)));
    padding(:,i)=min(c.vmax*h/2,rate*h/2+c.amax*h^2/8)+c.guard;
end
pad=padding(:)'; p=reshape(ref.P,3,[]);
wl=s.bounds(1,:)'+c.radius+pad; wh=s.bounds(2,:)'-c.radius-pad;
margin=c.radius+c.clearance+pad; p=min(wh,max(wl,p));
valid=safeBatch(p,p,s.obstacles,margin,wl,wh,zeros(1,size(p,2)));
relocated=0;
for q=find(~valid)
    [~,i]=ind2sub([Q,N],q); corrected=[]; best=Inf;
    if isfield(ref,'guides')
        route=ref.guides{i};
        for edge=1:size(route,2)-1
            a=route(:,edge); d=route(:,edge+1)-a;
            u=min(1,max(0,d'*(p(:,q)-a)/max(d'*d,1e-20))); candidate=a+u*d;
            if safeBatch(candidate,candidate,s.obstacles,margin(q),wl(:,q),wh(:,q),0)&&sum((candidate-p(:,q)).^2)<best
                corrected=candidate; best=sum((candidate-p(:,q)).^2);
            end
        end
    end
    if isempty(corrected)
        candidates=p(:,q);
        for b=1:size(s.obstacles,1)
            for axis=1:3
                a=p(:,q); a(axis)=s.obstacles(b,axis)-margin(q)-2*c.guard; candidates(:,end+1)=a; %#ok<AGROW>
                a=p(:,q); a(axis)=s.obstacles(b,axis+3)+margin(q)+2*c.guard; candidates(:,end+1)=a; %#ok<AGROW>
            end
        end
        legal=safeBatch(candidates,candidates,s.obstacles,margin(q),wl(:,q),wh(:,q),zeros(1,size(candidates,2)));
        costs=sum((candidates-p(:,q)).^2,1); costs(~legal)=Inf; [best,j]=min(costs);
        if isfinite(best), corrected=candidates(:,j); end
    end
    if isempty(corrected), error('BU3D:CorridorSeed','No free static seed at node %d.',q); end
    p(:,q)=corrected; relocated=relocated+1;
end
[lo,hi]=growBatch(p,s.obstacles,margin,wl,wh,zeros(1,size(p,2)),c.stcExpansion,c.expandStep);
out=struct('lo',reshape(lo,3,Q,N),'hi',reshape(hi,3,Q,N),...
    'pairs',zeros(0,3),'rlo',zeros(3,0),'rhi',zeros(3,0),'requiredDistance',zeros(1,0),...
    'margin',0,'relativeMargin',0,'temporalPadding',padding',...
    'relocatedStatic',relocated,'relocatedRelative',0);
if ~buildRelative, return; end
maxPairs=N*(N-1)/2*Q; pairNodes=zeros(maxPairs,3); centers=zeros(3,maxPairs); radii=zeros(1,maxPairs); count=0;
for i=1:N-1
    for j=i+1:N
        rate=min(2*c.vmax,min(norm(s.v0(:,i)-s.v0(:,j))+2*c.amax*t,norm(s.vf(:,i)-s.vf(:,j))+2*c.amax*(c.horizon-t)));
        radius=2*c.radius+c.clearance+min(c.vmax*h,rate*h/2+c.amax*h^2/4)+2*c.guard;
        gap=max(max(out.lo(:,:,i)-out.hi(:,:,j),out.lo(:,:,j)-out.hi(:,:,i)),0);
        active=find(sum(gap.^2,1)<radius.^2); m=numel(active); if m==0, continue; end
        r=ref.P(:,active,i)-ref.P(:,active,j); lengthR=sqrt(sum(r.^2,1));
        tiny=lengthR<1e-10;
        if any(tiny)
            % Physical geometry, not agent numbers, resolves coincident seeds.
            direction=s.starts(:,i)-s.starts(:,j);
            if norm(direction)<1e-10, direction=s.exits(:,i)-s.exits(:,j); end
            if norm(direction)<1e-10, error('BU3D:IdenticalTasks','Coincident identical UAV tasks.'); end
            r(:,tiny)=repmat(direction/norm(direction),1,sum(tiny)); lengthR=sqrt(sum(r.^2,1));
        end
        move=lengthR<radius(active)+4*c.guard;
        if any(move)
            scale=reshape(radius(active(move))+4*c.guard,1,[])./reshape(lengthR(move),1,[]);
            r(:,move)=r(:,move).*scale;
        end
        slots=count+(1:m); pairNodes(slots,:)=[i*ones(m,1),j*ones(m,1),active'];
        centers(:,slots)=r; radii(slots)=radius(active); count=count+m;
        out.relocatedRelative=out.relocatedRelative+sum(move);
    end
end
out.pairs=pairNodes(1:count,:); out.requiredDistance=radii(1:count);
if count
    [out.rlo,out.rhi]=growBatch(centers(:,1:count),zeros(0,6),0,-inf(3,count),inf(3,count),radii(1:count),c.rstcExpansion,c.expandStep);
end
end

function [lo,hi]=growBatch(p,obs,margin,wl,wh,radius,limit,step)
M=size(p,2); lo=p; hi=p; blocked=false(6,M); moved=zeros(6,M);
while ~all(blocked(:))
    for face=1:6
        active=~blocked(face,:); if ~any(active), continue; end
        d=ceil(face/2); delta=min(step,limit-moved(face,:)); delta(~active)=0;
        a=lo; b=hi;
        if mod(face,2), a(d,:)=max(wl(d,:),lo(d,:)-delta); else, b(d,:)=min(wh(d,:),hi(d,:)+delta); end
        good=safeBatch(a,b,obs,margin,wl,wh,radius); accept=active&good;
        lo(:,accept)=a(:,accept); hi(:,accept)=b(:,accept); moved(face,accept)=moved(face,accept)+delta(accept);
        if mod(face,2), atBound=lo(d,:)<=wl(d,:); else, atBound=hi(d,:)>=wh(d,:); end
        blocked(face,accept&(moved(face,:)>=limit-1e-12|atBound))=true;
        reject=active&~good;
        if any(reject)
            lower=zeros(1,M); upper=delta;
            for iter=1:16
                mid=(lower+upper)/2; a=lo; b=hi;
                if mod(face,2), a(d,reject)=max(wl(d,reject),lo(d,reject)-mid(reject)); else, b(d,reject)=min(wh(d,reject),hi(d,reject)+mid(reject)); end
                ok=safeBatch(a,b,obs,margin,wl,wh,radius);
                lower(reject&ok)=mid(reject&ok); upper(reject&~ok)=mid(reject&~ok);
            end
            if mod(face,2), lo(d,reject)=max(wl(d,reject),lo(d,reject)-lower(reject)); else, hi(d,reject)=min(wh(d,reject),hi(d,reject)+lower(reject)); end
            blocked(face,reject)=true;
        end
    end
end
end

function yes=safeBatch(lo,hi,obs,margin,wl,wh,radius)
yes=all(lo>=wl,1)&all(hi<=wh,1);
if any(radius>0), yes=yes&sum(max(max(lo,-hi),0).^2,1)>=radius.^2; return; end
for b=1:size(obs,1)
    yes=yes&~(all(hi>=obs(b,1:3)'-margin,1)&all(lo<=obs(b,4:6)'+margin,1));
end
end
