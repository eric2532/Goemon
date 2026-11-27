"""Verify cached spider frames against original RGBA, not just species IDs."""
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
import cg_assets as cg
from prepare_east_region_population import stage_native_refresh
from recover_habaru_encounter import body_rows


class ReusedNativeFramesTest(unittest.TestCase):
    def test_direct_original_variant_cannot_be_overwritten_by_body_reference(self):
        with tempfile.TemporaryDirectory(prefix='crossgate-direct-variant-') as temporary:
            folder = Path(temporary)
            with self.assertRaisesRegex(AssertionError, 'body-fit reference'):
                stage_native_refresh([81, 83], folder)
            self.assertFalse(list(folder.iterdir()))

    def test_every_spider_frame_matches_original_pixels_and_preserved_anchor(self):
        with tempfile.TemporaryDirectory(prefix='crossgate-native-refresh-') as temporary:
            folder = Path(temporary)
            report = stage_native_refresh([103, 104], folder)
            data = json.loads((folder / 'motions.json').read_text())
            table = list(struct.iter_unpack('<4f', (folder / 'frames.bin').read_bytes()))
            palette = Image.open(ROOT / 'assets/characters/crossgate/east_region/palette.png').convert('RGBA')
            images = {}; colors = {}; checked = 0
            for skin, key in [(103, 'original:2874'), (104, 'original:2872')]:
                ident, _, original_clips = cg.actor(key)
                self.assertEqual(ident, data['variants'][skin]['id'])
                clips = {(c['action'], c['direction']): c for c in original_clips}
                idle, _, y = cg.frame_parts(key, clips[0, 4]['index'], 0)
                _, foot = body_rows(idle); shift = y + foot - 10
                for action_index, action in enumerate(data['actions']):
                    for direction in range(8):
                        clip = table[(skin * len(data['actions']) + action_index) * 8 + direction]
                        original = clips[action, direction]
                        self.assertEqual(int(clip[1]), len(original['frames']))
                        self.assertAlmostEqual(clip[2], original['duration'] / 1000, places=5)
                        for index in range(int(clip[1])):
                            frame = int(clip[0]) + index
                            x, y, w, h = map(int, table[data['clip_count'] + frame * 2])
                            ox, oy, page, row = table[data['clip_count'] + frame * 2 + 1]
                            path = data['atlas_paths'][int(page)]
                            if path not in images: images[path] = Image.open(ROOT / path.removeprefix('res://')).convert('L')
                            if row not in colors:
                                columns = palette.width // 256
                                colors[row] = [palette.getpixel((i + int(row) % columns * 256, int(row) // columns)) for i in range(256)]
                            image = Image.new('RGBA', (w, h))
                            image.putdata([colors[row][i] for i in images[path].crop((x, y, x+w, y+h)).getdata()])
                            source, sx, sy = cg.frame_parts(key, original['index'], index)
                            box = source.getbbox(); source = source.crop(box)
                            self.assertEqual(image.size, source.size, (skin, action, direction, index))
                            self.assertEqual(image.tobytes(), source.tobytes(), (skin, action, direction, index))
                            self.assertEqual((ox, oy), (sx + box[0], sy + box[1] - shift))
                            checked += 1
            self.assertEqual(checked, 1296)
            self.assertTrue(report['unrelated_rows_preserved'])


if __name__ == '__main__': unittest.main()
