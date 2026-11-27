"""Offshore decoration keeps native pixels while separating rock from flat water."""
import json
import sys
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from recover_venoa_walls import native_without_ground_shadow


class IsletLayers(unittest.TestCase):
    def test_native_layers_partition_without_repainting(self):
        catalog = json.loads((ROOT / 'assets/maps/original_crossgate/east/catalog.json').read_text())
        folder = ROOT / 'assets/maps/falan/east_region/landmarks'
        profiles = json.loads((folder / 'profiles.json').read_text())['graphics']
        for serial in (12912, 12913, 12914, 12919, 12922):
            with self.subTest(serial=serial):
                g = catalog['graphics'][str(serial)]
                x, y, w, h = g['rect']
                page = Image.open(ROOT / 'assets/maps/original_crossgate' / catalog['pages'][g['page']])
                original, _ = native_without_ground_shadow(page.crop((x, y, x+w, y+h)).convert('RGBA'))
                rock = Image.open(folder / f'{serial}-islet-rock.png').convert('RGBA')
                water = Image.open(folder / f'{serial}-islet-water.png').convert('RGBA')
                back = Image.open(folder / f'{serial}-islet-back.png').convert('RGBA')
                self.assertEqual(Image.alpha_composite(water, rock).tobytes(), original.tobytes())
                self.assertEqual(back.getchannel('A').tobytes(), rock.getchannel('A').tobytes())
                self.assertTrue(rock.getbbox() and water.getbbox())
                self.assertGreater(profiles[str(serial)]['ground_offset'], 0)


if __name__ == '__main__':
    unittest.main()
