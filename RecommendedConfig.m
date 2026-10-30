function c=RecommendedConfig()
% Recommended configuration; frozen benchmark defaults remain in code/.
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'code'));
c=RevisionConfig(); c.fastPathSeconds=3;
c.experimentTag='recommended_3s_20261031';
c.outputRoot=fullfile(root,'results','recommended_3s');
c.backupRoot=fullfile(root,'results','recommended_3s_mirror');
end
