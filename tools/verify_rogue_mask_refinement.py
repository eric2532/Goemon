"""Compare the v2.37 mask/neck correction with an accepted v2.36 snapshot.

Blender -b --python tools/verify_rogue_mask_refinement.py -- BASELINE_DIR OUTPUT_JSON
The report checks authored .blend data and the actual batched GLB consumed by Godot.
Visual mask coverage is reviewed separately; the hidden painted face must remain intact.
"""
import hashlib
import json
from pathlib import Path
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[1]
HEROES = ('samurai', 'dragoon', 'magic-swordsman')
TOLERANCE = 3e-6
WRAP = 'Equipment crimson mouth and neck wrap'
KNOT = 'Equipment crimson scarf side knot'
TAIL = 'Equipment continuous long scarf tail'
MASK_PREFIXES = {
    'dragoon': ('Equipment dragon closed ', 'Equipment dragon visor ',
                'Equipment dragon face ', 'Equipment dragon muzzle '),
    'magic-swordsman': ('Equipment demon ',),
}


def close(a, b, tolerance=TOLERANCE):
    if isinstance(a, (list, tuple)) and isinstance(b, (list, tuple)):
        return len(a) == len(b) and all(close(x, y, tolerance) for x, y in zip(a, b))
    return abs(a - b) <= tolerance


def moved(points, delta):
    return [[v + d for v, d in zip(point, delta)] for point in points]


def bounds(points):
    return [[min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)]]


