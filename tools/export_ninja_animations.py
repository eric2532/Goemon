"""Export approved Ninja anchors without changing the user's pose workbench.

Blender -b --python tools/export_ninja_animations.py
The original templates after frame 1 are deliberately not a slash timeline:
the user authored the start and finish on 0 and 1.
"""
import bpy, json, hashlib
from pathlib import Path
from mathutils import Matrix, Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'docs/ninja-motion-workbench/Ninja_Animation_Workbench.blend'
OUTPUT=ROOT/'assets/animations/ninja_approved.json'
C=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1))); CI=C.inverted()
def pack(m):
 q=m.to_quaternion();return [*m.translation,q.x,q.y,q.z,q.w,*m.to_scale()]
def export():
 bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
 rig=bpy.data.objects['Reference_Rig'];scene=bpy.context.scene
 controls={'right':'Blade_Control','left':'Offhand_Control'}
 names=[b.name for b in rig.data.bones if b.name not in controls.values()]
 mesh_matrix=bpy.data.objects['Weapon_Cutlass_Geometry'].matrix_basis.copy()
 def action(name):
  a=bpy.data.actions[name];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
  for track in rig.animation_data.nla_tracks:track.mute=True
 def frame(f):scene.frame_set(f);bpy.context.view_layer.update()
 def sample():
  body=[]
  for name in names:
   pb=rig.pose.bones[name];m=C@pb.matrix@CI;rest=C@pb.bone.matrix_local@CI
   delta=m.copy();delta.translation=(0,0,0)
   delta=delta@rest.to_3x3().inverted().to_4x4();delta.translation=m.translation
   body.append(pack(delta))
  return {'bones':body,'weapons':{side:pack(C@rig.pose.bones[n].matrix@CI) for side,n in controls.items()}}
 action('01_Idle');frame(0);approved={b.name:b.matrix_basis.copy() for b in rig.pose.bones};idle_anchor=sample()
 frame(1);baseline={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
 idle=[]
 for f in range(217):
  frame(f+1)
  raw={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
  for b in rig.pose.bones:b.matrix_basis=approved[b.name]@baseline[b.name].inverted()@raw[b.name]
  bpy.context.view_layer.update();idle.append(sample())
 # Exact authored pose at the loop seam, independent of template roundoff.
 idle[0]=idle_anchor;idle[-1]=idle_anchor
 action('03_Cross_Slash_RMB');slash=[]
 for f in [0,1]:frame(f);slash.append(sample())
 tip=(C@mesh_matrix@Vector((-.375,-.015,.806,1))).xyz
 data={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'bones':names,
       'weapon_mesh_transform_blender':[list(row) for row in mesh_matrix],'weapon_tip':list(tip),
       'clips':{'idle':{'action':'01_Idle','source_frames':[0],'fps':60,'period_frames':216,'frames':idle},
                'slash':{'action':'03_Cross_Slash_RMB','source_frames':[0,1],'fps':60,'period_frames':0,'frames':slash}}}
 OUTPUT.write_text(json.dumps(data,separators=(',',':'))+'\n')
 # Only the user's mesh-local size/orientation changes enter the live model.
 # The pose workbench's extra controls and posed skeleton never replace it.
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/blender/characters/goemon_cosplay/ninja.blend'))
 bpy.data.objects['Weapon_Cutlass_Geometry'].matrix_basis=mesh_matrix
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/characters/goemon_cosplay/ninja.blend'))
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/characters/goemon_cosplay/ninja.glb'),export_format='GLB',use_selection=True,export_animations=False,export_yup=True,export_skins=True,export_materials='EXPORT',export_extras=True)
 print('NINJA_APPROVED_EXPORT_OK',{'idle_frames':len(idle),'slash_source_frames':[0,1],'weapon_tip':list(tip)})
if __name__=='__main__':export()
