"""Validate real GLB geometry, UVs and rig compatibility against Goemon.

Catches accidental sculpting of the shared base, missing outfits, stripped
face UVs, and exports that cannot retain the current weapon/animation contract.
"""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/characters/goemon_cosplay'
HEROES = ['edo', 'pirate', 'samurai', 'ninja', 'mage', 'knight', 'dragoon',
          'magic-swordsman', 'ranger', 'explorer', 'master-thief']


def read(path):
    raw = path.read_bytes()
    assert raw[:4] == b'glTF' and struct.unpack_from('<I', raw, 8)[0] == len(raw)
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    return doc, raw[28 + length:]


def values(doc, blob, accessor):
    a = doc['accessors'][accessor]
    view = doc['bufferViews'][a['bufferView']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    fmt = {5126: 'f', 5123: 'H', 5125: 'I', 5121: 'B'}[a['componentType']]
    size = struct.calcsize(fmt) * width
    start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    return [struct.unpack_from('<' + fmt * width, blob, start + i * view.get('byteStride', size)) for i in range(a['count'])]


def mesh_pairs(doc, blob, name):
    node = next(n for n in doc['nodes'] if n['name'] == name)
    pairs = set()
    for p in doc['meshes'][node['mesh']]['primitives']:
        points = values(doc, blob, p['attributes']['POSITION'])
        uvs = values(doc, blob, p['attributes']['TEXCOORD_0'])
        pairs.update(tuple(round(v, 5) for v in (*point, *uv)) for point, uv in zip(points, uvs))
    return pairs


def run():
    failures = []
    if not (OUT / 'goemon.glb').exists():
        print('FAIL: Goemon cosplay baseline and variants have not been built')
        return 1
    base, binary = read(OUT / 'goemon.glb')
    expected = {name: mesh_pairs(base, binary, name) for name in ['Skin', 'Hair_Normal']}
    for hero in HEROES:
        try:
            doc, blob = read(OUT / (hero + '.glb'))
            names = {n['name'] for n in doc['nodes']}
            for name in expected:
                actual = mesh_pairs(doc, blob, name)
                # Rogue faces +Z. glTF bakes the 180-degree orientation into
                # skinned positions; compare in the original Goemon space.
                if hero != 'edo':
                    actual = {(-x, y, -z, u, v) for x, y, z, u, v in actual}
                assert len(actual) == len(expected[name]), f'{name} lost vertices or UV seams'
                assert all(any(max(abs(a-b) for a,b in zip(p,q)) < .000025 for q in actual)
                           for p in expected[name]), f'{name} geometry/UV differs from Goemon'
            assert len(doc['skins'][0]['joints']) == 22, 'Goemon skeleton was changed'
            assert any(n.startswith('Costume_') for n in names), 'costume missing'
            if hero != 'edo':
                assert {'Driver_Body', 'Driver_Head', 'Driver_Arm_L', 'Driver_Arm_R', 'Driver_Leg_L', 'Driver_Leg_R', 'Weapon_Cutlass'} <= names, 'native animation/weapon pivots missing'
            print('PASS:', hero, 'exact Goemon base, UVs, 22-bone rig and costume')
        except (AssertionError, KeyError, StopIteration, FileNotFoundError) as exc:
            failures.append(f'{hero}: {exc}')
    for error in failures:
        print('FAIL:', error)
    print(f'GOEMON_COSPLAY_ASSETS: {len(HEROES) - len(failures)}/{len(HEROES)} passed')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(run())
