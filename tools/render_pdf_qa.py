"""Render all deliverable PDF pages and flag structural text problems."""
from pathlib import Path
import sys,json,subprocess,concurrent.futures,argparse
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'python_packages'))
import fitz
from PIL import Image,ImageDraw
parser=argparse.ArgumentParser();parser.add_argument('--tag',default='final');args=parser.parse_args()
OUT=ROOT/'tmp/pdf_qa'/args.tag;OUT.mkdir(parents=True,exist_ok=True)
POP=Path.home()/'.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/bin/pdftoppm.exe'
if not POP.exists():POP=Path('pdftoppm')
TARGETS={'clean':ROOT/'paper/revised_clean/manuscript.pdf','marked':ROOT/'paper/revision_marked/manuscript.pdf','response':ROOT/'paper/reviewer_response/main.pdf'}
def render(item):
 name,p=item;folder=OUT/name;folder.mkdir(exist_ok=True)
 cp=subprocess.run([str(POP),'-r','96','-png',str(p),str(folder/'page')],capture_output=True,text=True)
 if cp.returncode:raise RuntimeError(cp.stderr)
 doc=fitz.open(p);pages=[]
 for i,page in enumerate(doc):
  t=page.get_text();bad=[]
  if '\ufffd' in t:bad.append('replacement glyph')
  if '??' in t:bad.append('unresolved reference')
  lines=[line for b in page.get_text('dict')['blocks'] if 'lines' in b for line in b['lines']]
  clipped=[l['bbox'] for l in lines if l['bbox'][0]<0 or l['bbox'][2]>page.rect.width+.5 or l['bbox'][3]>page.rect.height+.5]
  heads=[x for x in t.splitlines() if x.startswith(('Figure ','Table ','Algorithm ','7.','8.','R1.','R2.','R3.'))]
  pages.append({'page':i+1,'words':len(t.split()),'headings':heads,'issues':bad,'outside_page':clipped,'portrait':page.rect.height>page.rect.width})
 images=sorted(folder.glob('page-*.png'))
 for k in range(0,len(images),6):
  canvas=Image.new('RGB',(1100,2370),'#d8d8d8');draw=ImageDraw.Draw(canvas)
  for j,f in enumerate(images[k:k+6]):
   im=Image.open(f);im.thumbnail((530,750));x=10+(j%2)*550;y=25+(j//2)*790;canvas.paste(im,(x,y));draw.text((x,y-19),f'{name} / page {k+j+1}',fill='black')
  canvas.save(folder/f'contact-{k//6+1:02d}.png')
 return name,{'pdf':str(p),'pages':len(doc),'render_stderr':cp.stderr,'page_audit':pages}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:reports=dict(pool.map(render,TARGETS.items()))
(OUT/'report.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
print(json.dumps({k:{'pages':v['pages'],'render_warnings':v['render_stderr'],'flagged':[x for x in v['page_audit'] if x['issues'] or x['outside_page'] or not x['portrait']]} for k,v in reports.items()},indent=2))
