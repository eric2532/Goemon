"""Author Edo's fire/smoke explosion masters and editable animation in Blender."""
from pathlib import Path
import bpy, math, random, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/vfx'
REVIEW=ROOT/'tests/edo-firecaster'
OUT.mkdir(parents=True,exist_ok=True);REVIEW.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rng=random.Random(2910)
masters=bpy.data.collections.new('EXPORT MASTERS');bpy.context.scene.collection.children.link(masters)
def move_collection(obj,collection):
 for source in list(obj.users_collection):source.objects.unlink(obj)
 collection.objects.link(obj)
def material(name,color,emission=0):
 mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
 bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.8
 if emission:
  bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
 return mat
orange=material('Flame envelope - ember orange',(1,.105,.008),1.7)
gold=material('Hot core - yellow white',(1,.68,.10),3.0)
smoke_mat=material('Cooling smoke - charcoal',(0.16,.12,.11))
parts=[]
for layer,mat in [('Envelope',orange),('Core',gold)]:
 lobes=[]
 count=6 if layer=='Envelope' else 4
 for i in range(count):
  angle=i*2.39996
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
  obj=bpy.context.object
  for vertex in obj.data.vertices:
   v=vertex.co;tip=max(0,v.z)
   v.x*=1-.68*tip;v.y*=1-.68*tip
   v.x+=.25*tip*tip
  obj.scale=(.38,.38,.88 if i else .68) if layer=='Envelope' else (.23,.23,.56)
  radius=.34 if layer=='Envelope' else .15
  obj.location=(math.cos(angle)*radius,math.sin(angle)*radius,.12+rng.random()*.2)
  obj.rotation_euler=(math.sin(angle)*.4,math.cos(angle)*.4,angle)
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  lobes.append(obj)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in lobes:obj.select_set(True)
 bpy.context.view_layer.objects.active=lobes[0];bpy.ops.object.join();obj=bpy.context.object
 obj.name='FireBurst_'+layer;obj.data.materials.append(mat)
 for face in obj.data.polygons:face.use_smooth=True
 move_collection(obj,masters);parts.append(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'edo_fire_burst.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
# Reuse the approved Blender smoke topology in this editable combined study.
with bpy.data.libraries.load(str(ROOT/'assets/blender/vfx/Sky_Strike_Smoke.blend'),link=False) as (source,dest):
 dest.objects=[name for name in source.objects if name.startswith('Smoke_Billow_')]
smoke_masters=dest.objects
for obj in smoke_masters:
 masters.objects.link(obj);obj.data=obj.data.copy();obj.data.materials.clear();obj.data.materials.append(smoke_mat)
 obj.hide_render=True;obj.hide_set(True)
for obj in parts:obj.hide_render=True;obj.hide_set(True)
scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=36;scene.render.fps=30
for kind,center,scale in [('Departure',Vector((-4,0,0)),.85),('Arrival',Vector((4,0,0)),1.0)]:
 collection=bpy.data.collections.new(kind+' - fire then expanding smoke');scene.collection.children.link(collection)
 for i in range(12):
  angle=i*2.399963;direction=Vector((math.cos(angle),math.sin(angle),.28+float(i%3)*.12))
  for master in parts:
   obj=bpy.data.objects.new(kind+'_Flame_%02d_'%i+master.name,master.data);collection.objects.link(obj)
   for frame,travel,size in [(1,0,.01),(5,.30,.95),(10,.72,.85),(18,1,.01)]:
    obj.location=center+direction*travel*3*scale;obj.scale=Vector((size,size,size))*scale
    obj.rotation_euler=(math.sin(angle)*.6,math.cos(angle)*.6,angle)
    obj.keyframe_insert('location',frame=frame);obj.keyframe_insert('scale',frame=frame)
  master=smoke_masters[i%len(smoke_masters)]
  obj=bpy.data.objects.new(kind+'_Smoke_%02d'%i,master.data);collection.objects.link(obj)
  for frame,travel,size,rise in [(1,0,.01,0),(8,.40,.48,.25),(19,.8,1.0,.8),(36,1,.01,1.8)]:
   obj.location=center+direction*travel*3.7*scale+Vector((0,0,rise));obj.scale=Vector((size,size,size))*scale
   obj.keyframe_insert('location',frame=frame);obj.keyframe_insert('scale',frame=frame)
# Studio camera and ground are excluded from the mesh-only runtime export.
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='Preview ground';floor.location.z=-.9
floor.data.materials.append(material('Studio floor',(0.04,.055,.075)))
bpy.ops.object.camera_add(location=(12,-20,12));camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,.6))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=16;scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(0,-4,10));bpy.context.object.data.energy=1700;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=10
scene.world.color=(.12,.12,.12);scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1400;scene.render.resolution_y=840;scene.render.resolution_percentage=100
scene.frame_set(8)
scene['runtime_export']='assets/models/vfx/edo_fire_burst.glb'
scene['effect_timing']='Fast bright radial fire burst, followed by expanding and rising charcoal smoke.'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/vfx/Edo_Fire_Explosion.blend'))
scene.render.filepath=str(REVIEW/'blender-fire-explosion.png');bpy.ops.render.render(write_still=True)
stats={obj.name:{'vertices':len(obj.data.vertices),'triangles':sum(len(face.vertices)-2 for face in obj.data.polygons)} for obj in parts}
(REVIEW/'blender-assets.json').write_text(json.dumps(stats,indent=2))
print('EDO_FIRE_BLENDER_COMPLETE',json.dumps(stats))
