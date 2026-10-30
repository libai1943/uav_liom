"""Create a complete word-level redline, treating displays/floats atomically."""
import os,re,sys,hashlib,subprocess,shutil,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OLD=ROOT/'paper/revision_blue';NEW=ROOT/'paper/revision_ma57_20261031/clean';OUT=ROOT/'paper/revision_ma57_20261031/marked'
blocks={};presence={}
def flatten(path,base,stack=()):
 if path in stack:raise ValueError('Recursive input '+str(path))
 s=path.read_text(encoding='utf-8-sig')
 for a,b in [('–','--'),('—','---'),('’',"'"),('‘',"'"),('“','``'),('”',"''"),(' ',' ')]:s=s.replace(a,b)
 def sub(m):
  p=base/(m.group(1)+('' if m.group(1).endswith('.tex') else '.tex'))
  if not p.exists():raise FileNotFoundError(p)
  return '\n'+flatten(p,base,stack+(path,))+'\n'
 return re.sub(r'\\(?:input|include)\{([^}]+)\}',sub,s)
def atomic(s,side):
 # Floats are indivisible: changed tables/algorithms remain valid LaTeX.
 patterns=[r'\\(?:sub)*section\*?\{[^{}]*\}',r'\\begin\{(figure\*?|table\*?|algorithm2e)\}.*?\\end\{\1\}',r'\\begin\{(subequations)\}.*?\\end\{\1\}',r'\\begin\{(equation\*?|align\*?|gather\*?|multline\*?|displaymath)\}.*?\\end\{\1\}',r'\\\[.*?\\\]']
 for pattern in patterns:
  def sub(m):
   body=m.group();key='B'+hashlib.sha256(re.sub(r'\s+',' ',body).encode()).hexdigest()[:18]
   blocks[(key,side)]=body;presence.setdefault(key,set()).add(side)
   return '\n\\REVISIONBLOCK{'+key+'}\n'
  s=re.sub(pattern,sub,s,flags=re.S)
 return s

def style_block(key):
 sides=presence[key];side='new' if 'new' in sides else 'old';s=blocks[(key,side)];changed=len(sides)==1
 if side=='old':
  # Preserve old figure assets and statistical macros without changing clean output.
  s=re.sub(r'(\\includegraphics(?:\[[^]]*\])?\{)([^}]+)(\})',lambda m:m.group(1)+'old_assets/'+m.group(2)+m.group(3),s)
 if not changed:return s
 color='RevisionBlue' if side=='new' else 'RevisionRed';what='Added or revised' if side=='new' else 'Deleted'
 heading=re.fullmatch(r'\\((?:sub)*section)\*?\{([^{}]*)\}',s)
 if heading:
  if side=='old':return r'\par\noindent{\color{RevisionRed}\sout{\textbf{'+heading.group(2)+r'}}}\par'
  return '\\'+heading.group(1)+'{\\textcolor{RevisionBlue}{'+heading.group(2)+'}}'
 isfloat=re.match(r'\\begin\{(figure\*?|table\*?|algorithm2e)\}',s)
 if side=='old':
  s=re.sub(r'\\label\{[^}]+\}','',s)
  if not isfloat:
   s=s.replace(r'\begin{subequations}','').replace(r'\end{subequations}','')
   for env in ['equation','align','gather','multline']:s=s.replace('\\begin{'+env+'}','\\begin{'+env+'*}').replace('\\end{'+env+'}','\\end{'+env+'*}')
 if not isfloat:
  s=re.sub(r'\n[ \t]*\n','\n',s)
  return '\n\\begin{mdframed}[nobreak=true,linecolor='+color+',linewidth=.65pt,innerleftmargin=5pt,innerrightmargin=5pt,innertopmargin=2pt,innerbottommargin=2pt,skipabove=6pt,skipbelow=6pt]\n\\color{'+color+'}\n'+(r'{\scriptsize Deleted mathematical display}\par'+'\n' if side=='old' else '')+s+'\n\\end{mdframed}\n'
 env=isfloat.group(1);captionprefix='Deleted: ' if side=='old' else ''
 # Color complete replacements; additions/deletions in prose remain word-level.
 if env=='algorithm2e':
  s=s.replace(r'\begin{algorithm2e}',r'\begin{algorithm2e}',1)
  k=s.find('\n');s=s[:k+1]+'\\color{'+color+'}\n'+s[k+1:]
  if side=='old':s=s.replace(r'\caption{',r'\caption{Deleted: ',1);s='\\setcounter{revSavedAlgorithm}{\\value{algocf}}\n\\begin{NoHyper}\n'+s+'\n\\end{NoHyper}\n\\setcounter{algocf}{\\value{revSavedAlgorithm}}\n'
  return s
 # Caption numbering advances only for the revised version.
 if side=='old':s=s.replace(r'\caption{',r'\caption*{\textcolor{RevisionRed}{Deleted:} ',1)
 frame='\\begin{mdframed}[linecolor='+color+',linewidth=.65pt,innerleftmargin=2pt,innerrightmargin=2pt,innertopmargin=3pt,innerbottommargin=3pt]\n\\color{'+color+'}\n'
 frame+=r'\setlength{\textwidth}{\linewidth}\setlength{\fulllength}{\linewidth}'+'\n'
 if r'\begin{adjustwidth}' in s:
  s=re.sub(r'(\\begin\{adjustwidth\}\{[^}]*\}\{[^}]*\})',lambda m:m.group()+ '\n'+frame,s,count=1)
  s=s.replace(r'\end{adjustwidth}',r'\end{mdframed}'+'\n'+r'\end{adjustwidth}',1)
 else:
  s=re.sub(r'(\\begin\{'+re.escape(env)+r'\}(?:\[[^]]*\])?)',lambda m:m.group()+'\n'+frame,s,count=1)
  s=s.replace('\\end{'+env+'}',r'\end{mdframed}'+'\n'+'\\end{'+env+'}',1)
 return s

