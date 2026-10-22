import bpy,runpy
from pathlib import Path
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'));r=d['DOGS'][7];src=P/'sources/08_Iwa.blend';bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene
if not s.get('cuirass_support_added'):
 root=bpy.data.objects['CHARACTER | Iwa'];col=root.users_collection[0];m=bpy.data.materials['leather']
 for sign in [-1,1]:
  for pts in [[(.88,sign*.36,1.18),(.72,sign*.46,1.29),(.48,sign*.51,1.35),(.20,sign*.46,1.30)],[(.88,sign*.36,.68),(.64,sign*.44,.69),(.34,sign*.47,.76)]]:
   ob=d['curve']('ARMOR | cuirass suspension strap',pts,m,.025);ob.parent=root
   for c in list(ob.users_collection):c.objects.unlink(ob)
   col.objects.link(ob)
 s['cuirass_support_added']=True;cam=s.camera.matrix_world.copy();ortho=s.camera.data.ortho_scale;note=s['scale_note'];d['save_export'](r);s.camera.matrix_world=cam;s.camera.data.ortho_scale=ortho;s['scale_note']=note;bpy.ops.wm.save_as_mainfile(filepath=str(src),compress=True)
print('Iwa cuirass suspension straps added')
