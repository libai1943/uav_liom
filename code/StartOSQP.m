function StartOSQP(c)
% Start/reuse a project-local OSQP service before planning timing begins.
if nargin<1,c=RevisionConfig();end
root=fileparts(fileparts(mfilename('fullpath')));
if ping(),return;end
python=getenv('UAV_PYTHON');
if isempty(python)
    bundled=fullfile(getenv('USERPROFILE'),'.cache','codex-runtimes','codex-primary-runtime','dependencies','python','python.exe');
    if isfile(bundled),python=bundled;else,python='python';end
end
if ~isfolder(fullfile(root,'tmp')),mkdir(fullfile(root,'tmp'));end
start=System.Diagnostics.ProcessStartInfo();start.FileName=python;
start.Arguments=sprintf('-u "%s" %d',fullfile(root,'tools','osqp_worker.py'),c.osqpPort);
start.UseShellExecute=false;start.CreateNoWindow=true;start.WorkingDirectory=root;
setenv('TEMP',fullfile(root,'tmp'));setenv('TMP',fullfile(root,'tmp'));
setenv('PYTHONDONTWRITEBYTECODE','1');setenv('OPENBLAS_NUM_THREADS','1');
p=System.Diagnostics.Process.Start(start);
fid=fopen(fullfile(root,'tmp','osqp_worker.pid'),'w');fprintf(fid,'%d',p.Id);fclose(fid);
for k=1:40
    pause(.25);if ping(),return;end
    if p.HasExited,error('REV:WorkerStartup','OSQP worker stopped. Install requirements and set UAV_PYTHON to the Python executable.');end
end
error('REV:WorkerStartup','OSQP worker did not become ready.');
    function ready=ping()
        ready=false;
        try
            client=tcpclient('127.0.0.1',c.osqpPort,'Timeout',1);configureTerminator(client,'LF');
            writeline(client,jsonencode(struct('ping',true)));answer=jsondecode(readline(client));clear client
        catch
            return
        end
        if isfield(answer,'root')&&~strcmpi(strrep(answer.root,'/','\'),strrep(root,'/','\'))
            error('REV:WorkerProject','OSQP port is occupied by a different project. Choose a different osqpPort.');
        end
        ready=isfield(answer,'version');
    end
end


