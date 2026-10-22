import bpy,json,datetime
from mathutils import Matrix
from pathlib import Path
folder=Path('/Users/eric/Desktop/Projects_Codex/Sonic/docs/dragoon-motion-workbench')
scene=bpy.context.scene;rig=bpy.data.objects['Reference_Rig']
assert rig.animation_data.action.name=='03_Lance_Thrust_1'
recovered=json.loads((folder/'stored_pose_recovery.json').read_text())[0]
# The saved file retains the user's unkeyed FK pose even though evaluating
# its animation replaces it. Restore those stored transforms directly.
for pb in rig.pose.bones:pb.matrix_basis=Matrix(recovered['basis'][pb.name])
bpy.context.view_layer.update()
contact_basis={pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones}
def capture():return {'bones':{pb.name:[list(row) for row in pb.matrix] for pb in rig.pose.bones},'basis':{pb.name:[list(row) for row in pb.matrix_basis] for pb in rig.pose.bones},'weapon_world':[list(row) for row in bpy.data.objects['Weapon_Cutlass'].matrix_world]}
contact=capture()
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
snapshot=folder/('Dragoon_Recovered_Poke_'+stamp+'.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(snapshot),copy=True)
scene.frame_set(1);bpy.context.view_layer.update();start=capture()
scene.frame_set(2)
for pb in rig.pose.bones:pb.matrix_basis=contact_basis[pb.name]
bpy.context.view_layer.update()
output={'source_frame':2,'snapshot':str(snapshot),'recovered_from':recovered['source'],'action':'03_Lance_Thrust_1','fps':60,'start':start,'contact':contact}
(folder/'strike_pose_inputs.json').write_text(json.dumps(output,indent=2)+'\n')
for area in bpy.context.screen.areas:
    if area.type=='CONSOLE':
        area.type='DOPESHEET_EDITOR' if area.y<100 else 'VIEW_3D'
        if area.type=='DOPESHEET_EDITOR':area.spaces.active.mode='ACTION'
print('RECOVERED_STRIKE_INPUTS_OK',str(snapshot))
