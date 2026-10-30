function manifest=sourceManifest(root)
files=dir(fullfile(root,'**','*.m')); names={}; digests={};
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name); relative=erase(path,[root,filesep]);
    if startsWith(relative,['results',filesep]), continue; end
    fid=fopen(path,'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    hash=java.security.MessageDigest.getInstance('SHA-256'); hash.update(bytes);
    names{end+1}=relative; digests{end+1}=lower(reshape(dec2hex(typecast(hash.digest(),'uint8'),2)',1,[])); %#ok<AGROW>
end
[names,order]=sort(names); digests=digests(order);
manifest=struct('paths',{names},'sha256',{digests});
end
