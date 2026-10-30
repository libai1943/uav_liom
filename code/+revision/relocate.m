function next=relocate(previous,candidate,corr,s,c)
% Shared deterministic reference update for both hard and relaxed outer loops.
% Finite numerical iterates may seed a new corridor; they are never accepted here.
next=previous;
if ~isempty(candidate)&&all(isfinite([candidate.P(:);candidate.V(:)]))&&max(abs(candidate.P(:)))<1e4
    next.P=candidate.P; next.V=candidate.V;
else
    next.P=.5*(corr.lo+corr.hi);
end
for i=1:c.numAgents
    next.P(:,1,i)=s.starts(:,i); next.P(:,end,i)=s.exits(:,i);
    next.V(:,1,i)=s.v0(:,i); next.V(:,end,i)=s.vf(:,i);
end
next.A=diff(next.V,1,2)/(c.horizon/c.intervals);
end
