function [U,b,vertices]=motionPolytope(kind)
% Convex hull of unit vectors is an INNER approximation of the Euclidean ball.
% Each row U*x <= b is linear. Axial vertices attain the full physical limit.
if strcmp(kind,'cube')
    U=[eye(3);-eye(3)]; b=ones(6,1)/sqrt(3); vertices=[]; return;
end
assert(ismember(kind,{'hull14','hull26'}),'REV:Polytope','Unknown motion polytope.');
[a,b0,d]=ndgrid(-1:1,-1:1,-1:1); vertices=[a(:),b0(:),d(:)];
if strcmp(kind,'hull14'), vertices(sum(abs(vertices),2)==2,:)=[]; end
vertices(all(vertices==0,2),:)=[]; vertices=vertices./vecnorm(vertices,2,2);
facets=convhulln(vertices); rows=zeros(size(facets,1),4);
for k=1:size(facets,1)
    v=vertices(facets(k,:),:); normal=cross(v(2,:)-v(1,:),v(3,:)-v(1,:));
    normal=normal/norm(normal); offset=normal*v(1,:)';
    if offset<0, normal=-normal; offset=-offset; end
    rows(k,:)=[normal,offset];
end
rows=unique(round(rows,12),'rows'); U=rows(:,1:3); b=rows(:,4);
end
