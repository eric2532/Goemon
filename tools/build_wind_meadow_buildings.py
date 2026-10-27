"""Initial Blender authoring of Wind Meadow walls, watchtower and barracks.

Existing masters are never rebuilt. Edit them and run tools/export_blender.py.
"""
import bpy
import math
from mathutils import Vector
from pathlib import Path
import json
import random
import runpy
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'assets/blender/environments/wind_meadow/buildings'
TEXTURES = ROOT/'assets/textures/wind_meadow'
REPORT = ROOT/'build/Other Files/Asset Toolkit/Wind Meadow/Buildings'
R = random.Random(231023)
PALETTE = ['879b94', 'b5bcaa', 'ddd7b4', '806f4f', '578d89', '365f66',
           'cfb56c', '30474a', 'b8695d', 'f6d99a', '718b4d', '6e674d',
           '617c7d', '9caa7c', 'eee4bc', '597c4b']


def linear(c):
    return c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4


def atlas():
    if (TEXTURES/'architecture_paint.png').exists():
        image = bpy.data.images.load(str(TEXTURES/'architecture_paint.png'))
        image.pack()
        return painted_material(image)
    image = bpy.data.images.new('Wind Meadow architecture paint', 1024, 1024, alpha=False)
    pixels = []
    for y in range(1024):
        row, py = divmod(y, 256)
        for x in range(1024):
            column, px = divmod(x, 256)
            slot = row*4+column
            base = [int(PALETTE[slot][i:i+2], 16)/255 for i in (0, 2, 4)]
            u, v = px/256, py/256
            paint = .035*math.sin(u*19+math.sin(v*14))+.025*math.sin(u*53-v*29)
            value = 1+paint
            if slot in (0, 1):
                brick_row = int(v*5)
                joint_x = (u*4+(brick_row % 2)*.5) % 1
                joint_y = (v*5) % 1
                value += .035*math.sin(brick_row*4+int(u*4)*7)
                if joint_x < .022 or joint_y < .035:
                    value *= .66
                elif joint_x < .048 or joint_y < .075:
                    value *= 1.12
            elif slot in (3, 11):
                value += .06*math.sin(u*82+math.sin(v*9)*1.3)
                if (u*5) % 1 < .025:
                    value *= .65
            elif slot in (4, 5):
                tile_row = int(v*7)
                tile_x = (u*7+(tile_row % 2)*.5) % 1
                tile_y = (v*7) % 1
                value += .075*math.sin(tile_x*math.pi)
                if tile_x < .025 or tile_y < .05:
                    value *= .7
                elif tile_y < .12:
                    value *= 1.15
            elif slot == 8:
                value += .04*math.sin(u*38)
            pixels.extend([linear(max(0, min(1, c*value))) for c in base]+[1])
    image.pixels = pixels
    image.filepath_raw = str(TEXTURES/'architecture_paint.png')
    image.file_format = 'PNG'
    image.save()
    image.pack()
    return painted_material(image)


def painted_material(image):
    m = bpy.data.materials.new('Wind Meadow painted architecture')
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value = .92
    bs.inputs['Specular IOR Level'].default_value = .18
    texture = m.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image = image
    texture.interpolation = 'Linear'
    m.node_tree.links.new(texture.outputs['Color'], bs.inputs['Base Color'])
    return m


MATERIAL = None
groups = {}
inventory = {}


def finish(obj, name, slot, group='Architecture'):
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.clear()
    obj.data.materials.append(MATERIAL)
    data = obj.data
    uv = data.uv_layers.active or data.uv_layers.new(name='UVMap')
    minimum = [min(v.co[i] for v in data.vertices) for i in range(3)]
    extent = [max(v.co[i] for v in data.vertices)-minimum[i] for i in range(3)]
    for face in data.polygons:
        axis = max(range(3), key=lambda i: abs(face.normal[i]))
        axes = [i for i in range(3) if i != axis]
        if axis == 1:
            axes = [0, 2]
        for li in face.loop_indices:
            co = data.vertices[data.loops[li].vertex_index].co
            u, v = [(co[a]-minimum[a])/max(.001, extent[a]) for a in axes]
            uv.data[li].uv = ((slot % 4+(u*.96+.02))/4, (slot//4+(v*.96+.02))/4)
    groups.setdefault(group, []).append(obj)
    return obj


def box(name, p, size, slot, bevel=.06, group='Architecture'):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Soft worn edges', 'BEVEL')
        modifier.width = min(bevel, min(size)*.2)
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj, name, slot, group)


def beam(name, a, b, width, slot=3):
    a, b = Vector(a), Vector(b)
    obj = box(name, (a+b)*.5, (width, width, (b-a).length), slot, width*.14)
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = (b-a).to_track_quat('Z', 'Y')
    return obj


def custom(name, vertices, faces, slot, group='Architecture'):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, slot, group)


