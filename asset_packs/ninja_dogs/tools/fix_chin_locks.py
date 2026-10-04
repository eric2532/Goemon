import bpy,runpy,math
from pathlib import Path
from mathutils import Matrix,Vector
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'));r=d['DOGS'][6];src=P/'sources/07_Maboro.blend';bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene
if not s.get('ear_locks_follow_head'):
 h=Vector(r['head']);T=Matrix.Translation(h)@Matrix.Rotation(math.radians(-35),4,'Z')@Matrix.Translation(-h);count=0
 for o in bpy.data.objects:
  if o.name.startswith('FUR | long feathered Chin ear'):o.matrix_basis=T@o.matrix_basis;count+=1
 assert count==2,count
 s['ear_locks_follow_head']=True;cam=s.camera.matrix_world.copy();ortho=s.camera.data.ortho_scale;note=s['scale_note'];d['save_export'](r);s.camera.matrix_world=cam;s.camera.data.ortho_scale=ortho;s['scale_note']=note;bpy.ops.wm.save_as_mainfile(filepath=str(src),compress=True)
print('Chin ear feathering follows head rotation')
