function ok=pointClear(p,s,margin)
ok=all(p>=s.bounds(1,:)'+margin)&all(p<=s.bounds(2,:)'-margin);
if ~ok, return; end
for b=1:size(s.obstacles,1)
    if all(p>=s.obstacles(b,1:3)'-margin)&all(p<=s.obstacles(b,4:6)'+margin)
        ok=false; return
    end
end
end
