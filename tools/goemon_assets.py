#!/usr/bin/env python3
"""Goemon asset audit, lossless optimization, provenance checks and Godot comparison."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from asset_pipeline.audit import audit, write_report
from asset_pipeline.glb import digest
from asset_pipeline.optimize import optimize, validate_preservation

ROOT = Path(__file__).resolve().parents[1]
ASSETS = {'goldmine': 'assets/economy_v1/gold_mine/goldmine_v1.glb', 'musashi': 'assets/characters/recovered_musashi/musashi.glb'}
MANIFEST = ROOT / 'assets/optimized/manifest.json'


def report_root():
    try:
        common = Path(subprocess.check_output(['git','rev-parse','--path-format=absolute','--git-common-dir'],cwd=ROOT,text=True).strip())
        return common.parent/'build/Other Files/Asset Toolkit'
    except (OSError,subprocess.CalledProcessError): return ROOT/'build/Other Files/Asset Toolkit'


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
    p.add_argument('--asset',choices=['all']+list(ASSETS),default='all')
    p=commands.add_parser('check',help='Reject stale sources, changed outputs or preservation failures')
    p=commands.add_parser('compare',help='Synchronized Godot comparison; optional capture sweep')
    p.add_argument('--asset',choices=list(ASSETS),required=True);p.add_argument('--before',type=Path);p.add_argument('--after',type=Path)
    p.add_argument('--out',type=Path);p.add_argument('--capture',action='store_true');p.add_argument('--all-clips',action='store_true')
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
        manifest=json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {'version':1,'assets':[]}
        for name in ASSETS if args.asset=='all' else [args.asset]:
            source=ROOT/ASSETS[name];output=ROOT/'assets/optimized'/(name+'.glb')
            item=optimize(source,output);item['asset']=name
            import_settings(source,output)
            for key in ('source','output'):item[key]=str(Path(item[key]).relative_to(ROOT))
            for key in ('before','after'):item[key]['path']=str(Path(item[key]['path']).relative_to(ROOT))
            manifest['assets']=[e for e in manifest['assets'] if e['asset']!=name]+[item]
            MANIFEST.write_text(json.dumps(manifest,indent=2)+'\n')
            print('%s: meshes %d → %d; surfaces %d → %d; triangles %d → %d; preservation PASS'%(name,item['before']['mesh_instances'],item['after']['mesh_instances'],item['before']['surfaces'],item['after']['surfaces'],item['before']['triangles'],item['after']['triangles']))
        return 0
    if args.command=='check':
        if not MANIFEST.exists():raise ValueError('No optimized manifest; run optimize first')
        manifest=json.loads(MANIFEST.read_text());errors=check_manifest(manifest)
        for item in manifest['assets']:
            if not errors and not validate_preservation(ROOT/item['source'],ROOT/item['output'])['passed']:errors.append('Preservation failed: '+item['asset'])
        if errors:print('\n'.join(errors),file=sys.stderr);return 1
        print('PASS: optimized source/output hashes, geometry, animation samples, skin binds, nodes and texture bytes')
        return 0
    before=(args.before or ROOT/ASSETS[args.asset]).resolve();after=(args.after or ROOT/'assets/optimized'/(args.asset+'.glb')).resolve()
    if not before.exists() or not after.exists():raise ValueError('Comparison inputs must exist; run optimize first')
    output=(args.out or report_root()/args.asset).resolve();output.mkdir(parents=True,exist_ok=True)
    command=[args.godot,'--path',str(ROOT),'--rendering-method','gl_compatibility','--resolution','1280x820','--log-file',str(output/'godot.log'),'--script','res://tools/asset_compare.gd','--','--before='+str(before),'--after='+str(after),'--out='+str(output),'--asset='+args.asset]
    if args.capture:command.append('--capture')
    if args.all_clips:command.append('--all-clips')
    return subprocess.run(command,cwd=ROOT).returncode


if __name__=='__main__':
    try:sys.exit(main())
    except (OSError,ValueError,KeyError,IndexError) as exc:print('Asset toolkit: '+str(exc),file=sys.stderr);sys.exit(1)
