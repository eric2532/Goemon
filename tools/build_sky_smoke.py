"""Blender-authored reusable billowing smoke, with animated takeoff/stomp studies."""
import bpy, math, random, os, json
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng=random.Random(726)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
material=bpy.data.materials.new('Warm pearl smoke');material.diffuse_color=(.61,.64,.66,1)
material.use_nodes=True
bs=material.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.61,.64,.66,1);bs.inputs['Roughness'].default_value=1
billows=[];stats=[]
for variant in range(3):
 parts=[]
 for i in range(9):
  a=i*2.39996;radius=.32 if i else 0
  p=Vector((math.cos(a)*radius,math.sin(a)*radius,rng.uniform(-.18,.24)))
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=rng.uniform(.33,.52),location=p)
  obj=bpy.context.object;parts.append(obj)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in parts:obj.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();obj=bpy.context.object
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 mod=obj.modifiers.new('Unified soft billows','REMESH');mod.mode='VOXEL';mod.voxel_size=.09;mod.use_smooth_shade=True
 bpy.ops.object.modifier_apply(modifier=mod.name)
 smooth=obj.modifiers.new('Soft smoke surface','SMOOTH');smooth.factor=1.1;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
 dec=obj.modifiers.new('Game mesh budget','DECIMATE');dec.ratio=.5;bpy.ops.object.modifier_apply(modifier=dec.name)
 obj.name='Smoke_Billow_'+str(variant);obj.data.materials.append(material)
 for p in obj.data.polygons:p.use_smooth=True
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
 bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/models/vfx/smoke_billow_'+str(variant)+'.glb',export_format='GLB',use_selection=True,export_animations=False)
 stats.append({'mesh':obj.name,'vertices':len(obj.data.vertices),'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons)})
 billows.append(obj);obj.hide_render=True;obj.hide_set(True)
# Keep editable animation studies next to the export masters in the native Blender source.
for kind,center,count in [('Takeoff',Vector((-3,0,0)),12),('Stomp',Vector((3,0,0)),18)]:
 collection=bpy.data.collections.new(kind+' smoke animation');bpy.context.scene.collection.children.link(collection)
 for i in range(count):
  obj=bpy.data.objects.new(kind+'_billow_%02d'%i,billows[i%3].data);collection.objects.link(obj)
  a=i*2.39996;direction=Vector((math.cos(a),math.sin(a),0))
  base=center+direction*(.15 if kind=='Takeoff' else .3)
  spread=direction*(1.1 if kind=='Takeoff' else 3.0)+Vector((0,0,(1.4+i*.07) if kind=='Takeoff' else .5+rng.random()*.5))
  for frame,t,scale in [(1,0,.08),(7,.28,.7),(18,.7,1.05),(30,1,.01)]:
   obj.location=base+spread*t;obj.scale=Vector((scale,scale,scale));obj.rotation_euler=(t*.5,a,t)
   for channel in ['location','scale','rotation_euler']:obj.keyframe_insert(channel,frame=frame)
scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=30;scene.render.fps=30;scene.frame_set(10)
bpy.ops.object.camera_add(location=(8,-13,9));camera=bpy.context.object;camera.name='Smoke preview camera';camera.rotation_euler=((Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler());camera.data.type='ORTHO';camera.data.ortho_scale=13;scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(1,-4,8));bpy.context.object.data.energy=1700;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=7
scene.world.color=(.25,.25,.25)
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=1200;scene.render.resolution_y=720;scene.render.resolution_percentage=100
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/blender/vfx/Sky_Strike_Smoke.blend')
scene.render.filepath=ROOT+'/tests/sky-smoke-world/blender-smoke.png';bpy.ops.render.render(write_still=True)
json.dump(stats,open(ROOT+'/tests/sky-smoke-world/smoke-meshes.json','w'),indent=2)
