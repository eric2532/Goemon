"""Blender --background --python tools/build_enemy_lods.py; preserve original sources."""
import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
report=[]
for name in ['ninja']:
 for level,ratio in [('near',.28),('far',.085)]:
  bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/blender/enemies'/f'{name}.blend'))
  for obj in list(bpy.context.scene.objects):
   if obj.type!='MESH': continue
   bpy.context.view_layer.objects.active=obj;obj.hide_set(False)
   dec=obj.modifiers.new('Crowd triangle budget','DECIMATE');dec.ratio=ratio;dec.use_collapse_triangulate=True
   bpy.ops.object.modifier_move_up(modifier=dec.name)
   bpy.ops.object.modifier_apply(modifier=dec.name)
  out=ROOT/'assets/models/enemies'/f'{name}_{level}.glb'
  bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_cameras=False,export_lights=False,export_animations=False,export_skins=True,export_apply=False)
  tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
  report.append({'asset':name+'_'+level,'triangles':tris})
(ROOT/'tests/performance-legs/enemy-lods.json').write_text(json.dumps(report,indent=2))
