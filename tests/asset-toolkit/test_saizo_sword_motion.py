import json
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
import cg_assets as cg
import cg_sounds
from recover_crossgate_saizo import RECORDS


class SaizoSwordMotionTest(unittest.TestCase):
    def test_original_single_cut_pixels_order_clock_and_markers(self):
        for skin in RECORDS:
            folder = ROOT / f'assets/characters/crossgate/fighters/saizo/{skin}'
            data = json.loads((folder / 'motions.json').read_text())
            atlas = Image.open(folder / 'atlas-0.png').convert('RGBA')
            for original in cg.actor(data['key'])[2]:
                if original['action'] != 5:
                    continue
                with self.subTest(skin=skin, direction=original['direction']):
                    saved = data['clips'][f'5:{original["direction"]}']
                    self.assertEqual(saved['source_frames'], list(range(len(original['frames']))))
                    self.assertEqual(saved['duration'], original['duration']/1000)
                    cues = cg_sounds.clip_cues(original)
                    self.assertEqual([(c['frame'], c['id']) for c in cues], [(5, 105), (6, 133)])
                    self.assertEqual(saved['contacts'], [cues[1]['atMs']/1000])
                    self.assertEqual(saved['sounds'], cues[:1])
                    for index, region in enumerate(saved['frames']):
                        image, x, y = cg.frame_parts(data['key'], original['index'], index)
                        box = image.getbbox()
                        page, left, top, width, height, ox, oy = region
                        self.assertEqual(page, 0)
                        self.assertEqual((ox, oy), (x+box[0], y+box[1]))
                        self.assertEqual(atlas.crop((left, top, left+width, top+height)).tobytes(), image.crop(box).tobytes())


if __name__ == '__main__':
    unittest.main()