def inspect_source(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    bpy.context.view_layer.update()
    result = {}
    for obj in bpy.data.objects:
        if obj.type not in ('MESH', 'EMPTY'):
            continue
        item = {'type': obj.type, 'parent': obj.parent.name if obj.parent else None,
                'world': [list(row) for row in obj.matrix_world],
                'basis': [list(row) for row in obj.matrix_basis]}
        if obj.type == 'MESH':
            item.update(points=[list(obj.matrix_world @ v.co) for v in obj.data.vertices],
                        local_points=[list(v.co) for v in obj.data.vertices],
                        polygons=[list(p.vertices) for p in obj.data.polygons],
                        material_indices=[p.material_index for p in obj.data.polygons],
                        materials=[m.name if m else None for m in obj.data.materials],
                        uv=[[[p.uv.x, p.uv.y] for p in uv.data] for uv in obj.data.uv_layers],
                        uv_layers=[uv.name for uv in obj.data.uv_layers],
                        painted_face=bool(obj.get('painted_face')))
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            item['mesh_health'] = {'nonmanifold_edges': sum(not e.is_manifold for e in bm.edges),
                                   'degenerate_faces': sum(f.calc_area() < 1e-10 for f in bm.faces),
                                   'signed_volume': bm.calc_volume(signed=True)}
            bm.free()
        if obj.name == 'ScarfTail':
            item['contract'] = {key: obj.get(key) for key in ('wind_axis', 'length', 'root_pin_length')}
        if obj.name == TAIL:
            item['contract'] = {key: obj.get(key) for key in ('length_subdivisions', 'continuous_cloth')}
        result[obj.name] = item
    return result


class GLB:
    def __init__(self, path):
        raw = path.read_bytes()
        assert raw[:4] == b'glTF', path
        length = struct.unpack_from('<I', raw, 12)[0]
        self.doc = json.loads(raw[20:20 + length])
        self.binary = raw[28 + length:]
        self.nodes = {n['name']: n for n in self.doc['nodes']}
        self.parents = {child: i for i, node in enumerate(self.doc['nodes'])
                        for child in node.get('children', [])}

    def accessor(self, index):
        a = self.doc['accessors'][index]
        v = self.doc['bufferViews'][a['bufferView']]
        count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
        char = {5121: 'B', 5123: 'H', 5125: 'I', 5126: 'f'}[a['componentType']]
        fmt = '<' + char * count
        stride = v.get('byteStride', struct.calcsize(fmt))
        offset = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        return [struct.unpack_from(fmt, self.binary, offset + i * stride) for i in range(a['count'])]

    def matrix(self, index):
        node = self.doc['nodes'][index]
        if 'matrix' in node:
            values = node['matrix']
            local = Matrix([values[i::4] for i in range(4)])
        else:
            xyzw = node.get('rotation', [0, 0, 0, 1])
            local = Matrix.LocRotScale(Vector(node.get('translation', [0, 0, 0])),
                                      Quaternion((xyzw[3], *xyzw[:3])),
                                      Vector(node.get('scale', [1, 1, 1])))
        return self.matrix(self.parents[index]) @ local if index in self.parents else local

    def world(self, name):
        return self.matrix(self.doc['nodes'].index(self.nodes[name]))

    def primitives(self, name):
        return self.doc['meshes'][self.nodes[name]['mesh']]['primitives']

    def signature(self, name):
        return [{'material': self.doc['materials'][p['material']]['name'],
                 'mode': p.get('mode', 4), 'indices': self.accessor(p['indices']),
                 'attributes': {key: self.accessor(value) for key, value in p['attributes'].items()}}
                for p in self.primitives(name)]

    def image_hashes(self):
        result = {}
        for image in self.doc.get('images', []):
            view = self.doc['bufferViews'][image['bufferView']]
            offset = view.get('byteOffset', 0)
            result[image['name']] = hashlib.sha256(self.binary[offset:offset + view['byteLength']]).hexdigest()
        return result


def main():
    args = sys.argv[sys.argv.index('--') + 1:]
    baseline, output = map(Path, args)
    report = {'baseline': str(baseline), 'heroes': {}, 'preserved': {},
              'failures': [], 'checks': 0, 'numeric_tolerance': TOLERANCE}

    def check(condition, label):
        report['checks'] += 1
        if not condition:
            report['failures'].append(label)

    for hero in HEROES:
        before = inspect_source(baseline / 'assets/blender/rogue' / (hero + '.blend'))
        after = inspect_source(ROOT / 'assets/blender/rogue' / (hero + '.blend'))
        manifest = json.loads((ROOT / 'assets/rogue/styled' / (hero + '-build.json')).read_text())
        old_glb = GLB(baseline / 'assets/rogue/styled/models' / (hero + '.glb'))
        glb = GLB(ROOT / 'assets/rogue/styled/models' / (hero + '.glb'))
        counts = {'native_pivots': 0, 'body_weapon_meshes': 0, 'unchanged_meshes': 0,
                  'rigidly_lowered_head_meshes': 0, 'painted_faces': 0}
        health = {}
        removed = set(before) - set(after)
        added = set(after) - set(before)
        check(all(after[n]['type'] == 'MESH' for n in added), hero + ' no added native pivots')
        expected_removed = ({'Equipment dragon swept snout', 'Equipment dragon silver muzzle rim',
                             'Equipment dragon teal eye inlay -1', 'Equipment dragon teal eye inlay 1',
                             'Equipment dragon jaw guard -1', 'Equipment dragon jaw guard 1'}
                            if hero == 'dragoon' else
                            {'Pilot silver sweeping fringe'} if hero == 'magic-swordsman' else set())
        check(removed == expected_removed, hero + ' only approved old outlines removed')
        check(removed <= set(manifest['equipment_removed']), hero + ' removed components recorded')
        check(all(before[n]['type'] == 'MESH' and before[n]['parent'] == 'Head'
                  and (n.startswith('Equipment ') or n == 'Pilot silver sweeping fringe')
                  for n in removed), hero + ' removals confined to approved helmet components')
        for name, old in before.items():
            if name not in after:
                continue
            new = after[name]
            check(old['parent'] == new['parent'], hero + ' parent ' + name)
            if old['type'] == 'EMPTY':
                expected = [row[:] for row in old['world']]
                if hero == 'samurai' and name in ('Head', 'ScarfTail'):
                    expected[2][3] -= .13 if name == 'Head' else .08
                check(close(expected, new['world']), hero + ' native pivot ' + name)
                counts['native_pivots'] += 1
                continue
            for field in ('polygons', 'material_indices', 'materials', 'uv', 'uv_layers'):
                check(old[field] == new[field], hero + ' retained ' + field + ' ' + name)
            if old['painted_face']:
                counts['painted_faces'] += 1
                check(old['uv'] == new['uv'], hero + ' painted face UV exact ' + name)
            if old['parent'] not in ('Head', 'ScarfTail'):
                check(old['points'] == new['points'], hero + ' body/weapon world geometry exact ' + name)
                counts['body_weapon_meshes'] += 1
            elif hero == 'samurai' and name == 'Samurai neck':
                low, high = bounds(old['points'])
                height = high[2] - low[2]
                expected = [[p[0], p[1], low[2] + (p[2] - low[2]) * (height - .13) / height]
                            for p in old['points']]
                check(close(expected, new['points']), 'samurai compressed neck fixed bottom and top minus .13')
            elif hero == 'samurai' and name == WRAP:
                old_front = [p[2] for p in old['points'] if abs(p[0]) < 1e-5 and p[1] < -.1]
                front = [p[2] for p in new['points'] if abs(p[0]) < 1e-5 and p[1] < -.1]
                check(close(max(old_front) - min(old_front), .40), 'samurai baseline wrap front height .40')
                check(close(max(front) - min(front), .27), 'samurai compact wrap front height .27')
                check(close(min(front), min(old_front)), 'samurai wrap lower edge unchanged')
            elif hero == 'samurai' and name == KNOT:
                check(len(old['points']) == len(new['points']) == 25, 'samurai knot three closed octagonal rings and tip')
                for ring, (old_width, old_depth, width, depth) in enumerate(zip(
                        (.095, .10, .082), (.08, .075, .065), (.075, .08, .070), (.065, .06, .05))):
                    old_ring = [Vector(p) for p in old['points'][ring * 8: ring * 8 + 8]]
                    new_ring = [Vector(p) for p in new['points'][ring * 8: ring * 8 + 8]]
                    center = sum(old_ring, Vector()) / 8
                    new_center = sum(new_ring, Vector()) / 8
                    check(close(list(new_center), list(center + Vector((0, 0, -.08)))),
                          'samurai knot center lowered .08 ring ' + str(ring))
                    wide = old_ring[0] - center
                    thick = old_ring[2] - center
                    check(close(wide.length, old_width) and close(thick.length, old_depth),
                          'samurai baseline knot cross section ring ' + str(ring))
                    check(close((new_ring[0] - new_center).length, width) and
                          close((new_ring[2] - new_center).length, depth),
                          'samurai compact knot exact width/depth ring ' + str(ring))
                    wide.normalize()
                    thick.normalize()
                    expected = [list(center + Vector((0, 0, -.08)) +
                                     wide * (point - center).dot(wide) * width / old_width +
                                     thick * (point - center).dot(thick) * depth / old_depth)
                                for point in old_ring]
                    check(close(expected, [list(p) for p in new_ring]), 'samurai compact knot ring shape ' + str(ring))
                check(close(moved(old['points'][-1:], (0, 0, -.08)), new['points'][-1:]),
                      'samurai knot tip lowered .08')
            elif hero == 'samurai':
                dz = -.08 if name == TAIL else -.13
                check(close(moved(old['points'], (0, 0, dz)), new['points']), 'samurai rigid shift ' + name)
                if name not in (KNOT, TAIL):
                    counts['rigidly_lowered_head_meshes'] += 1
            else:
                check(old['points'] == new['points'], hero + ' preserved source world geometry exact ' + name)
                counts['unchanged_meshes'] += 1
        for name, new in after.items():
            if new['type'] != 'MESH':
                continue
            check(new['uv_layers'] == ['Painted palette'], hero + ' source single UV0 ' + name)
            if name not in before:
                check(name.startswith('Equipment ') and new['parent'] == 'Head', hero + ' new component scope ' + name)
            # Translated legacy solids retain their accepted winding. Only newly
            # authored or reshaped geometry is required to have positive volume.
            reshaped = name not in before or (hero == 'samurai' and name in ('Samurai neck', WRAP, KNOT))
            if reshaped:
                h = new['mesh_health']
                check(h['nonmanifold_edges'] == 0 and h['degenerate_faces'] == 0 and h['signed_volume'] > 0,
                      hero + ' closed positive manifold ' + name)
                health[name] = h
        for name, old in old_glb.nodes.items():
            check(name in glb.nodes, hero + ' retained GLB node ' + name)
            if name not in glb.nodes:
                continue
            if 'mesh' not in old:
                expected = [list(row) for row in old_glb.world(name)]
                if hero == 'samurai' and name in ('Head', 'ScarfTail'):
                    expected[1][3] -= .13 if name == 'Head' else .08
                check(close(expected, [list(row) for row in glb.world(name)]), hero + ' GLB pivot ' + name)
            elif name not in ('Head_Geometry', 'ScarfTail_Geometry'):
                check(old_glb.signature(name) == glb.signature(name), hero + ' GLB body/weapon attributes exact ' + name)
                check(old_glb.world(name) == glb.world(name), hero + ' GLB body/weapon transform exact ' + name)
        for mesh in glb.doc['meshes']:
            for p in mesh['primitives']:
                check([k for k in p['attributes'] if k.startswith('TEXCOORD_')] == ['TEXCOORD_0'],
                      hero + ' GLB single UV0 ' + mesh['name'])
        face = next(p for p in glb.primitives('Head_Geometry')
                    if 'Drawn face' in glb.doc['materials'][p['material']]['name'])
        old_face = next(p for p in old_glb.primitives('Head_Geometry')
                        if 'Drawn face' in old_glb.doc['materials'][p['material']]['name'])
        face_uv = glb.accessor(face['attributes']['TEXCOORD_0'])
        check(face_uv == old_glb.accessor(old_face['attributes']['TEXCOORD_0']), hero + ' GLB painted UV0 exact')
        unique_uv = set(face_uv)
        spans = [max(p[i] for p in face_uv) - min(p[i] for p in face_uv) for i in range(2)]
        check(len(unique_uv) > 400 and min(spans) > .28, hero + ' GLB face landmark UV span')
        face_material = glb.doc['materials'][face['material']]
        check(face_material['pbrMetallicRoughness']['baseColorTexture'].get('texCoord', 0) == 0,
              hero + ' GLB painted material samples UV0')
        check(old_glb.image_hashes() == glb.image_hashes(), hero + ' GLB palette and face image hashes exact')
        hero_report = {**counts, 'removed_components': sorted(removed), 'new_or_reshaped_geometry': health,
                       'triangles': manifest['triangles'], 'mesh_batches': manifest['mesh_batches'],
                       'export_face_uv': {'distinct_coordinates': len(unique_uv), 'spans': spans, 'exact': face_uv == old_glb.accessor(old_face['attributes']['TEXCOORD_0'])},
                       'embedded_image_hashes': glb.image_hashes(),
                       'glb_head_local_translation': glb.nodes['Head'].get('translation', [0, 0, 0]),
                       'glb_head_world_translation': list(glb.world('Head').translation)}
        if hero in MASK_PREFIXES:
            mask_names = [n for n in after if n.startswith(MASK_PREFIXES[hero])]
            check(bool(mask_names), hero + ' mask source components present')
            check(any('closed' in n and 'shell' in n for n in mask_names), hero + ' full face shell present')
            points = [glb.world('Head_Geometry') @ Vector(p)
                      for primitive in glb.primitives('Head_Geometry')
                      for p in glb.accessor(primitive['attributes']['POSITION'])]
            tree = KDTree(len(points))
            for i, point in enumerate(points):
                tree.insert(point, i)
            tree.balance()
            distances = {name: max(tree.find(Vector((p[0], p[2], -p[1])))[2]
                                   for p in after[name]['points']) for name in mask_names}
            check(all(d <= TOLERANCE for d in distances.values()), hero + ' every source mask vertex present in GLB Head_Geometry')
            hero_report['exported_mask_components'] = distances
        if hero == 'samurai':
            old_bound, new_bound = bounds(before['Samurai neck']['points']), bounds(after['Samurai neck']['points'])
            old_height = old_bound[1][2] - old_bound[0][2]
            new_height = new_bound[1][2] - new_bound[0][2]
            check(before[TAIL]['local_points'] == after[TAIL]['local_points'], 'samurai scarf tail local vertices exact')
            check(before[TAIL]['contract'] == after[TAIL]['contract'], 'samurai scarf tail subdivisions contract exact')
            check(before['ScarfTail']['contract'] == after['ScarfTail']['contract'], 'samurai scarf axis/length/pin contract exact')
            check(after['ScarfTail']['contract'] == {'wind_axis': 'Godot local -Z / Blender local +Y', 'length': 1.4, 'root_pin_length': .1}, 'samurai source pinned axis contract')
            check(close(after[TAIL]['basis'], [list(row) for row in Matrix.Identity(4)]), 'samurai source tail identity transform')
            check(old_glb.signature('ScarfTail_Geometry') == glb.signature('ScarfTail_Geometry'), 'samurai GLB scarf attributes exact')
            root, tail = glb.nodes['ScarfTail'], glb.nodes['ScarfTail_Geometry']
            check(glb.doc['nodes'].index(root) in glb.nodes['Head']['children'] and
                  glb.doc['nodes'].index(tail) in root['children'], 'samurai GLB Head/ScarfTail/ScarfTail_Geometry hierarchy')
            check(not any(key in tail for key in ('translation', 'rotation', 'scale', 'matrix')), 'samurai GLB tail identity transform')
            primitives = glb.primitives('ScarfTail_Geometry')
            check(len(primitives) == 1 and 'NORMAL' in primitives[0]['attributes'], 'samurai GLB continuous cloth with normals')
            vertices = glb.accessor(primitives[0]['attributes']['POSITION'])
            stations = sorted(set(round(-v[2], 5) for v in vertices))
            check(len(stations) == 25 and close(stations[0], 0) and close(stations[-1], 1.4), 'samurai GLB 24 length segments along -Z')
            hero_report['neck'] = {'before_bounds': old_bound, 'after_bounds': new_bound,
                                    'before_height': old_height, 'after_height': new_height,
                                    'height_reduction': old_height - new_height,
                                    'percent_reduction': (1 - new_height / old_height) * 100}
            hero_report['scarf'] = {'root_source_world': [after['ScarfTail']['world'][i][3] for i in range(3)],
                                     'root_glb_world': list(glb.world('ScarfTail').translation),
                                     'root_glb_local': root['translation'], 'length_stations': stations,
                                     'export_vertices': len(vertices), 'local_geometry_unchanged': True,
                                     'axis': '-Z', 'pin_length': .1, 'wrap_front_height': .27,
                                     'knot_center_delta': [0, 0, -.08],
                                     'knot_widths': [.075, .08, .070], 'knot_depths': [.065, .06, .05]}
        report['heroes'][hero] = hero_report

    hashes = json.loads((baseline / 'sha256.json').read_text())
    older = ROOT / 'build/rogue-equipment-upgrade/baseline/sha256.json'
    if older.exists():
        for path, digest in json.loads(older.read_text()).items():
            if '/faces/' in path or '/atlases/' in path or path == 'assets/blender/characters/kai.blend':
                hashes.setdefault(path, digest)
    for path, digest in hashes.items():
        if path == 'tools/equip_rogue_roster.py' or any('/' + h + '.' in path or '/' + h + '-' in path for h in HEROES):
            continue
        full_path = ROOT / path
        same = full_path.exists() and hashlib.sha256(full_path.read_bytes()).hexdigest() == digest
        report['preserved'][path] = same
        check(same, 'preserved file hash ' + path)
    check('assets/rogue/styled/faces/painted-faces.png' in report['preserved'], 'baseline face atlas hash available')
    check('assets/blender/characters/kai.blend' in report['preserved'], 'baseline Kai master hash available')
    report['success'] = not report['failures']
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + '\n')
    print('ROGUE_MASK_REFINEMENT_VERIFY checks=%d failures=%d' % (report['checks'], len(report['failures'])))
    print(json.dumps(report['failures'], indent=2))
    assert report['success'], report['failures']


if __name__ == '__main__':
    main()