def socket(name, p):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = p
    obj.empty_display_size = .4


def roof(p, width, depth, height):
    x, y, z = p
    # Broad hipped roof with gently lifted corners and a substantial rim.
    vertices = []
    for scale, up in ((1, 0), (.84, .28), (.42, height*.75), (.10, height)):
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vertices.append((x+sx*width*.5*scale, y+sy*depth*.5*scale, z+up+(.18 if scale == 1 else 0)))
    faces = []
    for row in range(3):
        for k in range(4):
            faces.append((row*4+k, row*4+(k+1) % 4, (row+1)*4+(k+1) % 4, (row+1)*4+k))
    faces.append((12, 13, 14, 15))
    custom('Swept teal tile roof', vertices, faces, 4)
    for a, b in ((0, 1), (1, 2), (2, 3), (3, 0)):
        beam('Dark eave fascia', vertices[a], vertices[b], .22, 5)
    beam('Rounded ridge', (x-width*.12, y, z+height+.06), (x+width*.12, y, z+height+.06), .25, 5)


def arch(x, y, z, width, height, slot=11, doors=False):
    # A painted inset, with separate stone voussoirs and a dark recessed surround.
    radius = width*.5
    spring = height-radius
    shape = [(x-radius, y, z), (x+radius, y, z)]
    for i in range(13):
        a=i*math.pi/12
        shape.append((x+radius*math.cos(a), y, z+spring+radius*math.sin(a)))
    custom('Arched doorway' if doors else 'Arched window', shape, [tuple(range(len(shape)))], slot)
    for side in (-1, 1):
        box('Pale jamb', (x+side*(radius+.14), y-.04, z+spring*.5), (.28, .3, spring), 1)
    for i in range(9):
        a = (i+.5)*math.pi/9
        obj = box('Arch stone', (x+(radius+.16)*math.cos(a), y-.04, z+spring+(radius+.16)*math.sin(a)), (.3, .32, (radius+.16)*math.pi/9*1.02), 1, 0)
        obj.rotation_euler.y = -a
    if doors:
        beam('Door seam', (x, y-.02, z+.1), (x, y-.02, z+height-.1), .035, 7)
        for sign in (-1, 1):
            for level in (.33, .72):
                box('Door iron strap', (x+sign*width*.25, y-.06, z+spring*level), (width*.38, .055, .09), 12, .01)
            box('Door handle', (x+sign*.18, y-.10, z+height*.39), (.09, .1, .19), 6, .02)


def lantern(x, y, z):
    box('Lantern bracket', (x, y+.12, z+.6), (.12, .42, .14), 3, .02)
    box('Warm lantern glass', (x, y, z), (.28, .27, .48), 9, .04, 'Lanterns')
    for h in (-.26, .26):
        box('Lantern cap', (x, y, z+h), (.4, .37, .09), 5, .025)


def banner(x, y, z, scale=1):
    beam('Banner hanger', (x-scale*.7, y, z+.2), (x+scale*.7, y, z+.2), .1, 6)
    v=[(x+sx*scale*.58, y-.02+math.sin(t*4)*.05, z-t*scale*1.9) for t in (0, .5, 1) for sx in (-1, 1)]
    custom('Muted red banner', v, [(0, 2, 3, 1), (2, 4, 5, 3)], 8, 'Banners')
    custom('Sun crest', [(x-scale*.25, y-.09, z-scale*.7), (x, y-.09, z-scale*.4), (x+scale*.25, y-.09, z-scale*.7), (x, y-.09, z-scale)], [(0, 1, 2, 3)], 6, 'Banners')


def moss(width, depth, z=0):
    for i in range(15):
        x = R.uniform(-width*.5+.5, width*.5-.5)
        y = R.choice((-1, 1))*depth*.48
        box('Moss at footing', (x, y, z+.15), (R.uniform(.35, .85), .1, R.uniform(.15, .3)), 10, .04)


