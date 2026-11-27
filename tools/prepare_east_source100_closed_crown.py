"""Private one-tree closed crown study; no catalog, runtime or source-art writes."""
from collections import Counter, deque
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13'
OUT = BASE / 'Tree Closed Crown Candidate'
SOURCE = BASE / 'Tree Leaf Only Candidate/10074-native.png'
NATIVE = ROOT / 'assets/maps/falan/east_region/native_trees'
# Measured visible foliage groups; subdivision and hidden half-depth are inferred.
LOBES = [(68, 0, 171, 112), (14, 34, 94, 103), (145, 44, 212, 122),
         (2, 108, 102, 194), (68, 85, 164, 178), (128, 106, 224, 196),
         (46, 156, 175, 233), (150, 166, 214, 224)]


def prepare():
    original = Image.open(SOURCE).convert('RGBA')
    leaves = Image.open(NATIVE / '10074-foliage.png').convert('RGBA')
    native = json.loads((NATIVE / 'data.json').read_text())['graphics']['10074']
    assert hashlib.sha256(original.tobytes()).hexdigest() == native['source_rgba_sha256']
    width, height = original.size
    # Retain the original canopy/wood separation. Olive lower bark is not foliage.
    alpha = leaves.getchannel('A')
    mask = {(x, y) for y in range(235) for x in range(width)
            if alpha.getpixel((x, y)) >= 128}
    # Filled internal holes influence only thickness. Geometry keeps source gaps.
    exterior = set()
    queue = deque([(-1, -1)])
    while queue:
        x, y = queue.popleft()
        if (x, y) in exterior or (x, y) in mask:
            continue
        if not (-1 <= x <= width and -1 <= y <= 235):
            continue
        exterior.add((x, y))
        queue.extend((x + dx, y + dy) for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)))
    envelope = {(x, y) for y in range(235) for x in range(width)} - exterior
    distance = {p: 0 for p in envelope}
    queue.clear()
    for x, y in envelope:
        if any((x + dx, y + dy) not in envelope for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0))):
            distance[x, y] = 1
            queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            q = (x + dx, y + dy)
            if q in distance and distance[q] == 0:
                distance[q] = distance[x, y] + 1
                queue.append(q)

    vertices, triangles, lookup = [], [], {}

    def vertex(point):
        key = tuple(round(v, 6) for v in point)
        if key not in lookup:
            lookup[key] = len(vertices)
            vertices.append(key)
        return lookup[key]

    def value(point):
        x, y = point
        return alpha.getpixel((min(width - 1, int(x)), min(height - 1, int(y)))) / 255 if y < 235 else 0

    def clip(triangle):
        result = []
        for a, b in zip(triangle, triangle[1:] + triangle[:1]):
            av, bv = value(a), value(b)
            if av >= .5:
                result.append(a)
            if (av >= .5) != (bv >= .5):
                t = (.5 - av) / (bv - av)
                result.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
        return result

    for y in range(0, 235, 2):
        for x in range(0, width, 2):
            a, b, c, d = (x, y), (min(x + 2, width - 1), y), (min(x + 2, width - 1), min(y + 2, 235)), (x, min(y + 2, 235))
            for tri in ([a, b, c], [a, c, d]):
                polygon = clip(tri)
                for i in range(1, len(polygon) - 1):
                    ids = [vertex(polygon[j]) for j in (0, i, i + 1)]
                    if len(set(ids)) == 3:
                        triangles.append(ids)
    counts = Counter(tuple(sorted((a, b))) for tri in triangles for a, b in zip(tri, tri[1:] + tri[:1]))
    assert all(n in (1, 2) for n in counts.values())
    edges = [(a, b) for tri in triangles for a, b in zip(tri, tri[1:] + tri[:1]) if counts[tuple(sorted((a, b)))] == 1]
    blur = original.filter(ImageFilter.GaussianBlur(12))
    depths = []
    for x, y in vertices:
        depth = 0
        for left, top, right, bottom in LOBES:
            u = (x - (left + right) * .5) / ((right - left) * .5)
            v = (y - (top + bottom) * .5) / ((bottom - top) * .5)
            # Round the individual visible clumps, rather than extruding one leaf-shaped slab.
            radius = min(3.8, (right - left) * .5 * 3 / (32 * math.sqrt(2)))
            depth = max(depth, radius * math.sqrt(max(0, 1 - u * u - v * v)))
        shade = sum(blur.getpixel((min(width - 1, int(x)), min(height - 1, int(y))))[:3]) / 765
        depths.append(round(.08 + depth * (.90 + .2 * shade), 6))
    # Independent repeated leaf grain uses one opaque native micro-patch only.
    _, px, py = max((sum(original.getpixel((xx, yy))[3] >= 250
                         for yy in range(y, y + 24) for xx in range(x, x + 24)), x, y)
                    for y in range(20, 190, 8) for x in range(24, width - 48, 8))
    patch = original.crop((px, py, px + 24, py + 24)).convert('RGB')
    tile = Image.new('RGB', (48, 48))
    tile.paste(patch, (0, 0)); tile.paste(ImageOps.mirror(patch), (24, 0))
    tile.paste(ImageOps.flip(tile.crop((0, 0, 48, 24))), (0, 24))
    OUT.mkdir(parents=True, exist_ok=True)
    original.save(OUT / '10074-native.png')
    tile.save(OUT / 'leaf-grain.png')
    source = {'schema': 1, 'status': 'PRIVATE_UNREVIEWED_ONE_TREE', 'graphic': 10074,
              'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'source_rgba_sha256': hashlib.sha256(original.tobytes()).hexdigest(),
              'native_leaf_mask_sha256': hashlib.sha256((NATIVE / '10074-foliage.png').read_bytes()).hexdigest(),
              'leaf_only_bottom': 235, 'source_leaf_pixels': len(mask), 'closed_internal_holes_for_depth_only': len(envelope - mask),
              'source_visible_lobe_boxes': LOBES,
              'native_pixels_per_horizontal_world_unit': 32 * math.sqrt(2) / 3,
              'rear_texture_repeats_per_world_unit': 32 * math.sqrt(2) / (3 * 48),
              'vertices': vertices, 'front_triangles': triangles, 'boundary_edges': edges, 'depths': depths,
              'leaf_grain_native_crop': [px, py, px + 24, py + 24],
              'reuse': ['Existing source-traced Native27 wood, unchanged', 'Existing native-skin/source projection and original-owner Y frame'],
              'inferences': ['Hidden rounded clump depth from eight visible native foliage groups; major source gaps are physically retained.',
                             'Closed reverse uses independently repeated 24px native leaf micro-grain, never the whole front.',
                             'No camera-dependent discard, map, support, Native, source origin or collision changes.']}
    # Every boundary is closed by the runtime side strip; no orphan edge is discarded.
    assert len(depths) == len(vertices) and all(0 < d < 4.2 for d in depths)
    assert len(edges) == sum(n == 1 for n in counts.values())
    (OUT / 'source.json').write_text(json.dumps(source, separators=(',', ':')) + '\n')
    print(f'PRIVATE closed crown: {len(vertices)} points, {len(triangles)} front triangles, {len(edges)} closed rim edges')


if __name__ == '__main__':
    prepare()
