"""The approved surface changes must not alter recovered motion or equipment contracts."""
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from asset_pipeline.glb import GLB


class SoldierPolishTest(unittest.TestCase):
    def test_original_motion_textures_and_rigid_parts_survive(self):
        provenance = json.loads((ROOT / 'assets/models/enemies/thirstquencher/provenance.json').read_text())
        for ident in (1, 2, 3):
            with self.subTest(variant=ident):
                source = GLB.read(ROOT / f'assets/characters/thirstquencher/soldier_{ident}.glb')
                polished = GLB.read(ROOT / f'assets/models/enemies/thirstquencher/soldier_{ident}.glb')
                self.assertEqual(source.animation_digest(), polished.animation_digest())
                self.assertEqual(source.doc['skins'], polished.doc['skins'])
                for a, b in zip(source.doc['skins'], polished.doc['skins']):
                    self.assertEqual(source.accessor(a['inverseBindMatrices']), polished.accessor(b['inverseBindMatrices']))
                self.assertEqual([n.get('name') for n in source.doc['nodes']],
                                 [n.get('name') for n in polished.doc['nodes']])
                self.assertEqual([source.image_bytes(i) for i in source.doc['images']],
                                 [polished.image_bytes(i) for i in polished.doc['images']])
                self.assertEqual(source.doc['samplers'], polished.doc['samplers'])
                self.assertEqual(len(polished.doc['meshes']), 11)
                for original, candidate in zip(source.doc['meshes'], polished.doc['meshes']):
                    old = [v for p in original['primitives'] for v in source.accessor(p['attributes']['POSITION'])]
                    new = [v for p in candidate['primitives'] for v in polished.accessor(p['attributes']['POSITION'])]
                    for axis in range(3):
                        self.assertGreaterEqual(min(v[axis] for v in new), min(v[axis] for v in old) - 1e-5)
                        self.assertLessEqual(max(v[axis] for v in new), max(v[axis] for v in old) + 1e-5)
                    for primitive in candidate['primitives']:
                        attributes = primitive['attributes']
                        self.assertIn('COLOR_0', attributes)
                        weights = polished.accessor(attributes['WEIGHTS_0'])
                        self.assertTrue(all(abs(w[0] - 1) < 1e-6 and not any(w[1:]) for w in weights))
                from asset_pipeline.glb import digest
                entry = provenance[ident - 1]
                self.assertEqual(entry['source_sha256'], digest((ROOT / f'assets/blender/enemies/thirstquencher/soldier_{ident}.blend').read_bytes()))
                self.assertEqual(entry['glb_sha256'], digest(polished.path.read_bytes()))
