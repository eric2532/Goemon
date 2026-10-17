import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(__file__).resolve().parent
inputs=json.loads((folder/'approved_strike_inputs.json').read_text())
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
assert rig.animation_data.action.name=='03_Lance_Thrust_1'
errors={}
for frame,expected in [(1,inputs['start']),(7,inputs['contact']),(8,inputs['contact']),(9,inputs['contact']),(23,inputs['start'])]:
 scene.frame_set(frame);bpy.context.view_layer.update()
 error=max(abs(pb.matrix[i][j]-expected['bones'][pb.name][i][j]) for pb in rig.pose.bones for i in range(4) for j in range(4))
 assert error<1e-4,(frame,error)
 errors[frame]=error
# Other clips and the character's editable geometry stay unchanged.
def action_signature(action):
 return [(fc.data_path,fc.array_index,[(tuple(k.co),k.interpolation,tuple(k.handle_left),tuple(k.handle_right)) for k in fc.keyframe_points]) for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
with bpy.data.libraries.load(inputs['snapshot']) as (src,dst):
 names=[name for name in src.actions if name!='03_Lance_Thrust_1']
 dst.actions=names[:]
 dst.objects=['Skin','Hair_Normal','Costume_dragoon','Weapon_Cutlass_Geometry','Reference_Rig']
for name,source in zip(names,dst.actions):
 assert action_signature(source)==action_signature(bpy.data.actions[name]),name
 bpy.data.actions.remove(source)
for original in dst.objects:
 name=original.name.rsplit('.',1)[0];current=bpy.data.objects[name]
 if original.type=='MESH':
  assert [tuple(v.co) for v in original.data.vertices]==[tuple(v.co) for v in current.data.vertices],name
  assert [[tuple(uv.uv) for uv in layer.data] for layer in original.data.uv_layers]==[[tuple(uv.uv) for uv in layer.data] for layer in current.data.uv_layers],name
 else:
  for bone in original.data.bones:assert abs(bone.length-current.data.bones[bone.name].length)<1e-7
 bpy.data.objects.remove(original,do_unlink=True)
report={'saved_file_verified':True,'pose_errors':errors,'other_clips_unchanged':True,'meshes_uvs_bone_lengths_unchanged':True,'approved_core_preserved':True}
(folder/'full_strike_saved_verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('FULL_STRIKE_SAVED_VERIFIED',json.dumps(report))
if '--render' in __import__('sys').argv:
 if bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
 for obj in list(scene.objects):
  if obj.type in {'LIGHT','CAMERA'}:bpy.data.objects.remove(obj,do_unlink=True)
 camera_data=bpy.data.cameras.new('Strike_Preview');camera=bpy.data.objects.new('Strike_Preview',camera_data);scene.collection.objects.link(camera)
 camera.location=(6,-2.7,3.3);camera.rotation_euler=(Vector((0,-.8,1.4))-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=6.6;scene.camera=camera
 scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.16,.21,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
 for loc,power,size in [((3,-5,7),650,5),((-4,-2,4),450,4),((1,4,6),600,3)]:
  ld=bpy.data.lights.new('Strike_Light','AREA');ld.energy=power;ld.size=size
  light=bpy.data.objects.new('Strike_Light',ld);scene.collection.objects.link(light);light.location=loc;light.rotation_euler=(Vector((0,0,1.3))-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=8;scene.cycles.max_bounces=3
 scene.render.resolution_x=560;scene.render.resolution_y=400;scene.render.resolution_percentage=100;scene.render.film_transparent=False
 for frame in (1,3,5,7,12,17):
  scene.frame_set(frame);scene.render.filepath=str(folder/('strike_preview_%02d.png'%frame));bpy.ops.render.render(write_still=True)
