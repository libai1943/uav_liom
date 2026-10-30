function m=model(ref,corr,s,c,kind,rho)
% Numerical sparse QP assembly. No symbolic differentiation or hidden penalties.
% kind: soft (two penalties), hard (exact box corridors), rsc (hard planes).
N=c.numAgents; K=c.intervals; Q=K+1; h=c.horizon/K; n=3*Q*N;
pi=reshape(1:n,3,Q,N); vi=pi+n;
D=sparse(1:K,1:K,-1,K,Q)+sparse(1:K,2:Q,1,K,Q);
M=sparse(1:K,1:K,.5,K,Q)+sparse(1:K,2:Q,.5,K,Q);
DP=kron(speye(N),kron(D,speye(3))); AV=kron(speye(N),kron(M,speye(3)));
B=[sparse(3*K*N,n),DP/h]; F=[DP,-h*AV];
if strcmp(kind,'rsc')
    pairs=zeros(0,3); t=(0:K)*h;
    rate=min(2*c.vmax,2*c.amax*min(t,c.horizon-t));
    required=2*c.radius+c.clearance+min(c.vmax*h,rate*h/2+c.amax*h^2/4)+2*c.guard;
    for i=1:N-1
        for j=i+1:N
            gap=max(max(corr.lo(:,:,i)-corr.hi(:,:,j),corr.lo(:,:,j)-corr.hi(:,:,i)),0);
            active=find(sum(gap.^2,1)<required.^2);
            pairs=[pairs;i*ones(numel(active),1),j*ones(numel(active),1),active']; %#ok<AGROW>
        end
    end
else, pairs=corr.pairs; end
E=size(pairs,1); soft=strcmp(kind,'soft'); ns=E*soft; nx=2*n+ns;
lb=[corr.lo(:);-c.vmax*ones(n,1);zeros(ns,1)];
ub=[corr.hi(:);c.vmax*ones(n,1);inf(ns,1)];
for i=1:N
    for k=[1,Q]
        p=s.starts(:,i); v=s.v0(:,i); if k==Q, p=s.exits(:,i); v=s.vf(:,i); end
        ids=pi(:,k,i);
        if any(p<lb(ids)-c.validationTolerance|p>ub(ids)+c.validationTolerance)
            error('REV:EndpointBox','Endpoint is outside its spatial box.');
        end
        lb(ids)=p; ub(ids)=p; lb(vi(:,k,i))=v; ub(vi(:,k,i))=v;
    end
end
if any(lb>ub), error('REV:EmptyBox','Empty spatial box.'); end
[U,b]=revision.motionPolytope(c.motionPolytope);
VV=kron(speye(Q*N),sparse(U)); AA=kron(speye(K*N),sparse(U));
C=[sparse(size(VV,1),n),VV;AA*B];
upper=[repmat(c.vmax*b,Q*N,1);repmat(c.amax*b,K*N,1)];
lower=-inf(size(upper)); C=[C,sparse(size(C,1),ns)];
R=sparse(3*E,2*n);
if E
    ii=reshape((3*(pairs(:,3)-1)+3*Q*(pairs(:,1)-1)+(1:3))',[],1);
    jj=reshape((3*(pairs(:,3)-1)+3*Q*(pairs(:,2)-1)+(1:3))',[],1);
    R=sparse([(1:3*E)';(1:3*E)'],[ii;jj],[ones(3*E,1);-ones(3*E,1)],3*E,2*n);
end
if strcmp(kind,'rsc')
    rv=reshape(R*[ref.P(:);ref.V(:)],3,E); len=vecnorm(rv);
    for e=find(len<1e-10)
        d=s.starts(:,pairs(e,1))-s.starts(:,pairs(e,2)); rv(:,e)=d; len(e)=norm(d);
    end
    if any(len<1e-10), error('REV:ZeroNormal','Undefined relative plane normal.'); end
    normals=rv./len; T=sparse(repelem((1:E)',3),1:3*E,normals(:),E,3*E);
    t=(pairs(:,3)-1)*h; rate=min(2*c.vmax,2*c.amax*min(t,c.horizon-t));
    pad=min(c.vmax*h,rate*h/2+c.amax*h^2/4)+2*c.guard;
    C=[C;T*R]; lower=[lower;2*c.radius+c.clearance+pad]; upper=[upper;inf(E,1)];
elseif soft
    S=kron(speye(E),ones(3,1));
    C=[C;R,-S;-R,-S]; lower=[lower;-inf(6*E,1)]; upper=[upper;corr.rhi(:);-corr.rlo(:)];
else
    C=[C;R]; lower=[lower;corr.rlo(:)]; upper=[upper;corr.rhi(:)];
end
H=2*c.smoothWeight*h*(B'*B); g=zeros(nx,1);
if soft
    H=H+2*rho(1)/h*(F'*F); g(2*n+1:end)=rho(2);
else
    C=[C;F]; lower=[lower;zeros(size(F,1),1)]; upper=[upper;zeros(size(F,1),1)];
end
H=blkdiag(H,sparse(ns,ns)); x0=[ref.P(:);ref.V(:);zeros(ns,1)];
x0=min(ub,max(lb,x0));
if soft&&E
    rv=reshape(R*x0(1:2*n),3,E);
    x0(2*n+1:end)=max([zeros(1,E);corr.rlo-rv;rv-corr.rhi],[],1)';
end
% Eliminate fixed endpoint variables exactly before handing the QP to a solver.
fixed=isfinite(lb)&lb==ub; free=find(~fixed); fidx=find(fixed); xf=lb(fixed);
shift=C(:,fixed)*xf;
m=struct('H',H(free,free),'g',g(free)+H(free,fixed)*xf,'C',C(:,free),...
    'lower',lower-shift,'upper',upper-shift,'lb',lb(free),'ub',ub(free),'x0',x0(free),...
    'free',free,'fixed',fidx,'fixedValues',xf,'nx',nx,'n',n,'F',F,'B',B,...
    'fullH',H,'fullg',g,'fullC',C,'fullLower',lower,'fullUpper',upper,...
    'fullLb',lb,'fullUb',ub,'relativeCount',E,'soft',soft,'kind',kind,'h',h);
% Remove identically zero redundant rows; inconsistent rows remain and are flagged.
zero=full(sum(abs(m.C),2))==0;
if any(zero&(m.lower>c.qpTolerance|m.upper<-c.qpTolerance))
    m.inconsistent=true;
else, m.inconsistent=false; end
keep=~zero; m.C=m.C(keep,:); m.lower=m.lower(keep); m.upper=m.upper(keep);
end
