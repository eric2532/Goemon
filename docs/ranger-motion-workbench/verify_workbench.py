import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(__file__).resolve().parent
samples=json.loads((folder/'game_pose_samples.json').read_text());manifest=json.loads((folder/'actions.json').read_text())
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
c=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)));ci=c.inverted()
worst_position=0.;worst_rotation=0.;worst_bow=0.
for clip,meta in zip(samples['clips'],manifest):
    action=bpy.data.actions[clip['name']];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    assert action.use_fake_user and len(action.slots)==1
    for frame in meta['keyframes']:
        scene.frame_set(frame);bpy.context.view_layer.update()
        sample=clip['frames'][frame-1]
        for name,p in zip(samples['bones'],sample['bones']):
            pb=rig.pose.bones[name]
            expected=(ci@Matrix(p['delta'])@c)@pb.bone.matrix_local
            expected.translation=(ci@Vector((*p['position'],1))).xyz
            worst_position=max(worst_position,(pb.matrix.translation-expected.translation).length)
            worst_rotation=max(worst_rotation,pb.matrix.to_quaternion().rotation_difference(expected.to_quaternion()).angle)
        expected=rig.matrix_world@ci@Matrix(sample['bow'])@c
        actual=bpy.data.objects['Weapon_Cutlass'].matrix_world
        worst_bow=max(worst_bow,max(abs(actual[i][j]-expected[i][j]) for i in range(4) for j in range(4)))
    assert all(math.isfinite(x) for pb in rig.pose.bones for row in pb.matrix for x in row)
# Verify geometry, UVs, original bones against the user's preserved snapshot.
with bpy.data.libraries.load(str(folder.parents[1]/'assets/blender/characters/goemon_cosplay/ranger.blend')) as (src,dst):
    dst.objects=['Skin','Hair_Normal','Costume_ranger','Weapon_Cutlass_Geometry','Reference_Rig']
for original in dst.objects:
    current=bpy.data.objects[original.name.rsplit('.',1)[0]]
    if original.type=='MESH':
        assert [tuple(v.co) for v in original.data.vertices]==[tuple(v.co) for v in current.data.vertices]
        assert [[tuple(uv.uv) for uv in layer.data] for layer in original.data.uv_layers]==[[tuple(uv.uv) for uv in layer.data] for layer in current.data.uv_layers]
    else:
        for bone in original.data.bones:
            assert abs(bone.length-current.data.bones[bone.name].length)<1e-7
    bpy.data.objects.remove(original,do_unlink=True)
report={'actions':len(manifest),'original_bones':len(samples['bones']),'position_error_m':worst_position,'rotation_error_radians':worst_rotation,'bow_matrix_error':worst_bow,'geometry_uvs_bone_lengths_preserved':True}
print('RANGER_VERIFY',json.dumps(report))
assert worst_position<.0001 and worst_rotation<.002 and worst_bow<.0001
(folder/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
# A rendering check uses temporary scene objects and never saves the work file.
if '--render' in __import__('sys').argv:
    if bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    for o in list(scene.objects):
        if o.type in {'LIGHT','CAMERA'}:bpy.data.objects.remove(o,do_unlink=True)
    camera_data=bpy.data.cameras.new('Preview_Camera');camera=bpy.data.objects.new('Preview_Camera',camera_data);scene.collection.objects.link(camera)
    camera.location=(4,-7,3.6);camera.rotation_euler=(Vector((0,0,1.4))-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=5.7;scene.camera=camera
    scene.world.color=(.15,.15,.15)
    for location,power,size in [((2,-5,7),1200,5),((-4,-2,4),850,4),((1,4,6),1100,3)]:
        ld=bpy.data.lights.new('Preview_Light','AREA');ld.energy=power;ld.shape='DISK';ld.size=size
        light=bpy.data.objects.new('Preview_Light',ld);scene.collection.objects.link(light);light.location=location;light.rotation_euler=(Vector((0,0,1.3))-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
    scene.render.resolution_x=700;scene.render.resolution_y=700;scene.render.resolution_percentage=100
    for action_name,frame in [('01_Idle',1),('02_Run',11),('03_Jump',43)]:
        action=bpy.data.actions[action_name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0];scene.frame_set(frame)
        scene.render.filepath=str(folder/(action_name+'.png'));bpy.ops.render.render(write_still=True)
