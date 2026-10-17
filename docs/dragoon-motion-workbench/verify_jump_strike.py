import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(__file__).resolve().parent
record=json.loads((folder/'jump_strike_timing.json').read_text());inputs=json.loads((folder/'jump_pose_inputs.json').read_text())
scene=bpy.context.scene;rig=bpy.data.objects['Reference_Rig'];act=rig.animation_data.action
assert act.name=='06_Azure_Leap' and scene.frame_start==1 and scene.frame_end==228 and scene.render.fps==60
refs={label:{n:Matrix(m) for n,m in inputs['poses'][str(i)]['bones'].items()} for i,label in enumerate(('crouch','airborne','dive','landing'))}
act_saved=act
rig.animation_data.action=bpy.data.actions['00_Idle_Approved_Base'];rig.animation_data.action_slot=rig.animation_data.action.slots[0]
scene.frame_set(1);bpy.context.view_layer.update();refs['idle']={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
rig.animation_data.action=act_saved;rig.animation_data.action_slot=act_saved.slots[0]
checks={1:'crouch',12:'crouch',48:'airborne',84:'airborne',114:'dive',150:'dive',180:'landing',192:'landing',228:'idle'}
errors={};max_delta=0.;previous=None;heights=[];steps=[]
for f in range(1,229):
 scene.frame_set(f);bpy.context.view_layer.update();pose={pb.name:pb.matrix.copy() for pb in rig.pose.bones}
 assert all(math.isfinite(x) for m in pose.values() for row in m for x in row)
 if f in checks:
  ref=refs[checks[f]];errors[str(f)]=max(abs(pose[n][i][j]-ref[n][i][j]) for n in ref for i in range(4) for j in range(4))
 if 48<=f<=84 or 114<=f<=150 or 180<=f<=192:
  label='airborne' if f<=84 else 'dive' if f<=150 else 'landing';ref=refs[label]
  assert max(abs(pose[n][i][j]-ref[n][i][j]) for n in ref for i in range(4) for j in range(4))<1e-4
 if previous:
  ds=sorted([((pose[n].translation-previous[n].translation).length,n) for n in pose],reverse=True)
  steps.append((ds[0][0],f,ds[0][1]));max_delta=max(max_delta,ds[0][0])
 previous=pose
 height=bpy.data.objects['PREVIEW_Jump_Travel'].location.z;heights.append(height)
 # The weapon constraint still follows its animated control while both inherit preview travel.
 weapon=bpy.data.objects['Weapon_Cutlass'];target=rig.matrix_world@pose['Lance_Control']
 assert max(abs(weapon.matrix_world[i][j]-target[i][j]) for i in range(4) for j in range(4))<1e-4
assert max(errors.values())<1e-4,errors
assert abs(max(heights)-2.5)<1e-5 and heights[0]==0 and heights[-1]==0
print('LARGEST_STEPS',sorted(steps,reverse=True)[:12])
assert max_delta<.3,max_delta
# Compare original saved clips and native mesh/UV/rest skeleton data independently.
def signature(a):return [(fc.data_path,fc.array_index,[(tuple(k.co),k.interpolation,tuple(k.handle_left),tuple(k.handle_right)) for k in fc.keyframe_points]) for l in a.layers for s in l.strips for bag in s.channelbags for fc in bag.fcurves]
with bpy.data.libraries.load(record['source']) as (src,dst):
 names=[n for n in src.actions if n!='06_Azure_Leap'];dst.actions=names[:]
 dst.objects=['Skin','Hair_Normal','Costume_dragoon','Weapon_Cutlass_Geometry','Reference_Rig']
for n,a in zip(names,dst.actions):
 assert signature(a)==signature(bpy.data.actions[n]),n
 bpy.data.actions.remove(a)
for obj in dst.objects:
 name=obj.name.rsplit('.',1)[0];current=bpy.data.objects[name]
 if obj.type=='MESH':
  assert [tuple(v.co) for v in obj.data.vertices]==[tuple(v.co) for v in current.data.vertices]
  assert [[tuple(u.uv) for u in l.data] for l in obj.data.uv_layers]==[[tuple(u.uv) for u in l.data] for l in current.data.uv_layers]
 else:
  for b in obj.data.bones:assert b.matrix_local==current.data.bones[b.name].matrix_local
 bpy.data.objects.remove(obj,do_unlink=True)
report={'saved_file_verified':True,'frames_checked':228,'exact_pose_errors':errors,'max_bone_step_m':max_delta,'all_other_clips_unchanged':True,'native_mesh_uv_rest_bones_unchanged':True,'preview_height_m':max(heights),'duration_seconds':227/60}
(folder/'jump_strike_saved_verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('JUMP_STRIKE_SAVED_VERIFIED',json.dumps(report))
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
 scene.render.resolution_x=480;scene.render.resolution_y=480;scene.render.resolution_percentage=100
 frames=sorted(set(range(1,229,6))|{12,48,84,99,114,150,180,192,228})
 for f in frames:
  scene.frame_set(f);scene.render.filepath=str(folder/('jump_preview_%03d.png'%f));bpy.ops.render.render(write_still=True)
 (folder/'jump_preview_frames.json').write_text(json.dumps(frames))
