function [out,info]=executable(candidate,s,c)
% Orthogonal control correction enforcing BOTH endpoint moments, then rollout.
% This is a closed-form 2-by-2 solve per axis, not an additional NLP.
K=c.intervals; h=c.horizon/K; N=c.numAgents;
H=[h*ones(1,K);h^2*(K-(0:K-1)-.5)];
out=candidate; A=diff(candidate.V,1,2)/h;
out.P=zeros(3,K+1,N); out.V=out.P; out.A=A;
info=struct('maxControlCorrection',0,'maxPositionChange',0,'endpointError',0);
for i=1:N
    target=[s.vf(:,i)-s.v0(:,i),s.exits(:,i)-s.starts(:,i)-c.horizon*s.v0(:,i)]';
    original=A(:,:,i)';
    corrected=original+H'*((H*H')\(target-H*original));
    out.A(:,:,i)=corrected';
    out.P(:,1,i)=s.starts(:,i); out.V(:,1,i)=s.v0(:,i);
    for k=1:K
        out.P(:,k+1,i)=out.P(:,k,i)+h*out.V(:,k,i)+.5*h^2*out.A(:,k,i);
        out.V(:,k+1,i)=out.V(:,k,i)+h*out.A(:,k,i);
    end
    info.maxControlCorrection=max(info.maxControlCorrection,max(abs(corrected(:)-original(:))));
    info.endpointError=max([info.endpointError;abs(out.P(:,end,i)-s.exits(:,i));abs(out.V(:,end,i)-s.vf(:,i))]);
end
info.maxPositionChange=max(abs(out.P(:)-candidate.P(:)));
out.representation='integrated_piecewise_constant_acceleration';
end
