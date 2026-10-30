"""Audit and package the tested Oct31 external comparisons and revised papers."""
from pathlib import Path
import csv, datetime, hashlib, json, re, shutil, subprocess, sys, zipfile

ROOT = Path(__file__).resolve().parents[1]
PAPER = ROOT / 'paper/revision_20261031'
OUT = ROOT / 'release_20261031'
NOW = datetime.datetime.now().isoformat(timespec='seconds')

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding='utf-8')

def text(path):
    return path.read_text(encoding='utf-8-sig')

def tree(path):
    excluded = {'.aux', '.log', '.out', '.toc', '.pyc', '.blg', '.xdv'}
    return [p for p in path.rglob('*') if p.is_file() and p.suffix not in excluded
            and '__pycache__' not in p.parts and not p.name.endswith('.partial.mat')]

def mapping(paths):
    return {p.relative_to(ROOT).as_posix(): p for p in paths}

def archive(name, files, base=None):
    records = []
    target = OUT / (name + '.zip')
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as dest:
        if base:
            with zipfile.ZipFile(base) as src:
                for entry in src.infolist():
                    if entry.is_dir() or entry.filename == 'MANIFEST.json' or entry.filename in files:
                        continue
                    data = src.read(entry)
                    current = ROOT / entry.filename
                    if current.is_file() and current.suffix in {'.m', '.py'}:
                        assert current.read_bytes() == data, 'Base release source changed: '+entry.filename
                    dest.writestr(entry.filename, data)
                    records.append(dict(path=entry.filename, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
        for rel, p in sorted(files.items()):
            dest.write(p, rel)
            records.append(dict(path=rel, bytes=p.stat().st_size, sha256=sha(p)))
        dest.writestr('MANIFEST.json', json.dumps(dict(created=NOW,
            qp_solver='OSQP', nonlinear_comparisons='CasADi 3.6.1 / Ipopt / MUMPS',
            files=sorted(records, key=lambda x:x['path'])), indent=2))
    with zipfile.ZipFile(target) as check:
        assert check.testzip() is None, target
        assert len(check.namelist()) == len(set(check.namelist())), 'Duplicate archive entry'
    digest = sha(target)
    (OUT/(name+'.sha256.txt')).write_text(digest+'  '+target.name+'\n')
    return dict(file=target.name, files=len(records), bytes=target.stat().st_size, sha256=digest, crc_passed=True)

def main():
    OUT.mkdir(exist_ok=True)
    old_manifest_sha = sha(ROOT/'release/release_manifest.json')
    # Regeneration must exactly reproduce the already compiled table.
    table = PAPER/'clean/data_revision/external_table.tex'
    table_text = text(table)
    cp = subprocess.run([sys.executable, str(ROOT/'comparisons_20261031/analyze_verified.py')],
                        capture_output=True, text=True)
    (ROOT/'results/external_analysis_final_console.txt').write_text(cp.stdout+cp.stderr, encoding='utf-8')
    assert cp.returncode == 0, cp.stderr
    assert text(table) == table_text, 'Compiled table differs from audited regenerated table'
    table_body=text(table).split('\\caption{',1)[1].split('\\end{adjustwidth}',1)[0].strip()
    marked_source=text(PAPER/'marked/manuscript.tex')
    assert table_body in marked_source, 'Audited table differs from compiled marked source'
    audit = json.loads(text(ROOT/'results/external_20261031_audit.json'))
    assert audit['selected_attempts'] == 50 and audit['same_inputs_verified']
    for key in ['frozen_sources_verified','accepted_identity_checks_verified']:
        assert audit[key]
    pilot = list(csv.DictReader((ROOT/'results/external_20261031_pilot/summary.csv').open(encoding='utf-8-sig')))
    assert len(pilot) == 6
    # Historical numerical source snapshots remain untouched.
    for snap in ['source_hashes.json', 'verified_source_hashes.json']:
        for item in json.loads(text(ROOT/'comparisons_20261031'/snap)):
            rel = item['File'].replace('\\','/').split('/comparisons_20261031/',1)[1]
            assert sha(ROOT/'comparisons_20261031'/rel).lower() == item['SHA256'].lower(), rel

    clean_bbl = text(PAPER/'clean/manuscript.bbl')
    marked_bbl = text(PAPER/'marked/clean_references.bbl')
    assert re.sub(r'\s+', ' ', clean_bbl) == re.sub(r'\s+', ' ', marked_bbl)
    def cite_map(folder):
        return dict(re.findall(r'\\bibcite\{([^}]+)\}\{\{(\d+)\}', text(PAPER/folder/'manuscript.aux')))
    clean_map = cite_map('clean'); marked_map = cite_map('marked')
    assert len(clean_map) == 39 and clean_map == marked_map
    assert clean_map['li2022stitching'] == '5'
    bib_audit = dict(reference_count=39, identical_bbl_text=True, identical_citation_numbering=True,
        background_parallel_stitching_reference=5, citation_map=clean_map,
        deleted_only_reference_labels='Original numbers occur only in deleted passages; no extra revised bibliography entries.')
    write_json(PAPER/'bibliography_audit.json', bib_audit)
    response_text='\n'.join(text(p) for p in (PAPER/'response').glob('*.tex'))
    comments=re.findall(r'\\reviewitem\{(R[^}]+)', response_text)
    assert len(comments)==len(set(comments))==33

    qa0=json.loads(text(ROOT/'tmp/pdf_qa/october31_external_final/report.json'))
    qa1=json.loads(text(ROOT/'tmp/pdf_qa/october31_external_response_final/report.json'))
    qa0['response']=qa1['response']
    docs={}
    for name, report in qa0.items():
        assert all(not x['issues'] and not x['outside_page'] and x['portrait'] for x in report['page_audit'])
        assert not report['render_stderr']
        pdf=Path(report['pdf'])
        docs[name]=dict(relative_path=pdf.relative_to(ROOT).as_posix(), pages=report['pages'],
            sha256=sha(pdf), all_pages_visually_reviewed=True)
    assert [docs[k]['pages'] for k in ['clean','marked','response']]==[28,47,10]
    qa=dict(created=NOW, passed=True, all_pages_inspected=True, total_pages=85, documents=docs,
        review_comments=33, bibliography=bib_audit,
        method='Poppler full-page rendering, visual review of all page sheets and changed pages, and structural text/portrait/overflow checks.',
        contact_sheets=['tmp/pdf_qa/october31_external_final', 'tmp/pdf_qa/october31_external_response_final'])
    write_json(ROOT/'results/final_pdf_qa_20261031.json',qa)

    changelog='''2026-10-31 revision: external comparisons and editorial consistency
ASCO-3D, Direct NLP and norm-tangent SCP-3D were implemented and evaluated against the proposed method and iterative hard RSC on ten fixed tasks. The selected table has 50 entries; all 76 pilot/formal/verified attempts are preserved. Nonlinear external comparisons use Ipopt/MUMPS; every QP uses OSQP. ASCO risk-range updates follow the supplied original source. Final SCP uses the original norm tangent and direct sparse assembly. The ASCO inner CPU cap is separate from construction cost. All ASCO/SCP cases were rerun after these corrections; provenance is recorded without outcome-dependent row selection.
The comparison reports accepted, late-accepted and unaccepted attempts separately. The new Winding A hard-RSC acceptance is reported alongside the earlier repetitions; the paper does not infer that an initially incompatible corridor precludes a later hard reconstruction. Winding B's 31.92 s accepted motion is marked late. No population success-rate superiority is claimed.
The parallel-stitching paper (Li et al.,2022, DOI10.1109/TIV.2022.3156429) is cited in the computational-efficiency background as reference5. Both manuscripts have the same39 references and numbering. Figure2 labels are smaller and centered below the panels. Method/table/section references and33 reviewer responses are synchronized. All85 final PDF pages were rendered and visually reviewed. The prior October30 delivery and frozen planner remain intact.
'''
    (PAPER/'CHANGELOG.txt').write_text(changelog,encoding='utf-8')
    readme='''ELECTRONICS REVISION - 2026-10-31 LOCAL DELIVERY

Read Electronics_clean.pdf first. Electronics_marked.pdf contains blue additions,
red deletions and framed changed displays. Response_to_reviewers.pdf addresses
all 33 comments. The clean and marked bibliographies both contain 39 references.

The added Table5 records 10 tasks x 5 methods: proposed LIOM, iterative hard
RSC, ASCO-3D, Direct NLP and norm-tangent SCP-3D. Every method uses the same saved
reference, fixed horizon, endpoints, physical bounds and final checking.
All actual QPs use OSQP. Only nonlinear ASCO/Direct-NLP instances use Ipopt.
The 50 selected entries have explicit provenance in external_20261031_audit.json.
All 76 original pilot/formal/verified attempts, including failures, are retained.
These are task-matched adaptations of the original strategies to the UAV task.

PACKAGES
UAV_Revision_Code_20261031.zip contains the complete prior planner/simulation
code plus the new comparisons. UAV_External_Data_20261031.zip contains all new
attempts and the ten source records with saved common references. Extract both
into the SAME root. Electronics_Revision_LaTeX_20261031.zip contains the updated
sources, figures, PDFs, redline generator and submitted-source baseline.
The complete earlier data remain in ../release/UAV_Revision_Data_20261030.zip
(about1.14 GiB). Extract that archive into the same root to reproduce all older
paper figures. The new data archive is an addition, not a replacement for it.
No file has been uploaded and no open-source license has been selected.

RUNNING
MATLAB R2021b was used. Configure UAV_PYTHON as described in
README_PRIOR_CODE_DATA.txt; install requirements.txt. Install the CasADi3.6.1
MATLAB distribution for nonlinear comparisons and adjust C:/casadi in the
entry scripts if needed. Original AMPL/HSL binaries and reference PDFs are
not required or redistributed. Run one solver process at a time.
From the extracted root, in MATLAB:
  addpath('comparisons_20261031'); FinalExternalSelftest;
  FinalExternalStudy('final');
The self-test checks OSQP/Ipopt routing, common hard integration and motion
constraints, physical acceptance, and agreement on a simple analytical case.
FinalExternalStudy runs all five final implementations serially, saving fresh
results to results/external_20261031_final and skipping completed attempts.
Its components were tested in the supplied phases; the paper table preserves
those measurements rather than claiming a new all-five batch was rerun.
For a short test, FinalExternalStudy('pilot') uses a separate final_pilot folder.
Use RunWindingExample for the existing one-button winding demonstration.

ANALYSIS AND LATEX
  python comparisons_20261031/analyze_verified.py
reconstructs the selected table from the formal and verified records and
checks numerical source hashes, common inputs, and accepted endpoint/identity
checks. It does not overwrite the raw measurements. See comparisons_20261031/
README.txt and METHOD_MAP.txt for phase details. norm_source_hashes.json was an
unused development snapshot and is excluded from this release. Other historical
entry scripts are retained to identify the saved diagnostic phases.
Compile manuscript.tex in paper/revision_20261031/clean and marked, and main.tex
in response. The marked manuscript uses the clean bibliography verbatim.
Regeneration uses paper/revision_20261031/build_marked.py and the supplied old
source; local Perl/latexdiff paths may need configuration on another computer.
The prior finalizer scripts generate prior-version documents; use this new
revision directory for the delivered paper. Archive CRCs and per-file SHA-256
manifests have been checked. release_manifest.json records the inspected PDFs.
'''
    (OUT/'README.txt').write_text(readme,encoding='utf-8')
    (OUT/'交付说明.txt').write_text('''2026-10-31新版交付
论文清稿28页，蓝增红删标注稿47页，逐条回复10页（33条意见）。两稿参考文献均39篇，编号一致。
新增ASCO-3D、直接NLP、范数切平面SCP-3D对比；10个固定任务与本文方法、迭代硬RSC比较，表格50条记录。
全部76次试验/诊断结果保留。按时通过、超时通过和未通过分别标记。实际QP均OSQP，非线性对比使用Ipopt/MUMPS。
代码包、新数据包解压到同一根目录即可运行新对比；LaTeX包包含新论文、标注稿与回复源码。
旧版完整数据约1.14GiB保留在相邻release目录的UAV_Revision_Data_20261030.zip，未重复占用磁盘；复现所有原图时也解压到同一根目录。
新数据包含10个源算例和共用参考轨迹，独立复现新对比无需先解压全部旧数据。
详情、运行命令和版本来源见README.txt。旧交付未覆盖；未上传网上。
''',encoding='utf-8')
    extras={'README.txt':OUT/'README.txt','README_PRIOR_CODE_DATA.txt':ROOT/'release_support/README_CODE_DATA.txt',
            'requirements.txt':ROOT/'release_support/requirements.txt','LICENSE_DECISION.txt':ROOT/'release_support/LICENSE_DECISION.txt'}
    code_files=mapping([p for p in tree(ROOT/'comparisons_20261031') if p.name!='norm_source_hashes.json'])
    code_files.update(extras)
    code_files['tools/package_external_20261031.py']=Path(__file__)
    archives=[archive('UAV_Revision_Code_20261031',code_files,ROOT/'release/UAV_Revision_Code_20261030.zip')]

    data=[]
    for folder in ['external_20261031_pilot','external_20261031_formal','external_20261031_verified']:
        data+=tree(ROOT/'results'/folder)
    for p in (ROOT/'results').iterdir():
        if p.is_file() and ('external' in p.name or p.name=='norm_scp_selftest.mat') and p.suffix in ['.txt','.mat','.json']:
            if p.name!='external_comparison_state.json': data.append(p)
    files=['osqp_revision_v6/main/'+x+'_adaptive_default_R1.mat' for x in ['C01','C03','C05','C25','C27','C29']]
    files+=['winding_paired_stage1/PW1_S6102_R1_adaptive.mat','winding_paired_stage2/PW2_S7202_R1_adaptive.mat',
            'osqp_revision_v6/scaling/N15_K060_S4101_adaptive_default_R1.mat','osqp_revision_v6/scaling/N20_K060_S4101_adaptive_default_R1.mat']
    data += [ROOT/'results'/x for x in files]
    data += [ROOT/'results/final_pdf_qa_20261031.json']
    data_files=mapping(data);data_files.update(extras)
    archives.append(archive('UAV_External_Data_20261031',data_files))
    latex=mapping(tree(PAPER)+tree(ROOT/'paper/revision_blue'));latex.update(extras)
    archives.append(archive('Electronics_Revision_LaTeX_20261031',latex))
    pdf_map={'Electronics_clean.pdf':PAPER/'clean/manuscript.pdf',
             'Electronics_marked.pdf':PAPER/'marked/manuscript.pdf',
             'Response_to_reviewers.pdf':PAPER/'response/main.pdf'}
    for name,p in pdf_map.items():shutil.copy2(p,OUT/name)
    summary=dict(created=NOW,published_online=False,previous_release_unchanged=True,archives=archives,
        older_full_data='../release/UAV_Revision_Data_20261030.zip',
        pdfs=[dict(file=name,sha256=sha(OUT/name)) for name in pdf_map],qa=qa,
        comparison=dict(selected_attempts=50,preserved_attempts=76,source_audit='results/external_20261031_audit.json'))
    assert sha(ROOT/'release/release_manifest.json')==old_manifest_sha
    write_json(OUT/'release_manifest.json',summary)
    write_json(ROOT/'results/external_comparison_state.json',dict(stage='complete',completed=NOW,
        release='release_20261031',selected_attempts=50,preserved_attempts=76,
        qp_solver='OSQP',nonlinear_external_solver='Ipopt/MUMPS',published_online=False,
        final_pdf_qa='results/final_pdf_qa_20261031.json',previous_release_unchanged=True))
    state=ROOT/'CURRENT_WORK.txt'
    state.write_text('DELIVERABLES COMPLETE — 2026-10-31 EXTERNAL COMPARISON REVISION\n'
        'Canonical new delivery: release_20261031/release_manifest.json. Clean28, marked47, response10 pages; '
        'all85 pages rendered and visually checked;39 identical references,33 review comments. '
        'ASCO/directNLP/normSCP actual matched comparisons complete:50 selected rows across10 fixed tasks; '
        'all76 pilot/formal/verified attempts retained. AllQPs OSQP; only nonlinear external comparisons '
        'use explicitly authorized Ipopt/MUMPS. Numerical frozen sources unchanged. '
        'New WindingA hardRSC acceptance and WindingB late acceptance explicitly reported alongside earlier records. '
        'All packages CRC-verified with SHA256 manifests. Prior Oct30 release unchanged; no online upload. '
        'No solver batch pending; completion follow-up stays paused.\n\n'+text(state),encoding='utf-8')
    print(json.dumps(dict(archives=archives,pages={k:v['pages'] for k,v in docs.items()},references=39,comments=33),indent=2))

if __name__=='__main__':main()
