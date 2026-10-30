"""Package verified major-revision deliverables locally; never publish them."""
from pathlib import Path
import hashlib,json,zipfile,shutil,datetime
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'release'
EXCLUDE={'.log','.aux','.toc','.out','.synctex.gz','.partial','.pyc','.bak'}
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
def tree(folder):
 return [p for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix not in EXCLUDE and not p.name.endswith('.partial.mat')]
def archive(name,paths,extras=None):
 mapping={p.relative_to(ROOT).as_posix():p for p in paths}
 mapping.update(extras or {})
 records=[{'path':name,'bytes':p.stat().st_size,'sha256':sha(p)} for name,p in sorted(mapping.items())]
 manifest={'created':datetime.datetime.now().isoformat(timespec='seconds'),'planning_solver':'OSQP','independent_feasibility_checks':'HiGHS linear programming only','files':records}
 target=OUT/(name+'.zip')
 with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as z:
  for rel,p in sorted(mapping.items()):z.write(p,rel)
  z.writestr('MANIFEST.json',json.dumps(manifest,indent=2))
 with zipfile.ZipFile(target) as z:
  if z.testzip() is not None:raise RuntimeError('Archive CRC verification failed: '+str(target))
 digest=sha(target);(OUT/(name+'.sha256.txt')).write_text(digest+'  '+target.name+'\n',encoding='utf-8')
 return {'archive':str(target),'files':len(records),'bytes':target.stat().st_size,'sha256':digest}
def run():
 OUT.mkdir(exist_ok=True)
 if not (ROOT/'results/manuscript_audit.json').exists():raise RuntimeError('Final data audit is missing')
 qa=json.loads((ROOT/'results/final_pdf_qa.json').read_text(encoding='utf-8'))
 if not qa.get('all_pages_inspected') or not qa.get('passed'):raise RuntimeError('Final PDF verification has not passed')
 for doc in qa['documents'].values():
  if sha(ROOT/doc['relative_path']) != doc['sha256']:raise RuntimeError('A PDF changed after visual verification')
 extras={'README.txt':ROOT/'release_support/README_CODE_DATA.txt','requirements.txt':ROOT/'release_support/requirements.txt','LICENSE_DECISION.txt':ROOT/'release_support/LICENSE_DECISION.txt'}
 code=tree('code')+tree('code_search')+tree('simulation')+[ROOT/'RunWindingExample.m']
 for name in ['osqp_worker.py','analyze_revision.py','finalize_narrative.py','winding_evidence.py','winding_mechanism_audit.py','build_marked.py','TargetedGeometryStudy.m','OsqpNumericalAudit.m','WindingSearch.m','WindingSearchFine.m','PairedWindingStudy.m','WindingGeometryMap.m','AuditWindingSearch.m','AuditPairedWinding.m','package_revision.py','render_pdf_qa.py']:
  code.append(ROOT/'tools'/name)
 data=[]
 for folder in ['osqp_revision_v6','targeted_geometry','osqp_numerical_audit','winding_search_stage1','winding_fine_stage1','winding_paired_stage1','winding_paired_stage2','winding_geometry_map','winding_evidence','mujoco_tracking']:
  data+=tree('results/'+folder)
 for name in ['manuscript_audit.json','final_pdf_qa.json','heap_guide_audit_interrupted.json','additional_startup_recovery.json','logo_resource_repair.json']:
  p=ROOT/'results'/name
  if p.exists():data.append(p)
 for p in (ROOT/'results').glob('*_console.txt'):data.append(p)
 for p in (ROOT/'results').glob('*.mat'):data.append(p)
 for name in ['solver_conditioning_pilot.json','solver_lifting_pilot.json']:
  p=ROOT/'results'/name
  if p.exists():data.append(p)
 data+=tree('results/simulator_checks')
 for pattern in ['winding_example_*']:
  for p in (ROOT/'results').glob(pattern):
   if p.is_dir():data+=tree(str(p.relative_to(ROOT)))
 # Preserve the interrupted exploratory prototype with its explicit audit record.
 p=ROOT/'archive/guide_heap_prototype_20261030.m'
 if p.exists():data.append(p)
 latex=[]
 for folder in ['paper/revised_clean','paper/revision_marked','paper/reviewer_response','paper/revision_blue']:latex+=tree(folder)
 releases=[archive('UAV_Revision_Code_20261030',code,extras),archive('UAV_Revision_Data_20261030',data,extras),archive('Electronics_Revision_LaTeX_20261030',latex,extras)]
 pdfs={'Electronics_clean.pdf':'paper/revised_clean/manuscript.pdf','Electronics_marked.pdf':'paper/revision_marked/manuscript.pdf','Response_to_reviewers.pdf':'paper/reviewer_response/main.pdf'}
 for name,rel in pdfs.items():shutil.copy2(ROOT/rel,OUT/name)
 summary={'created':datetime.datetime.now().isoformat(timespec='seconds'),'published_online':False,'archives':releases,'pdfs':[{ 'file':name,'sha256':sha(OUT/name)} for name in pdfs],'qa':qa}
 (OUT/'release_manifest.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
 print(json.dumps(summary,indent=2))
if __name__=='__main__':run()
