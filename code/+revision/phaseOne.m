function report=phaseOne(m,c)
% Independent HiGHS LP: minimize a common row-scaled violation of hard QP rows.
% No claim of an exact-arithmetic infeasibility certificate is made.
import casadi.*
clock=tic; n=numel(m.free); normRow=max(1,full(sqrt(sum(m.C.^2,2))));
scale=spdiags(1./normRow,0,numel(normRow),numel(normRow)); C=scale*m.C;
lo=m.lower./normRow; hi=m.upper./normRow;
iu=isfinite(hi); il=isfinite(lo); A=[C(iu,:),-ones(sum(iu),1);-C(il,:),-ones(sum(il),1)];
u=[hi(iu);-lo(il)]; lb=[m.lb;0]; ub=[m.ub;Inf];
% Detect impossible fixed rows eliminated from the reduced model separately.
if m.inconsistent
    report=struct('status','INCONSISTENT_FIXED_ROW','minimumScaledViolation',Inf,'seconds',toc(clock)); return;
end
H=DM(sparse(n+1,n+1)); Ad=DM(sparse(A));
opts=struct('error_on_fail',false,'print_time',false,'highs',struct('output_flag',false,'time_limit',c.totalBudget));
f=conic('phase_one','highs',struct('h',H.sparsity(),'a',Ad.sparsity()),opts);
g=[zeros(n,1);1]; z=f('h',H,'g',g,'a',Ad,'lba',-inf(size(u)),'uba',u,'lbx',lb,'ubx',ub);
stats=f.stats(); x=full(z.x); la=full(z.lam_a); lx=full(z.lam_x);
stationarity=norm(g+A'*la+lx,Inf);
bound=0; valid=true;
for j=1:numel(la)
    if la(j)<-1e-9, valid=false; end
    bound=bound-la(j)*u(j);
end
for j=1:numel(lx)
    if lx(j)>0
        if isfinite(ub(j)), bound=bound-lx(j)*ub(j); elseif lx(j)>1e-9, valid=false; end
    else
        if isfinite(lb(j)), bound=bound-lx(j)*lb(j); elseif lx(j)<-1e-9, valid=false; end
    end
end
report=struct('status',stats.return_status,'solverSuccess',stats.success,...
    'minimumScaledViolation',x(end),'primalViolation',max([0;A*x-u;lb-x;x-ub]),...
    'dualStationarity',stationarity,'dualBound',bound,'dualSignsValid',valid,...
    'dualityGap',x(end)-bound,'seconds',toc(clock),'statistics',stats,'primal',x,'dualRows',la,'dualBounds',lx);
report.numericallySupportedInfeasibility=stats.success&&valid&&stationarity<1e-8&&...
    report.primalViolation<1e-7&&bound>1e-6&&abs(report.dualityGap)<1e-6;
end
