#!/usr/bin/env python3
"""Goemon asset audit, lossless optimization, provenance checks and Godot comparison."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import shutil
import copy
import sys

from asset_pipeline.audit import audit, write_report
from asset_pipeline.glb import digest
from asset_pipeline.optimize import optimize, validate_preservation

ROOT = Path(__file__).resolve().parents[1]
ASSETS = {'goldmine': 'assets/economy_v1/gold_mine/goldmine_v1.glb', 'musashi': 'assets/characters/recovered_musashi/musashi.glb'}
RECIPES = json.loads((ROOT/'tools/asset_pipeline/gameplay.json').read_text())
ASSETS.update({name:entry['source'] for name,entry in RECIPES.items()})
MANIFEST = ROOT / 'assets/optimized/manifest.json'
ROUTES = ROOT / 'assets/optimized/routes.json'


def report_root():
    try:
        common = Path(subprocess.check_output(['git','rev-parse','--path-format=absolute','--git-common-dir'],cwd=ROOT,text=True).strip())
        return common.parent/'build/Other Files/Asset Toolkit'
    except (OSError,subprocess.CalledProcessError): return ROOT/'build/Other Files/Asset Toolkit'


def staged_manifest():return report_root()/'gameplay-candidates.json'

def load_manifest(path):return json.loads(path.read_text()) if path.exists() else {'version':1,'assets':[]}

def selected_candidates():
    combined={e['asset']:e for e in load_manifest(MANIFEST)['assets']}
    combined.update({e['asset']:e for e in load_manifest(staged_manifest())['assets']})
    return list(combined.values())

def check_manifest(manifest, root=ROOT):
    errors = []
    for item in manifest.get('assets',[]):
        for key,label in [('source','stale source'),('output','changed/missing optimized output')]:
            path = Path(root)/item[key]
            if not path.exists() or digest(path.read_bytes()) != item[key+'_sha256']:
                errors.append('%s: %s; run optimize again' % (label,path))
    return errors


def import_settings(source, output):
    """Preserve source import semantics without copying source resource UIDs."""
    settings = Path(str(source)+'.import')
    params = settings.read_text().split('[params]',1)[1] if settings.exists() else '\nnodes/use_name_suffixes=false\nanimation/remove_immutable_tracks=false\n'
    target = Path(str(output)+'.import')
    if target.exists():
        text=target.read_text()
        text=text.split('[params]',1)[0]+'[params]'+params
    else:
        text='[remap]\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[params]'+params
    target.write_text(text)


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    commands=parser.add_subparsers(dest='command',required=True)
    p=commands.add_parser('audit',help='Read-only GLB inventory and sortable HTML report')
    p.add_argument('paths',nargs='*',type=Path);p.add_argument('--out',type=Path,default=report_root());p.add_argument('--budgets',type=Path)
    p=commands.add_parser('optimize',help='Generate validated derivatives; originals are never overwritten')
    p.add_argument('--asset',choices=['all','gameplay']+list(ASSETS),default='all')
    p=commands.add_parser('activate',help='Use validated derivatives in gameplay; originals stay available')
    p.add_argument('--asset',choices=['all','gameplay']+list(ASSETS),default='gameplay')
    p=commands.add_parser('check',help='Reject stale sources, changed outputs or preservation failures')
    p.add_argument('--staged',action='store_true')
    p=commands.add_parser('compare',help='Synchronized Godot comparison; optional capture sweep')
    p.add_argument('--asset',choices=list(ASSETS),required=True);p.add_argument('--before',type=Path);p.add_argument('--after',type=Path)
    p.add_argument('--out',type=Path);p.add_argument('--capture',action='store_true');p.add_argument('--all-clips',action='store_true');p.add_argument('--imported',action='store_true')
    p.add_argument('--godot',default=os.environ.get('GODOT_BIN','/Applications/Godot.app/Contents/MacOS/Godot'))
    args=parser.parse_args(argv)
    if args.command=='audit':
        paths=[]
        for p in args.paths or [ROOT/'assets']:
            paths.extend(p.rglob('*.glb') if p.is_dir() else [p])
        budgets=json.loads(args.budgets.read_text()) if args.budgets else None
        report=audit(paths,budgets,ROOT);write_report(report,args.out)
        print('Audited %d assets; %d read errors. %s'%(len(report['assets']),len(report['errors']),args.out/'audit.html'))
        return int(bool(report['errors']))
    if args.command=='optimize':
        for name in (ASSETS if args.asset=='all' else RECIPES if args.asset=='gameplay' else [args.asset]):
            manifest_path=staged_manifest() if name in RECIPES else MANIFEST
            manifest=load_manifest(manifest_path)
            source=ROOT/ASSETS[name];output=(report_root()/'Candidates' if name in RECIPES else ROOT/'assets/optimized')/(name+'.glb')
            item=optimize(source,output,preserve_mesh_nodes=RECIPES.get(name,{}).get('preserve_mesh_nodes',''));item['asset']=name
            item['preserve_mesh_nodes']=RECIPES.get(name,{}).get('preserve_mesh_nodes','')
            import_settings(source,output)
            for key in ('source','output'):item[key]=str(Path(item[key]).relative_to(ROOT))
            for key in ('before','after'):item[key]['path']=str(Path(item[key]['path']).relative_to(ROOT))
            manifest['assets']=[e for e in manifest['assets'] if e['asset']!=name]+[item]
            manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
            print('%s: meshes %d → %d; surfaces %d → %d; triangles %d → %d; preservation PASS'%(name,item['before']['mesh_instances'],item['after']['mesh_instances'],item['before']['surfaces'],item['after']['surfaces'],item['before']['triangles'],item['after']['triangles']))
        return 0
    if args.command=='activate':
        names=set(ASSETS if args.asset=='all' else RECIPES if args.asset=='gameplay' else [args.asset])
        selected=[e for e in selected_candidates() if e['asset'] in names]
        errors=check_manifest({'assets':selected})
        if errors:raise ValueError('Cannot activate stale candidates: '+'; '.join(errors))
        active=load_manifest(MANIFEST);routes=json.loads(ROUTES.read_text()) if ROUTES.exists() else {}
        for entry in selected:
            b,a=entry['before'],entry['after']
            if not (a['surfaces']<b['surfaces'] or a['materials']<b['materials'] or a['bytes']<b['bytes']*.98):continue
            if not validate_preservation(ROOT/entry['source'],ROOT/entry['output'])['passed']:raise ValueError('Preservation failed: '+entry['asset'])
            item=copy.deepcopy(entry);target=ROOT/'assets/optimized'/(item['asset']+'.glb')
            if (ROOT/item['output']).resolve()!=target.resolve():shutil.copy2(ROOT/item['output'],target)
            import_settings(ROOT/item['source'],target)
            item['output']=str(target.relative_to(ROOT));item['after']['path']=item['output']
            active['assets']=[e for e in active['assets'] if e['asset']!=item['asset']]+[item]
            routes['res://'+item['source']]='res://'+item['output']
        MANIFEST.write_text(json.dumps(active,indent=2)+'\n');ROUTES.write_text(json.dumps(routes,indent=2,sort_keys=True)+'\n')
        print('Activated %d optimized gameplay routes'%len(routes));return 0
    if args.command=='check':
        if not MANIFEST.exists():raise ValueError('No optimized manifest; run optimize first')
        manifest={'assets':selected_candidates()} if args.staged else load_manifest(MANIFEST);errors=check_manifest(manifest)
        from prepare_crossgate_player_audio import check_local
        errors.extend(check_local())
        from prepare_crossgate_cosmetics import check_local as check_cosmetics
        errors.extend(check_cosmetics())
        for item in manifest['assets']:
            if not errors and not validate_preservation(ROOT/item['source'],ROOT/item['output'])['passed']:errors.append('Preservation failed: '+item['asset'])
        if errors:print('\n'.join(errors),file=sys.stderr);return 1
        print('PASS: optimized source/output hashes, geometry, animation samples, skin binds, nodes and texture bytes')
        print('PASS: Cross Gate player attack audio coverage, source hashes and original PCM')
        print('PASS: recovered cosmetics and prepared character attachments')
        return 0
    candidate=next((e for e in (load_manifest(MANIFEST)['assets'] if args.imported else selected_candidates()) if e['asset']==args.asset),{})
    before=(args.before or ROOT/ASSETS[args.asset]).resolve();after=(args.after or ROOT/candidate.get('output','assets/optimized/'+args.asset+'.glb')).resolve()
    if not before.exists() or not after.exists():raise ValueError('Comparison inputs must exist; run optimize first')
    output=(args.out or report_root()/args.asset).resolve();output.mkdir(parents=True,exist_ok=True)
    command=[args.godot,'--path',str(ROOT),'--rendering-method','gl_compatibility','--resolution','1280x820','--log-file',str(output/'godot.log'),'--script','res://tools/asset_compare.gd','--','--before='+str(before),'--after='+str(after),'--out='+str(output),'--asset='+args.asset]
    if args.imported:command.append('--imported')
    if args.capture:command.append('--capture')
    if args.all_clips:command.append('--all-clips')
    return subprocess.run(command,cwd=ROOT).returncode


if __name__=='__main__':
    try:sys.exit(main())
    except (OSError,ValueError,KeyError,IndexError) as exc:print('Asset toolkit: '+str(exc),file=sys.stderr);sys.exit(1)
