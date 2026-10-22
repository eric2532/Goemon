"""Read the saved approved pose without evaluating/changing its animation."""
import bpy,json
from pathlib import Path
folder=Path(__file__).resolve().parent
record=json.loads((folder/'approved_hit_source.json').read_text())
snapshot=Path(record['file'])
with bpy.data.libraries.load(str(snapshot)) as (src,dst):dst.objects=['Reference_Rig']
raw=dst.objects[0]
contact={'bones':{pb.name:[list(row) for row in pb.matrix] for pb in raw.pose.bones},'basis':{pb.name:[list(row) for row in pb.matrix_basis] for pb in raw.pose.bones}}
bpy.ops.wm.open_mainfile(filepath=str(snapshot),load_ui=False)
rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
assert rig.animation_data.action.name=='03_Lance_Thrust_1'
# Capture the keyed frame-one start only after the approved pose is secure.
scene.frame_set(1);bpy.context.view_layer.update()
start={'bones':{pb.name:[list(row) for row in pb.matrix] for pb in rig.pose.bones},'basis':{pb.name:[list(row) for row in pb.matrix_basis] for pb in rig.pose.bones}}
output={'source_frame':2,'snapshot':str(snapshot),'action':'03_Lance_Thrust_1','fps':60,'start':start,'contact':contact}
(folder/'approved_strike_inputs.json').write_text(json.dumps(output,indent=2)+'\n')
for label,pose in [('start',start),('approved_hit',contact)]:
 print('APPROVED_STRIKE_INPUT',label,{name:[round(pose['bones'][name][i][3],4) for i in range(3)] for name in ['Hand_R','Foot_L','Foot_R','Lance_Control']})
