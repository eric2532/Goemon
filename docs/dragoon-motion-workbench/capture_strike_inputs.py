"""Run in Blender's live console: preserve unkeyed contact pose FIRST."""
import bpy,json,datetime
from mathutils import Matrix
from pathlib import Path
folder=Path('/Users/eric/Desktop/Projects_Codex/Sonic/docs/dragoon-motion-workbench')
scene=bpy.context.scene;rig=bpy.data.objects['Reference_Rig']
assert rig.animation_data.action.name=='03_Lance_Thrust_1'
assert not bpy.context.screen.is_animation_playing
bpy.context.view_layer.update()
frame=scene.frame_current
basis={pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones}
def capture():
    return {'bones':{pb.name:[list(row) for row in pb.matrix] for pb in rig.pose.bones},'basis':{pb.name:[list(row) for row in pb.matrix_basis] for pb in rig.pose.bones},'weapon_world':[list(row) for row in bpy.data.objects['Weapon_Cutlass'].matrix_world]}
current_capture=capture()
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
snapshot=folder/('Dragoon_Before_Full_Strike_'+stamp+'.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(snapshot),copy=True)
if frame!=2:scene.frame_set(2);bpy.context.view_layer.update()
contact=current_capture if frame==2 else capture()
scene.frame_set(1);bpy.context.view_layer.update()
start=capture()
scene.frame_set(2)
for pb in rig.pose.bones:pb.matrix_basis=Matrix(contact['basis'][pb.name])
bpy.context.view_layer.update()
output={'source_frame':2,'live_frame_on_capture':frame,'live_pose':current_capture,'snapshot':str(snapshot),'action':'03_Lance_Thrust_1','fps':60,'start':start,'contact':contact}
(folder/'strike_pose_inputs.json').write_text(json.dumps(output,indent=2)+'\n')
for area in bpy.context.screen.areas:
    if area.type=='CONSOLE':
        area.type='DOPESHEET_EDITOR' if area.y<100 else 'VIEW_3D'
        if area.type=='DOPESHEET_EDITOR':area.spaces.active.mode='ACTION'
print('STRIKE_INPUTS_CAPTURED',str(snapshot),'contact_source_frame',frame)
