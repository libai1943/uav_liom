function WaitForQuietCPU()
% Exclude external CPU-load waiting from algorithm timing.
root=fileparts(fileparts(mfilename('fullpath')));
if ~isfile(fullfile(root,'tmp','managed_timing')),return;end
python=getenv('UAV_PYTHON');if isempty(python),python='python';end
[status,message]=system(sprintf('"%s" "%s" --gate --seconds 2',python,fullfile(root,'tools','quiet_runner.py')));
assert(status==0,'TIMING:Gate','CPU-load gate failed: %s',message);
end
