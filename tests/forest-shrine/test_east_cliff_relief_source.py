"""Source and closed-mesh contracts for the scoped East cliff derivative."""
import collections
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import unittest
import zlib

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / 'assets/maps/falan/east_field_cliffs/relief'


def geometry(serial):
    binary = (ASSET / f'{serial}.bin').read_bytes()
    assert binary[:4] in [b'ECR2', b'ECR3']
    paint_stride = 12 if binary[:4] == b'ECR3' else 8
    ns, np, ni, npi, length = struct.unpack_from('<IIIII', binary, 4)
    raw = zlib.decompress(binary[24:])
    assert len(raw) == length
    offset = ns * 40
    solid = list(struct.iter_unpack('<10f', raw[:offset]))
    paint = list(struct.iter_unpack('<'+str(paint_stride)+'f', raw[offset:offset + np * paint_stride * 4]))
    offset += np * paint_stride * 4
    ids = list(struct.unpack_from(f'<{ni}I', raw, offset))
    paint_ids = list(struct.unpack_from(f'<{npi}I', raw, offset + ni * 4))
    assert offset + (ni + npi) * 4 == length
    return binary, solid, paint, ids, paint_ids


class EastCliffReliefSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((ASSET / 'data.json').read_text())
        cls.profile_path = ROOT / cls.data['source_profile']
        cls.profiles = json.loads(cls.profile_path.read_text())

    def test_exact_six_native_families_and_profile_provenance(self):
        self.assertEqual({12536, 12537, 12538, 12542, 12543, 12546}, set(map(int, self.data['graphics'])))
        digest = hashlib.sha256(self.profile_path.read_bytes()).hexdigest()
        for token, row in self.data['graphics'].items():
            with self.subTest(graphic=token):
                native = self.profiles['profiles'][token]
                self.assertEqual(digest, row['source_profile_sha256'])
                self.assertEqual(native['rgba_sha256'], row['native_rgba_sha256'])
                self.assertIn('inferred', row['inference'])
                self.assertEqual(64, len(row['measured_native_lobes']))

    def test_source_fitted_bounds_and_closed_stone_body(self):
        for token, row in self.data['graphics'].items():
            with self.subTest(graphic=token):
                binary, solid, paint, ids, paint_ids = geometry(token)
                self.assertEqual(hashlib.sha256(binary).hexdigest(), row['geometry_sha256'])
                self.assertEqual(len(ids) // 3, row['solid_triangles'])
                self.assertEqual(len(paint_ids) // 3, row['paint_triangles'])
                foot = row['source_footprint']
                center = [(foot[0] - 1) * 1.5, 0, -(foot[1] - 1) * 1.5]
                measured = row['geometry_bounds']
                for axis in range(3):
                    self.assertAlmostEqual(max(v[axis] for v in solid) + center[axis], measured[1][axis], places=4)
                    self.assertAlmostEqual(min(v[axis] for v in solid) + center[axis], measured[0][axis], places=4)
                if 'maximum_inferred_lateral_overhang_m' in row:
                    fitted = row['source_contour']['fitted_source_bounds']
                    self.assertAlmostEqual(measured[0][1], fitted[0][1], places=4)
                    self.assertAlmostEqual(measured[1][1], fitted[1][1], places=4)
                    inferred = max([0.] + [fitted[0][a]-measured[0][a] for a in [0, 2]] + [measured[1][a]-fitted[1][a] for a in [0, 2]])
                    self.assertAlmostEqual(inferred, row['maximum_inferred_lateral_overhang_m'], places=5)
                    self.assertLessEqual(inferred, row['maximum_inferred_relief_m'] + 1e-5)
                    self.assertEqual(3, row['base_loop_subdivisions'])
                    self.assertEqual(1, row['source_patch_refinement'])
                    self.assertTrue(14336 <= len(ids)//3 <= 57344)
                    centres = [p['center'] for p in row['measured_native_lobes']]
                    continuation = row['hidden_patch_continuation']
                    self.assertTrue(continuation['source_lobe_centres'])
                    for centre in continuation['source_lobe_centres']:
                        self.assertIn(centre, centres)
                if binary[:4] == b'ECR3':
                    covered = row['source_paint_triangles']
                    self.assertEqual(len(covered), len(set(covered)))
                    self.assertEqual(len(covered) * 3, len(paint_ids))
                    for front_triangle, source_triangle in enumerate(covered):
                        for vertex in range(3):
                            original = solid[ids[source_triangle * 3 + vertex]][:3]
                            painted = paint[paint_ids[front_triangle * 3 + vertex]][:3]
                            for a, b in zip(original, painted):
                                self.assertAlmostEqual(a, b, places=5, msg='Paint replaces the exact body face without an offset')
                edges = collections.Counter()
                for start in range(0, len(ids), 3):
                    points = [tuple(round(v, 5) for v in solid[i][:3]) for i in ids[start:start + 3]]
                    for i in range(3):
                        edges[tuple(sorted((points[i], points[(i + 1) % 3])))]+=1
                self.assertEqual({2}, set(edges.values()), 'All stone edges must have two incident faces')
                self.assertGreater(max(p[2] for p in solid) - min(p[2] for p in solid), 8.)

    def test_paint_follows_original_projection_without_uv_edge_clamping(self):
        for token, row in self.data['graphics'].items():
            with self.subTest(graphic=token):
                _, solid, paint, _, paint_ids = geometry(token)
                with Image.open(ASSET / f'{token}.png') as source_image:
                    image = source_image.copy()
                self.assertEqual(hashlib.sha256((ASSET / f'{token}.png').read_bytes()).hexdigest(), row['paint_png_sha256'])
                center = [(row['source_footprint'][0] - 1) * 1.5, 0, -(row['source_footprint'][1] - 1) * 1.5]
                for v in paint:
                    x, y, z = [v[i] + center[i] for i in range(3)]
                    u = (x + z) * 32 / 3 - row['source_origin'][0]
                    w = (z - x) * 8 - y / row['pixel_height'] - row['source_origin'][1]
                    self.assertAlmostEqual(u, v[-2] * image.width, places=3)
                    self.assertAlmostEqual(w, v[-1] * image.height, places=3)
                    self.assertTrue(0 <= v[-2] < 1 and 0 <= v[-1] < 1)
                    self.assertAlmostEqual(math.sqrt(sum(n * n for n in v[3:6])), 1., places=4)
                self.assertLess(row['maximum_source_projection_error_pixels'], 1e-9)
                self.assertGreater(row['maximum_inferred_relief_m'], .2)
                self.assertLessEqual(row['maximum_inferred_relief_m'], .701)

    def test_every_native_rgb_is_preserved(self):
        sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
        import cg_library as lib
        lookup = lib.serial_index()
        for token, row in self.data['graphics'].items():
            with self.subTest(graphic=token):
                source = lookup[int(token)]
                original = lib.image_from_record(source['pack'], source['row']).convert('RGBA')
                prepared = Image.open(ASSET / f'{token}.png').convert('RGBA')
                self.assertEqual(original.convert('RGB').tobytes(), prepared.convert('RGB').tobytes())
                for old, new in zip(original.getdata(), prepared.getdata()):
                    self.assertIn(new[3], [old[3], 0])
                self.assertTrue(row['source_rgb_preserved'])
                for sample in row.get('source_contour', {}).get('confirmed_overhang_samples', []):
                    x, y = sample['native_pixel']
                    self.assertEqual(list(original.getpixel((x, y))), sample['rgba'])
                    self.assertGreaterEqual(sample['rgba'][3], 128)
                    self.assertGreater(max(sample['rgba'][:3]), 45)


if __name__ == '__main__':
    unittest.main()
