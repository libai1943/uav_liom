function plotCase(result,s,c,folder)
if ~result.success, return; end
f=figure('Visible','off','Color','w','Position',[100 100 1200 900]);
layout=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact'); colors=lines(c.numAgents);
for panel=1:2
    ax=nexttile(layout); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    for i=1:c.numAgents
        P=result.trajectory.P(:,:,i);
        if panel==2, P=result.reference.P(:,:,i); end
        plot3(ax,P(1,:),P(2,:),P(3,:),'Color',colors(i,:),'LineWidth',1.6);
        scatter3(ax,P(1,1),P(2,1),P(3,1),24,colors(i,:),'filled');
        plot3(ax,P(1,end),P(2,end),P(3,end),'s','Color',colors(i,:));
    end
    for b=1:size(s.obstacles,1)
        ob=s.obstacles(b,:); [xx,yy,zz]=ndgrid(ob([1 4]),ob([2 5]),ob([3 6]));
        verts=[xx(:),yy(:),zz(:)]; faces=convhulln(verts);
        patch(ax,'Vertices',verts,'Faces',faces,'FaceColor',[.65 .65 .65],'FaceAlpha',.15,'EdgeAlpha',.2);
    end
    xlabel(ax,'x (m)'); ylabel(ax,'y (m)'); zlabel(ax,'z (m)'); axis(ax,'equal'); view(ax,40,25);
    if panel==1, title(ax,'Accepted cooperative motion'); else, title(ax,'Initial geometric reference'); end
end
t=linspace(0,c.horizon,c.intervals+1);
ax=nexttile(layout); hold(ax,'on'); grid(ax,'on');
for i=1:c.numAgents, plot(ax,t,vecnorm(result.trajectory.V(:,:,i)),'Color',colors(i,:),'LineWidth',1.3); end
yline(ax,c.vmax,'k--'); xlabel(ax,'Time (s)'); ylabel(ax,'Speed (m/s)'); title(ax,'Euclidean speed');
ax=nexttile(layout); hold(ax,'on'); grid(ax,'on');
for i=1:c.numAgents
    a=vecnorm(result.trajectory.A(:,:,i)); stairs(ax,t,[a,a(end)],'Color',colors(i,:),'LineWidth',1.3);
end
yline(ax,c.amax,'k--'); xlabel(ax,'Time (s)'); ylabel(ax,'Acceleration (m/s^2)'); title(ax,'Control magnitude');
exportgraphics(f,fullfile(folder,'trajectories_and_controls.pdf'),'ContentType','vector');
exportgraphics(f,fullfile(folder,'trajectories_and_controls.png'),'Resolution',180); close(f);
end
