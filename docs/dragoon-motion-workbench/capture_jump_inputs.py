import bpy,json,math
from pathlib import Path
from mathutils import Vector,Matrix
folder=Path(__file__).resolve().parent
source=json.loads((folder/'jump_source.json').read_text())['file']
with bpy.data.libraries.load(source) as (src,dst):dst.objects=['Reference_Rig']
raw=dst.objects[0]
raw_pose={'bones':{pb.name:[list(r) for r in pb.matrix] for pb in raw.pose.bones},'basis':{pb.name:[list(r) for r in pb.matrix_basis] for pb in raw.pose.bones}}
bpy.ops.wm.open_mainfile(filepath=source,load_ui=True)
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene;action=rig.animation_data.action
assert action.name=='06_Azure_Leap',action.name
curves=[fc for l in action.layers for s in l.strips for bag in s.channelbags for fc in bag.fcurves]
keys={str(f):sorted({fc.data_path.split('"')[1] for fc in curves if 'pose.bones[' in fc.data_path and any(abs(k.co.x-f)<.001 for k in fc.keyframe_points)}) for f in range(4)}
poses={}
for f in range(4):
 scene.frame_set(f);bpy.context.view_layer.update()
 poses[str(f)]={'bones':{pb.name:[list(r) for r in pb.matrix] for pb in rig.pose.bones},'basis':{pb.name:[list(r) for r in pb.matrix_basis] for pb in rig.pose.bones}}
raw_error=max(abs(raw_pose['basis'][n][i][j]-poses['3']['basis'][n][i][j]) for n in raw_pose['basis'] for i in range(4) for j in range(4))
poses['3']=raw_pose
record={'source':source,'action':action.name,'fps':scene.render.fps,'poses':poses,'raw_saved_pose':raw_pose,'raw_frame3_error':raw_error,'keyed_bones':keys}
(folder/'jump_pose_inputs.json').write_text(json.dumps(record,indent=2)+'\n')
print('JUMP_INPUTS',json.dumps({'raw_frame3_error':raw_error,'keys':keys,'positions':{f:{n:[round(p['bones'][n][i][3],3) for i in range(3)] for n in ('Root','Pelvis','Hand_R','Foot_L','Foot_R','Lance_Control')} for f,p in poses.items()}}))
if bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for obj in list(scene.objects):
 if obj.type in {'LIGHT','CAMERA'}:bpy.data.objects.remove(obj,do_unlink=True)
cd=bpy.data.cameras.new('Jump_Preview');camera=bpy.data.objects.new('Jump_Preview',cd);scene.collection.objects.link(camera)
camera.location=(6,-2.6,3.1);camera.rotation_euler=(Vector((0,-.4,1.35))-camera.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=5.7;scene.camera=camera
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.16,.21,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
for loc,power,size in [((3,-5,7),650,5),((-4,-2,4),450,4),((1,4,6),600,3)]:
 ld=bpy.data.lights.new('Jump_Light','AREA');ld.energy=power;ld.size=size
 light=bpy.data.objects.new('Jump_Light',ld);scene.collection.objects.link(light);light.location=loc;light.rotation_euler=(Vector((0,0,1.3))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12;scene.cycles.max_bounces=3
scene.render.resolution_x=640;scene.render.resolution_y=480;scene.render.resolution_percentage=100;scene.render.film_transparent=False
for frame in range(4):
 scene.frame_set(frame)
 if frame==3:
  rig.animation_data.action=None
  for pb in rig.pose.bones:pb.matrix_basis=Matrix(raw_pose['basis'][pb.name])
  bpy.context.view_layer.update()
 scene.render.filepath=str(folder/('jump_user_pose_%02d.png'%frame));bpy.ops.render.render(write_still=True)
