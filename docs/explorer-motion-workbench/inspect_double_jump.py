import bpy,json,datetime
from pathlib import Path
folder=Path('/Users/eric/Desktop/Projects_Codex/Sonic/docs/explorer-motion-workbench')
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
snapshot=folder/('Explorer_Before_Double_Jump_'+stamp+'.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(snapshot),copy=True)
def matrix(m):return [list(row) for row in m]
report={'snapshot':str(snapshot),'frame':scene.frame_current,'action':rig.animation_data.action.name,'rig_world':matrix(rig.matrix_world),'bones':{p.name:{'parent':p.parent.name if p.parent else None,'rest':matrix(p.bone.matrix_local),'pose':matrix(p.matrix),'basis':matrix(p.matrix_basis)} for p in rig.pose.bones},'areas':[(a.type,a.width,a.height) for a in bpy.context.screen.areas]}
(folder/'double_jump_initial.json').write_text(json.dumps(report,indent=2))
print('DOUBLE_JUMP_SNAPSHOT',str(snapshot))
