function distance=signedBoxDistance(P,ob)
% Exact positive-level feasible sets; retain an escape gradient inside boxes.
% The tiny norm floor acts only within 1e-8 m of the box, far inside every
% excluded UAV clearance region, and cannot introduce a feasible point.
import casadi.*
M=size(P,2); faces=fmax(repmat(ob(1:3)',1,M)-P,P-repmat(ob(4:6)',1,M));
positive=fmax(faces,0);
distance=sqrt(fmax(sum1(positive.^2),1e-16))+fmin(fmax(fmax(faces(1,:),faces(2,:)),faces(3,:)),0);
end
