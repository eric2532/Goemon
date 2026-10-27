"""Export saved light-polish soldier masters without regenerating their geometry.

Blender --background --python tools/export_soldier_polish.py
"""
import hashlib
import json
from pathlib import Path
import struct

import bpy

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/blender/enemies/thirstquencher'
OUT = ROOT / 'assets/models/enemies/thirstquencher'
OUT.mkdir(parents=True, exist_ok=True)


def zero_based_ticks(path):
    # Recovered Blender actions begin on frame 1; runtime source ticks begin at 0.
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    binary = bytearray(raw[28 + size:])
    for index in {s['input'] for a in doc['animations'] for s in a['samplers']}:
        accessor = doc['accessors'][index]
        view = doc['bufferViews'][accessor['bufferView']]
        offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        values = struct.unpack_from('<' + 'f' * accessor['count'], binary, offset)
        assert abs(values[0] - 1 / 30) < 1e-6
        values = [(round(value * 30) - 1) / 30 for value in values]
        struct.pack_into('<' + 'f' * len(values), binary, offset, *values)
        accessor['min'], accessor['max'] = [min(values)], [max(values)]
    text = json.dumps(doc, separators=(',', ':')).encode()
    text += b' ' * (-len(text) % 4)
    path.write_bytes(struct.pack('<III', 0x46546c67, 2, 28 + len(text) + len(binary))
                     + struct.pack('<II', len(text), 0x4e4f534a) + text
                     + struct.pack('<II', len(binary), 0x004e4942) + binary)


report = []
for ident in (1, 2, 3):
    source = SOURCE / f'soldier_{ident}.blend'
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.context.scene
    assert scene.render.fps == 30
    meshes = [o for o in scene.objects if o.type == 'MESH']
    arm = next(o for o in scene.objects if o.type == 'ARMATURE')
    assert len(meshes) == 11 and len(arm.data.bones) == 12
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    for ob in meshes:
        world = ob.matrix_world.copy()
        ob.parent = None
        ob.matrix_world = world
        ob.select_set(True)
        assert len(ob.modifiers) == 1 and ob.modifiers[0].type == 'ARMATURE'
    path = OUT / f'soldier_{ident}.glb'
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format='GLB', use_selection=True,
        export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=False, export_anim_single_armature=True,
        export_anim_slide_to_zero=True, export_all_influences=False,
        export_skins=True, export_yup=True, export_extras=True,
        export_optimize_animation_size=False)
    zero_based_ticks(path)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before
    report.append({'variant': ident, 'source_sha256': before,
                   'glb_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT / 'provenance.json').write_text(json.dumps(report, indent=2) + '\n')
print('SOLDIER_POLISH_EXPORT_COMPLETE', json.dumps(report))
