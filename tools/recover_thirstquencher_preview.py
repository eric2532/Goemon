from pathlib import Path
import json,struct,math,bpy
from mathutils import Vector,Matrix,Euler
R=Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')
O=Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Soldiers')
v=json.loads((R/'visual_manifest.json').read_text());mods={m['id']:m for m in v['models']};lists=json.loads((O/'candidate_lists_077.json').read_text());d=(R/'raw/SC01.CD.dir/FILE_077.dir/0.4.dec').read_bytes();B=0x80128158
C=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for j,(li,pose) in enumerate(zip([lists[5],lists[2],lists[6]],[0x801a0768]*3)):
 meshes=[]
 for i,m in enumerate(li['models']):
  b0,b1,b2,x,y,z,rx=struct.unpack_from('<3B3bh',d,pose-B+i*8); ry=b1|((b0&15)<<8); rz=b2|((b0&240)<<4)
  M=(C@Euler([a*math.tau/4096 for a in [rx,ry,rz]],'XYZ').to_matrix()@C.transposed()).to_4x4();M.translation=C@Vector((x,y,z))
  prev=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(R/mods[m]['path']))
  for ob in set(bpy.data.objects)-prev:
   if ob.type=='MESH': ob.matrix_world=Matrix.Translation(((j-1)*180,0,0))@M@ob.matrix_world;meshes.append(ob)
   for mat in getattr(ob.data,'materials',[]):mat.use_backface_culling=False
 sc=bpy.context.scene
sc.render.engine='CYCLES';sc.cycles.samples=12;sc.render.resolution_x=1200;sc.render.resolution_y=650;sc.render.resolution_percentage=100;sc.world.color=(.25,.25,.25);sc.view_settings.view_transform='Standard'
bpy.ops.object.camera_add(location=(0,-650,100));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,40))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=600;sc.camera=cam
bpy.ops.object.light_add(type='AREA',location=(0,-300,500));bpy.context.object.data.energy=50000;bpy.context.object.data.size=700
sc.render.filepath=str(O/'recovered_three_types.png');bpy.ops.render.render(write_still=True)
