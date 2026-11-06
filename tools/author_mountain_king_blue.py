"""Bake blue glow, armor and clothing into the saved Mountain King masters."""
import hashlib
import json
from pathlib import Path
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT.parent / 'Warcraft/assets/MountainKing'
OUT = ROOT / 'build/Other Files/Asset Toolkit/Mountain King'

def preserved():
    values = []
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            values.append([obj.name, [list(v.co) for v in obj.data.vertices],
                           [list(p.vertices) for p in obj.data.polygons],
                           [[list(u.uv) for u in layer.data] for layer in obj.data.uv_layers],
                           [[[g.group, g.weight] for g in v.groups] for v in obj.data.vertices]])
        elif obj.type == 'ARMATURE':
            values.append([obj.name, [[b.name, b.parent.name if b.parent else '',
                            [list(row) for row in b.matrix_local]] for b in obj.data.bones]])
    for action in bpy.data.actions:
        curves = []
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        curves.append([curve.data_path, curve.array_index,
                                       [[list(k.co), list(k.handle_left), list(k.handle_right), k.interpolation] for k in curve.keyframe_points]])
        values.append([action.name, action.frame_start, action.frame_end, curves])
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()

def blue_outfit(original):
    pixels = np.array(original.pixels[:], dtype=np.float32).reshape(original.size[1], original.size[0], 4)
    before = pixels.copy()
    if original.name.startswith('TeamColor'):
        pixels[:, :, :3] = np.array([.035, .25, .8])
    else:
        assert list(original.size) == [256, 256], 'Unexpected Mountain King atlas'
        y, x = np.indices((256, 256))
        y = 255 - y  # Atlas coordinates are measured from its top edge.
        # These authored atlas regions exclude the face/beard, skull and weapons.
        armor = ((x >= 156) & (y < 108)) | ((x >= 80) & (x < 180) & (y >= 100))
        rgb = pixels[:, :, :3]
        neutral = rgb.max(axis=2) - rgb.min(axis=2) < .18
        mask = armor & neutral
        rgb[mask] = rgb[mask].max(axis=1, keepdims=True) * np.array([.18, .48, .95])
        assert np.array_equal(pixels[~mask], before[~mask]), 'Unselected atlas pixels changed'
        assert np.count_nonzero(mask) > 1000
    assert np.array_equal(pixels[:, :, 3], before[:, :, 3]), 'Alpha changed'
    blue = bpy.data.images.new('MountainKing_BlueOutfit_' + original.name, width=original.size[0], height=original.size[1], alpha=True)
    blue.colorspace_settings.name = original.colorspace_settings.name
    blue.pixels.foreach_set(pixels.ravel())
    blue['mountain_king_blue_outfit'] = True
    blue['source_image'] = original.name
    blue.pack()
    return blue

reports = []
for name in ['MountainKing', 'MountainKing_Portrait']:
    path = PACKAGE / (name + '.blend')
    bpy.ops.wm.open_mainfile(filepath=str(path))
    before = preserved()
    model_name = bpy.context.scene['source_model'].removesuffix('.mdx')
    source = json.loads((ROOT.parent / 'Warcraft/work' / (model_name + '.mdx.json')).read_text())
    images = {}
    outfits = {}
    for material in bpy.data.materials:
        material_id = material.get('warcraft_material_id')
        if material_id is None:
            continue
        for node in material.node_tree.nodes:
            if node.type != 'TEX_IMAGE' or node.image is None:
                continue
            original = node.image
            if original.get('mountain_king_blue_outfit'):
                continue
            if original.name.startswith(('heromountainking', 'TeamColor')):
                if original.name not in outfits:
                    outfits[original.name] = blue_outfit(original)
                node.image = outfits[original.name]
                continue
            if source['Materials'][material_id]['Layers'][-1]['FilterMode'] not in [3, 4]:
                continue
            if original.get('mountain_king_blue'):
                continue
            if original.name not in images:
                pixels = np.array(original.pixels[:], dtype=np.float32).reshape(-1, 4)
                pixels[:, :3] = pixels[:, :3].max(axis=1, keepdims=True) * np.array([39/255, 141/255, 1])
                blue = bpy.data.images.new('MountainKing_BlueGlow', width=original.size[0], height=original.size[1], alpha=True)
                blue.colorspace_settings.name = original.colorspace_settings.name
                blue.pixels.foreach_set(pixels.ravel())
                blue['mountain_king_blue'] = True
                blue['source_image'] = original.name
                blue.pack()
                images[original.name] = blue
            node.image = images[original.name]
    bpy.context.scene['goemon_energy_color'] = '#278dff'
    bpy.context.scene['goemon_outfit_color'] = 'blue'
    assert preserved() == before, 'Geometry, UVs, weights, rig or animation changed'
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    bpy.context.scene.render.filepath = str(PACKAGE / (name + '-preview.png'))
    bpy.ops.render.render(write_still=True)
    reports.append({'master': str(path), 'protected_content_sha256': before,
                    'new_blue_images': len(images), 'new_outfit_images': len(outfits), 'master_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
(OUT / 'blue-master-preservation.json').write_text(json.dumps(reports, indent=2) + '\n')
print('MOUNTAIN_BLUE_MASTER_PRESERVED', json.dumps(reports))
