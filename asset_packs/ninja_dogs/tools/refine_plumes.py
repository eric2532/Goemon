import bpy,runpy
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'))
for r in d['DOGS']:
 if r['id'] not in ['06','07']:continue
 src=P/'sources'/f"{r['id']}_{r['name']}.blend";bpy.ops.wm.open_mainfile(filepath=str(src))
 for o in list(bpy.data.objects):
  if o.name in ['ANATOMY | sculpted tail','FUR | directional tail plume']:bpy.data.objects.remove(o,do_unlink=True)
 d['tail'](r,{m.name:m for m in bpy.data.materials});bpy.context.view_layer.update()
 if r['id']=='06':
  for o in bpy.data.objects:
   if o.name.startswith('DISPLAY |'):
    c=sum((o.matrix_world@Vector(b) for b in o.bound_box),Vector())/8
    if c.x>.8 and c.z>1.3:o.location+=Vector((0,.35,.14))
 bpy.ops.wm.save_as_mainfile(filepath=str(src),compress=True)
