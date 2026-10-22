"""Shared-Goemon and facial multi-angle review; never saves either source model.
Blender -b --python tools/render_rogue_roster_review.py -- [HERO ...]
--baseline DIR selects old sources; --output DIR selects evidence folder.
--portraits regenerates the selected roster portrait outputs.
--exported reviews the actual GLBs rather than editable source meshes.
--headroom frames tall head equipment completely in the detail renders.
"""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
ALL=('pirate','samurai','ninja','mage','knight','dragoon','magic-swordsman','ranger','explorer','master-thief')
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(ALL)
baseline=None;output=ROOT/'build/rogue-roster-upgrade/after';portraits='--portraits' in args
if portraits:args.remove('--portraits')
exported='--exported' in args
if exported:args.remove('--exported')
headroom='--headroom' in args
if headroom:args.remove('--headroom')
for flag in ['--baseline','--output']:
 if flag in args:
  i=args.index(flag);value=Path(args[i+1]);del args[i:i+2]
  if flag=='--baseline':baseline=value
  else:output=value

def render(hero):
 source=(baseline or ROOT)/'assets/blender/rogue'/(hero+'.blend');out=output/hero;out.mkdir(parents=True,exist_ok=True)
 if exported:
  bpy.ops.wm.read_factory_settings(use_empty=True)
  bpy.ops.import_scene.gltf(filepath=str((baseline or ROOT)/'assets/rogue/styled/models'/(hero+'.glb')))
 else:bpy.ops.wm.open_mainfile(filepath=str(source))
 rogue=list(bpy.data.objects)
 for o in rogue:
  if not o.parent:o.scale*=1.15;o.location.x+=2
 with bpy.data.libraries.load(str(ROOT/'assets/blender/characters/kai.blend'),link=False) as (data,target):target.objects=[n for n in data.objects if n in ['Skin','Hair_Normal','Reference_Rig']]
 for o in target.objects:
  if o:bpy.context.scene.collection.objects.link(o)
 rig=next(o for o in target.objects if o and o.type=='ARMATURE');rig.rotation_euler.z=math.pi;rig.location.x=-2
 s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=1200;s.render.resolution_y=800;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.film_transparent=False
 s.world=bpy.data.worlds.new('Shared neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.24,.27,.32,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.7;s.view_settings.view_transform='Standard'
 for loc,power,size in [((-3,-5,7),650,5),((4,-1,5),260,4),((0,4,5),350,4)]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(Vector((0,0,1.5))-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=(0,-12,1.72));cam=bpy.context.object;s.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=9.3
 roots=[rig]+[o for o in rogue if not o.parent]
 # glTF imports use quaternion mode; convert before applying review Euler yaw.
 for o in roots:o.rotation_mode='XYZ'
 base={o:o.rotation_euler.copy() for o in roots}
 angles=[('front',0),('side',math.pi/2),('three-quarter',math.pi/5),('back',math.pi)]
 for name,a in angles:
  for o in roots:o.rotation_euler.z=base[o].z+a
  cam.rotation_euler=(Vector((0,0,1.72))-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(out/('goemon-'+name+'.png'));bpy.ops.render.render(write_still=True)
 # Weapons remain visible in full-body comparisons, but hide during isolated
 # head closeups so a sword/staff cannot obscure the nose profile.
 weapon_hidden=[]
 for obj in rogue:
  ancestor=obj
  while ancestor:
   if ancestor.name.startswith('Weapon_'):
    if obj.type=='MESH':obj.hide_render=True;weapon_hidden.append(obj)
    break
   ancestor=ancestor.parent
 # Identical face camera for every before/after pair. The full native head branch
 # includes headwear/ears/mask; facial photos are not altered to hide intersections.
 for o in target.objects:
  if o:o.hide_render=True
 for o in roots:
  if o!=rig:o.location.x=0
 s.render.resolution_x=720;s.render.resolution_y=720;cam.data.ortho_scale=1.85 if headroom else 1.33
 head_height=2.25 if headroom else 2.06
 cam.location=(0,-12,head_height);cam.rotation_euler=(Vector((0,0,head_height))-cam.location).to_track_quat('-Z','Y').to_euler()
 for name,a in angles:
  for o in roots:
   if o!=rig:o.rotation_euler.z=base[o].z+a
  s.render.filepath=str(out/('head-'+name+'.png'));bpy.ops.render.render(write_still=True)
 if portraits:
  for obj in weapon_hidden:obj.hide_render=False
  for o in roots:
   if o!=rig:o.rotation_euler.z=math.pi/8
  cam.data.ortho_scale=4.8;s.render.resolution_x=640;s.render.resolution_y=720;cam.location=(0,-12,3.4);cam.rotation_euler=(Vector((0,0,1.7))-cam.location).to_track_quat('-Z','Y').to_euler();s.render.film_transparent=True;s.render.filepath=str(ROOT/'assets/rogue/styled/portraits'/(hero+'-portrait.png'));bpy.ops.render.render(write_still=True)
 print('ROGUE_REVIEW_COMPLETE',hero,str(out),flush=True)
for hero in args or ALL:render(hero)
