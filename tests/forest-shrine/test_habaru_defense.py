"""Check prepared defense pixels and preservation of the six existing Habaru clips."""
import hashlib
import json
import struct
import sys
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'assets/characters/crossgate/habaru'
SOURCE = ROOT.parent / 'Magic Power/tools'
sys.path.insert(0, str(SOURCE))
import cg_assets as cg


class HabaruDefense(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((PACK / 'motions.json').read_text())
        cls.rows = list(struct.iter_unpack('<4f', (PACK / 'frames.bin').read_bytes()))
        cls.palette = Image.open(PACK / 'palette.png').convert('RGBA')
        cls.pages = [Image.open(PACK / f'atlas-{i}.png') for i in range(cls.data['pages'])]

    def frame(self, index):
        rect = self.rows[self.data['clip_count'] + index * 2]
        ox, oy, page, palette = self.rows[self.data['clip_count'] + index * 2 + 1]
        x, y, w, h = map(int, rect)
        indices = self.pages[int(page)].crop((x, y, x+w, y+h)).tobytes()
        rgba = b''.join(bytes(self.palette.getpixel((i, int(palette)))) for i in indices)
        return Image.frombytes('RGBA', (w, h), rgba), ox, oy

    def test_original_defense(self):
        self.assertEqual(self.data['actions'], [0, 3, 5, 8, 10, 1, 9])
        ident, _, clips = cg.actor('original:2759')
        self.assertEqual(ident, self.data['variants'][0]['id'])
        idle = next(c for c in clips if c['action'] == 0 and c['direction'] == 4)
        idle_image, _, idle_y = cg.frame_parts('original:2759', idle['index'], 0)
        sys.path.insert(0, str(ROOT / 'tools'))
        from recover_habaru_encounter import body_rows
        _, foot = body_rows(idle_image)
        shift = idle_y + foot - 10
        for direction in range(8):
            clip = next(c for c in clips if c['action'] == 9 and c['direction'] == direction)
            start, count, duration, _ = self.rows[6*8+direction]
            self.assertEqual(count, len(clip['frames']))
            self.assertAlmostEqual(duration, clip['duration']/1000)
            for frame in range(int(count)):
                actual, ox, oy = self.frame(int(start)+frame)
                original, x, y = cg.frame_parts('original:2759', clip['index'], frame)
                bounds = original.getbbox()
                self.assertEqual(actual.tobytes(), original.crop(bounds).tobytes())
                self.assertEqual((ox, oy), (x+bounds[0], y+bounds[1]-shift))

    def test_existing_clips_preserved(self):
        baseline = ROOT / 'build/Other Files/Asset Toolkit/Habaru Counter/original-clips.json'
        if not baseline.exists():
            self.skipTest('One-time pre-change snapshot is unavailable')
        before = json.loads(baseline.read_text())
        for field in ['timelines', 'variants', 'sounds']:
            self.assertEqual(self.data[field], before[field])
        digest = hashlib.sha256()
        for skin in range(len(self.data['variants'])):
            for clip in range(6):
                for direction in range(8):
                    start, count, duration, scale = self.rows[(skin*7+clip)*8+direction]
                    digest.update(struct.pack('<iff', int(count), duration, scale))
                    for frame in range(int(start), int(start+count)):
                        image, ox, oy = self.frame(frame)
                        digest.update(struct.pack('<4f', ox, oy, *image.size))
                        digest.update(image.tobytes())
        self.assertEqual(digest.hexdigest(), before['decoded_sha256'])

    def test_bear_skill_icon(self):
        ident, _, clips = cg.actor('original:2807')
        self.assertEqual(ident, 101010)
        idle = next(c for c in clips if c['action'] == 0 and c['direction'] == 5)
        original, _, _ = cg.frame_parts('original:2807', idle['index'], 0)
        icon = Image.open(ROOT / 'assets/ui/crossgate/skills/summon-bears.png').convert('RGBA')
        self.assertEqual(icon.size, (128, 128))
        foreground = icon.crop((30, 38, 98, 128))
        for source, actual in zip(original.getdata(), foreground.getdata()):
            if source[3] == 255:
                self.assertEqual(actual, source)
        self.assertIsNotNone(icon.crop((0, 0, 56, 38)).getbbox())
        self.assertIsNotNone(icon.crop((72, 0, 128, 38)).getbbox())


if __name__ == '__main__':
    unittest.main()
