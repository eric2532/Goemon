"""One-time Blender preparation of recovered Skullpion's castle contact poses."""
from pathlib import Path
import bpy,math
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
MASTER=ROOT/'assets/blender/enemies/skullpion/Skullpion.blend'
assert not MASTER.exists(),'Refusing to overwrite an editable master; use export_skullpion.py for saved edits'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'build/Other Files/Asset Toolkit/Skullpion/Skullpion.blend'))
scene=bpy.context.scene
parts=sorted((o for o in scene.objects if o.type=='MESH'),key=lambda o:o.name)
assert len(parts)==22
# Preserve the recovered meshes and source actions; only bake additional castle actions.
for ob in parts:
 ob['rom_part']=ob.name
 ob['geometry_policy']='Original recovered triangles, UVs and material bindings; prepared motion only'
source_pairs=[('Castle_Idle','801adc24'),('Castle_Walk','801adc6c'),('Castle_Ascend','801ae46c'),('Castle_Cling','801ae6dc'),('Castle_Jump','801ae824')]
frames_by_action={}
def assign(action):
 for ob in parts:
  ob.animation_data.action=action
  ob.animation_data.action_slot=next(s for s in action.slots if s.identifier=='OB'+ob.name)
 scene.frame_set(scene.frame_current);bpy.context.view_layer.update()
def vertices(ob,matrix):return [matrix@v.co for v in ob.data.vertices]
def prepare(matrices,wall):
 feet=[v for name in ['Part_10','Part_11'] for v in vertices(bpy.data.objects[name],matrices[name])]
 floor=min(v.z for v in feet)
 # The tail must trail above the supporting feet rather than pass through the floor.
 tail=[v for ob in parts if 16<=int(ob.name[-2:])<=20 for v in vertices(ob,matrices[ob.name])]
 pelvis=vertices(bpy.data.objects['Part_21'],matrices['Part_21'])
 base=vertices(bpy.data.objects['Part_20'],matrices['Part_20'])
 a,b=min(((a,b) for a in base for b in pelvis),key=lambda pair:(pair[0]-pair[1]).length_squared)
 pivot=(a+b)*.5
 angle=0
 if min(v.z for v in tail)<floor:
  for step in range(1,181):
   trial=math.radians(step*.5);rotation=Matrix.Rotation(trial,4,'X')
   if min((pivot+rotation@(v-pivot)).z for v in tail)>=floor:angle=trial;break
  assert angle,f'Tail cannot fit: floor={floor}, tail={min(v.z for v in tail)}, pivot={pivot}, action={bpy.data.objects["Part_00"].animation_data.action.name}, frame={scene.frame_current}'
  rotation=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,'X')@Matrix.Translation(-pivot)
  for ob in parts:
   if 16<=int(ob.name[-2:])<=20:matrices[ob.name]=rotation@matrices[ob.name]
 front=min(v.y for name in ['Part_01','Part_02','Part_10','Part_11'] for v in vertices(bpy.data.objects[name],matrices[name]))
 shift=Vector((0,-1.0-front if wall else 0,-floor))
 return {n:Matrix.Translation(shift)@m for n,m in matrices.items()}
for name,address in source_pairs:
 source=bpy.data.actions['Source__'+address];assign(source)
 duration=source.frame_range[1]/scene.render.fps
 frames=sorted(set([0.0,float(source.frame_range[1])]+[float(f) for f in range(math.ceil(source.frame_range[1])+1) if f<=source.frame_range[1]]))
 samples=[]
 for frame in frames:
  scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
  matrices={ob.name:ob.matrix_world.copy() for ob in parts}
  samples.append((frame,prepare(matrices,name in ['Castle_Ascend','Castle_Cling']) if name!='Castle_Jump' else matrices))
 frames_by_action[name]=(duration,samples)
# Prepared transitions retain the original rigid parts and avoid snapping on takeoff.
rest=frames_by_action['Castle_Idle'][1][0][1]
cling=frames_by_action['Castle_Cling'][1][-2][1]
for name,start,duration in [('Castle_Ascend',rest,.4),('Castle_Jump',cling,.6)]:
 length,samples=frames_by_action[name]
 for frame,matrices in samples:
  alpha=min(1,frame/scene.render.fps/duration);alpha=alpha*alpha*(3-2*alpha)
  for ob in parts:matrices[ob.name]=start[ob.name].lerp(rest[ob.name] if name=='Castle_Jump' else matrices[ob.name],alpha)
 # Normalize each transition's actual feet again after interpolation.
 for _,matrices in samples:
  floor=min(v.z for n in ['Part_10','Part_11'] for v in vertices(bpy.data.objects[n],matrices[n]))
  for n in matrices:matrices[n]=Matrix.Translation((0,0,-floor))@matrices[n]
for name,(duration,samples) in frames_by_action.items():
 action=bpy.data.actions.new(name);action.use_fake_user=True
 for ob in parts:
  slot=action.slots.new('OBJECT',ob.name);ob.animation_data.action=action;ob.animation_data.action_slot=slot
  ob.rotation_mode='QUATERNION'
  for frame,matrices in samples:
   local=ob.parent.matrix_world.inverted()@matrices[ob.name]
   ob.location,ob.rotation_quaternion,ob.scale=local.decompose()
   ob.keyframe_insert('location',frame=frame);ob.keyframe_insert('rotation_quaternion',frame=frame);ob.keyframe_insert('scale',frame=frame)
  track=ob.animation_data.nla_tracks.new();track.name=name;track.mute=True
  strip=track.strips.new(name,1,action);strip.action_slot=slot
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for curve in bag.fcurves:
     for key in curve.keyframe_points:key.interpolation='LINEAR'
 action['preparation']='Foot/floor and castle-plane alignment baked in Blender; source mesh untouched'
scene['skullpion_wall_plane']=-1.0
scene['skullpion_runtime_multiplier']=12.0
scene['skullpion_prepared_actions']=[name for name,_ in source_pairs]
assign(bpy.data.actions['Castle_Cling']);scene.frame_set(0)
for name,point in [('CastleWallContact',(0,-1,0)),('ModelFloor',(0,0,0))]:
 ob=bpy.data.objects.new(name,None);scene.collection.objects.link(ob);ob.location=point;ob.empty_display_type='PLAIN_AXES';ob.empty_display_size=.3;ob['export_exclude']=True
for image in bpy.data.images:
 if image.source=='FILE' and image.packed_file is None:image.pack()
scene.unit_settings.scale_length=1
bpy.ops.wm.save_as_mainfile(filepath=str(MASTER));print('SKULLPION_PREPARED',MASTER)
