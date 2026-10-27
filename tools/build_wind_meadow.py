"""Create original meadow study assets. Run with Blender --background --python this_file.

Initial generation only. Edit saved masters and use tools/export_blender.py thereafter.
"""
import json
import math
from pathlib import Path
import random
import runpy

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/blender/environments/wind_meadow'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Wind Meadow'
if list(SOURCE.glob('*.blend')):
    raise RuntimeError('Editable masters exist; edit them and use tools/export_blender.py.')
SOURCE.mkdir(parents=True, exist_ok=True)
REPORT.mkdir(parents=True, exist_ok=True)
R = random.Random(231026)
materials = {}


def linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4


def color(hexcode):
    return tuple(linear(int(hexcode[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1,)


def material(name, double=False):
    if name not in materials:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        m.use_backface_culling = not double
        nodes = m.node_tree.nodes
        bs = nodes.get('Principled BSDF')
        bs.inputs['Roughness'].default_value = .94
        bs.inputs['Specular IOR Level'].default_value = .12
        vc = nodes.new('ShaderNodeVertexColor')
        vc.layer_name = 'Color'
        m.node_tree.links.new(vc.outputs['Color'], bs.inputs['Base Color'])
        materials[name] = m
    return materials[name]


def mesh(name, vertices, faces, colors, mat, soft=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(mat)
    attribute = data.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
    for item, value in zip(attribute.data, colors):
        item.color = value
    uv = data.uv_layers.new(name='UVMap')
    for loop in data.loops:
        p = data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (p.x * .25, p.y * .25)
    if soft:
        for polygon in data.polygons:
            polygon.use_smooth = True
        data.normals_split_custom_set_from_vertices([Vector((v[0]*.12, v[1]*.12, 1)).normalized() for v in vertices])
    return obj


def start():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1


def save(name, triangle_limit):
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    count = sum(len(p.vertices)-2 for o in objects for p in o.data.polygons)
    assert 0 < count <= triangle_limit, (name, count, triangle_limit)
    assert all(o.data.uv_layers and o.data.color_attributes.get('Color') for o in objects)
    bpy.context.scene['authoring_note'] = 'Original Wind Meadow art; metres, Z up; origin at ground. Vertex Color is linear. No Nintendo assets.'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name + '.blend')))
    # Use the existing project exporter, including its validation and inventory.
    runpy.run_path(str(ROOT / 'tools/export_blender.py'))
    inventory[name] = {'triangles': count, 'meshes': len(objects)}


def blade(v, f, c, base, height, width, angle, bend, tint, tip):
    p = Vector(base)
    side = Vector((math.cos(angle), math.sin(angle), 0))
    lean = Vector((-math.sin(angle), math.cos(angle), 0)) * bend
    offset = len(v)
    for t, w in ((0, 1), (.48, .72), (.8, .33)):
        center = p + Vector((0, 0, height*t)) + lean*t*t
        for sign in (-1, 1):
            v.append(tuple(center + side*width*w*sign))
            c.append(tuple(tint[i]*(1-t) + tip[i]*t for i in range(4)))
    v.append(tuple(p + Vector((0, 0, height)) + lean))
    c.append(tip)
    for a, b in ((0, 2), (2, 4)):
        f.extend([(offset+a, offset+a+1, offset+b+1), (offset+a, offset+b+1, offset+b)])
    f.append((offset+4, offset+5, offset+6))


def grass(name, tall):
    start()
    v, f, c = [], [], []
    for i in range(20 if tall else 15):
        a = R.uniform(0, math.tau)
        r = R.uniform(0, .35)
        blade(v, f, c, (math.cos(a)*r, math.sin(a)*r, -.015), R.uniform(.45, .85) if tall else R.uniform(.2, .49),
              R.uniform(.018, .036), a, R.uniform(.08, .28), color('497b3c'), color(R.choice(['a9cb61', 'c4d579', '87b94e'])))
    mesh('Grass', v, f, c, material('Meadow grass', True), True)
    save(name, 110)


def flowers(name, palette):
    start()
    v, f, c = [], [], []
    for k in range(5):
        x, y = R.uniform(-.35, .35), R.uniform(-.35, .35)
        h = R.uniform(.3, .62)
        blade(v, f, c, (x, y, 0), h, .009, k, .03, color('477b46'), color('6a9a57'))
        for sign in (-1, 1):
            p = Vector((x, y, h*.45))
            a = k*2.4 + sign
            d = Vector((math.cos(a), math.sin(a), .35))
            s = Vector((-d.y, d.x, 0))*.045
            j = len(v)
            v.extend([tuple(p), tuple(p+d*.1+s), tuple(p+d*.26), tuple(p+d*.1-s)])
            f.extend([(j, j+1, j+2), (j, j+2, j+3)])
            c.extend([color('497b46')]*4)
        for petal in range(5):
            a = petal*math.tau/5 + k
            d = Vector((math.cos(a), math.sin(a), 0))
            s = Vector((-d.y, d.x, 0))
            p = Vector((x+.02, y, h))
            j = len(v)
            v.extend([tuple(p), tuple(p+d*.07+s*.045+Vector((0, 0, .018))), tuple(p+d*.125+Vector((0, 0, .055))), tuple(p+d*.07-s*.045+Vector((0, 0, .018)))])
            f.extend([(j, j+1, j+2), (j, j+2, j+3)])
            c.extend([color('e1bd57'), color(palette[0]), color(palette[1]), color(palette[0])])
    mesh('Flowers', v, f, c, material('Meadow flowers', True), True)
    save(name, 100)


def branch(v, f, c, a, b, radius, end_radius):
    a, b = Vector(a), Vector(b)
    rotation = (b-a).to_track_quat('Z', 'Y')
    j = len(v)
    for p, r in ((a, radius), (b, end_radius)):
        for k in range(9):
            theta = k*math.tau/9
            v.append(tuple(p + rotation @ Vector((math.cos(theta)*r, math.sin(theta)*r, 0))))
            c.append(color(['716e4a', '85815b', '9b956a'][k % 3]))
    for k in range(9):
        f.append((j+k, j+(k+1)%9, j+(k+1)%9+9, j+k+9))
    f.extend([tuple(j+k for k in reversed(range(9))), tuple(j+9+k for k in range(9))])


def tree(name, shrub=False):
    start()
    v, f, c = [], [], []
    height = 1.0 if shrub else 5.3
    if not shrub:
        branch(v, f, c, (0, 0, 0), (.15, .05, 2.9), .36, .19)
        for k in range(6):
            a = k*2.4
            branch(v, f, c, (.1, .02, 2), (math.cos(a)*1.8, math.sin(a)*1.6, 4.4 + (k%2)*.6), .17, .035)
            branch(v, f, c, (0, 0, .3), (math.cos(a)*.7, math.sin(a)*.7, .02), .2, .04)
        mesh('Body', v, f, c, material('Meadow bark'))
    v, f, c = [], [], []
    # Overlapping clouds of individually modelled leaves break the silhouette.
    for cluster in range(24 if shrub else 46):
        a = cluster*2.39996
        r = math.sqrt((cluster+.5)/(24 if shrub else 46))
        p = Vector((math.cos(a)*r*(1 if shrub else 2.6), math.sin(a)*r*(.85 if shrub else 2.4), height+(1-r*r)*(.5 if shrub else 1.1)))
        for leaf in range(40 if shrub else 65):
            direction = Vector((R.gauss(0, 1), R.gauss(0, 1), R.gauss(0, 1))).normalized()
            center = p + Vector((direction.x, direction.y, direction.z*.72))*(R.random()**.32)*(.65 if shrub else 1.1)
            angle = R.uniform(0, math.tau)
            d = Vector((math.cos(angle), math.sin(angle), R.uniform(-.2, .7)))
            side = Vector((-d.y, d.x, .15))
            size = R.uniform(.1, .21) if shrub else R.uniform(.14, .27)
            j = len(v)
            v.extend([tuple(center-d*size), tuple(center+side*size*.58), tuple(center+d*size), tuple(center-side*size*.58)])
            f.extend([(j, j+1, j+2), (j, j+2, j+3)])
            shade = max(0, min(1, .48+direction.z*.22+(center.z-height)*.12+R.uniform(-.16, .16)))
            low, high = color('3e783c'), color('a8c863')
            c.extend([tuple(low[i]*(1-shade)+high[i]*shade for i in range(4))]*4)
    mesh('Canopy', v, f, c, material('Meadow leaves', True), True)
    save(name, 7000 if not shrub else 2000)


def crag(name, mountain):
    start()
    v, f, c = [], [], []
    rings, segments = (25, 80) if mountain else (10, 32)
    radius, height = (18, 25) if mountain else (1.6, 1.65)
    for row in range(rings+1):
        t = row/rings
        for k in range(segments):
            a = k*math.tau/segments
            ridge = 1+.12*math.sin(a*5+.5)+.07*math.cos(a*11+t*.7)+.025*math.sin(a*23)
            terrace = .055*math.sin(t*27)+.035*math.cos(t*43)
            r = radius*(.035+(1-t)**.62)*(ridge+terrace)
            z = height*t + (math.sin(a*5+t*4)*.09*height*math.sin(math.pi*t))
            x, y = math.cos(a)*r+t*t*radius*.14, math.sin(a)*r
            v.append((x, y, z))
            stone = color(R.choice(['9caaa4', 'b0b8aa', 'bfc4b1', 'a5b2ad']))
            # Grassy shoulders and exposed vertical faces are authored in the mesh color.
            grassy = (.19 < t < .29 or .48 < t < .55 or t > .96) if mountain else t > .7
            c.append(color('8ba662') if grassy else stone)
    for row in range(rings):
        for k in range(segments):
            a = row*segments+k
            b = row*segments+(k+1)%segments
            f.append((a, b, b+segments, a+segments))
    f.append(tuple(range(rings*segments, (rings+1)*segments)))
    obj = mesh('Cliff' if mountain else 'Rock', v, f, c, material('Meadow stone'))
    for p in obj.data.polygons:
        p.use_smooth = True
    save(name, 4200 if mountain else 700)


inventory = {}
grass('grass_short', False)
grass('grass_tall', True)
flowers('flowers_blue', ('a7b8e5', 'e0e8ff'))
flowers('flowers_ivory', ('f0e7b5', 'fffae0'))
flowers('flowers_coral', ('dc8e98', 'ffd1cd'))
tree('broadleaf_tree')
tree('leafy_shrub', True)
crag('terraced_mountain', True)
crag('mossy_boulder', False)
(REPORT / 'authoring-inventory.json').write_text(json.dumps(inventory, indent=2)+'\n')
print('WIND_MEADOW_ASSETS', json.dumps(inventory))
