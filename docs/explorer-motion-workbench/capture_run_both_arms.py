"""Capture the unsaved live frame before touching animation evaluation."""
import bpy,json,datetime
from pathlib import Path
folder=Path('/Users/eric/Desktop/Projects_Codex/Sonic/docs/explorer-motion-workbench')
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
assert rig.animation_data.action.name=='02_Run' and scene.frame_current==0
assert not bpy.context.screen.is_animation_playing
bpy.context.view_layer.update()
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
snapshot=folder/('Explorer_Before_Both_Arms_Run_'+stamp+'.blend')
data={'frame':scene.frame_current,'action':rig.animation_data.action.name,'snapshot':str(snapshot),'rig_world':[list(r) for r in rig.matrix_world],'bones':{p.name:{'basis':[list(r) for r in p.matrix_basis],'matrix':[list(r) for r in p.matrix]} for p in rig.pose.bones},'weapons':{n:[list(r) for r in bpy.data.objects[n].matrix_world] for n in ['Weapon_Cutlass','Weapon_Pistol']}}
bpy.ops.wm.save_as_mainfile(filepath=str(snapshot),copy=True)
(folder/'run_both_arms_input.json').write_text(json.dumps(data,indent=2)+'\n')
print('RUN_BOTH_ARMS_CAPTURE_OK',snapshot)
