function result=run(s,c,method,sharedReference)
% Fixed task, common physical acceptance and budget across all method variants.
clock=tic; cpu0=cputime; reference=[]; initializationOffset=0; cpuOffset=0;
result=struct('method',method,'success',false,'successWithinBudget',false,...
    'status','NOT_RUN','failureStage','','history',{{}},'cost',NaN,'outerIterations',0,...
    'solveCount',0,'workerCpuSeconds',0,'initializationSeconds',0,'guideSeconds',0,'sfmAndTimingSeconds',0,...
    'corridorSeconds',0,'assemblySeconds',0,'solverSetupSeconds',0,'solveSeconds',0,...
    'verificationSeconds',0,'endpointCorrectionSeconds',0,'exactFinishCount',0,...
    'relocatedStatic',0,'relocatedRelative',0,'maxVariables',0,'maxRows',0,'maxNonzeros',0);
try
    tick=tic;
    try
        if nargin>=4
            reference=sharedReference;
            initializationOffset=reference.seconds; cpuOffset=reference.cpuSeconds;
        else, reference=revision.initialize(s,c); end
    catch err
        result.initializationSeconds=toc(tick); result.guideSeconds=NaN; result.sfmAndTimingSeconds=NaN;
        result.failureStage='initialization'; rethrow(err);
    end
    result.initializationSeconds=reference.seconds; result.guideSeconds=reference.guideSeconds;
    result.sfmAndTimingSeconds=reference.sfmAndTimingSeconds; ref=reference;
    rho=[c.kinematicPenalty,c.slackPenalty]; budget=max(0,c.totalBudget-initializationOffset); qTolerance=c.normalizedDefectTolerance;
    oneshot=ismember(method,{'hard_once','rsc_once','soft_once'});
    maxOuter=c.maxOuter; if oneshot, maxOuter=1; end
    for outer=1:maxOuter
        if toc(clock)>=budget, result.status='BUDGET_EXHAUSTED'; result.failureStage='budget'; break; end
        result.outerIterations=outer; tick=tic;
        isRsc=ismember(method,{'rsc_once','rsc_iter'});
        try, corr=bu3d.corridors(ref,s,c,~isRsc);
        catch err, result.failureStage='corridor_construction'; rethrow(err); end
        result.corridorSeconds=result.corridorSeconds+toc(tick);
        result.relocatedStatic=result.relocatedStatic+corr.relocatedStatic;
        result.relocatedRelative=result.relocatedRelative+corr.relocatedRelative;
        kind='soft';
        if isRsc, kind='rsc'; elseif ismember(method,{'hard_once','hard_iter'}), kind='hard'; end
        phases={kind}; if strcmp(method,'hybrid'), phases={'hard','soft'}; end
        if strcmp(method,'adaptive')&&outer==1, phases={'rsc','soft'}; end
        candidate=[]; numerical=false; validation=struct('success',false,'message','not checked');
        for phase=1:numel(phases)
            if toc(clock)>=budget, break; end
            validation=struct('success',false,'message','not checked');
            kind=phases{phase}; [candidate,info]=oneSolve(kind);
            numerical=gate(info,strcmp(kind,'soft'));
            accepted=false; restoration=[];
            if numerical, [motion,restoration,validation]=checkMotion(candidate); accepted=validation.success; end
            record(info,kind,numerical,accepted,validation,restoration,candidate);
            if accepted, accept(motion,validation,restoration,candidate); break; end
            if numerical&&~accepted&&strcmp(kind,'soft')&&c.validationRecovery
                qTolerance=max(c.minDefectTolerance,qTolerance/4);
                rho(1)=min(c.kinematicPenaltyMax,rho(1)*c.penaltyGrowth);
            end
            if numerical&&~accepted&&strcmp(kind,'soft')&&c.exactFinish&&toc(clock)<budget
                % Same spatial/relative corridors and task; replace both softened blocks by exact constraints.
                result.exactFinishCount=result.exactFinishCount+1;
                [polished,hardInfo]=oneSolve('hard'); hardPass=gate(hardInfo,false);
                report=struct('success',false,'message','exact finish numerical gate'); restore=[];
                if hardPass, [motion,restore,report]=checkMotion(polished); end
                record(hardInfo,'exact_finish',hardPass,hardPass&&report.success,report,restore,polished);
                if hardPass&&report.success, accept(motion,report,restore,polished); break; end
                % Keep the relaxed iterate for the shared next-corridor update when exact finishing fails.
            end
        end
        if result.success, break; end
        if toc(clock)>=budget, result.status='BUDGET_EXHAUSTED'; result.failureStage='budget'; break; end
        result.status='NOT_ACCEPTED'; result.failureStage='numerical_recovery';
        if numerical, result.failureStage='continuous_validation'; end
        usable=candidate;
        if isempty(candidate)||~info.finite, usable=[]; end
        result.lastCandidate=candidate; result.lastCorridors=corr;
        next=revision.relocate(ref,usable,corr,s,c);
        moved=max(abs(next.P(:)-ref.P(:))); ref=next;
        if strcmp(kind,'soft')&&exist('info','var')
            if ~defectPass(info), rho(1)=min(c.kinematicPenaltyMax,rho(1)*c.penaltyGrowth); end
            if ~slackPass(info), rho(2)=min(c.slackPenaltyMax,rho(2)*c.penaltyGrowth); end
        end
        if ~oneshot&&ismember(method,{'hard_iter','rsc_iter'})&&moved<1e-9
            result.status='STALLED_HARD_RECONSTRUCTION'; result.failureStage='hard_reconstruction_stalled'; break;
        end
    end
