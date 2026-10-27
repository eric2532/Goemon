"""One-time ruin authoring from saved Wind Meadow masters; never overwrites edits.

Blender --background --python tools/build_wind_meadow_ruins.py
After editing a ruin master, use tools/export_blender.py instead.
"""
import bmesh
import bpy
import hashlib
import math
from mathutils import Vector
from pathlib import Path
import random
import runpy
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/blender/environments/wind_meadow/buildings'
RECIPES = {'wall_ruins': 'wall_section', 'gate_ruins': 'gate_frame',
           'tower_ruins': 'watchtower', 'barracks_ruins': 'barracks'}


def cut(obj, point, normal):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    result = bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                                   dist=.0001, plane_co=point, plane_no=normal,
                                   clear_outer=True, clear_inner=False)
    edges = [e for e in result['geom_cut'] if isinstance(e, bmesh.types.BMEdge) and e.is_boundary]
    if edges:
        faces = bmesh.ops.holes_fill(bm, edges=edges, sides=0)['faces']
        uv = bm.loops.layers.uv.verify()
        for face in faces:
            face.material_index = 0
            for loop in face.loops:
                # Fresh stone uses the existing pale masonry atlas cell.
                loop[uv].uv = (.26+(loop.vert.co.x*.07 % .22), .02+(loop.vert.co.y*.07 % .22))
    bm.normal_update()
    bm.to_mesh(obj.data)
    bm.free()


def load_parts(name):
    with bpy.data.libraries.load(str(SOURCE / (name+'.blend')), link=False) as (available, loaded):
        loaded.objects = available.objects
    meshes = []
    for obj in loaded.objects:
        if obj.type != 'MESH':
            continue
        bpy.context.collection.objects.link(obj)
        obj.data = obj.data.copy()
        obj.data.transform(obj.matrix_world)
        obj.matrix_world.identity()
        meshes.append(obj)
    return meshes


def clone(obj):
    piece = obj.copy()
    piece.data = obj.data.copy()
    bpy.context.collection.objects.link(piece)
    return piece


def ground(obj, x, y, turn, tilt=.0, lift=0.0):
    coords = [v.co for v in obj.data.vertices]
    centre = sum(coords, Vector()) / len(coords)
    for v in obj.data.vertices:
        v.co -= centre
    obj.rotation_euler = (tilt, tilt*.37, turn)
    bpy.context.view_layer.update()
    low = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
    obj.location = (x, y, -low+lift)


def build(name, original):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1
    sources = load_parts(original)
    architecture = next(o for o in sources if o.name.startswith('Architecture'))
    result = []
    half = 3 if name == 'wall_ruins' else (8.9 if name == 'barracks_ruins' else 6)
    # Three differently broken stumps preserve the footprint without an intact silhouette.
    for i, height in enumerate([2.8, 1.05, 3.8]):
        obj = clone(architecture)
        left = -half+i*2*half/3
        right = left+2*half/3
        cut(obj, (left, 0, 0), (-1, 0, 0))
        cut(obj, (right, 0, 0), (1, 0, 0))
        cut(obj, ((left+right)/2, 0, height), (.22*(-1 if i % 2 else 1), .13, 1))
        obj.name = 'Broken foundation %d' % i
        if obj.data.polygons:
            result.append(obj)
        else:
            bpy.data.objects.remove(obj, do_unlink=True)
    block = load_parts('stone_block')[0]
    block.data.materials[0] = architecture.data.materials[0]
    rng = random.Random(251025+list(RECIPES).index(name))
    for i in range(7 if name == 'wall_ruins' else 17):
        obj = clone(block)
        # Fractured chunks of the original block, retaining its UVs and worn edges.
        cut(obj, (rng.uniform(-.7, 1), 0, 2), (1, .28, .18))
        cut(obj, (0, rng.uniform(-1, .7), 1), (-.17, -1, .3))
        cut(obj, (0, 0, rng.uniform(1.4, 2.6)), (.25, -.18, 1))
        obj.scale = (rng.uniform(.42, .85), rng.uniform(.45, .9), rng.uniform(.45, .8))
        x = rng.uniform(-half, half)
        y = rng.choice([-1, 1])*rng.uniform(1.9, 4.5) if name == 'wall_ruins' else rng.uniform(-half, half)
        ground(obj, x, y, rng.uniform(-math.pi, math.pi), rng.uniform(-.6, .6))
        obj.name = 'Fallen masonry %02d' % i
        result.append(obj)
    if name != 'wall_ruins':
        # Reuse cropped upper architecture: blue coping, oak and roof fragments.
        for i in range(4):
            obj = clone(architecture)
            x = (-.7 if i % 2 else .7)*half
            cut(obj, (x-1.3, 0, 0), (-1, 0, 0))
            cut(obj, (x+1.3, 0, 0), (1, 0, 0))
            cut(obj, (0, 0, 5.0 if name == 'barracks_ruins' else 19), (0, 0, -1))
            cut(obj, (0, 0, 8.5 if name == 'barracks_ruins' else 27), (0, 0, 1))
            if not obj.data.polygons:
                bpy.data.objects.remove(obj, do_unlink=True)
                continue
            ground(obj, x, (-1 if i < 2 else 1)*half*.65, rng.uniform(-1, 1), 1.25, .25)
            obj.name = 'Fallen crown %d' % i
            result.append(obj)
    for obj in sources+[block]:
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in result:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = result[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = 'RuinedArchitecture'
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    cut(obj, (0, 0, 0), (0, 0, -1))
    cut(obj, (0, 0, 5.5), (.06, -.04, 1))
    triangles = sum(len(p.vertices)-2 for p in obj.data.polygons)
    assert 0 < triangles < 8000 and obj.data.uv_layers
    assert min(v.co.z for v in obj.data.vertices) >= -.01
    bpy.context.scene['source_master'] = original+'.blend; stone_block.blend'
    bpy.context.scene['authoring_note'] = 'Cosmetic ruins; no collision. Same ground-centre origin and painted atlas as intact kit. Edit this saved master; do not regenerate.'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name+'.blend')))
    runpy.run_path(str(ROOT / 'tools/export_blender.py'))


if __name__ == '__main__':
    names = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(RECIPES)
    assert names and all(name in RECIPES for name in names)
    assert not any((SOURCE / (name+'.blend')).exists() for name in names), 'Saved ruins exist; edit masters and use the normal exporter'
    originals = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in SOURCE.glob('*.blend')}
    for name in names:
        build(name, RECIPES[name])
    assert all(hashlib.sha256(path.read_bytes()).hexdigest() == digest for path, digest in originals.items()), 'Original master changed'
