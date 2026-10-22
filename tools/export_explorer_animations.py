"""Sample Explorer's approved workbook without modifying any Blender assets."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Matrix
root=Path(__file__).resolve().parents[1]
source=root/'docs/explorer-motion-workbench/Explorer_Animation_Workbench.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects['Reference_Rig']
controls={'right':'Right_Blade_Control','left':'Left_Blade_Control'}
names=[b.name for b in rig.data.bones if b.name not in controls.values()]
c=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)));ci=c.inverted()
def pack(m):
    q=m.to_quaternion();return [*m.translation,q.x,q.y,q.z,q.w,*m.to_scale()]
clips={}
for key,name,end,period in [('idle','01_Idle',217,216),('run','02_Run',41,40),('jump','03_Jump',91,0)]:
    action=bpy.data.actions[name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    for track in rig.animation_data.nla_tracks:track.mute=True
    frames=[]
    for f in range(1,end+1):
        bpy.context.scene.frame_set(f);bpy.context.view_layer.update()
        bones=[]
        for n in names:
            pb=rig.pose.bones[n];m=c@pb.matrix@ci;rest=c@pb.bone.matrix_local@ci
            delta=m.copy();delta.translation=(0,0,0)
            delta=delta@rest.to_3x3().inverted().to_4x4();delta.translation=m.translation
            bones.append(pack(delta))
        frames.append({'bones':bones,'weapons':{side:pack(c@rig.pose.bones[control].matrix@ci) for side,control in controls.items()}})
    clips[key]={'action':name,'fps':60,'period_frames':period,'frames':frames}
output=root/'assets/animations/explorer_approved.json'
output.write_text(json.dumps({'source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'bones':names,'clips':clips},separators=(',',':'))+'\n')
print('EXPLORER_EXPORT_OK',output,{k:len(v['frames']) for k,v in clips.items()})
