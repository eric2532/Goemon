"""One-time preparation from existing editable meadow foliage and Cedar Pass bamboo.
Edit the resulting .blend files and use tools/export_blender.py for later changes.
"""
import hashlib
import json
import math
from pathlib import Path
import random
import runpy

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / 'assets/blender/environments/wind_meadow'
MASTER = DIR / 'broadleaf_tree.blend'
BAMBOO = ROOT / 'assets/models/cedar_pass/bamboo_cluster.glb'
NAMES = ['cedar_tree', 'pine_tree', 'sakura_tree', 'bamboo_cluster']
assert all(not (DIR / (name + '.blend')).exists() for name in NAMES), 'Edit existing variants; do not regenerate over artist edits.'
protected = [MASTER, DIR / 'leafy_shrub.blend', ROOT / 'assets/models/environments/wind_meadow/broadleaf_tree.glb', BAMBOO]
before = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}


def color(value):
    values = [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values) + (1,)


def recolor(attribute, low, high):
    lo, hi = color(low), color(high)
    luminance = [sum(c * w for c, w in zip(item.color[:3], (.2, .7, .1))) for item in attribute.data]
    minimum, maximum = min(luminance), max(luminance)
    for item, light in zip(attribute.data, luminance):
        shade = .2 + .8 * ((light - minimum) / max(.001, maximum - minimum)) ** .7
        item.color = tuple(a * (1 - shade) + b * shade for a, b in zip(lo, hi))


report = {'protected_before': before, 'variants': []}
for name in NAMES:
    if name == 'bamboo_cluster':
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(BAMBOO))
        for obj in bpy.context.scene.objects:
            if obj.type != 'MESH':
                continue
            obj.name = 'Body'
            attribute = obj.data.color_attributes.active_color
            assert attribute, 'Bamboo retains its baked vertex-color contract'
            recolor(attribute, '3b6941', 'a2b66b')
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.remove_doubles(threshold=.000001);bpy.ops.object.mode_set(mode='OBJECT')
            for polygon in obj.data.polygons:
                polygon.use_smooth = True
            if obj.data.has_custom_normals:
                obj.data.normals_split_custom_set([(0, 0, 0)] * len(obj.data.loops))
    else:
        bpy.ops.wm.open_mainfile(filepath=str(MASTER))
        body = bpy.data.objects['Body']
        canopy = bpy.data.objects['Canopy']
        original_counts = [(len(o.data.vertices), len(o.data.polygons)) for o in (body, canopy)]
        for obj in (body, canopy):
            obj.data = obj.data.copy()
            for slot in obj.material_slots:
                slot.material = slot.material.copy()
            obj['reused_source'] = str(MASTER.relative_to(ROOT))
        for vertex in body.data.vertices:
            vertex.co.x *= .65 if name == 'cedar_tree' else .95
            vertex.co.y *= .65 if name == 'cedar_tree' else .95
            vertex.co.z *= 1.4 if name == 'cedar_tree' else 1.1
        for polygon in body.data.polygons:
            polygon.use_smooth = len(polygon.vertices) == 4
        rng = random.Random(301026)
        assert len(canopy.data.vertices) % 4 == 0, 'Reuse each existing leaf card intact'
        for start in range(0, len(canopy.data.vertices), 4):
            leaves = list(canopy.data.vertices[start:start + 4])
            center = sum((v.co for v in leaves), Vector()) / 4
            if name == 'cedar_tree':
                height = 3.1 + 6.2 * rng.random() ** 1.4
                u = (height - 3.1) / 6.2
                radius = (2.8 * (1 - u) ** .75 + .08) * (.8 + .2 * math.sin(height * 3.0) ** 2)
                radius *= math.sqrt(rng.uniform(.25, 1))
                angle = math.atan2(center.y, center.x)
                target = Vector((math.cos(angle) * radius + u * .25, math.sin(angle) * radius, height))
            elif name == 'pine_tree':
                target = Vector((center.x * 1.13 + .25, center.y * .95, 4.5 + (center.z - 3.68) * .5))
            else:
                target = Vector((center.x * 1.12, center.y * 1.08, 3.9 + (center.z - 3.68) * .7))
            for vertex in leaves:
                vertex.co = target + (vertex.co - center)
        palettes = {'cedar_tree': ('315c42', '8eb567'), 'pine_tree': ('365f46', 'a1b875'), 'sakura_tree': ('a46d7c', 'f3ded1')}
        recolor(canopy.data.color_attributes['Color'], *palettes[name])
        assert original_counts == [(len(o.data.vertices), len(o.data.polygons)) for o in (body, canopy)], 'No leaf duplication or decimation'
        canopy.data.update();body.data.update()
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1
    bpy.context.scene['style_reference'] = 'Breath of the Wild: natural palette, organic silhouettes, soft wrapped light; original meadow geometry'
    bpy.context.scene['preparation_tool'] = 'tools/prepare_meadow_tree_variants.py (initial preparation only)'
    bpy.ops.wm.save_as_mainfile(filepath=str(DIR / (name + '.blend')))
    runpy.run_path(str(ROOT / 'tools/export_blender.py'))
    report['variants'].append({'name': name, 'meshes': {o.name: {'vertices': len(o.data.vertices), 'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons)} for o in bpy.context.scene.objects if o.type == 'MESH'}})
assert before == {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}, 'Original meadow and Cedar Pass assets remain unchanged'
report['protected_after'] = before
out = ROOT / 'build/Other Files/Asset Toolkit/Map Catalog/tree-preparation.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, indent=2) + '\n')
print('MEADOW_TREE_PREPARATION_PASS', out)
