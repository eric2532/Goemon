"""Recover the original Blood Gulch teleporter pad and its green energy assets.

Read-only input: user's Xbox disc ISO or extracted bloodgulch.map. Requires
requirements.txt. Native shader definitions and editable JMS/tags are retained;
no sound attachment or sample is included in this visual-only adaptation.
"""
import argparse, contextlib, hashlib, json, shutil, tempfile
from pathlib import Path
from extract_energy_sword import extract_iso_map
from extract_weapon_effects import normalize, references
from decode_extracted_assets import model

ROOT = Path(__file__).resolve().parents[2]


def extract(source, destination, log_path):
 from refinery.core import RefineryCore
 import reclaimer.meta.wrappers.halo1_map as halo1
 original = halo1.byteswap_comp_verts
 def corrected(block):
  original(block)
  data = block.STEPTREE.data
  for offset in range(0, len(data), 32):
   data[offset+28], data[offset+29] = data[offset+29], data[offset+28]
 halo1.byteswap_comp_verts = corrected
 destination.mkdir(parents=True, exist_ok=True)
 editable = destination/'source'
 editable.mkdir(exist_ok=True)
 (editable/'.gdignore').touch()
 try:
  log_path.parent.mkdir(parents=True, exist_ok=True)
  with log_path.open('w') as log, contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
   refinery = RefineryCore()
   cache = refinery.load_map(source, autoload_resources=False)
   tags = cache.tag_index.tag_index
   lookup = {(t.class_1.enum_name, t.path): i for i, t in enumerate(tags)}
   pad_path = r'scenery\teleporter_base\teleporter_base'
   pending = [lookup[('scenery', pad_path)]]
   found = {}
   while pending:
    index = pending.pop(0)
    if index in found: continue
    tag = tags[index]
    if tag.class_1.enum_name in ('sound', 'sound_looping', 'sound_scenery'): continue
    meta = cache.get_meta(index)
    found[index] = {'class': tag.class_1.enum_name, 'path': tag.path, 'native': normalize(meta)}
    for ref in references(meta):
     key = (ref['class'], ref['path'])
     if key in lookup: pending.append(lookup[key])
    refinery.extract_tag(index, extract_mode='tags', out_dir=editable/'tags', do_printout=False)
    if tag.class_1.enum_name in ('model', 'bitmap'):
     refinery.extract_tag(index, extract_mode='data', out_dir=editable/'data', do_printout=False, bitmap_extract_format='png')
   mesh = model(editable/'data/scenery/teleporter_base/models/teleporter_base superhigh.jms')
   (destination/'model.json').write_text(json.dumps(mesh, separators=(',', ':'))+'\n')
   (destination/'native_tags.json').write_text(json.dumps({'map': source.name, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'tags': list(found.values())}, indent=2)+'\n')
   images = {}
   textures = destination/'textures'
   textures.mkdir(exist_ok=True)
   for key, bitmap in {
    'teleporter_base': r'scenery\teleporter_base\bitmaps\teleporter_base',
    'metal_flat': r'levels\b30\bitmaps\metal flat generic',
    'metal_strips': r'levels\b30\bitmaps\metal strips decorative wide',
    'shield': r'scenery\teleporter_shield\bitmaps\teleporter_shield',
    'energy_mask': r'scenery\teleporter_shield\bitmaps\teleporter_shield_energy mask',
    'plasma': r'levels\a50\devices\prison door\bitmaps\energy plasma',
    'volumetric_dust': r'scenery\teleporter_base\bitmaps\base volumetric dust',
    'teleporter_dust': r'scenery\teleporter_base\bitmaps\teleporter_dust',
   }.items():
    path = editable/'data'/Path(bitmap.replace('\\', '/')+'.png')
    target = textures/(key+'.png')
    shutil.copy2(path, target)
    images[key] = {'tag': bitmap, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
   (destination/'provenance.json').write_text(json.dumps({'map_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'model_tag': pad_path, 'vertices': len(mesh['vertices']), 'triangles': len(mesh['triangles']), 'jms_unit_meters': .03048, 'images': images, 'adaptation': 'Uniform 10x scene scale. Original mesh, UVs and pixels. Godot translations of native generic/Chicago additive shaders and scrolling periods; no audio or gameplay collision.'}, indent=2)+'\n')
 finally:
  halo1.byteswap_comp_verts = original
 print('HALO_TELEPORTER_EXTRACTED', len(found), 'tags;', len(mesh['triangles']), 'triangles;', len(images), 'runtime images')


if __name__ == '__main__':
 parser = argparse.ArgumentParser(description=__doc__)
 parser.add_argument('disc_or_map', type=Path)
 parser.add_argument('--destination', type=Path, default=ROOT/'assets/scenery/halo_teleporter')
 parser.add_argument('--log', type=Path, default=Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/halo-teleporter-source-20261021/extraction.log'))
 args = parser.parse_args()
 if args.disc_or_map.suffix.lower() == '.map':
  extract(args.disc_or_map, args.destination, args.log)
 else:
  with tempfile.TemporaryDirectory(prefix='goemon-teleporter-') as folder:
   path = Path(folder)/'bloodgulch.map'
   extract_iso_map(args.disc_or_map, path, 'bloodgulch.map')
   extract(path, args.destination, args.log)