def battlements(width, depth, deck):
    for sign in (-1, 1):
        box('Parapet', (0, sign*(depth*.5-.45), deck+.6), (width, .85, 1.2), 0)
        box('Parapet', (sign*(width*.5-.45), 0, deck+.6), (.85, depth, 1.2), 0)
        for x in range(-int(width*.5)+2, int(width*.5), 4):
            box('Rounded merlon', (x, sign*(depth*.5-.45), deck+1.7), (1.65, .95, 1), 1, .12)
        for y in range(-int(depth*.5)+2, int(depth*.5), 4):
            box('Rounded merlon', (sign*(width*.5-.45), y, deck+1.7), (.95, 1.65, 1), 1, .12)


def start():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    groups.clear()
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1


def save(name, footprint):
    # A few semantic mesh groups share one atlas instead of hundreds of draw surfaces.
    for label, objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = label
        bpy.context.scene.cursor.location = (0, 0, 0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    triangles = sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)
    assert 0 < triangles < 8000, (name, triangles)
    assert len(meshes) <= 4
    assert all(o.data.uv_layers for o in meshes)
    bpy.context.scene['authoring_note'] = 'Wind Meadow original architecture. Metres; Blender -Y front exports to Godot +Z. Visual kit, not gameplay collision.'
    bpy.context.scene['footprint_metres'] = footprint
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    runpy.run_path(str(ROOT/'tools/export_blender.py'))
    inventory[name] = {'triangles': triangles, 'mesh_groups': len(meshes), 'footprint_metres': footprint}


def watchtower():
    start()
    # Tower retains the current 20m open deck and the 25m rear lookout.
    box('Tower footing', (0, 0, .35), (11.7, 11.7, .7), 0, .12)
    for row in range(4):
        box('Stone shaft course', (0, 0, .7+(row+.5)*4.7), (9.9-row*.16, 9.9-row*.16, 4.7), 0, .1)
    for x in (-4.7, 4.7):
        for y in (-4.7, 4.7):
            box('Tower corner rib', (x, y, 9.9), (.78, .78, 19.1), 1)
    for z in (7.6, 14):
        arch(0, -5.03, z, .8, 2.25, 7)
        for x in (-5.03, 5.03):
            box('Side arrow slit', (x, 0, z+1), (.04, .28, 1.6), 7, .005)
    box('Occupied deck', (0, 0, 19.75), (11, 11, .5), 1)
    battlements(10.6, 10.6, 20)
    for x in (-4.7, 4.7):
        box('Rear lookout pier', (x, 4.7, 22.2), (.85, .85, 4.4), 0)
    box('Rear lookout', (0, 4, 24.7), (11.8, 4, .6), 1)
    for x in (-4, 0, 4):
        box('Lookout crown', (x, 5.4, 25.3), (1.8, .85, .6), 1)
    arch(0, -5.07, .7, 2, 3.1, 11, True)
    banner(-2.8, -5.13, 18.7, .9)
    for x in (-1.8, 1.8):
        lantern(x, -5.35, 2.5)
    moss(11.7, 11.7)
    socket('DeckCenter', (0, 0, 20))
    socket('RearLookout', (0, 4, 25))
    socket('Entrance', (0, -5.5, .7))
    save('watchtower', [12, 12])

def barracks():
    start()
    # Low garrison keeps its entire central roof deck open for existing soldiers.
    box('Barracks footing', (0, 0, .35), (17.8, 17.8, .7), 0, .12)
    box('Barracks ground floor', (0, 0, 2.9), (17.2, 17.2, 5), 2, .13)
    box('Lower stone belt', (0, 0, 1), (17.45, 17.45, 1.2), 0)
    for x in (-7.9, -4.2, 4.2, 7.9):
        for y in (-8.65, 8.65):
            box('Barracks upright', (x, y, 3.1), (.3, .25, 4.5), 3)
    for z in (1.7, 5.1):
        for y in (-8.65, 8.65):
            box('Long timber rail', (0, y, z), (17.4, .3, .25), 3)
    for x in (-5.7, 5.7):
        arch(x, -8.72, 2.1, 1.5, 2.1, 7)
        arch(x, 8.72, 2.1, 1.5, 2.1, 7)
    box('Open defensive deck', (0, 0, 5.7), (17.8, 17.8, .6), 1)
    battlements(17.2, 17.2, 6)
    arch(0, -8.73, .7, 3.7, 3.8, 11, True)
    for x in (-2.7, 2.7):
        box('Entrance canopy post', (x, -8.8, 2.1), (.22, .25, 3.6), 3)
    roof((0, -7.7, 4.5), 6.4, 2.1, .65)
    for x in (-3.6, 3.6):
        lantern(x, -8.92, 3.2)
    banner(6.5, -8.85, 5.1, .85)
    for i in range(2):
        box('Barracks step', (0, -8.6-i*.15, .18*(2-i)), (4.6, .65, .3), 1)
    moss(17.8, 17.8)
    socket('DeckCenter', (0, 0, 6))
    socket('Entrance', (0, -8.9, .5))
    socket('RallyPoint', (0, -11, 0))
    save('barracks', [18, 18])


