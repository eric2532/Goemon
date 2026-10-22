"""Export approved Dragoon poses; never modify the Blender source or model."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Matrix
root=Path(__file__).resolve().parents[1]
source=root/'docs/dragoon-motion-workbench/Dragoon_Regular_Jump.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects['Reference_Rig']
names=[b.name for b in rig.data.bones if b.name!='Lance_Control']
c=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
ci=c.inverted()
def pack(m):
 q=m.to_quaternion();return [*m.translation,q.x,q.y,q.z,q.w,*m.to_scale()]
clips={}
for key,name,end in [('idle','01_Idle',217),('attack','03_Lance_Thrust_1',34),('jump','02_Jump',140),('jump_strike','06_Azure_Leap',228)]:
 action=bpy.data.actions[name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 for track in rig.animation_data.nla_tracks:track.mute=True
 frames=[]
 for f in range(1,end+1):
  bpy.context.scene.frame_set(f);bpy.context.view_layer.update()
  bones=[]
  for n in names:
   pb=rig.pose.bones[n];m=c@pb.matrix@ci;rest=c@pb.bone.matrix_local@ci
   d=m.copy();d.translation=(0,0,0);d=d@rest.to_3x3().inverted().to_4x4();d.translation=m.translation
   bones.append(pack(d))
  frames.append({'bones':bones,'lance':pack(c@rig.pose.bones['Lance_Control'].matrix@ci)})
 clips[key]={'action':name,'fps':60,'frames':frames}
output=root/'assets/animations/dragoon_approved.json'
output.write_text(json.dumps({'source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'bones':names,'clips':clips},separators=(',',':'))+'\n')
print('DRAGOON_EXPORT_OK',output,{k:len(v['frames']) for k,v in clips.items()})
