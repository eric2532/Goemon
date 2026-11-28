"""Preserve established native kits and authenticate the appended source frames."""
import hashlib
import json
from pathlib import Path
import struct
import unittest
from PIL import Image
import test_explore_laboratory_native as laboratory

ROOT = laboratory.ROOT
BANK = laboratory.BANK
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Explore Access/Frontier native'
BASE = max(REPORT.glob('Before append-*'), key=lambda path: int(path.name.rsplit('-', 1)[1]))


class FrontierNativeTest(unittest.TestCase):
    def test_existing_kits_are_exact(self):
        old = json.loads((BASE / 'motions.json').read_text())
        new = json.loads((BANK / 'motions.json').read_text())
        self.assertEqual(len(old['variants']), int(BASE.name.rsplit('-', 1)[1]))
        for key in ['variants', 'timelines', 'atlas_paths', 'skin_pages', 'variant_heights', 'variant_sources']:
            self.assertEqual(new[key][:len(old[key])], old[key], key)
        for cue, path in old['sounds'].items():
            self.assertEqual(new['sounds'][cue], path)
        a = list(struct.iter_unpack('<4f', (BASE / 'frames.bin').read_bytes()))
        b = list(struct.iter_unpack('<4f', (BANK / 'frames.bin').read_bytes()))
        self.assertEqual(a[:old['clip_count']], b[:old['clip_count']])
        count = max(int(r[0] + r[1]) for r in a[:old['clip_count']]) * 2
        self.assertEqual(a[old['clip_count']:old['clip_count'] + count], b[new['clip_count']:new['clip_count'] + count])
        with Image.open(BASE / 'palette.png') as original, Image.open(BANK / 'palette.png') as current:
            self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(), hashlib.sha256(current.crop((0, 0, *original.size)).tobytes()).hexdigest())
        species = json.loads((BASE / 'species.json').read_text())
        self.assertEqual(json.loads((BANK / 'species.json').read_text())[:len(species)], species)

    def test_all_added_frames_and_cues_match_originals(self):
        proof = laboratory.LaboratoryNativeTest(methodName='runTest')
        proof.new = json.loads((BANK / 'motions.json').read_text())
        proof.b = list(struct.iter_unpack('<4f', (BANK / 'frames.bin').read_bytes()))
        species = json.loads((BANK / 'species.json').read_text())
        for skin in range(174, len(species)):
            row = species[skin]
            with self.subTest(skin=skin, appearance=row['id']):
                proof.check_original(row['key'], skin, row['id'], remapped_cues=row.get('prepared_from') is not None, report=REPORT)

    def test_incomplete_source_parties_remain_explicit(self):
        staged = json.loads((REPORT / 'encounters-staged.json').read_text())
        for pool in staged['zones'] + list(staged['bosses'].values()):
            if pool['preparation_blockers']:
                self.assertEqual(pool['groups'], [])
            for key, weight in pool['groups']:
                self.assertGreater(weight, 0)
                self.assertTrue(staged['groups'][key]['members'])


if __name__ == '__main__':
    unittest.main()
