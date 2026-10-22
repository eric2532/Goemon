from pathlib import Path
import bpy
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parent.parent/'assets/characters/thirstquencher/projectiles';O=Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Soldiers');bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for i,name in enumerate(['bullet','casing']):
 previous=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(R/f'{name}.glb'));added=set(bpy.data.objects)-previous;meshes=[o for o in added if o.type=='MESH'];vs=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box];lo=Vector(tuple(min(v[a] for v in vs) for a in range(3)));hi=Vector(tuple(max(v[a] for v in vs) for a in range(3)));m=Matrix.Translation(((i-.5)*1.7,0,0))@Matrix.Scale(1.3/max(hi-lo),4)@Matrix.Translation(-(lo+hi)/2)
 for ob in added:
  if ob.parent not in added:ob.matrix_world=m@ob.matrix_world
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=12;sc.render.resolution_x=1100;sc.render.resolution_y=650;sc.render.resolution_percentage=100;sc.world.color=(.2,.2,.2);sc.view_settings.view_transform='Standard'
bpy.ops.object.camera_add(location=(1,-5,2));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.2;sc.camera=cam
bpy.ops.object.light_add(type='AREA',location=(0,-3,4));bpy.context.object.data.energy=200;bpy.context.object.data.size=4;sc.render.filepath=str(O/'original_bullet_and_casing.png');bpy.ops.render.render(write_still=True)
