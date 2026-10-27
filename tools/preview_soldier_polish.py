"""Blender-only soldier design comparisons; never writes the recovered masters.

Run: Blender --background --python tools/preview_soldier_polish.py
"""
import hashlib
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/characters/thirstquencher'
OUT = ROOT / 'build/Other Files/Asset Toolkit/Soldier Polish'
OUT.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def motion():
    return [[a.name, [[c.data_path, c.array_index,
                      [(tuple(k.co), k.interpolation) for k in c.keyframe_points]]
                     for layer in a.layers for strip in layer.strips
                     for bag in strip.channelbags for c in bag.fcurves]]
            for a in bpy.data.actions]


def polish(ob, modern):
    # Recovered triangles duplicate every corner; weld topology while retaining loop UV/colors.
    mesh = ob.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    mesh.normals_split_custom_set([(0, 0, 0)] * len(mesh.loops))
    bpy.context.view_layer.objects.active = ob
    bevel = ob.modifiers.new('Rounded authored edges', 'BEVEL')
    bevel.width = 0.018 if modern else 0.006
    bevel.segments = 3 if modern else 2
    bevel.limit_method = 'ANGLE'
    bevel.angle_limit = math.radians(28)
    # Evaluate the surface work before the existing rigid animation modifier.
    bpy.ops.object.modifier_move_up(modifier=bevel.name)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    mesh = ob.data
    for face in mesh.polygons:
        face.use_smooth = True
    if modern and ob['source_part_index'] != 10:
        smooth = ob.modifiers.new('Softer cartoon contours', 'SMOOTH')
        smooth.factor = 0.55
        smooth.iterations = 3
        bpy.ops.object.modifier_move_up(modifier=smooth.name)
        bpy.ops.object.modifier_apply(modifier=smooth.name)
        mesh = ob.data
    # Original emission materials bypass light; reuse their existing painted color graph.
    for material in mesh.materials:
        if material.get('soldier_polish'):
            continue
        nodes = material.node_tree.nodes
        emission = next(n for n in nodes if n.type == 'EMISSION')
        paint = emission.inputs['Color'].links[0].from_socket
        shader = nodes.new('ShaderNodeBsdfPrincipled')
        shader.inputs['Roughness'].default_value = 0.65
        shader.inputs['Specular IOR Level'].default_value = 0.25
        material.node_tree.links.new(paint, shader.inputs['Base Color'])
        output = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
        material.node_tree.links.new(shader.outputs['BSDF'], output.inputs['Surface'])
        material['soldier_polish'] = True
        for node in nodes:
            if node.type == 'TEX_IMAGE':
                node.interpolation = 'Linear' if modern else 'Closest'


report = []
original_hashes = {p: sha(p) for p in SOURCE.glob('soldier_*') if p.is_file()}
for ident in (1, 2, 3):
    for style in ('light', 'modern'):
        destination = OUT / f'soldier_{ident}_{style}.blend'
        assert not destination.exists(), f'Preserve edited candidate: {destination}'
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE / f'soldier_{ident}.blend'))
        before = motion()
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        assert len(meshes) == 11
        triangles_before = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
        rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
        bones = [(b.name, tuple(v for row in b.matrix_local for v in row)) for b in rig.data.bones]
        for ob in meshes:
            uv_names = [uv.name for uv in ob.data.uv_layers]
            polish(ob, style == 'modern')
            assert len(ob.vertex_groups) == 1 and ob.modifiers[0].type == 'ARMATURE'
            assert uv_names == [uv.name for uv in ob.data.uv_layers]
            assert ob.data.color_attributes
            assert all(len(v.groups) == 1 and abs(v.groups[0].weight - 1) < 1e-6 for v in ob.data.vertices)
        assert before == motion(), 'Source action data changed'
        assert bones == [(b.name, tuple(v for row in b.matrix_local for v in row)) for b in rig.data.bones]
        rig.animation_data.action = bpy.data.actions['Source__801aff18']
        bpy.context.scene.frame_set(1)
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(destination))
        report.append({'variant': ident, 'style': style, 'source_triangles': triangles_before,
                       'triangles': sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons),
                       'parts': len(meshes), 'bones': len(bones), 'actions_unchanged': True,
                       'rig_unchanged': True, 'rigid_weights_valid': True})

# One shared studio, three rows: original, light polish, modern cartoon.
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 1800
scene.render.resolution_y = 1800
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
scene.world = bpy.data.worlds.new('Studio')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (0.16, 0.19, 0.23, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = 0.6
groups = []
for row, style in enumerate(('original', 'light', 'modern')):
    for ident in (1, 2, 3):
        path = SOURCE / f'soldier_{ident}.blend' if style == 'original' else OUT / f'soldier_{ident}_{style}.blend'
        with bpy.data.libraries.load(str(path)) as (available, loaded):
            loaded.objects = available.objects
        objects = [o for o in loaded.objects if o and o.type in ('MESH', 'ARMATURE')]
        for ob in objects:
            scene.collection.objects.link(ob)
        pivot = bpy.data.objects.new(f'{style}_{ident}', None)
        scene.collection.objects.link(pivot)
        for ob in objects:
            if ob.parent is None:
                ob.parent = pivot
        pivot.location = ((ident - 2) * 1.25, 0, (2 - row) * 1.55)
        groups.append(pivot)
    bpy.ops.object.text_add(location=(-1.8, -0.1, (2 - row) * 1.55 + 1.23), rotation=(math.pi / 2, 0, 0))
    label = bpy.context.object
    label.data.body = {'original': 'ORIGINAL', 'light': 'LIGHT POLISH', 'modern': 'MODERN CARTOON'}[style]
    label.data.size = 0.15
    label.data.extrude = 0
    material = bpy.data.materials.new('Label')
    material.diffuse_color = (0.85, 0.9, 1, 1)
    label.data.materials.append(material)
for location, energy, size in [((-3, -4, 7), 450, 5), ((4, -1, 5), 250, 4), ((0, 3, 6), 500, 3)]:
    bpy.ops.object.light_add(type='AREA', location=location)
    light = bpy.context.object
    light.data.energy, light.data.shape, light.data.size = energy, 'DISK', size
    light.rotation_euler = (Vector((0, 0, 2)) - light.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(0, -10, 3.2))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 2.25)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 4.9
scene.camera = camera
for view, angle in [('threequarter', 25), ('front', 0), ('side', 90), ('back', 180)]:
    for pivot in groups:
        pivot.rotation_euler.z = math.radians(angle)
    scene.render.filepath = str(OUT / f'{view}.png')
    bpy.ops.render.render(write_still=True)
assert all(sha(path) == digest for path, digest in original_hashes.items()), 'Recovered source changed'
(OUT / 'validation.json').write_text(json.dumps(report, indent=2))
print('SOLDIER_POLISH_PREVIEW_COMPLETE', json.dumps(report))
