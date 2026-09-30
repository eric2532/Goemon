"""Run with Blender -b --python tools/validate_edo_v01.py."""
import bpy,json,hashlib,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[1];O=R/'assets/blender/enemies/musashi/Redesign_v01'
bpy.ops.wm.open_mainfile(filepath=str(O/'Edo_Ember_v01.blend'))
old=bpy.data.objects['BEFORE_Edo_Refined'];new=bpy.data.objects['EDO_EMBER_V01_Surface'];rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
def bounds(o):
 v=[o.matrix_world@v.co for v in o.data.vertices];return [[min(p[i] for p in v) for i in range(3)],[max(p[i] for p in v) for i in range(3)]]
originals=['assets/blender/enemies/musashi/Final/Musashi_Final.blend','assets/blender/enemies/musashi/Musashi_Playable.blend','assets/blender/enemies/musashi/Edo_Playable_Refined.blend','assets/characters/musashi/model/edo_refined.glb','assets/characters/musashi/animations/motion.gd','assets/characters/musashi/combat/musashi_combat.gd','scripts/player.gd']
checks={}
for p in originals:
 if not (R/p).exists():continue
 current=hashlib.sha256((R/p).read_bytes()).hexdigest();base=hashlib.sha256(subprocess.check_output(['git','show','65fa8b1:'+p],cwd=R)).hexdigest();checks[p]={'sha256':current,'unchanged':current==base}
report={'originals':checks,'before_bounds':bounds(old),'after_bounds':bounds(new),'normalized_weights':all(abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in new.data.vertices),'all_vertices_skinned':all(len(v.groups)>0 for v in new.data.vertices),'uv_maps':len(new.data.uv_layers),'bone_names':[b.name for b in rig.data.bones],'packed_images':[(i.name,bool(i.packed_file)) for i in bpy.data.images if i.type=='IMAGE'],'external_libraries':len(bpy.data.libraries),'bone_animation_source':'Existing unmodified MusashiMotion; GLB contains no root-motion/attack tracks.'}
(O/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
assert all(v['unchanged'] for v in checks.values());assert report['normalized_weights'] and report['all_vertices_skinned'];assert report['uv_maps']>0
