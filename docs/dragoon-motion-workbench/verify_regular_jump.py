import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(__file__).resolve().parent
record=json.loads((folder/'regular_jump_timing.json').read_text());scene=bpy.context.scene;rig=bpy.data.objects['Reference_Rig'];action=rig.animation_data.action
assert action.name=='02_Jump' and scene.frame_start==1 and scene.frame_end==140 and scene.render.fps==60
references={}
for label,name in [('crouch','Jump_Pose_Crouch'),('air','Jump_Pose_Airborne'),('land','Jump_Pose_Landing'),('idle','00_Idle_Approved_Base')]:
 rig.animation_data.action=bpy.data.actions[name];rig.animation_data.action_slot=rig.animation_data.action.slots[0]
 scene.frame_set(1);bpy.context.view_layer.update();references[label]={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
checks={1:'crouch',12:'crouch',40:'air',72:'air',98:'land',108:'land',140:'idle'}
errors={};steps=[];previous=None;min_upright=999.;height=[];grip_error=0.
air_grip=references['air']['Hand_R'].inverted()@references['air']['Lance_Control']
for f in range(1,141):
 scene.frame_set(f);bpy.context.view_layer.update();pose={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
 assert all(math.isfinite(v) for m in pose.values() for row in m for v in row)
 if f in checks:errors[f]=max(abs(pose[n][i][j]-references[checks[f]][n][i][j]) for n in pose for i in range(4) for j in range(4))
 min_upright=min(min_upright,pose['Head'].translation.z-pose['Pelvis'].translation.z)
 assert max(pose[n].translation.z for n in ('Foot_L','Foot_R'))<pose['Head'].translation.z
 if f in (20,40,56,72):
  grip=pose['Hand_R'].inverted()@pose['Lance_Control'];grip_error=max(grip_error,max(abs(grip[i][j]-air_grip[i][j]) for i in range(4) for j in range(4)))
 if previous:steps.append((max((pose[n].translation-previous[n].translation).length for n in pose),f))
 previous=pose;height.append(bpy.data.objects['PREVIEW_Jump_Travel'].location.z)
 weapon=bpy.data.objects['Weapon_Cutlass'];target=rig.matrix_world@pose['Lance_Control']
 assert max(abs(weapon.matrix_world[i][j]-target[i][j]) for i in range(4) for j in range(4))<1e-4
assert max(errors.values())<1e-4,errors
assert min_upright>.5,min_upright
assert grip_error<1e-4,grip_error
assert max(steps)[0]<.4,max(steps)
assert abs(max(height)-2.4)<1e-5 and height[0]==0 and height[-1]==0
# Independent source comparison: the approved attack, jump strike, idle, and all
# other existing clips, native mesh vertices/UVs/rest skeleton are unchanged.
def signature(a):return [(fc.data_path,fc.array_index,[(tuple(k.co),k.interpolation,tuple(k.handle_left),tuple(k.handle_right)) for k in fc.keyframe_points]) for l in a.layers for s in l.strips for bag in s.channelbags for fc in bag.fcurves]
with bpy.data.libraries.load(record['source']) as (src,dst):
 names=[n for n in src.actions if n!='02_Jump'];dst.actions=names[:]
 dst.objects=['Skin','Hair_Normal','Costume_dragoon','Weapon_Cutlass_Geometry','Reference_Rig']
for name,act in zip(names,dst.actions):
 assert signature(act)==signature(bpy.data.actions[name]),name
 bpy.data.actions.remove(act)
for obj in dst.objects:
 name=obj.name.rsplit('.',1)[0];current=bpy.data.objects[name]
 if obj.type=='MESH':
  assert [tuple(v.co) for v in obj.data.vertices]==[tuple(v.co) for v in current.data.vertices]
  assert [[tuple(u.uv) for u in l.data] for l in obj.data.uv_layers]==[[tuple(u.uv) for u in l.data] for l in current.data.uv_layers]
 else:
  for b in obj.data.bones:assert b.matrix_local==current.data.bones[b.name].matrix_local
 bpy.data.objects.remove(obj,do_unlink=True)
report={'saved_file_verified':True,'frames_checked':140,'exact_approved_pose_errors':errors,'upright_head_over_pelvis_min_m':min_upright,'max_bone_step_m':max(steps)[0],'air_and_push_hand_grip_error':grip_error,'approved_jump_strike_and_other_clips_unchanged':True,'native_mesh_uv_rest_bones_unchanged':True,'duration_seconds':139/60,'has_downward_dive':False}
(folder/'regular_jump_saved_verification.json').write_text(json.dumps(report,indent=2)+'\n');print('REGULAR_JUMP_SAVED_VERIFIED',json.dumps(report))
if '--render' in __import__('sys').argv:
 if bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
 for obj in list(scene.objects):
  if obj.type in {'LIGHT','CAMERA'}:bpy.data.objects.remove(obj,do_unlink=True)
 cd=bpy.data.cameras.new('Jump_Preview');camera=bpy.data.objects.new('Jump_Preview',cd);scene.collection.objects.link(camera)
 camera.location=(7,-3.2,4.8);camera.rotation_euler=(Vector((0,-.3,2.7))-camera.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=8.;scene.camera=camera
 scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.16,.21,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
 for loc,power,size in [((3,-5,8),700,5),((-4,-2,6),500,4),((1,4,8),700,3)]:
  ld=bpy.data.lights.new('Jump_Light','AREA');ld.energy=power;ld.size=size
  light=bpy.data.objects.new('Jump_Light',ld);scene.collection.objects.link(light);light.location=loc;light.rotation_euler=(Vector((0,0,2.4))-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12;scene.cycles.max_bounces=3
 scene.render.resolution_x=480;scene.render.resolution_y=480;scene.render.resolution_percentage=100;scene.render.film_transparent=False
 for f in (1,20,40,56,72,84,98,120,140):
  scene.frame_set(f);scene.render.filepath=str(folder/('regular_jump_preview_%03d.png'%f));bpy.ops.render.render(write_still=True)
