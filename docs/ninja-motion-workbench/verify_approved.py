"""Independently verify authored anchors, preserved sources and model changes."""
import bpy,json,hashlib,sys
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
ROOT=Path(__file__).resolve().parents[2]
FEATURE=ROOT/'build/Other Files/ninja-authored-poses-20261017'
sys.path.insert(0,str(ROOT/'tools'))
import build_ninja_weapon as design
DATA=json.loads((ROOT/'assets/animations/ninja_approved.json').read_text())
source=ROOT/DATA['source']
assert hashlib.sha256(source.read_bytes()).hexdigest()==DATA['source_sha256']
assert source.read_bytes()==(FEATURE/'before'/DATA['source']).read_bytes(),'User workbook was overwritten'
C=Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)));CI=C.inverted()
def unpack(v):return Matrix.LocRotScale(Vector(v[:3]),Quaternion((v[6],v[3],v[4],v[5])),Vector(v[7:10]))
bpy.ops.wm.open_mainfile(filepath=str(source));rig=bpy.data.objects['Reference_Rig'];worst=0
for action,source_frame,key,index in [('01_Idle',0,'idle',0),('03_Cross_Slash_RMB',0,'slash',0),('03_Cross_Slash_RMB',1,'slash',1)]:
 a=bpy.data.actions[action];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0];bpy.context.scene.frame_set(source_frame);bpy.context.view_layer.update()
 sample=DATA['clips'][key]['frames'][index]
 for name,v in zip(DATA['bones'],sample['bones']):
  bone=rig.pose.bones[name];expected=C@bone.matrix@CI;got=unpack(v);rest=C@bone.bone.matrix_local@CI
  got=got@rest.to_3x3().to_4x4()
  worst=max(worst,max(abs(got[i][j]-expected[i][j]) for i in range(4) for j in range(4)))
 for side,control in [('right','Blade_Control'),('left','Offhand_Control')]:
  expected=C@rig.pose.bones[control].matrix@CI;got=unpack(sample['weapons'][side])
  worst=max(worst,max(abs(got[i][j]-expected[i][j]) for i in range(4) for j in range(4)))
# Quaternion/TRS packing drops only the template's tiny floating-point shear.
assert worst<.00002,worst
mesh_matrix=bpy.data.objects['Weapon_Cutlass_Geometry'].matrix_basis.copy()
rest={b.name:[list(b.head_local),list(b.tail_local)] for b in rig.data.bones if b.name in DATA['bones']}
original=FEATURE/'before/assets/blender/characters/goemon_cosplay/ninja.blend'
bpy.ops.wm.open_mainfile(filepath=str(original));before=design.protected_state();original_mesh=bpy.data.objects['Weapon_Cutlass_Geometry'];vertices=[tuple(v.co) for v in original_mesh.data.vertices]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/blender/characters/goemon_cosplay/ninja.blend'))
assert design.protected_state()==before,'Non-weapon object changed'
mesh=bpy.data.objects['Weapon_Cutlass_Geometry'];assert [tuple(v.co) for v in mesh.data.vertices]==vertices
assert max(abs(mesh.matrix_basis[i][j]-mesh_matrix[i][j]) for i in range(4) for j in range(4))<1e-6
for b in bpy.data.objects['Reference_Rig'].data.bones:assert [list(b.head_local),list(b.tail_local)]==rest[b.name]
assert any((C@mesh.matrix_basis@v.co-Vector(DATA['weapon_tip'])).length<1e-5 for v in mesh.data.vertices),'Tip must be a real mesh vertex'
result={'authored_anchor_matrix_error':worst,'workbook_byte_identical':True,'non_weapon_objects_unchanged':True,'mesh_vertices_unchanged':True,'user_weapon_transform_preserved':True,'original_rest_bones_preserved':True,'weapon_tip_is_real_vertex':True}
(FEATURE/'asset-verification.json').write_text(json.dumps(result,indent=2)+'\n');print('NINJA_AUTHORED_ASSET_OK',result)
