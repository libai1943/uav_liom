function [candidate,info]=subproblem(ref,s,c,method,range,env) %#ok<INUSD>
% Numeric sparse norm-tangent SCP; pair restriction follows IROS2012 Eq.17.
assert(strcmp(method,'scp'));clock=tic;N=c.numAgents;K=c.intervals;Q=K+1;h=c.horizon/K;n=3*Q*N;nx=2*n;
pi=reshape(1:n,3,Q,N);vi=pi+n;
D=sparse(1:K,1:K,-1,K,Q)+sparse(1:K,2:Q,1,K,Q);
M0=sparse(1:K,1:K,.5,K,Q)+sparse(1:K,2:Q,.5,K,Q);
DP=kron(speye(N),kron(D,speye(3)));AV=kron(speye(N),kron(M0,speye(3)));
B=[sparse(3*K*N,n),DP/h];F=[DP,-h*AV];H=2*c.smoothWeight*h*(B'*B);g=zeros(nx,1);
[U,b]=revision.motionPolytope(c.motionPolytope);VV=kron(speye(Q*N),sparse(U));AA=kron(speye(K*N),sparse(U));
blocks={[sparse(size(VV,1),n),VV],AA*B,F};
low={-inf(size(VV,1),1),-inf(size(AA,1),1),zeros(3*K*N,1)};
high={repmat(c.vmax*b,Q*N,1),repmat(c.amax*b,K*N,1),zeros(3*K*N,1)};
lb=[repmat(s.bounds(1,:)'+c.radius,Q*N,1);-c.vmax*ones(n,1)];
ub=[repmat(s.bounds(2,:)'-c.radius,Q*N,1);c.vmax*ones(n,1)];
for i=1:N
 lb(pi(:,1,i))=s.starts(:,i);ub(pi(:,1,i))=s.starts(:,i);lb(pi(:,end,i))=s.exits(:,i);ub(pi(:,end,i))=s.exits(:,i);
 lb(vi(:,1,i))=s.v0(:,i);ub(vi(:,1,i))=s.v0(:,i);lb(vi(:,end,i))=s.vf(:,i);ub(vi(:,end,i))=s.vf(:,i);
end
sample=(0:4*K)';interval=min(floor(sample/4)+1,K);u=sample/4-(interval-1);M=numel(sample);
PS=sparse([1:M,1:M],[interval;interval+1],[1-u;u],M,Q);
VS=sparse([1:M,1:M],[interval;interval+1],[.5*h*u.*(1-u);-.5*h*u.*(1-u)],M,Q);
local=[kron(PS,speye(3)),kron(VS,speye(3))];positions=cell(N,1);
for i=1:N,positions{i}=reshape(local*[reshape(ref.P(:,:,i),[],1);reshape(ref.V(:,:,i),[],1)],3,M);end
count=0;times=sample'*h/4;dt=h/8;
for i=1:N
 for j=i+1:N
  rr=positions{i}-positions{j};len=vecnorm(rr);normal=rr./max(len,1e-12);
  for z=find(len<1e-12),d=s.starts(:,i)-s.starts(:,j);normal(:,z)=d/norm(d);end
  rate=min(2*c.vmax,min(norm(s.v0(:,i)-s.v0(:,j))+2*c.amax*times,norm(s.vf(:,i)-s.vf(:,j))+2*c.amax*(c.horizon-times)));
  pad=min(2*c.vmax*dt,rate*dt+c.amax*dt^2)+2*c.guard;
  T=sparse(repelem((1:M)',3),1:3*M,normal(:),M,3*M);G=T*local;
  [ri,ci,val]=find(G);coli=[reshape(pi(:,:,i),[],1);reshape(vi(:,:,i),[],1)];colj=[reshape(pi(:,:,j),[],1);reshape(vi(:,:,j),[],1)];
  blocks{end+1}=sparse([ri;ri],[coli(ci);colj(ci)],[val;-val],M,nx);
  low{end+1}=(2*c.radius+c.clearance+pad)';high{end+1}=inf(M,1);count=count+M;
 end
 for bidx=1:size(s.obstacles,1)
  ob=s.obstacles(bidx,:);R=positions{i};near=min(max(R,ob(1:3)'),ob(4:6)');delta=R-near;len=vecnorm(delta);normal=delta./max(len,1e-12);
  for z=find(len<1e-12)
   [~,face]=max([ob(1:3)'-R(:,z);R(:,z)-ob(4:6)']);axis=mod(face-1,3)+1;
   normal(:,z)=0;normal(axis,z)=2*(face>3)-1;near(axis,z)=ob(axis+3*(face>3));
  end
  rate=min(c.vmax,min(norm(s.v0(:,i))+c.amax*times,norm(s.vf(:,i))+c.amax*(c.horizon-times)));
  pad=min(c.vmax*dt,rate*dt+.5*c.amax*dt^2)+c.guard;
  T=sparse(repelem((1:M)',3),1:3*M,normal(:),M,3*M);G=T*local;
  [ri,ci,val]=find(G);cols=[reshape(pi(:,:,i),[],1);reshape(vi(:,:,i),[],1)];
  blocks{end+1}=sparse(ri,cols(ci),val,M,nx);
  low{end+1}=(c.radius+c.clearance+pad+sum(normal.*near))';high{end+1}=inf(M,1);count=count+M;
 end
end
C=vertcat(blocks{:});lower=vertcat(low{:});upper=vertcat(high{:});x0=min(ub,max(lb,[ref.P(:);ref.V(:)]));
fixed=isfinite(lb)&lb==ub;free=find(~fixed);ff=find(fixed);xf=lb(fixed);shift=C(:,fixed)*xf;
m=struct('H',H(free,free),'g',g(free)+H(free,fixed)*xf,'C',C(:,free),...
 'lower',lower-shift,'upper',upper-shift,'lb',lb(free),'ub',ub(free),'x0',x0(free),...
 'free',free,'fixed',ff,'fixedValues',xf,'nx',nx,'n',n,'F',F,'fullH',H,'fullg',g,...
 'fullC',C,'fullLower',lower,'fullUpper',upper,'fullLb',lb,'fullUb',ub,'relativeCount',0,'soft',false,'kind','direct','h',h);
zero=full(sum(abs(m.C),2))==0;m.inconsistent=any(zero&(m.lower>c.qpTolerance|m.upper<-c.qpTolerance));
m.C=m.C(~zero,:);m.lower=m.lower(~zero);m.upper=m.upper(~zero);
assembly=toc(clock);opts=c;opts.maxCpuSeconds=max(.01,c.availableSeconds-assembly);
if assembly>=c.availableSeconds
 candidate=[];info=struct('status','BUILD_BUDGET','finite',false,'maxConstraintViolation',Inf,'buildSeconds',assembly,'solveSeconds',0,'collisionConstraints',count,'backend','none','workerCpuSeconds',0);return;
end
[candidate,info]=revision.qp(m,opts);info.buildSeconds=info.buildSeconds+assembly;
info.maxConstraintViolation=info.violation;info.collisionConstraints=count;info.iterations=info.solverIterations;info.optimizedObjective=info.objective;info.constraints=numel(lower);
end
