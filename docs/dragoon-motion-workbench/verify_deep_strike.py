import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(__file__).resolve().parent
record=json.loads((folder/'deep_strike_verification.json').read_text())
reference=json.loads((folder/'approved_strike_inputs.json').read_text())
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
assert scene.frame_start==1 and scene.frame_end==34 and scene.render.fps==60
assert rig.animation_data.action.name=='03_Lance_Thrust_1'
core={n:Matrix(m) for n,m in reference['contact']['bones'].items()}
start={n:Matrix(m) for n,m in reference['start']['bones'].items()}
core_error=0.;leg_error=0.;grip_error=0.;length_error=0.;recovery_error=0.
grips={side:core['Lance_Control'].inverted()@core['Hand_'+side] for side in ('L','R')}
core_lengths={side:((core['Forearm_'+side].translation-core['Arm_'+side].translation).length,(core['Hand_'+side].translation-core['Forearm_'+side].translation).length) for side in ('L','R')}
for frame in range(1,35):
 scene.frame_set(frame);bpy.context.view_layer.update()
 pose={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
 assert all(math.isfinite(v) for mat in pose.values() for row in mat for v in row)
 if 7<=frame<=12:core_error=max(core_error,max(abs(pose[name][i][j]-core[name][i][j]) for name in pose for i in range(4) for j in range(4)))
 if 7<=frame<=20:
  for name in ['Root','Pelvis','Leg_L','Leg_R','Shin_L','Shin_R','Foot_L','Foot_R']:leg_error=max(leg_error,max(abs(pose[name][i][j]-core[name][i][j]) for i in range(4) for j in range(4)))
  for side in ['L','R']:
   grip=pose['Lance_Control'].inverted()@pose['Hand_'+side]
   grip_error=max(grip_error,max(abs(grip[i][j]-grips[side][i][j]) for i in range(4) for j in range(4)))
   lengths=((pose['Forearm_'+side].translation-pose['Arm_'+side].translation).length,(pose['Hand_'+side].translation-pose['Forearm_'+side].translation).length)
   length_error=max(length_error,max(abs(a-b) for a,b in zip(lengths,core_lengths[side])))
 if frame==18:
  advance=pose['Lance_Control'].translation-core['Lance_Control'].translation
  assert abs(advance.length-.14)<1e-5,advance
  assert advance.normalized().dot(Vector(record['extension_direction_rig']))>.99999
  assert (pose['Arm_R'].translation-core['Arm_R'].translation).length>.07
 if frame==34:recovery_error=max(abs(pose[name][i][j]-start[name][i][j]) for name in pose for i in range(4) for j in range(4))
assert max(core_error,leg_error,grip_error,length_error,recovery_error)<1e-4
assert record['hold_time_multiplier']==2.5

def signature(action):return [(fc.data_path,fc.array_index,[(tuple(k.co),k.interpolation,tuple(k.handle_left),tuple(k.handle_right)) for k in fc.keyframe_points]) for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
with bpy.data.libraries.load(record['backup']) as (src,dst):
 names=[n for n in src.actions if n!='03_Lance_Thrust_1'];dst.actions=names[:]
 dst.objects=['Skin','Hair_Normal','Costume_dragoon','Weapon_Cutlass_Geometry','Reference_Rig']
for name,action in zip(names,dst.actions):
 assert signature(action)==signature(bpy.data.actions[name]),name
 bpy.data.actions.remove(action)
for obj in dst.objects:
 name=obj.name.rsplit('.',1)[0];current=bpy.data.objects[name]
 if obj.type=='MESH':
  assert [tuple(v.co) for v in obj.data.vertices]==[tuple(v.co) for v in current.data.vertices]
  assert [[tuple(uv.uv) for uv in layer.data] for layer in obj.data.uv_layers]==[[tuple(uv.uv) for uv in layer.data] for layer in current.data.uv_layers]
 else:
  for bone in obj.data.bones:assert abs(bone.length-current.data.bones[bone.name].length)<1e-7
 bpy.data.objects.remove(obj,do_unlink=True)
report={'saved_file_verified':True,'frames_checked':34,'core_hold_multiplier':2.5,'core_error':core_error,'fixed_leg_error':leg_error,'hand_grip_error':grip_error,'arm_segment_length_error':length_error,'return_to_start_error':recovery_error,'lance_advance_m':.14,'other_clips_unchanged':True,'mesh_uv_bone_lengths_unchanged':True}
(folder/'deep_strike_saved_verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('DEEP_STRIKE_SAVED_VERIFIED',json.dumps(report))
if '--render' in __import__('sys').argv:
 if bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
 for obj in list(scene.objects):
  if obj.type in {'LIGHT','CAMERA'}:bpy.data.objects.remove(obj,do_unlink=True)
 cd=bpy.data.cameras.new('Deep_Preview');camera=bpy.data.objects.new('Deep_Preview',cd);scene.collection.objects.link(camera)
 camera.location=(6,-1.2,2.8);camera.rotation_euler=(Vector((0,-.85,1.4))-camera.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=6.0;scene.camera=camera
 scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.16,.21,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
 for loc,power,size in [((3,-5,7),650,5),((-4,-2,4),450,4),((1,4,6),600,3)]:
  ld=bpy.data.lights.new('Deep_Light','AREA');ld.energy=power;ld.size=size
  light=bpy.data.objects.new('Deep_Light',ld);scene.collection.objects.link(light);light.location=loc;light.rotation_euler=(Vector((0,0,1.3))-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=8;scene.cycles.max_bounces=3
 scene.render.resolution_x=640;scene.render.resolution_y=440;scene.render.resolution_percentage=100;scene.render.film_transparent=False
 for frame in (7,15,18,25):
  scene.frame_set(frame);scene.render.filepath=str(folder/('deep_strike_preview_%02d.png'%frame));bpy.ops.render.render(write_still=True)
