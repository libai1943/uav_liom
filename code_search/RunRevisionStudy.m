function folder=RunRevisionStudy(suite,selection)
% Atomic per-attempt files, exact source freeze, deterministic resumption.
if nargin<1, suite='main'; end
root=fileparts(mfilename('fullpath')); addpath(root);
setenv('OMP_NUM_THREADS','1'); setenv('MKL_NUM_THREADS','1'); maxNumCompThreads(1);
c=RevisionConfig(); folder=fullfile(c.outputRoot,suite); if ~isfolder(folder), mkdir(folder); end
fprintf('STAGE source manifest\n');
manifest=revision.sourceManifest(root);
workerFile=fullfile(fileparts(root),'tools','osqp_worker.py');
workerText=fileread(workerFile); md=java.security.MessageDigest.getInstance('SHA-256'); md.update(uint8(workerText));
manifest.workerSha256=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[])); frozen=fullfile(c.outputRoot,'source_manifest.mat');
if isfile(frozen)
    old=load(frozen,'manifest'); assert(isequal(old.manifest,manifest),'REV:SourceChanged','Frozen source changed: use a new experiment tag/output directory.');
else
    save(frozen,'manifest');
    copyfile(workerFile,fullfile(c.outputRoot,'osqp_worker.py'));
    for k=1:numel(manifest.paths)
        dest=fullfile(c.outputRoot,'source_snapshot',manifest.paths{k});
        if ~isfolder(fileparts(dest)), mkdir(fileparts(dest)); end
        copyfile(fullfile(root,manifest.paths{k}),dest);
    end
end
fprintf('STAGE scenario design\n');
jobs=RevisionDesign(suite);
fprintf('STAGE environment, %d jobs\n',numel(jobs));
environment=struct('matlab',version,'qpSolver','OSQP 1.1.3',...
    'platform',computer,'threads',maxNumCompThreads,'started',datestr(now,30));
fprintf('STAGE saving design\n');
designFile=fullfile(folder,'design.mat');
if isfile(designFile)
    old=load(designFile,'jobs'); assert(isequaln(old.jobs,jobs),'REV:DesignChanged','Design differs from stored jobs.');
else, save(designFile,'jobs','environment','manifest'); end
fprintf('STAGE mirroring source\n');
mirror=fullfile(c.backupRoot,suite); if ~isfolder(mirror), mkdir(mirror); end
copyfile(designFile,fullfile(mirror,'design.mat'));
copyfile(frozen,fullfile(c.backupRoot,'source_manifest.mat'));
if ~isfolder(fullfile(c.backupRoot,'source_snapshot'))
    copyfile(fullfile(c.outputRoot,'source_snapshot'),fullfile(c.backupRoot,'source_snapshot'));
end
if nargin<2, selection=1:numel(jobs); end
diary(fullfile(folder,'console.txt')); closeDiary=onCleanup(@()diary('off')); %#ok<NASGU>
fprintf('SUITE %s: %d planned attempts; %d selected\n',suite,numel(jobs),numel(selection));
for index=selection
    job=jobs(index); file=fullfile(folder,[job.key,'.mat']);
    if isfile(file), continue; end
    pending=struct('index',index,'key',job.key,'started',datestr(now,30));
    fid=fopen(fullfile(folder,'pending.json'),'w'); fprintf(fid,'%s',jsonencode(pending)); fclose(fid);
    fprintf('\nATTEMPT %d/%d %s N=%d K=%d T=%g\n',index,numel(jobs),job.key,job.cfg.numAgents,job.cfg.intervals,job.cfg.horizon);
    result=revision.run(job.scene,job.cfg,job.method);
    temp=fullfile(folder,[job.key,'.partial.mat']); save(temp,'job','result','environment','-v7'); movefile(temp,file,'f');
    copyfile(file,fullfile(mirror,[job.key,'.mat']));
    SummarizeRevisionStudy(suite);
end
fid=fopen(fullfile(folder,'pending.json'),'w'); fprintf(fid,'%s',jsonencode(struct('status','selection_complete','finished',datestr(now,30)))); fclose(fid);
SummarizeRevisionStudy(suite);
copyfile(fullfile(folder,'summary.csv'),fullfile(mirror,'summary.csv'));
fprintf('SELECTION COMPLETE %s\n',folder);
end
