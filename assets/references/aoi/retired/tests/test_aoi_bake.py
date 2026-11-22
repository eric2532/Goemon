"""The new sprite character must keep its complete source clock and atlas data."""
import hashlib
import json
from pathlib import Path
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / 'assets/characters/crossgate/fighters/aoi'


class AoiBakeTest(unittest.TestCase):
    def test_complete_preserved_clock_and_valid_pixels(self):
        data = json.loads((ASSET / 'motions.json').read_text())
        source = ROOT / 'assets/characters/crossgate/kazi/motions.json'
        clock = json.loads(source.read_text())
        master = ROOT / 'assets/blender/characters/aoi/aoi.blend'
        self.assertEqual(data['authoring']['master_sha256'], hashlib.sha256(master.read_bytes()).hexdigest())
        self.assertEqual(data['authoring']['clock_sha256'], hashlib.sha256(source.read_bytes()).hexdigest())
        self.assertEqual(data['authoring']['pipe_multiplier'], 4)
        self.assertAlmostEqual(data['authoring']['pipe_length'], .95 * 4)
        self.assertEqual(set(data['clips']), {f'{a}:{d}' for a in [0, 1, 3, 5, 6, 8, 9, 10] for d in range(8)})
        atlases = [Image.open(ASSET / f'atlas-{i}.png').convert('RGBA') for i in range(data['pages'])]
        for key, clip in data['clips'].items():
            if key in clock['clips']:
                self.assertEqual(clip['duration'], clock['clips'][key]['duration'])
                self.assertEqual(len(clip['frames']), len(clock['clips'][key]['frames']))
            pixels = set()
            for page, x, y, w, h, ox, oy in clip['frames']:
                atlas = atlases[page]
                self.assertGreater(x, 0)
                self.assertGreater(y, 0)
                self.assertLessEqual(x + w, atlas.width)
                self.assertLessEqual(y + h, atlas.height)
                image = atlas.crop((x, y, x + w, y + h))
                self.assertIsNotNone(image.getbbox())
                self.assertEqual(image.getchannel('A').getextrema(), (0, 255))
                pixels.add(hashlib.sha256(image.tobytes()).hexdigest())
            if key.startswith('9:'):
                self.assertEqual(len(clip['frames']), 1, 'The source guard is a held pose')
            else:
                self.assertGreater(len(pixels), 1, key + ' needs real motion')
            if key.startswith('5:'):
                self.assertEqual(clip['contacts'], [.6 * 5 / 11, .6 * 6 / 11])


if __name__ == '__main__':
    unittest.main()
