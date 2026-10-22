"""Export fitted equipment from the saved ROM Blender pilot without changing it.

The game already evaluates the exact original body/motion archive. Only fitted
costume skinning, pipe geometry and grip/tip metadata need a glTF conversion.
"""
from pathlib import Path
import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[1]

bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'assets/blender/characters/rom_goemon_base/master_thief.blend'))
rig = bpy.data.objects['ROM_Goemon_Rig']
rig.animation_data_clear()
for pose in rig.pose.bones:
    pose.matrix_basis = Matrix.Identity(4)
costume = bpy.data.objects['MasterThief_Costume']
weapon = bpy.data.objects['MasterThief_Weapon']
values = weapon['rom_grip_frame']
grip_frame = Matrix(tuple(tuple(values[row * 4 + column] for column in range(4)) for row in range(4)))
# Keep the pipe rigid with a real wrist pivot, so Grand Smoke can enlarge it
# about the hand without scaling the forearm or displacing its grip.
weapon.modifiers.clear()
weapon.vertex_groups.clear()
for vertex in weapon.data.vertices:vertex.co = grip_frame.inverted() @ vertex.co
weapon.matrix_basis = grip_frame
tip = max((v.co.copy() for v in weapon.data.vertices), key=lambda p:p.length_squared)
weapon['contact_axis'] = [tip.x, tip.z, -tip.y]  # Blender -> glTF/Godot axes.
weapon['rom_hold_axis'] = [0, 1, 0]  # Canonical native shaft +Z in glTF axes.
weapon['source_blender'] = 'assets/blender/characters/rom_goemon_base/master_thief.blend'
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig, costume, weapon]:
    obj.hide_set(False)
    obj.select_set(True)
output = ROOT / 'assets/models/characters/rom_goemon_base/master_thief_equipment.glb'
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB',
    use_selection=True, export_cameras=False, export_lights=False,
    export_animations=False, export_skins=True, export_extras=True,
    export_yup=True, export_apply=False)
print('ROM_MASTER_THIEF_EQUIPMENT_EXPORTED', output)
