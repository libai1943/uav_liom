function [candidate,info]=subproblem(ref,s,c,method,range,env)
% Task-matched strategies: full NLP, ASCO activation, SCP tangent planes,
% and hard spatial/relative separating corridors. All have hard dynamics.
import casadi.*
assert(ismember(method,{'asco','nlp','scp'}));
clock=tic; [U,bmotion]=revision.motionPolytope(c.motionPolytope); N=c.numAgents; K=c.intervals; Q=K+1; h=c.horizon/K; n=3*Q*N;
w=SX.sym('w',2*n); pi=reshape(1:n,3,Q,N); vi=pi+n;
lb=-inf(2*n,1); ub=inf(2*n,1); grows={}; lower={}; upper={}; objective=0;
useCorridor=strcmp(method,'rsc'); linear=ismember(method,{'rsc','scp'});
if useCorridor, corr=bu3d.corridors(ref,s,c,false); end
positions=cell(N,1); samples=cell(N,1); times=linspace(0,c.horizon,4*K+1); dt=h/8;
if useCorridor, times=linspace(0,c.horizon,Q); dt=h/2; end
M=numel(times); count=0;
for i=1:N
    P=reshape(w(pi(:,:,i)),3,Q); V=reshape(w(vi(:,:,i)),3,Q); A=(V(:,2:Q)-V(:,1:K))/h;
    objective=objective+c.smoothWeight*h*sumsqr(A);
    add(vec(U*A),-inf(size(U,1)*K,1),repmat(c.amax*bmotion,K,1));
    add(vec(U*V),-inf(size(U,1)*Q,1),repmat(c.vmax*bmotion,Q,1));
    add(vec(P(:,2:end)-P(:,1:end-1)-.5*h*(V(:,2:end)+V(:,1:end-1))),zeros(3*K,1),zeros(3*K,1));
    lb(pi(:,:,i))=repmat(s.bounds(1,:)'+c.radius,1,Q);
    ub(pi(:,:,i))=repmat(s.bounds(2,:)'-c.radius,1,Q);
    if useCorridor
        lb(pi(:,:,i))=max(reshape(lb(pi(:,:,i)),3,Q),corr.lo(:,:,i));
        ub(pi(:,:,i))=min(reshape(ub(pi(:,:,i)),3,Q),corr.hi(:,:,i));
        assert(all(s.starts(:,i)>=lb(pi(:,1,i))-c.validationTolerance)&&all(s.starts(:,i)<=ub(pi(:,1,i))+c.validationTolerance),'Start excluded from spatial box.');
        assert(all(s.exits(:,i)>=lb(pi(:,end,i))-c.validationTolerance)&&all(s.exits(:,i)<=ub(pi(:,end,i))+c.validationTolerance),'Goal excluded from spatial box.');
    end
    lb(vi(:,:,i))=-c.vmax; ub(vi(:,:,i))=c.vmax;
    lb(pi(:,1,i))=s.starts(:,i); ub(pi(:,1,i))=s.starts(:,i);
    lb(pi(:,end,i))=s.exits(:,i); ub(pi(:,end,i))=s.exits(:,i);
    lb(vi(:,1,i))=s.v0(:,i); ub(vi(:,1,i))=s.v0(:,i);
    lb(vi(:,end,i))=s.vf(:,i); ub(vi(:,end,i))=s.vf(:,i);
    if useCorridor
        positions{i}=P; samples{i}=ref.P(:,:,i);
    else
        Ps={}; Rs={};
        for u=[0,.25,.5,.75]
            Ps{end+1}=(1-u)*P(:,1:K)+u*P(:,2:Q)-.5*h*u*(1-u)*(V(:,2:Q)-V(:,1:K)); %#ok<AGROW>
            Rs{end+1}=(1-u)*ref.P(:,1:K,i)+u*ref.P(:,2:Q,i)-.5*h*u*(1-u)*diff(ref.V(:,:,i),1,2); %#ok<AGROW>
        end
        % Interleave quarter-interval samples in increasing time order.
        T=horzcat(Ps{:}); R=horzcat(Rs{:}); order=reshape(reshape(1:4*K,K,4)',1,[]);
        positions{i}=[T(:,order),P(:,end)]; samples{i}=[R(:,order),ref.P(:,end,i)];
    end
end
for i=1:N
    for j=i+1:N
        r=samples{i}-samples{j}; lengths=vecnorm(r); signed=lengths-2*c.radius;
        active=true(1,M);
        if strcmp(method,'asco'), active=signed>=range(1)&signed<=range(2); end
        idx=find(active); count=count+numel(idx); if isempty(idx), continue; end
        d=positions{i}(:,idx)-positions{j}(:,idx);
        rate=min(2*c.vmax,min(norm(s.v0(:,i)-s.v0(:,j))+2*c.amax*times(idx),norm(s.vf(:,i)-s.vf(:,j))+2*c.amax*(c.horizon-times(idx))));
        pad=min(2*c.vmax*dt,rate*dt+c.amax*dt^2)+2*c.guard;
        safe=2*c.radius+c.clearance+pad;
        if strcmp(method,'rsc')
            normal=r(:,idx)./max(lengths(idx),1e-12);
            if any(lengths(idx)<1e-12), error('COMPARE:ZeroNormal','Undefined relative plane normal.'); end
            add(sum1(normal.*d)',safe',inf(numel(idx),1));
        elseif strcmp(method,'scp')
            add(sum1(2*r(:,idx).*d)',(safe.^2+lengths(idx).^2)',inf(numel(idx),1));
        else
            add(sum1(d.^2)',safe'.^2,inf(numel(idx),1));
        end
    end
    if ~useCorridor
        for b=1:size(s.obstacles,1)
            ob=s.obstacles(b,:); R=samples{i}; near=min(max(R,ob(1:3)'),ob(4:6)');
            d0=R-near; lengths=vecnorm(d0);
            signedFaces=max(ob(1:3)'-R,R-ob(4:6)');
            signed=lengths+min(max(signedFaces,[],1),0)-c.radius;
            active=true(1,M);
            if strcmp(method,'asco'), active=signed>=range(1)&signed<=range(2); end
            idx=find(active); count=count+numel(idx); if isempty(idx), continue; end
            P=positions{i}(:,idx);
            rate=min(c.vmax,min(norm(s.v0(:,i))+c.amax*times(idx),norm(s.vf(:,i))+c.amax*(c.horizon-times(idx))));
            pad=min(c.vmax*dt,rate*dt+.5*c.amax*dt^2)+c.guard; safe=c.radius+c.clearance+pad;
            if strcmp(method,'scp')
                add(sum1(2*d0(:,idx).*P)',(safe.^2-lengths(idx).^2+sum(2*d0(:,idx).*R(:,idx)))',inf(numel(idx),1));
            else
                signedDistance=external.signedBoxDistance(P,ob);
                add(signedDistance',safe',inf(numel(idx),1));
            end
        end
    end
end
g=vertcat(grows{:}); lbg=vertcat(lower{:}); ubg=vertcat(upper{:});

x0=min(ub,max(lb,[ref.P(:);ref.V(:)]));
% Actual quadratic/affine instances always go through OSQP, including an
% ASCO iteration with no active nonlinear collision constraints.
if linear||count==0
    expr=Function('qp_export',{w},{hessian(objective,w),gradient(objective,w),jacobian(g,w),g});
    [hh,gg,cc,offset]=expr(zeros(2*n,1));
    H=sparse(hh); gv0=full(gg); C=sparse(cc); offset=full(offset);
    lo=lbg-offset; hi=ubg-offset;
    fixed=isfinite(lb)&lb==ub; free=find(~fixed); ff=find(fixed); xf=lb(fixed); shift=C(:,fixed)*xf;
    D=sparse(1:K,1:K,-1,K,Q)+sparse(1:K,2:Q,1,K,Q);
    M0=sparse(1:K,1:K,.5,K,Q)+sparse(1:K,2:Q,.5,K,Q);
    F=[kron(speye(N),kron(D,speye(3))),-h*kron(speye(N),kron(M0,speye(3)))];
    m=struct('H',H(free,free),'g',gv0(free)+H(free,fixed)*xf,'C',C(:,free),...
      'lower',lo-shift,'upper',hi-shift,'lb',lb(free),'ub',ub(free),'x0',x0(free),...
      'free',free,'fixed',ff,'fixedValues',xf,'nx',2*n,'n',n,'F',F,'fullH',H,'fullg',gv0,...
      'fullC',C,'fullLower',lo,'fullUpper',hi,'fullLb',lb,'fullUb',ub,...
      'relativeCount',0,'soft',false,'kind','direct','h',h);
    zero=full(sum(abs(m.C),2))==0;
    m.inconsistent=any(zero&(m.lower>c.qpTolerance|m.upper<-c.qpTolerance));
    m.C=m.C(~zero,:);m.lower=m.lower(~zero);m.upper=m.upper(~zero);
    assembly=toc(clock); opts=c;opts.maxCpuSeconds=max(.01,c.availableSeconds-assembly);
    if assembly>=c.availableSeconds
        candidate=[];info=budgetInfo(assembly);return;
    end
    [candidate,info]=revision.qp(m,opts);
    info.buildSeconds=info.buildSeconds+assembly;
    info.maxConstraintViolation=info.violation;info.collisionConstraints=count;
    info.iterations=info.solverIterations;info.optimizedObjective=info.objective;
    info.constraints=numel(lbg);return;
end
opts=struct('print_time',false,'error_on_fail',false);
opts.ipopt=struct('print_level',0,'max_iter',2000,'max_cpu_time',max(.01,c.availableSeconds-toc(clock)),...
    'tol',1e-7,'acceptable_tol',1e-6,'linear_solver',env.linearSolver,...
    'mu_strategy','adaptive','fixed_variable_treatment','make_parameter','bound_relax_factor',0);
if strcmp(method,'asco'),opts.ipopt.max_cpu_time=min(5,opts.ipopt.max_cpu_time);end
solver=nlpsol('comparison_solver','ipopt',struct('x',w,'f',objective,'g',g),opts);
buildSeconds=toc(clock);
if buildSeconds>=c.availableSeconds,candidate=[];info=budgetInfo(buildSeconds);return;end
% Ipopt's CPU cap is set before symbolic solver initialization. The recorded
% total wall budget is the common comparison gate; overruns remain recorded.
tick=tic;sol=solver('x0',x0,'lbx',lb,'ubx',ub,'lbg',lbg,'ubg',ubg);
solveSeconds=toc(tick);stats=solver.stats();z=full(sol.x);gv=full(sol.g);
candidate=struct('P',reshape(z(1:n),3,Q,N),'V',reshape(z(n+1:end),3,Q,N));
candidate.A=diff(candidate.V,1,2)/h;
info=struct('status',stats.return_status,'iterations',stats.iter_count,'variables',2*n,'constraints',numel(lbg),...
    'collisionConstraints',count,'buildSeconds',buildSeconds,'solveSeconds',solveSeconds,...
    'maxConstraintViolation',max([0;lb-z;z-ub;lbg-gv;gv-ubg]),'finite',all(isfinite(z))&&max(abs(z))<1e10,...
    'optimizedObjective',full(sol.f),'solverStatistics',stats,'backend','ipopt','workerCpuSeconds',0);
    function v=budgetInfo(seconds)
        v=struct('status','BUILD_BUDGET','finite',false,'maxConstraintViolation',Inf,...
          'buildSeconds',seconds,'solveSeconds',0,'collisionConstraints',count,'backend','none','workerCpuSeconds',0);
    end
    function add(expression,lo,hi)
        grows{end+1}=expression; lower{end+1}=lo; upper{end+1}=hi;
    end
end
