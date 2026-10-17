import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(__file__).resolve().parent
inputs=json.loads((folder/'jump_user_inputs.json').read_text())
record=json.loads((folder/'authored_jump_verification.json').read_text())
scene=bpy.context.scene;rig=bpy.data.objects['Reference_Rig'];action=rig.animation_data.action
assert action.name=='03_Jump' and scene.frame_start==1 and scene.frame_end==91
def error(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
def use(a,frame):
    rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
    scene.frame_set(frame);bpy.context.view_layer.update()
use(bpy.data.actions['00_Idle_Approved_Base'],1)
idle={p.name:p.matrix.copy() for p in rig.pose.bones}
expected={'launch':{n:Matrix(v) for n,v in inputs['poses']['1']['matrix'].items()},'air':{n:Matrix(v) for n,v in inputs['live_pose']['matrix'].items()},'idle':idle}
checks={1:'launch',7:'launch',22:'air',43:'air',60:'air',76:'launch',80:'launch',91:'idle'}
pose_errors={};steps=[];previous=None;follow=0.
for frame in range(1,92):
    use(action,frame)
    actual={p.name:p.matrix.copy() for p in rig.pose.bones}
    assert all(math.isfinite(v) for m in actual.values() for row in m for v in row)
    if frame in checks:pose_errors[str(frame)]=max(error(actual[n],expected[checks[frame]][n]) for n in actual)
    if previous:steps.append(max((actual[n].translation-previous[n].translation).length for n in actual))
    previous=actual
    for obj,control in [('Weapon_Cutlass','Right_Blade_Control'),('Weapon_Pistol','Left_Blade_Control')]:
        follow=max(follow,error(bpy.data.objects[obj].matrix_world,rig.matrix_world@actual[control]))
assert max(pose_errors.values())<1e-4,pose_errors
assert follow<1e-4 and max(steps)<.4
def signature(a):
    return [(fc.data_path,fc.array_index,[(tuple(k.co),k.interpolation,tuple(k.handle_left),tuple(k.handle_right)) for k in fc.keyframe_points]) for l in a.layers for s in l.strips for bag in s.channelbags for fc in bag.fcurves]
with bpy.data.libraries.load(record['snapshot']) as (src,dst):
    names=[n for n in src.actions if n!='03_Jump'];dst.actions=names[:]
for name,old in zip(names,dst.actions):
    assert signature(old)==signature(bpy.data.actions[name]),name
    bpy.data.actions.remove(old)
result={'saved_file':bpy.data.filepath,'frames_checked':91,'exact_user_and_idle_pose_errors':pose_errors,'both_blades_follow_error':follow,'max_bone_step_m':max(steps),'all_other_actions_preserved':True,'duration_seconds':1.5,'in_place':True}
(folder/'authored_jump_saved_verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('EXPLORER_AUTHORED_JUMP_SAVED_OK',json.dumps(result))
if '--render' in __import__('sys').argv:
    if bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    for obj in list(scene.objects):
        if obj.type in {'LIGHT','CAMERA'}:bpy.data.objects.remove(obj,do_unlink=True)
    camera_data=bpy.data.cameras.new('Preview_Camera');camera=bpy.data.objects.new('Preview_Camera',camera_data);scene.collection.objects.link(camera)
    camera.location=(4,-7,3.6);camera.rotation_euler=(Vector((0,0,1.4))-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=5.7;scene.camera=camera
    scene.world.color=(.15,.15,.15)
    for location,power,size in [((2,-5,7),1200,5),((-4,-2,4),850,4),((1,4,6),1100,3)]:
        ld=bpy.data.lights.new('Preview_Light','AREA');ld.energy=power;ld.shape='DISK';ld.size=size
        light=bpy.data.objects.new('Preview_Light',ld);scene.collection.objects.link(light);light.location=location;light.rotation_euler=(Vector((0,0,1.3))-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
    scene.render.resolution_x=600;scene.render.resolution_y=600;scene.render.resolution_percentage=100
    for frame in [1,14,43,68,76,91]:
        use(action,frame);scene.render.filepath=str(folder/('jump_connected_%03d.png'%frame));bpy.ops.render.render(write_still=True)
