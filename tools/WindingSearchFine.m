function WindingSearchFine(stage)
% Prospective winding-geometry search; every attempted outcome is retained.
if nargin<1,stage=1;end
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'code'),'C:\casadi');maxNumCompThreads(1);StartOSQP(RevisionConfig());
folder=fullfile(root,'results',sprintf('winding_fine_stage%d',stage));if ~isfolder(folder),mkdir(folder);end
jobs=struct([]);id=0;
if stage==1,counts=5;turns=3;widths=2.2;horizons=[16 20 24];seeds=6101:6102;
else,counts=[3 5 7];turns=[2 4];widths=[1.8 2.6];horizons=[16 20];seeds=6111:6112;end
for family={'baffles','portals'}
 for N=counts
  for turnsNow=turns
   for width=widths
    for horizon=horizons
     for seed=seeds
      id=id+1;c=RevisionConfig();c.numAgents=N;c.seed=seed;c.horizon=horizon;c.intervals=round(horizon/.2);c.guideResolution=.325;s=scene(c,family{1},turnsNow,width);
      for method=circshift({'adaptive','liom','rsc_iter'},[0,mod(id-1,3)])
       job=struct('id',sprintf('W%d_%03d',stage,id),'family',family{1},'turns',turnsNow,'width',width,'cfg',c,'scene',s,'method',method{1});
       if isempty(jobs),jobs=job;else,jobs(end+1)=job;end
      end
     end
    end
   end
  end
 end
end
file=fullfile(folder,'design.mat');if isfile(file),old=load(file,'jobs');assert(isequaln(old.jobs,jobs),'Design changed');else,save(file,'jobs','-v7');end
rows={};diary(fullfile(folder,'console.txt'));cleanup=onCleanup(@()diary('off'));
for k=1:numel(jobs)
 job=jobs(k);file=fullfile(folder,[job.id,'_',job.method,'.mat']);
 if isfile(file),d=load(file,'result');result=d.result;
 else
  fid=fopen(fullfile(folder,'pending.json'),'w');fprintf(fid,'%s',jsonencode(struct('index',k,'total',numel(jobs),'id',job.id,'method',job.method)));fclose(fid);
  fprintf('\nWINDING %d/%d %s %s N=%d turns=%d width=%.2f T=%g\n',k,numel(jobs),job.id,job.method,job.cfg.numAgents,job.turns,job.width,job.cfg.horizon);
  result=revision.run(job.scene,job.cfg,job.method);save(file,'job','result','-v7');
 end
 rows(end+1,:)={job.id,job.family,job.cfg.numAgents,job.turns,job.width,job.cfg.horizon,job.cfg.seed,job.method,result.success,result.successWithinBudget,result.planningSeconds,result.outerIterations,result.solveCount,result.failureStage};
 writetable(cell2table(rows,'VariableNames',{'Case','Family','N','Turns','Width','Tf','Seed','Method','Accepted','WithinBudget','Wall_s','OuterIterations','QPSolves','FailureStage'}),fullfile(folder,'summary.csv'));
end
fid=fopen(fullfile(folder,'completed.json'),'w');fprintf(fid,'%s',jsonencode(struct('completed',true,'attempts',numel(jobs))));fclose(fid);
end
function s=scene(c,family,turns,width)
rng(c.seed,'twister');N=c.numAgents;lo=[-8 -8 .5];hi=[8 8 7.5];s=struct('bounds',[lo;hi],'obstacles',zeros(0,6),'starts',zeros(3,N),'exits',zeros(3,N),'v0',zeros(3,N),'vf',zeros(3,N));
left=ceil(N/2);groups={1:left,left+1:N};
for g=1:2
 ids=groups{g};n=numel(ids);if n==0,continue;end
 yz=zeros(2,n);for j=1:n,yz(:,j)=[(-1)^j*1.15;2.6+1.1*floor((j-1)/2)];end
 yz=yz+.035*randn(2,n);x=-6;if g==2,x=6;end
 s.starts(:,ids)=[x*ones(1,n);yz];s.exits(:,ids)=[-x*ones(1,n);yz(:,randperm(n))+.025*randn(2,n)];
end
xs=linspace(-3.5,3.5,turns);
for b=1:turns
 cy=(-1)^b*1.65+.06*randn;cz=4+(-1)^b*.7;w=width/2;x=xs(b);
 s.obstacles(end+1,:)=[x-.2 lo(2) lo(3) x+.2 cy-w hi(3)];s.obstacles(end+1,:)=[x-.2 cy+w lo(3) x+.2 hi(2) hi(3)];
 if strcmp(family,'portals')
  zh=1.45;s.obstacles(end+1,:)=[x-.2 cy-w lo(3) x+.2 cy+w cz-zh];s.obstacles(end+1,:)=[x-.2 cy-w cz+zh x+.2 cy+w hi(3)];
 end
end
s.directions=(s.exits-s.starts)./vecnorm(s.exits-s.starts);s.desired=s.exits;s.name=family;s.seed=c.seed;
for i=1:N
 assert(bu3d.pointClear(s.starts(:,i),s,c.radius+c.clearance)&&bu3d.pointClear(s.exits(:,i),s,c.radius+c.clearance),'Unsafe endpoint');
 for j=1:i-1,assert(norm(s.starts(:,i)-s.starts(:,j))>=2*c.radius+c.clearance&&norm(s.exits(:,i)-s.exits(:,j))>=2*c.radius+c.clearance,'Overlapping endpoints');end
end
end
