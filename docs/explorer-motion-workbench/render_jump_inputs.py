import bpy,json
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(__file__).resolve().parent
inputs=json.loads((folder/'jump_user_inputs.json').read_text())
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
rig.animation_data.action=None
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
for name,pose in [('launch_frame1',inputs['poses']['1']),('air_current',inputs['live_pose'])]:
    for pb in rig.pose.bones:pb.matrix_basis=Matrix(pose['basis'][pb.name])
    bpy.context.view_layer.update()
    scene.render.filepath=str(folder/('jump_input_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