catch err
    result.status=['ERROR:',err.identifier];
    result.exception=struct('identifier',err.identifier,'message',err.message,'stack',err.stack);
    if isempty(result.failureStage), result.failureStage='solver_or_program'; end
    fprintf(2,'%s: %s\n',method,err.message);
end
result.reference=reference; result.planningSeconds=toc(clock)+initializationOffset; result.cpuSeconds=cputime-cpu0+result.workerCpuSeconds+cpuOffset;
result.successWithinBudget=result.success&&result.planningSeconds<=c.totalBudget;
result.timeWithinBudget=result.planningSeconds<=c.totalBudget;
if result.success&&~result.successWithinBudget, result.status='ACCEPTED_OVER_BUDGET'; end
result.horizon=c.horizon;
fprintf('RESULT %-11s accepted=%d acceptedWithinBudget=%d solves=%d wall=%.3f s stage=%s\n',...
    method,result.success,result.successWithinBudget,result.solveCount,result.planningSeconds,result.failureStage);
    function [x,inf0]=oneSolve(which)
        opts=c; opts.maxCpuSeconds=max(.01,min(c.maxCpuSeconds,budget-toc(clock)));
        if strcmp(method,'hybrid')&&strcmp(which,'hard'), opts.maxCpuSeconds=min(opts.maxCpuSeconds,c.hardFirstSeconds); end
        if strcmp(method,'adaptive')&&strcmp(which,'rsc'), opts.maxCpuSeconds=min(opts.maxCpuSeconds,c.fastPathSeconds); end
        opts.normalizedDefectTolerance=qTolerance;
        if oneshot, opts.maxCpuSeconds=max(.01,budget-toc(clock)); end
        tick0=tic; model=revision.model(ref,corr,s,opts,which,rho);
        assembly=toc(tick0); result.assemblySeconds=result.assemblySeconds+assembly;
        [x,inf0]=revision.qp(model,opts); inf0.assemblySeconds=assembly;
        result.solveCount=result.solveCount+1;
        if isfield(inf0,'workerCpuSeconds'), result.workerCpuSeconds=result.workerCpuSeconds+inf0.workerCpuSeconds; end
        result.solverSetupSeconds=result.solverSetupSeconds+inf0.buildSeconds;
        result.solveSeconds=result.solveSeconds+inf0.solveSeconds;
        result.maxVariables=max(result.maxVariables,inf0.variables);
        result.maxRows=max(result.maxRows,inf0.rows); result.maxNonzeros=max(result.maxNonzeros,inf0.nonzeros);
    end
    function yes=defectPass(inf0)
        if strcmp(c.recoveryCriterion,'normalized'), yes=inf0.normalizedD<=qTolerance;
        else, yes=inf0.D<=c.discreteInfeasibilityTolerance; end
    end
    function yes=slackPass(inf0)
        if strcmp(c.recoveryCriterion,'normalized'), yes=inf0.meanSlack<=c.meanSlackTolerance;
        else, yes=inf0.S<=c.slackSumTolerance; end
    end
    function yes=gate(inf0,soft)
        yes=inf0.finite&&inf0.violation<=c.qpCandidateTolerance;
        if soft, yes=yes&&defectPass(inf0)&&slackPass(inf0); end
    end
    function [out,restore,report]=checkMotion(x)
        tick0=tic; [out,restore]=bu3d.executable(x,s,c);
        result.endpointCorrectionSeconds=result.endpointCorrectionSeconds+toc(tick0);
        tick0=tic; report=bu3d.validate(out,s,c);
        result.verificationSeconds=result.verificationSeconds+toc(tick0);
    end
    function record(inf0,which,rec,passed,report,restore,raw)
        item=struct('outer',outer,'phase',which,'rho',rho,'defectTolerance',qTolerance,'info',inf0,'numericalRecovery',rec,...
            'accepted',passed,'validation',report,'restoration',restore,...
            'relocatedStatic',corr.relocatedStatic,'relocatedRelative',corr.relocatedRelative,...
            'candidate',raw,'corridors',corr);
        result.history{end+1}=item;
        fprintf('  %s %d/%s: %s D=%.3g S=%.3g violation=%.2g; %s\n',...
            method,outer,which,inf0.status,inf0.D,inf0.S,inf0.violation,report.message);
    end
    function accept(out,report,restore,raw)
        result.success=true; result.status='ACCEPTED'; result.failureStage='';
        result.trajectory=out; result.validation=report; result.restoration=restore;
        result.candidate=raw; result.corridors=corr;
        result.cost=c.smoothWeight*(c.horizon/c.intervals)*sum(out.A(:).^2);
    end
end