def run():
 OUT.mkdir(parents=True,exist_ok=True)
 for name in ['Definitions','figures_revision']:
  shutil.copytree(NEW/name,OUT/name,dirs_exist_ok=True)
 shutil.copy2(NEW/'references.bib',OUT/'references.bib')
 for name in ['figures','figures_extended','figures_v5','figures_revision','Definitions']:
  if (OLD/name).exists():shutil.copytree(OLD/name,OUT/'old_assets'/name,dirs_exist_ok=True)
 def protect_citations(text):
  return re.sub(r'(\\cite(?:p|t)?(?:\[[^]]*\]){0,2}\{[^}]+\})',lambda m:r'\mbox{'+m.group(1)+'}',text)
 oldtext=flatten(OLD/'manuscript.tex',OLD)
 revised_bbl=(NEW/'manuscript.bbl').read_text(encoding='utf-8')
 revised_keys=set(re.findall(r'\\bibitem(?:\[[\s\S]*?\])?\{([^}]+)\}',revised_bbl))
 original_aux=(ROOT/'tmp/baseline_numbering/manuscript.aux').read_text(encoding='utf-8')
 oldnumbers=dict(re.findall(r'\\bibcite\{([^}]+)\}\{\{(\d+)\}',original_aux))
 def historical_cite(m):
  keys=m.group(1).split(',');live=[x for x in keys if x in revised_keys];deleted=[x for x in keys if x not in revised_keys]
  return ((r'\cite{'+','.join(live)+'}') if live else '')+((r'\mbox{[orig. '+', '.join(oldnumbers[x] for x in deleted)+']}') if deleted else '')
 oldtext=re.sub(r'\\cite\{([^}]+)\}',historical_cite,oldtext)
 oldlabels=json.loads((OLD/'reference_numbers.json').read_text(encoding='utf-8'))
 def oldref(m):
  value=oldlabels.get(m.group(2))
  if value is None:raise RuntimeError('Unresolved submitted reference: '+m.group(2))
  return r'\mbox{'+('('+value+')' if m.group(1)=='eqref' else value)+'}'
 oldtext=re.sub(r'\\(eqref|ref)\*?\{([^}]+)\}',oldref,oldtext)
 old=atomic(protect_citations(oldtext),'old');new=atomic(protect_citations(flatten(NEW/'manuscript.tex',NEW)),'new')
 # Include any old graphic directories actually referenced by a deleted block.
 for (key,side),body in blocks.items():
  if side!='old':continue
  for path in re.findall(r'\\includegraphics(?:\[[^]]*\])?\{([^}]+)\}',body):
   p=OLD/path
   if not p.exists() and not p.suffix:p=p.with_suffix('.pdf')
   if p.exists():target=OUT/'old_assets'/p.relative_to(OLD);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
 temp=ROOT/'tmp/latexdiff_20261031';temp.mkdir(parents=True,exist_ok=True);(temp/'old.tex').write_text(old,encoding='utf-8');(temp/'new.tex').write_text(new,encoding='utf-8')
 pre=r'''\usepackage[normalem]{ulem}
\usepackage[framemethod=default]{mdframed}
\definecolor{RevisionBlue}{RGB}{0,76,153}
\definecolor{RevisionRed}{RGB}{180,0,0}
\newcounter{revSavedAlgorithm}
\providecommand{\DIFadd}[1]{{\protect\color{RevisionBlue}\ifmmode #1\else\uline{#1}\fi}}
\providecommand{\DIFdel}[1]{{\protect\color{RevisionRed}\ifmmode\text{\sout{\ensuremath{#1}}}\else\sout{#1}\fi}}
\providecommand{\DIFaddbegin}{}\providecommand{\DIFaddend}{}
\providecommand{\DIFdelbegin}{}\providecommand{\DIFdelend}{}
\providecommand{\DIFmodbegin}{}\providecommand{\DIFmodend}{}
\providecommand{\DIFaddFL}[1]{\DIFadd{#1}}\providecommand{\DIFdelFL}[1]{\DIFdel{#1}}
\providecommand{\DIFaddbeginFL}{}\providecommand{\DIFaddendFL}{}
\providecommand{\DIFdelbeginFL}{}\providecommand{\DIFdelendFL}{}
'''
 # Old statistics are needed only for deleted material.
 stat=OLD/'data_rest/statistics.tex'
 if stat.exists():pre+='\n'+stat.read_text(encoding='utf-8-sig').replace(r'\newcommand',r'\providecommand')
 (temp/'preamble.tex').write_text(pre,encoding='utf-8')
 cmd=[r'D:/Program Files/MATLAB/R2021b/sys/perl/win32/bin/perl.exe',str(ROOT/'tools/latexdiff/latexdiff/latexdiff-so'),'--encoding=utf8','--preamble='+str(temp/'preamble.tex'),'--exclude-safecmd=REVISIONBLOCK','--append-context2cmd=Title,abstract,keyword','--math-markup=whole',str(temp/'old.tex'),str(temp/'new.tex')]
 env=os.environ.copy();env['LC_ALL']='C';p=subprocess.run(cmd,capture_output=True,env=env)
 (temp/'latexdiff_stderr.txt').write_bytes(p.stderr)
 if p.returncode:raise RuntimeError(p.stderr.decode(errors='replace'))
 s=p.stdout.decode('utf-8').replace('\r\n','\n').replace('\r','\n')
 # Restore atomically deleted blocks from latexdiff's command comments.
 s=re.sub(r'%DIFDELCMD\s*<\s*\\REVISIONBLOCK\{(B[0-9a-f]+)\}(?:\s*%%%[^\n]*)?',lambda m:'\n'+style_block(m.group(1))+'\n',s)
 s=re.sub(r'\\REVISIONBLOCK\{(B[0-9a-f]+)\}',lambda m:style_block(m.group(1)),s)
 s=re.sub(r'%DIFDELCMD[^\n]*\\MBLOCKRIGHTBRACE[^\n]*', '}', s)
 if 'REVISIONBLOCK' in s or 'MBLOCK' in s:raise RuntimeError('Unexpanded redline block')
 s=s.replace("C26'sinitial","C26's initial")
 s=s.replace(r'\bibliography{references}',r'\input{clean_references.bbl}')
 (OUT/'clean_references.bbl').write_text(revised_bbl,encoding='utf-8')
 (OUT/'manuscript.tex').write_text(s,encoding='utf-8')
 (OUT/'revision_manifest.json').write_text(json.dumps({'baseline':str(OLD),'revised':str(NEW),'atomic_blocks':len(presence),'added_or_revised':sum(v=={'new'} for v in presence.values()),'deleted':sum(v=={'old'} for v in presence.values()),'unchanged':sum(len(v)==2 for v in presence.values())},indent=2))
 print(OUT/'manuscript.tex')
if __name__=='__main__':run()
