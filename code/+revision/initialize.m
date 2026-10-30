function ref=initialize(s,c)
% Factorial controls separate the geometric reference from relocation guides.
clock=tic; cpu0=cputime;
if strcmp(c.initializer,'guide')
    tick=tic; paths=cell(1,c.numAgents);
    for i=1:c.numAgents, paths{i}=bu3d.guide(s.starts(:,i),s.exits(:,i),s,c); end
    gs=toc(tick); ref=bu3d.referenceProfile(paths,s,c); ref.guides=paths;
    ref.guideSeconds=gs; ref.simulatedDuration=0;
else
    fallbackReason='';
    try
        ref=bu3d.initialize(s,c,c.initializer);
    catch err
        if c.referenceFallback && strcmp(c.initializer,'sfm') && ismember(err.identifier,{'BU3D:SFMTimeout','BU3D:ReferenceTimeLaw'})
            fallbackReason=err.identifier; tick=tic; paths=cell(1,c.numAgents);
            for i=1:c.numAgents, paths{i}=bu3d.guide(s.starts(:,i),s.exits(:,i),s,c); end
            gs=toc(tick); ref=bu3d.referenceProfile(paths,s,c); ref.guides=paths;
            ref.guideSeconds=gs; ref.simulatedDuration=0;
        else, rethrow(err); end
    end
    ref.fallbackReason=fallbackReason;
    if strcmp(c.initializer,'straight')&&c.relocationGuides
        tick=tic; ref.guides=cell(1,c.numAgents);
        for i=1:c.numAgents, ref.guides{i}=bu3d.guide(s.starts(:,i),s.exits(:,i),s,c); end
        ref.guideSeconds=toc(tick);
    end
end
if ~isfield(ref,'fallbackReason'), ref.fallbackReason=''; end
if ~c.relocationGuides&&isfield(ref,'guides'), ref=rmfield(ref,'guides'); end
ref.seconds=toc(clock); ref.cpuSeconds=cputime-cpu0; ref.kind=c.initializer;
ref.sfmAndTimingSeconds=max(0,ref.seconds-ref.guideSeconds);
ref.timingDescription='common-horizon trapezoid applied to each geometric arc length';
end
