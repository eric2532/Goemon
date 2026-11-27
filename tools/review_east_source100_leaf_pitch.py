"""Measure untouched native apparent leaves and the reused whole-canopy card/UV pitch."""
from pathlib import Path
import hashlib
import json
import math
import struct

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Tree Whole Canopy Candidate'
OUT = BASE / 'Leaf Pitch Audit'
MODEL = ROOT / 'assets/models/environments/wind_meadow/crossgate_flora/cg_woodland.glb'
TILE = MODEL.with_name('cg_woodland_cg_woodland.png')
NATIVE = BASE / '10074-native.png'
LEAVES = [(99, 215, 105, 224), (105, 216, 111, 225), (113, 219, 119, 226), (118, 207, 125, 217), (124, 211, 129, 219), (141, 216, 147, 226)]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def distribution(values):
    values = sorted(values)
    return {'min': values[0], 'p05': values[round((len(values) - 1) * .05)], 'median': values[len(values) // 2], 'p95': values[round((len(values) - 1) * .95)], 'max': values[-1]}


def main():
    blob = MODEL.read_bytes(); pos = 12; chunks = {}
    while pos < len(blob):
        length, kind = struct.unpack_from('<II', blob, pos); chunks[kind] = blob[pos + 8:pos + 8 + length]; pos += 8 + length
    gltf = json.loads(chunks[0x4e4f534a]); binary = chunks[0x004e4942]
    index = next(i for i, m in enumerate(gltf['meshes']) if m['name'] == 'Canopy')
    nodes = [n for n in gltf['nodes'] if n.get('mesh') == index]
    assert len(nodes) == 1
    assert nodes[0].get('translation', [0, 0, 0]) == [0, 0, 0] and nodes[0].get('scale', [1, 1, 1]) == [1, 1, 1]
    assert nodes[0].get('rotation', [0, 0, 0, 1]) == [0, 0, 0, 1] and 'matrix' not in nodes[0]
    primitive = gltf['meshes'][index]['primitives'][0]

    def array(key, fmt, components):
        a = gltf['accessors'][primitive['attributes'][key]]; v = gltf['bufferViews'][a['bufferView']]
        assert a['componentType'] == 5126
        offset = v.get('byteOffset', 0) + a.get('byteOffset', 0); stride = v.get('byteStride', components * 4)
        return [struct.unpack_from('<' + fmt, binary, offset + i * stride) for i in range(a['count'])]

    points, uvs = array('POSITION', 'fff', 3), array('TEXCOORD_0', 'ff', 2)
    assert len(points) == len(uvs) and len(points) % 4 == 0
    ppm = 32 * math.sqrt(2) / 3
    right = (1 / math.sqrt(2), 0, 1 / math.sqrt(2))
    eye = (-1, .72, 1); n = math.sqrt(sum(v * v for v in eye)); eye = tuple(v / n for v in eye)
    up = (eye[1] * right[2], eye[2] * right[0] - eye[0] * right[2], -eye[1] * right[0]); n = math.sqrt(sum(v * v for v in up)); up = tuple(v / n for v in up)
    dot = lambda p, q: sum(a * b for a, b in zip(p, q))
    span = max(dot(p, right) for p in points) - min(dot(p, right) for p in points)
    scale = (228 / ppm) / span
    metrics = {'edge_u_world_m': [], 'edge_v_world_m': [], 'projected_card_width_native_equiv_px': [], 'projected_card_height_native_equiv_px': [], 'u_world_m_per_texture_pixel': [], 'v_world_m_per_texture_pixel': []}
    for i in range(0, len(points), 4):
        assert uvs[i:i + 4] == [(0., 1.), (1., 1.), (1., 0.), (0., 0.)]
        p = [tuple(v * scale for v in q) for q in points[i:i + 4]]
        u = tuple(p[1][k] - p[0][k] for k in range(3)); v = tuple(p[3][k] - p[0][k] for k in range(3))
        ulen, vlen = math.sqrt(dot(u, u)), math.sqrt(dot(v, v))
        metrics['edge_u_world_m'].append(ulen); metrics['edge_v_world_m'].append(vlen)
        metrics['u_world_m_per_texture_pixel'].append(ulen / 32); metrics['v_world_m_per_texture_pixel'].append(vlen / 32)
        metrics['projected_card_width_native_equiv_px'].append((max(dot(q, right) for q in p) - min(dot(q, right) for q in p)) * ppm)
        metrics['projected_card_height_native_equiv_px'].append((max(dot(q, up) for q in p) - min(dot(q, up) for q in p)) * ppm)
    image = Image.open(NATIVE).convert('RGBA'); tile = Image.open(TILE).convert('RGBA')
    assert tile.size == (32, 32)
    pixels = list(tile.getdata()); mirror = list(ImageOps.mirror(tile).getdata()); flip = list(ImageOps.flip(tile).getdata())
    sample_records = [{'bounds': list(b), 'width_px': b[2] - b[0], 'height_px': b[3] - b[1], 'reference_world_width_m': (b[2] - b[0]) / ppm, 'reference_world_height_m': (b[3] - b[1]) / ppm} for b in LEAVES]
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGBA', (900, 180), (35, 45, 49, 255)); draw = ImageDraw.Draw(sheet)
    for i, b in enumerate(LEAVES):
        crop = image.crop(b); crop = crop.resize((crop.width * 12, crop.height * 12), Image.Resampling.NEAREST); sheet.alpha_composite(crop, (i * 150 + 25, 40)); draw.text((i * 150 + 5, 8), f'{i + 1}: {b[2] - b[0]}x{b[3] - b[1]} px', fill='white')
    sheet.save(OUT / 'observed-hanging-leaf-samples.png')
    records = {'scope': 'READ_ONLY one accepted-mass-direction canopy; no geometry/material/source changes.', 'source_files': {str(p.relative_to(ROOT)): sha(p) for p in [MODEL, TILE, NATIVE, Path(__file__)]}, 'uniform_whole_master_scale': scale, 'source_crown_width_world_m': 228 / ppm, 'native_reference_pixels_per_screen_world_m': ppm, 'native_apparent_leaf_samples': sample_records, 'native_sample_limits': 'Manually bounded clearly hanging visible leaf drawings near lower crown. Partial/occluded edges make this approximate apparent-size evidence, not botanical or exact segmentation proof.', 'existing_master_leaf_cards': len(points) // 4, 'quad_uv_contract': 'Every intact4vertexcard spans the full0..1 leaf-tile UV rectangle; vertices/UV/index untouched.', 'card_and_texture_metrics': {key: distribution(value) for key, value in metrics.items()}, 'source_tile': {'size': list(tile.size), 'alpha128_coverage_fraction': sum(c[3] >= 128 for c in pixels) / len(pixels), 'alpha255_coverage_fraction': sum(c[3] == 255 for c in pixels) / len(pixels), 'horizontal_exact_mirror_fraction': sum(a == b for a, b in zip(pixels, mirror)) / len(pixels), 'vertical_exact_mirror_fraction': sum(a == b for a, b in zip(pixels, flip)) / len(pixels)}, 'interpretation': ['Distinguish the size of each entire leaf-card plane from smaller painted leaf motifs inside its32px tile.', 'The existing tile is opaque over the full card; the current whole-master material does not clip a native rounded leaf contour. Card borders/tiling can therefore dominate even if painted motif texel pitch is near native.', 'Measure/preview a source-appropriate owned leaf material before resizing or duplicating the coherent whole-canopy geometry. No more stacked whole-tree copies.'], 'acceptance': 'Mass direction only accepted by Root; final foliage/reverse wood and actual-map views remain unfinished.'}
    (OUT / 'measurement.json').write_text(json.dumps(records, indent=2) + '\n')
    print(json.dumps({k: v for k, v in records.items() if k not in ['native_apparent_leaf_samples', 'source_files']}, indent=2))


if __name__ == '__main__':
    main()
