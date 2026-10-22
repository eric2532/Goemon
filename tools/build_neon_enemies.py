"""Blender recipe for new editable cyber ronin / armored oni assets only.
Run Blender --background --python tools/build_neon_enemies.py.
"""
from pathlib import Path
import bpy
import json
import math
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/blender/enemies/neon_set'
EXPORT = ROOT / 'assets/models/enemies/neon_set'
PREVIEW = ROOT / 'docs/neon-shrine'
for directory in (SOURCE, EXPORT, PREVIEW):
    directory.mkdir(parents=True, exist_ok=True)

def texture(object, tile):
    uv = object.data.uv_layers.active or object.data.uv_layers.new(name='UVMap')
    for face in object.data.polygons:
        for k, index in enumerate(face.loop_indices):
            u, v = ((.04, .04), (.96, .04), (.96, .96), (.04, .96))[k % 4]
            uv.data[index].uv = ((tile % 4 + u) / 4, 1 - (tile // 4 + v) / 4)
    object.data.materials.append(material)
    return object

def box(name, point, size, tile, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point)
    o = bpy.context.object
    o.name = name
    o.scale = size
    o.rotation_euler[1] = angle
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return texture(o, tile)

def lathe(name, profile, tile, segments=8):
    vertices = [(radius * math.sin(j * math.tau / segments),
                 radius * math.cos(j * math.tau / segments), z)
                for z, radius in profile for j in range(segments)]
    faces = []
    for row in range(len(profile) - 1):
        for j in range(segments):
            a = row * segments + j
            b = row * segments + (j + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    faces += [tuple(reversed(range(segments))),
              tuple((len(profile) - 1) * segments + j for j in range(segments))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    return texture(o, tile)

def beam(name, start, end, radius, tile, tip=None, segments=6):
    delta = Vector(end) - Vector(start)
    o = lathe(name, [(0, radius), (delta.length, radius if tip is None else tip)], tile, segments)
    o.location = start
    o.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    return o

def face_panel(tile):
    # Deliberate top-left UV orientation, independent of cube face loop order.
    mesh = bpy.data.meshes.new('Head_painted_face')
    mesh.from_pydata([(-.25, .32, 2.08), (.25, .32, 2.08),
                      (.25, .32, 1.64), (-.25, .32, 1.64)], [], [(0, 1, 2, 3)])
    mesh.update()
    o = bpy.data.objects.new('Head_painted_face', mesh)
    bpy.context.collection.objects.link(o)
    texture(o, tile)

def body(oni):
    for sign, limb in ((-1, 'L'), (1, 'R')):
        box('Leg_' + limb + '_boot', (sign * .25, .10, .12), (.38, .62, .24), 5)
        beam('Leg_' + limb, (sign * .25, 0, .25), (sign * .25, 0, .91), .17, 0)
        box('Leg_' + limb + '_shin', (sign * .25, .17, .46), (.32, .09, .36), 3)
        box('Leg_' + limb + '_circuit', (sign * .25, .225, .47), (.055, .015, .28), 9 if oni else 1)
        beam('Arm_' + limb, (sign * .34, 0, 1.43), (sign * .60, .02, 1.11), .19, 0)
        beam('Arm_' + limb + '_forearm', (sign * .60, .02, 1.11), (sign * .65, .17, .93), .14, 3)
        box('Arm_' + limb + '_hand', (sign * .65, .17, .93), (.23, .24, .23), 5)
    tunic = lathe('Root_tunic', [(.78, .40), (1.08, .38), (1.42, .43), (1.56, .29)], 0)
    tunic.scale.y = .73
    box('Root_belt', (0, 0, 1.02), (.81, .61, .13), 9)
    box('Root_chest_plate', (0, .27, 1.30), (.62, .13, .44), 3)
    box('Root_chest_mark', (0, .341, 1.31), (.055, .015, .28), 1)
    for sign in (-1, 1):
        box('Root_skirt_plate', (sign * .29, .19, .88), (.26, .28, .34), 6, sign * .13)
    neck = lathe('Head_neck', [(1.50, .15), (1.66, .15)], 5)
    head = lathe('Head_helmet', [(1.60, .24), (1.90, .31), (2.10, .26), (2.18, .08)], 3)
    box('Head_mask', (0, .298, 1.86), (.50, .035, .44), 3)
    face_panel(12 if oni else 8)
    if oni:
        for sign, limb in ((-1, 'L'), (1, 'R')):
            box('Arm_' + limb + '_pauldron', (sign * .49, 0, 1.48), (.44, .63, .26), 10)
            box('Arm_' + limb + '_light', (sign * .49, .325, 1.49), (.30, .022, .06), 9)
            beam('Head_horn', (sign * .23, .04, 2.03), (sign * .41, .05, 2.38), .11, 15, .055)
            beam('Head_horn_tip', (sign * .41, .05, 2.38), (sign * .33, .13, 2.55), .055, 15, 0)
        beam('Arm_R_kanabo', (.65, .17, .91), (.92, .28, 2.02), .075, 5, .12)
        beam('Arm_R_kanabo_head', (.83, .24, 1.60), (.94, .28, 2.10), .18, 3, .22)
        for z in (1.74, 1.98):
            box('Arm_R_kanabo_band', (.90, .275, z), (.39, .38, .065), 1)
        box('Root_back_plate', (0, -.31, 1.29), (.60, .12, .41), 10)
    else:
        hat = lathe('Head_kasa', [(2.07, .55), (2.14, .55), (2.36, .06)], 5, 10)
        lathe('Head_neon_hat_rim', [(2.065, .556), (2.09, .556)], 1, 10)
        box('Head_scarf', (0, -.25, 1.68), (.58, .22, .12), 9)
        beam('Root_scarf_tail', (-.17, -.28, 1.69), (-.40, -.44, 1.20), .06, 9, .035, 4)
        # Sword is named with the right-arm prefix so the crowd shader swings it.
        box('Arm_R_sword_grip', (.66, .17, .92), (.08, .08, .35), 5, -.17)
        box('Arm_R_tsuba', (.69, .17, 1.10), (.25, .18, .045), 15)
        box('Arm_R_blade', (.77, .17, 1.62), (.09, .035, 1.02), 13, -.17)
        box('Arm_R_blade_edge', (.81, .193, 1.62), (.025, .016, 1.02), 1, -.17)
        beam('Root_scabbard', (-.36, -.25, .83), (.35, -.34, 1.82), .07, 5, .045, 4)

def aim(o, point):
    o.rotation_euler = (Vector(point) - o.location).to_track_quat('-Z', 'Y').to_euler()

report = []
for asset in ('cyber_ronin', 'armored_oni'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    material = bpy.data.materials.new('NeonEnemy_PaintedAtlas')
    material.use_nodes = True
    principled = material.node_tree.nodes.get('Principled BSDF')
    principled.inputs['Roughness'].default_value = .72
    tex = material.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(str(ROOT / 'assets/textures/enemies/neon_set/neon_atlas.png'))
    tex.image.pack()
    tex.interpolation = 'Closest'
    material.node_tree.links.new(tex.outputs['Color'], principled.inputs['Base Color'])
    body(asset == 'armored_oni')
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.ops.export_scene.gltf(filepath=str(EXPORT / (asset + '.glb')), use_selection=True,
                             export_format='GLB', export_animations=False, export_skins=False)
    triangles = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.world = bpy.data.worlds.new('PreviewWorld')
    scene.world.color = (.18, .18, .24)
    scene.view_settings.view_transform = 'Standard'
    bpy.ops.object.camera_add(location=(3.4, 6.5, 3.2))
    camera = bpy.context.object
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 3.3
    aim(camera, (0, 0, 1.2))
    scene.camera = camera
    for location, power in (((3, 4, 6), 450), ((-4, 2, 3), 250), ((0, -4, 4), 300)):
        bpy.ops.object.light_add(type='AREA', location=location)
        bpy.context.object.data.energy = power
        bpy.context.object.data.size = 5
        aim(bpy.context.object, (0, 0, 1))
    scene.render.resolution_x = 560
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = str(PREVIEW / (asset + '.png'))
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (asset + '.blend')))
    bpy.ops.render.render(write_still=True)
    report.append({'asset': asset, 'triangles': triangles, 'materials': 1,
                   'source': str(SOURCE.relative_to(ROOT) / (asset + '.blend')),
                   'export': str(EXPORT.relative_to(ROOT) / (asset + '.glb')),
                   'authorship': 'Original low-poly geometry and painted 256px atlas',
                   'animation': 'Named rigid parts, existing GPU crowd animation'})
(PREVIEW / 'asset-catalog.json').write_text(json.dumps(report, indent=2) + '\n')
