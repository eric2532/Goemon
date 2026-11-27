"""Dark original wall paint must survive the opaque solid-atlas derivative."""
from pathlib import Path
import json
import sys
import unittest
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import recover_original_crossgate_maps as original
import prepare_east_region_maps as east


class WallPaintTest(unittest.TestCase):
    def test_published_room_wall_pixels_match_original_atlases(self):
        root = ROOT / 'assets/maps/original_crossgate'
        base_pages = len(json.loads((root / 'catalog.json').read_text())['pages'])
        checked = 0
        for path in [root / 'catalog.json', root / 'university/catalog.json',
                     ROOT / 'assets/maps/falan/sokia/fixed/catalog.json', root / 'east/catalog.json']:
            data = json.loads(path.read_text())
            prefix = path.parent if 'fixed' in path.parts else root
            offset = base_pages if path.parent.name == 'university' else 0
            by_page = {}
            for serial, row in data['graphics'].items():
                if row.get('family') == 'room_wall': by_page.setdefault(row['page'] - offset, []).append((serial, row))
            for page, rows in by_page.items():
                with Image.open(prefix / data['pages'][page]) as png: source = png.convert('RGBA')
                with Image.open(prefix / data['solid_pages'][page]) as png: solid = png.convert('RGB')
                for serial, row in rows:
                    x, y, w, h = row['rect']; art = source.crop((x, y, x+w, y+h))
                    mask = art.getchannel('A').point(lambda value: 255 if value else 0)
                    difference = ImageChops.difference(solid.crop((x, y, x+w, y+h)), art.convert('RGB'))
                    difference.paste((0, 0, 0), (0, 0, w, h), ImageChops.invert(mask))
                    self.assertIsNone(difference.getbbox(), (path, serial))
                    checked += 1
        self.assertGreaterEqual(checked, 283)

    def test_wall_with_only_dark_ink_is_not_discarded(self):
        image = Image.new('RGBA', (2, 2), (7, 8, 9, 255))
        graphic = dict(rect=[0, 0, 2, 2], page=0, family='room_wall')
        for result in [original.solid_pages({'graphics': {'1': graphic}}, [image])[0],
                       east.solid_pages({'1': graphic}, [image])[0]]:
            self.assertEqual(result.tobytes(), image.convert('RGB').tobytes())

    def test_dark_wall_pixels_survive_both_preparers(self):
        image = Image.new('RGBA', (4, 3))
        image.putpixel((1, 0), (160, 140, 120, 255))
        image.putpixel((1, 1), (9, 11, 13, 255))
        image.putpixel((2, 1), (0, 0, 0, 255))
        graphic = dict(rect=[0, 0, 4, 3], page=0, family='room_wall')
        for result in [original.solid_pages({'graphics': {'1': graphic}}, [image])[0],
                       east.solid_pages({'1': graphic}, [image])[0]]:
            for x, y in [(1, 0), (1, 1), (2, 1)]:
                self.assertEqual(result.getpixel((x, y)), image.getpixel((x, y))[:3])
            self.assertEqual(result.getpixel((3, 2)), (160, 140, 120))

    def test_non_wall_shadow_extension_stays_unchanged(self):
        image = Image.new('RGBA', (3, 1), (0, 0, 0, 0))
        image.putpixel((0, 0), (100, 120, 140, 255))
        image.putpixel((1, 0), (20, 20, 20, 255))
        graphic = dict(rect=[0, 0, 3, 1], page=0, family='prop')
        a = original.solid_pages({'graphics': {'1': graphic}}, [image])[0]
        b = east.solid_pages({'1': graphic}, [image])[0]
        self.assertEqual(a.tobytes(), b.tobytes())
        self.assertEqual(list(a.getdata()), [(100, 120, 140)] * 3)


if __name__ == '__main__': unittest.main()
