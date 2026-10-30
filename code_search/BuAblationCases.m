function cases=BuAblationCases()
% Frozen design: 3 families x 5 levels x 2 seeds; no outcome-based filtering.
fprintf('Loading base config\n'); base=BuConfig(); fprintf('Base config done\n'); base.randomizeSeed=false;
base.methods={'full','straight','no_liom'};
base.makePlots=false; base.figureVisible='off';
base.implementationVersion='rest_to_rest_trapezoidal_clock_20260921_v2';
counts=[3 4 5 6 7]; widths=[4.4 4.0 3.6 3.2 2.8];
scales=[.5 .65 .8 .95 1.1]; seeds=[101 202];
families={'crossing','passage','obstacles'};
orders=[1 2 3;2 3 1;3 1 2;1 3 2;3 2 1;2 1 3];
cases=struct([]); id=0;
for level=1:5
    for family=1:3
        for replicate=1:2
            id=id+1; fprintf('Scene %d\n',id); c=base; c.scenario=families{family}; c.seed=seeds(replicate);
            c.passageWidth=2.8; c.obstacleScale=1;
            if family==1, c.numAgents=counts(level); difficulty=counts(level); end
            if family==2, c.passageWidth=widths(level); difficulty=widths(level); end
            if family==3, c.obstacleScale=scales(level); difficulty=scales(level); end
            entry=struct('id',sprintf('C%02d',id),'level',level,'family',c.scenario,...
                'replicate',replicate,'seed',c.seed,'difficultyValue',difficulty,...
                'methodOrder',orders(mod(id-1,6)+1,:),'cfg',c,'scene',bu3d.scene(c));
            if isempty(cases), cases=entry; else, cases(end+1)=entry; end %#ok<AGROW>
        end
    end
end
end

