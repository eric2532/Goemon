"""Protect native dark paint while excluding transparent checkerboard ground shadow."""
from pathlib import Path
import sys
import unittest
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
from recover_venoa_walls import solid_native_paint


class VenoaPaintTest(unittest.TestCase):
    def test_shadow_mask_preserves_interior_pigment(self):
        source = Image.new('RGBA', (24, 24))
        draw = ImageDraw.Draw(source)
        draw.rectangle((3, 2, 20, 12), fill=(180, 165, 135, 255))
        draw.rectangle((8, 5, 12, 9), fill=(15, 34, 17, 255))
        draw.rectangle((15, 5, 17, 8), fill=(71, 71, 71, 255))
        count = 0
        for y in range(15, 23):
            for x in range(2, 22):
                if (x+y) % 2 == 0:
                    source.putpixel((x, y), (71, 71, 71, 255))
                    count += 1
        paint, removed = solid_native_paint(source)
        self.assertEqual(removed, count)
        self.assertEqual(paint.getpixel((9, 6)), source.getpixel((9, 6)))
        self.assertEqual(paint.getpixel((16, 6)), source.getpixel((16, 6)))
        self.assertNotEqual(paint.getpixel((3, 15)), (71, 71, 71, 255))
        self.assertEqual(paint.getchannel('A').getextrema(), (255, 255))


if __name__ == '__main__':
    unittest.main()
