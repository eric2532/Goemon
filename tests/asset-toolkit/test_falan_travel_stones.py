"""Keep recovered travel art and original shrine pixels reproducible."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from recover_falan_travel_stones import recover


class TravelStonesTest(unittest.TestCase):
    def test_source_art_and_cells_are_preserved(self):
        folder = ROOT / 'assets/maps/falan'
        source = json.loads((folder / 'travel_stone_source.json').read_text())
        self.assertEqual(hashlib.sha256((folder / 'travel_stone.png').read_bytes()).hexdigest(), source['atlas_sha256'])
        self.assertEqual({tuple(s['mapCell']) for s in source['stones']},
                         {(141,146), (63,77), (244,100), (233,76), (74,123), (164,130)})
        atlas = Image.open(folder / 'travel_stone_ornaments.png')
        sizes = [(60,63), (68,62), (52,116), (48,138), (48,126), (48,137), (32,64)]
        for i, (w,h) in enumerate(sizes):
            tile = atlas.crop((i%4*144, i//4*144, i%4*144+w, i//4*144+h))
            self.assertEqual(hashlib.sha256(tile.tobytes()).hexdigest(), source['ornament_pixel_hashes'][str(17235+i)])

    def test_recovery_reproduces_bundled_assets(self):
        archive = ROOT.parent / 'Magic Power'
        if not archive.is_dir():
            self.skipTest('The preserved Blue CG source is not attached')
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            recover(archive, output)
            for path in output.iterdir():
                self.assertEqual(path.read_bytes(), (ROOT / 'assets/maps/falan' / path.name).read_bytes(), path.name)


if __name__ == '__main__':
    unittest.main()
