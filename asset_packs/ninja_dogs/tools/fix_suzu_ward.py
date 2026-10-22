import bpy,runpy
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'));r=d['DOGS'][5];src=P/'sources/06_Suzu.blend';bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene
if not s.get('ward_motif_aligned'):
 count=0
 for o in bpy.data.objects:
  if o.name.startswith(('RITUAL | five-petal crest','RITUAL | flower center')):
   c=sum((o.matrix_world@Vector(b) for b in o.bound_box),Vector())/8/s['real_scale']
   if c.x>.8 and c.z>1.3:o.location+=Vector((0,.35,.14));count+=1
 assert count==6,count
 s['ward_motif_aligned']=True;cam=s.camera.matrix_world.copy();ortho=s.camera.data.ortho_scale;note=s['scale_note'];d['save_export'](r);s.camera.matrix_world=cam;s.camera.data.ortho_scale=ortho;s['scale_note']=note;bpy.ops.wm.save_as_mainfile(filepath=str(src),compress=True)
print('Suzu ward flower and paper aligned')
