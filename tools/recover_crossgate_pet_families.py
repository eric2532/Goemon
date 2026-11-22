"""Recover reviewed companion families with the existing lossless pet packer."""
import argparse
import json
import shutil
from pathlib import Path

from recover_crossgate_mantises import ROOT, recover, compose

CONFIG = Path(__file__).with_name('crossgate_pet_families.json')
OUT = ROOT / 'assets/characters/crossgate/companions'
STAGING = ROOT / 'build/Other Files/Asset Toolkit/Cross Gate Pet Expansion/Staging'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('--family')
    parser.add_argument('--compose',action='store_true')
    args=parser.parse_args()
    config=json.loads(CONFIG.read_text())
    if args.compose:
        assert all((OUT/f['folder']/'motions.json').exists() for f in config['families'])
        profiles=[{k:v[k] for k in ('body','visual_scale')} for f in config['families'] for v in f['variants']]
        (OUT/'catalog.json').write_text(json.dumps(dict(families=[f['folder'] for f in config['families']],profiles=profiles,unresolved=config['unresolved']),ensure_ascii=False,indent=2)+'\n')
        compose()
        return
    families=[f for f in config['families'] if args.family is None or f['folder']==args.family]
    assert families,'Unknown family'
    for family in families:
        rows=family['variants']
        profiles={v['key']:{k:v[k] for k in ('label','category','effect','xl','visual_scale','body')} for v in rows}
        for v in rows:
            for field in ('run_action','motion_key','ground_shift','graphic_dimensions','missing_audio'):
                if field in v:profiles[v['key']][field]=v[field]
        for cell,v in enumerate(rows):profiles[v['key']].update(portrait_path=f'res://assets/characters/crossgate/companions/{family["folder"]}/portraits.png',portrait_cell=cell)
        staged=STAGING/family['folder']
        recover(args.source,[(v['id'],v['key']) for v in rows],staged,
                {v['id'] for v in rows if v['xl']},profiles,
                legacy_contacts=family.get('legacy_contacts',True))
        pages=json.loads((staged/'motions.json').read_text())['pages']
        for folder in [staged,OUT/family['folder']]:
            for old in folder.glob('atlas-*.png'):
                if int(old.stem.split('-')[-1])>=pages:
                    old.unlink();old.with_suffix('.png.import').unlink(missing_ok=True)
        # Publish only a fully decoded family; a missing frame never becomes a guessed replacement.
        shutil.copytree(staged,OUT/family['folder'],dirs_exist_ok=True)
        print('VERIFIED_FAMILY',family['folder'],len(rows),flush=True)


if __name__=='__main__':main()
