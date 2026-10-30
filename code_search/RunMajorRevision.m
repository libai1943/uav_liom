function RunMajorRevision()
% Complete planned evidence set, resumable per attempt; never remove failures.
addpath('tests'); c=BuConfig(); bu3d.scene(c); StartOSQP(RevisionConfig());
fprintf('BEGIN MAJOR REVISION V6 %s\n',datestr(now,30));
for suite={'main','physical','horizon','scaling','sensitivity','initialization','bounds','acceptance'}
 fprintf('BEGIN SUITE %s\n',suite{1}); RunRevisionStudy(suite{1});
end
c=RevisionConfig(); fid=fopen(fullfile(c.outputRoot,'completed.json'),'w');
fprintf(fid,'%s',jsonencode(struct('completed',true,'finished',datestr(now,30))));fclose(fid);
fprintf('ALL PLANNED OSQP EXPERIMENTS COMPLETE\n');
end
