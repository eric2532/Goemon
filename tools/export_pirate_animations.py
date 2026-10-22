"""Read the approved workbench; export poses without changing the user's source."""
import bpy, json, hashlib
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'docs/pirate-motion-workbench/Pirate_Animation_Workbench.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
c=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)));ci=c.inverted()
def pack(m):
 q=m.to_quaternion();return [*m.translation,q.x,q.y,q.z,q.w,*m.to_scale()]
clips={};bounds={}
for key,scene_name,action_name,start,end in [
 ('idle','01 — Idle','01_Idle',0,0),
 ('jump','02 — Jump','02_Jump_Explorer',1,91),
 ('shot','03 — Gun Shot','03_Gun_Shot_User',0,24),
 ('slash','04 — Sword Slash','04_Three_Hit_Slash',0,72)]:
 sc=bpy.data.scenes[scene_name];bpy.context.window.scene=sc
 rig=next(o for o in sc.objects if o.type=='ARMATURE')
 action=bpy.data.actions[action_name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 names=[b.name for b in rig.data.bones if b.use_deform]
 assert len(names)==22
 for track in rig.animation_data.nla_tracks:track.mute=True
 frames=[]
 for f in range(start,end+1):
  sc.frame_set(f);bpy.context.view_layer.update();bones=[]
  for n in names:
   pb=rig.pose.bones[n];m=c@pb.matrix@ci;rest=c@pb.bone.matrix_local@ci
   delta=m.copy();delta.translation=(0,0,0);delta=delta@rest.to_3x3().inverted().to_4x4();delta.translation=m.translation
   bones.append(pack(delta))
  frames.append({'bones':bones,'weapons':{side:pack(c@rig.pose.bones[control].matrix@ci) for side,control in [('right','Sword_Control'),('left','Gun_Control')]}})
 clips[key]={'action':action_name,'fps':60,'start_frame':start,'end_frame':end,'frames':frames}
 if key=='idle':
  sword=next(o for o in sc.objects if o.name=='Weapon_Cutlass')
  blade=next(o for o in sword.children_recursive if o.name.startswith('Cutlass | swept forged blade'))
  tip=list(c.to_3x3()@(sword.matrix_world.inverted()@blade.matrix_world@blade.data.vertices[-1].co))
  deps=bpy.context.evaluated_depsgraph_get()
  for side,root_name,prefix in [('right','Weapon_Cutlass','Cutlass |'),('left','Weapon_Pistol','Flintlock |')]:
   weapon=bpy.data.objects[root_name];points=[]
   for ob in weapon.children_recursive:
    if ob.type not in ['MESH','CURVE'] or not ob.name.startswith(prefix):continue
    evaluated=ob.evaluated_get(deps);mesh=evaluated.to_mesh()
    transform=c@weapon.matrix_world.inverted()@ob.matrix_world
    points.extend([transform@v.co for v in mesh.vertices]);evaluated.to_mesh_clear()
   bounds[side]={'min':[min(v[i] for v in points) for i in range(3)],'max':[max(v[i] for v in points) for i in range(3)]}

output=ROOT/'assets/animations/pirate_approved.json'
output.write_text(json.dumps({'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'bones':names,'weapon_tip':tip,'weapon_bounds':bounds,'weapon_sizes':{'sword':2.2,'gun':1.8},'contacts':[13,29,48],'clips':clips},separators=(',',':'))+'\n')
actor=ROOT/'assets/rogue/scripts/actor.gd'
import re
actor.write_text(re.sub(r'"pirate": Vector3\([^\n]+', '"pirate": Vector3('+', '.join(f'{v:.9f}' for v in tip)+'),', actor.read_text(),count=1))
print('PIRATE_ANIMATIONS_EXPORTED', {k:len(v['frames']) for k,v in clips.items()},'tip',tip)
