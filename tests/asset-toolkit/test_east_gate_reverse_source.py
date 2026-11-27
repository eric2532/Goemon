"""Inferred ornamental, masonry and sculpture backs retain their source outlines."""
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/maps/falan/east_region/landmarks'


class GoralGateReverse(unittest.TestCase):
    def test_carved_faces_keep_original_openings(self):
        for serial in (1233018, 1233019, 1233181, 1233182):
            with self.subTest(serial=serial):
                front = Image.open(ART / f'{serial}-front.png').convert('RGBA')
                back = Image.open(ART / f'{serial}-back.png').convert('RGBA')
                self.assertEqual(front.getchannel('A').tobytes(), back.getchannel('A').tobytes())
                colors = {pixel[:3] for pixel in back.getdata() if pixel[3] >= 192}
                self.assertGreater(len(colors), 64, 'The carved gate must not become a uniform reverse panel')

    def test_wall_reverse_keeps_closed_source_outline_and_surface_detail(self):
        for serial in (1233010, 1233011, 1233014, 1233015):
            with self.subTest(serial=serial):
                front = Image.open(ART / f'{serial}-front.png').convert('RGBA')
                back = Image.open(ART / f'{serial}-back.png').convert('RGBA')
                self.assertEqual(front.getchannel('A').tobytes(), back.getchannel('A').tobytes())
                colors = {p[:3] for p in back.getdata() if p[3] >= 192}
                self.assertGreater(len(colors), 128, 'Masonry and coping need independent painted detail')
                self.assertNotEqual(front.tobytes(), back.tobytes(), 'The unseen wall body must not copy a front doorway')

    def test_sculpture_reverse_has_independent_stone_grain(self):
        for serial in (1235176, 1235177, 1235178):
            with self.subTest(serial=serial):
                front = Image.open(ART / f'{serial}-front.png').convert('RGBA')
                back = Image.open(ART / f'{serial}-back.png').convert('RGBA')
                self.assertEqual(front.getchannel('A').tobytes(), back.getchannel('A').tobytes())
                self.assertGreater(len({p[:3] for p in back.getdata() if p[3] >= 192}), 8,
                                   'The sculpture must not become a uniform gray cutout')
                self.assertNotEqual(front.tobytes(), back.tobytes())


if __name__ == '__main__':
    unittest.main()
