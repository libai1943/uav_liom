function jobs=RevisionDesign(suite)
% All scene seeds, sweep levels and variants are fixed before batch execution.
if nargin<1, suite='main'; end
base=RevisionConfig(); original=BuAblationCases(); jobs=struct([]);
switch suite
    case 'main'
        for k=1:30
            c=transfer(original(k).cfg); s=original(k).scene;
            for rep=1:3
                methods={'adaptive','liom','hard_once','hard_iter','rsc_iter'};
                if rep==1, methods=[methods,{'rsc_once','soft_once'}]; end
                methods=circshift(methods,[0,mod(k+rep-2,numel(methods))]);
                for m=methods, add(original(k).id,c,s,m{1},rep,'default'); end
            end
        end
    case 'physical'
        for f={'crossing','passage','obstacles'}
            for level=1:3
                seeds=3101:3110; if ~strcmp(f{1},'crossing'), seeds=3101:3105; end
                for seed=seeds
                    c=base; c.scenario=f{1}; c.seed=seed; c.horizon=12; c.intervals=60;
                    c.numAgents=10; if strcmp(f{1},'crossing'), c.numAgents=5+5*level; end
                    s=revision.physicalScene(c,level); id=sprintf('%s_L%d_S%d',f{1},level,seed);
                    for m={'adaptive','liom','hard_iter','rsc_iter'}, add(id,c,s,m{1},1,'default'); end
                end
            end
        end
    case 'horizon'
        for k=[13 14 19 20 25 26]
            for horizon=[8 9 10 11 12]
                c=transfer(original(k).cfg); c.horizon=horizon; s=original(k).scene;
                id=sprintf('%s_T%02d',original(k).id,horizon);
                for m={'adaptive','liom','hard_iter','rsc_iter'}, add(id,c,s,m{1},1,'default'); end
            end
        end
    case 'scaling'
        for N=[5 10 15 20]
            for K=[30 60 90]
                for seed=4101:4102
                    c=base; c.numAgents=N; c.intervals=K; c.seed=seed; c.scenario='crossing';
                    s=revision.physicalScene(c,1); id=sprintf('N%02d_K%03d_S%d',N,K,seed);
                    for rep=1:1
                        for m={'adaptive','rsc_iter'}, add(id,c,s,m{1},rep,'default'); end
                    end
                end
            end
        end
    case {'sensitivity','initialization','bounds','acceptance'}
        for k=[4 13 14 20 25 26]
            c0=transfer(original(k).cfg); s=original(k).scene; id=original(k).id;
            if strcmp(suite,'sensitivity')
                fields={'smoothWeight','kinematicPenalty','slackPenalty','kinematicPenaltyMax','slackPenaltyMax',...
                    'normalizedDefectTolerance','meanSlackTolerance','stcExpansion','rstcExpansion',...
                    'sfmRepulsion','sfmDistance','sfmLookahead','sfmTrackingTime','sfmTangentialFraction','qpCandidateTolerance'};
                add(id,c0,s,'liom',1,'nominal');
                for name=fields
                    for factor=[.5 2]
                        c=c0; c.(name{1})=factor*c0.(name{1});
                        add(id,c,s,'liom',1,sprintf('%s_x%g',name{1},factor));
                    end
                end
                for growth=[1.5 5]
                    c=c0; c.penaltyGrowth=growth; add(id,c,s,'liom',1,sprintf('growth_%g',growth));
                end
            elseif strcmp(suite,'initialization')
                for init={'sfm','straight','guide'}
                    for guides=[false true]
                        c=c0; c.initializer=init{1}; c.relocationGuides=guides;
                        add(id,c,s,'liom',1,sprintf('%s_guides%d',init{1},guides));
                    end
                end
            elseif strcmp(suite,'bounds')
                for p={'cube','hull14','hull26'}
                    c=c0; c.motionPolytope=p{1};
                    for m={'liom','rsc_iter'}, add(id,c,s,m{1},1,p{1}); end
                end
            else
                for normalized=[false true]
                    for finish=[false true]
                        c=c0; c.exactFinish=finish; c.validationRecovery=finish;
                        if ~normalized, c.recoveryCriterion='aggregate'; end
                        add(id,c,s,'liom',1,sprintf('normalized%d_finish%d',normalized,finish));
                    end
                end
            end
        end
    otherwise, error('REV:Suite','Unknown suite %s.',suite);
end
    function c=transfer(old)
        c=base;
        for name={'numAgents','seed','scenario','horizon','intervals','passageWidth','obstacleScale'}
            if isfield(old,name{1}), c.(name{1})=old.(name{1}); end
        end
    end
    function add(id,c,s,method,rep,variant)
        j=struct('id',id,'suite',suite,'cfg',c,'scene',s,'method',method,'repetition',rep,...
            'variant',variant,'key',sprintf('%s_%s_%s_R%d',id,method,variant,rep));
        if isempty(jobs), jobs=j; else, jobs(end+1)=j; end
    end
end