def wall_section():
    start()
    box('Wall footing', (0, 0, .4), (6, 6, .8), 0, .12)
    for row in range(2):
        box('Painted masonry', (0, 0, .8+(row+.5)*7.3), (6, 5.6, 7.3), 0, .06)
    box('Pale coping', (0, 0, 15.65), (6, 6, .7), 1, .08)
    for side in (-1, 1):
        box('Soft stone buttress', (0, side*2.85, 7.4), (.8, .3, 14.5), 1, .06)
    moss(6, 6)
    socket('JoinLeft', (-3, 0, 0));socket('JoinRight', (3, 0, 0))
    socket('WallTop', (0, 0, 16))
    save('wall_section', [6, 6])


def wall_corner():
    start()
    box('Corner footing', (0, 0, .4), (6, 6, .8), 0, .12)
    for row in range(2):
        box('Corner masonry', (0, 0, .8+(row+.5)*7.3), (5.6, 5.6, 7.3), 0, .08)
    for x in (-2.65, 2.65):
        for y in (-2.65, 2.65):
            box('Pale corner quoin', (x, y, 7.9), (.65, .65, 15), 1, .07)
    box('Corner coping', (0, 0, 15.65), (6, 6, .7), 1, .08)
    moss(6, 6)
    for name, p in [('JoinLeft', (-3, 0, 0)), ('JoinRight', (3, 0, 0)), ('JoinFront', (0, -3, 0)), ('JoinBack', (0, 3, 0)), ('WallTop', (0, 0, 16))]:
        socket(name, p)
    save('wall_corner', [6, 6])


def stone_block():
    start()
    box('Reusable masonry block', (0, 0, 3), (6, 6, 6), 0, .08)
    socket('StackTop', (0, 0, 6))
    save('stone_block', [6, 6])


def wall_cap():
    start()
    box('Reusable coping slab', (0, 0, .35), (6, 6, .7), 1, .08)
    save('wall_cap', [6, 6])


def gate_frame():
    start()
    # Existing gate opening 9.6m x 11m; raised leaf fits behind the 22m header.
    for side in (-1, 1):
        box('Gate pillar', (side*5.4, 0, 11), (1.2, 3.6, 22), 0, .06)
        box('Gate pillar footing', (side*5.4, 0, .5), (1.2, 4, 1), 1, .06)
    for row in range(2):
        box('Gate header course', (0, 0, 11+(row+.5)*5.5), (12, 3.6, 5.5), 0, .06)
    box('Gate coping', (0, 0, 21.65), (12, 4, .7), 1, .08)
    box('Sliding stone gate', (0, 0, 5.5), (9.6, .9, 11), 12, .06, 'GateDoor')
    for x in (-3.4, 3.4):
        banner(x, -1.84, 19.6, .8)
    socket('OpeningTop', (0, 0, 11))
    socket('GateOpenCenter', (0, 0, 16.5))
    socket('JoinLeft', (-6, 0, 0));socket('JoinRight', (6, 0, 0))
    save('gate_frame', [12, 4])


if __name__ == '__main__':
    recipes = {'watchtower': watchtower, 'barracks': barracks, 'wall_section': wall_section,
               'wall_corner': wall_corner, 'stone_block': stone_block, 'wall_cap': wall_cap, 'gate_frame': gate_frame}
    names = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(recipes)
    assert names and all(name in recipes for name in names), 'Choose known building names after --'
    assert not any((SOURCE/(name+'.blend')).exists() for name in names), 'Editable master exists; edit it and use tools/export_blender.py'
    for p in (SOURCE, TEXTURES, REPORT):
        p.mkdir(parents=True, exist_ok=True)
    MATERIAL = atlas()
    for name in names:
        recipes[name]()
    (REPORT/'authoring-inventory.json').write_text(json.dumps(inventory, indent=2)+'\n')
    print('WIND_MEADOW_BUILDINGS', json.dumps(inventory))
