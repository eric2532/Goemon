"""Identical-camera Goemon / Rogue comparisons; never edits the approved master."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
hero=sys.argv[sys.argv.index('--')+1]
out=ROOT/'build/character-style-audit'/hero;out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/blender/rogue'/(hero+'.blend')))
rogue=list(bpy.data.objects)
for o in rogue:
 if not o.parent:o.scale*=1.15;o.location.x+=2.0
with bpy.data.libraries.load(str(ROOT/'assets/blender/characters/kai.blend'), link=False) as (data,target):
 target.objects=[n for n in data.objects if n in ['Skin','Hair_Normal','Reference_Rig']]
for o in target.objects:
 if o:bpy.context.scene.collection.objects.link(o)
rig=next(o for o in target.objects if o and o.type=='ARMATURE');rig.rotation_euler.z=math.pi;rig.location.x=-2.0
# Keep Goemon at the approved rest pose, and frame both at shared ground height.
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=1400;s.render.resolution_y=800;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.film_transparent=False
s.world=bpy.data.worlds.new('Shared neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.24,.27,.32,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.7
s.view_settings.view_transform='Standard'
for loc,power,size in [((-3,-5,7),650,5),((4,-1,5),260,4),((0,4,5),350,4)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,1.5))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-12,2.15));cam=bpy.context.object;s.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=10.2
# Rotate each actor around its own origin so identical front/side/three-quarter cameras
# keep the same relative heights and left/right layout, without perspective bias.
roots=[rig]+[o for o in rogue if not o.parent]
base={o:o.rotation_euler.copy() for o in roots}
# Fit the full union of silhouettes across all review angles, once per pair.
review_points=[]
for a in [0,math.pi/2,math.pi/5,math.pi]:
 for o in roots:o.rotation_euler.z=base[o].z+a
 bpy.context.view_layer.update()
 for o in rogue+list(target.objects):
  if o and o.type=='MESH':review_points.extend(o.matrix_world@Vector(p) for p in o.bound_box)
zmin=min(p.z for p in review_points);zmax=max(p.z for p in review_points)
center_z=(zmin+zmax)/2
cam.location.z=center_z
cam.data.ortho_scale=max(max(abs(p.x) for p in review_points)*2+.7,(zmax-zmin+.7)*s.render.resolution_x/s.render.resolution_y)
for name,a in [('front',0),('side',math.pi/2),('three-quarter',math.pi/5),('back',math.pi)]:
 for o in roots:o.rotation_euler.z=base[o].z+a
 cam.rotation_euler=(Vector((0,0,center_z))-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
# Hero portrait uses the same matte material and lighting.
for o in target.objects:
 if o:o.hide_render=True
for o in roots:
 if o!=rig:o.location.x=0;o.rotation_euler.z=math.pi/8
cam.data.ortho_scale=4.8;s.render.resolution_x=640;s.render.resolution_y=720;cam.location=(0,-12,3.4);cam.rotation_euler=(Vector((0,0,1.7))-cam.location).to_track_quat('-Z','Y').to_euler();s.render.film_transparent=True;s.render.filepath=str(ROOT/'assets/rogue/styled/portraits'/(hero+'-portrait.png'));bpy.ops.render.render(write_still=True)
