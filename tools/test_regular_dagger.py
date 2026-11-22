"""Keep the selected dagger's pixels, flight orientation and preserved kunai."""
from pathlib import Path
import tempfile
import unittest

from PIL import Image

from recover_crossgate_kaz_skins import KAZ, prepare_dagger

ROOT = Path(__file__).resolve().parents[1]


class RegularDaggerTest(unittest.TestCase):
    def test_prepared_flight_art(self):
        source = Image.open(ROOT / 'assets/ui/crossgate/weapons/defaults/knife.png').convert('RGBA')
        atlas = Image.open(KAZ.parent / 'maze/regular-dagger.png').convert('RGBA')
        self.assertEqual(atlas.size, (768, 48))
        colors = set(source.getdata())
        for direction in range(16):
            frame = atlas.crop((direction * 48, 0, (direction + 1) * 48, 48))
            left, top, right, bottom = frame.getbbox()
            self.assertTrue(0 < left < right < 48 and 0 < top < bottom < 48)
            self.assertTrue(all(pixel in colors for pixel in frame.getdata() if pixel[3]))
        # The silver blade points right in frame zero; the gold guard stays behind it.
        frame = atlas.crop((0, 0, 48, 48))
        silver = [x for y in range(48) for x in range(48)
                  if (lambda p: p[3] and min(p[:3]) > 180)(frame.getpixel((x, y)))]
        gold = [x for y in range(48) for x in range(48)
                if (lambda p: p[3] and p[0] > p[2] * 1.5 and p[0] > 100)(frame.getpixel((x, y)))]
        self.assertGreater(sum(silver) / len(silver), sum(gold) / len(gold))
        preserved = (KAZ.parent / 'maze/dagger.png').read_bytes()
        with tempfile.TemporaryDirectory() as folder:
            prepare_dagger(Path(folder))
            with Image.open(Path(folder) / 'regular-dagger.png') as regenerated:
                self.assertEqual(regenerated.tobytes(), atlas.tobytes())
        self.assertEqual((KAZ.parent / 'maze/dagger.png').read_bytes(), preserved)


if __name__ == '__main__':
    unittest.main()
