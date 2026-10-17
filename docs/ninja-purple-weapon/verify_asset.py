import bpy,importlib.util,json,hashlib
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('ninja_weapon',root/'tools/build_ninja_weapon.py');kit=importlib.util.module_from_spec(spec);spec.loader.exec_module(kit)
old=root/'build/Other Files/ninja-purple-weapon-20261017/before/assets/blender/characters/goemon_cosplay/ninja.blend'
bpy.ops.wm.open_mainfile(filepath=str(old));before=kit.protected_state();grip=bpy.data.objects['Weapon_Cutlass'].matrix_local.copy()
bpy.ops.wm.open_mainfile(filepath=str(kit.LIVE));after=kit.protected_state()
assert before==after,'Non-weapon data changed'
assert bpy.data.objects['Weapon_Cutlass'].matrix_local==grip
ob=bpy.data.objects['Weapon_Cutlass_Geometry'];ob.data.calc_loop_triangles()
assert any((v.co-kit.TIP).length<.00001 for v in ob.data.vertices)
assert len(ob.data.loop_triangles)<3000
materials=[m.name for m in ob.data.materials]
assert any('Purple_handle' in s for s in materials)
assert any('Satin_silver' in s for s in materials)
counts={'vertices':len(ob.data.vertices),'triangles':len(ob.data.loop_triangles),'material_slots':len(materials)}
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(kit.GLB))
weapon=bpy.data.objects['Weapon_Cutlass'];geometry=bpy.data.objects['Weapon_Cutlass_Geometry']
local=weapon.matrix_world.inverted()@geometry.matrix_world
assert min(((local@v.co)-kit.TIP).length for v in geometry.data.vertices)<.0001,'GLB tip differs from game axis'
assert any('Purple_handle' in m.name for m in geometry.data.materials)
assert bpy.data.objects.get('Skin') and bpy.data.objects.get('Hair_Normal')
result={'protected_object_count':len(before),'all_non_weapon_geometry_uv_weights_materials_and_bones_unchanged':True,'grip_transform_unchanged':True,'blade_tip_matches_existing_combat_axis':True,'glb_reimport_valid':True,'geometry':counts,'materials':materials,'editable_blend':str(kit.DOC/'ninja-purple-weapon.blend'),'live_blend':str(kit.LIVE),'live_glb':str(kit.GLB)}
(kit.DOC/'asset-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('NINJA_WEAPON_ASSET_VERIFIED',json.dumps(result))
