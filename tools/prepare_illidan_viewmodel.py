"""Export the saved Illidan FPS master without overwriting editable art.

Blender --background --python tools/prepare_illidan_viewmodel.py
"""
import bpy
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / 'assets/blender/characters/warcraft/illidan_hands.blend'
OUTPUT = ROOT / 'assets/models/characters/warcraft/demon-hunter/first_person.glb'
bpy.ops.wm.open_mainfile(filepath=str(MASTER))
assert {a.name for a in bpy.data.actions} == {'Stand Alternate', 'Attack Alternate'}
before = hashlib.sha256(MASTER.read_bytes()).hexdigest()
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format='GLB', export_animations=True,
    export_animation_mode='ACTIONS', export_skins=True, export_yup=True, export_apply=False,
    export_all_influences=False, export_force_sampling=True, export_frame_range=False,
    export_nla_strips=False, export_def_bones=True, export_negative_frame='SLIDE',
    export_vertex_color='ACTIVE')
assert hashlib.sha256(MASTER.read_bytes()).hexdigest() == before
print('ILLIDAN_HANDS_EXPORTED', OUTPUT)
