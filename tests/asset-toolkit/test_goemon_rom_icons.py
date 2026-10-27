"""Runtime HUD images retain the recovered ROM pixel identities."""
import hashlib
import json
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

class GoemonRomIcons(unittest.TestCase):
    def test_original_weapon_pixels(self):
        directory = ROOT / 'assets/ui/rom_weapons'
        source = json.loads((directory / 'provenance.json').read_text())
        self.assertEqual(source['rom_sha256'], '1603be37427a33548857fc3d2e8867ede71121c353fb631b79b44f1d94845d80')
        self.assertEqual(len(source['icons']), 20)
        for icon in source['icons']:
            with self.subTest(icon=icon['file']):
                image = Image.open(directory / icon['file']).convert('RGBA')
                self.assertEqual(image.size, (24, 24))
                self.assertEqual(hashlib.sha256(image.tobytes()).hexdigest(), icon['rgba_sha256'])
                self.assertEqual(image.getextrema()[3], (0, 255))
