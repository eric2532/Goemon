"""Export the approved Blender flip without changing its source."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Matrix
root=Path(__file__).resolve().parents[1]
source=root/'docs/explorer-motion-workbench/Explorer_Double_Jump_Preview.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects['Reference_Rig'];action=bpy.data.actions['04_Double_Jump_Flip_Preview']
rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
controls={'R':'Right_Blade_Control','L':'Left_Blade_Control'}
names=[b.name for b in rig.data.bones if b.name not in controls.values()]
c=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)));ci=c.inverted()
def pack(m):
    q=m.to_quaternion();return [*m.translation,q.x,q.y,q.z,q.w,*m.to_scale()]
frames=[]
for f in range(1,50):
    bpy.context.scene.frame_set(f);bpy.context.view_layer.update();bones=[]
    for name in names:
        pb=rig.pose.bones[name];m=c@pb.matrix@ci;rest=c@pb.bone.matrix_local@ci
        delta=m.copy();delta.translation=(0,0,0)
        delta=delta@rest.to_3x3().inverted().to_4x4();delta.translation=m.translation;bones.append(pack(delta))
    grips={s:pack(c@(rig.pose.bones['Hand_'+s].matrix.inverted()@rig.pose.bones[control].matrix)@ci) for s,control in controls.items()}
    frames.append({'bones':bones,'grips':grips})
out=root/'assets/animations/tucked_double_jump.json'
out.write_text(json.dumps({'source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'fps':60,'duration':.8,'bones':names,'frames':frames},separators=(',',':'))+'\n')
print('TUCKED_DOUBLE_JUMP_EXPORT_OK',out,len(frames))
