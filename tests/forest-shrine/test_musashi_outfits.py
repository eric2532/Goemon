"""Catch wrong MoveImage units/order and invented equipment texture variants."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
RECOVERY = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')


class OutfitRecoveryTests(unittest.TestCase):
    def module(self):
        path = PROJECT / 'tools/recover_musashi_outfits.py'
        self.assertTrue(path.exists(), 'Original equipment texture recovery is missing')
        spec = importlib.util.spec_from_file_location('musashi_outfits', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_moveimage_uses_word_coordinates_and_snapshot_copy(self):
        module = self.module()
        words = bytearray(struct.pack('<12H', *range(12)))
        result = module.apply_moves(words, 4, 3, [(0, 0, 3, 2, 1, 1)])
        self.assertEqual(struct.unpack('<12H', result), (0, 1, 2, 3, 4, 0, 1, 2, 8, 4, 5, 6))
        self.assertEqual(struct.unpack('<12H', words), tuple(range(12)), 'Base VRAM must remain reusable')
        with self.assertRaises(ValueError):
            module.apply_moves(words, 4, 3, [(3, 0, 2, 1, 0, 0)])

    def test_four_bit_texture_decodes_low_nibble_first_with_original_palette(self):
        module = self.module()
        words = bytearray(1024 * 512 * 2)
        struct.pack_into('<H', words, 2 * (256 * 1024 + 512), 0x3210)
        struct.pack_into('<4H', words, 2 * (265 * 1024 + 352), 0, 31, 31 << 5, 31 << 10)
        pixels = module.decode_page(words, 24, 16982)
        self.assertEqual([pixels.getpixel((x, 0)) for x in range(4)], [(0, 0, 0, 0), (255, 0, 0, 255), (0, 255, 0, 255), (0, 0, 255, 255)])

    def test_disc_equipment_variants_have_real_source_pixels_and_all_combinations(self):
        module = self.module()
        with tempfile.TemporaryDirectory() as folder:
            report = module.recover(RECOVERY, Path(folder))
            equipment = {e['id']: e for e in report['equipment']}
            self.assertEqual(set(equipment), {'l_goggles', 'l_belt', 'l_brace', 'l_vest', 'l_shoes'})
            self.assertEqual(equipment['l_goggles']['flag'], '0x1d')
            self.assertEqual(equipment['l_shoes']['moves'][0]['source'], [512, 344, 8, 16])
            self.assertEqual(equipment['l_belt']['moves'][0]['destination'], [548, 304])
            self.assertEqual(len(report['looks']), 32)
            self.assertEqual(report['looks'][0]['equipment'], [])
            self.assertEqual(len(report['looks'][-1]['equipment']), 5)
            self.assertGreater(report['looks'][-1]['changed_vram_words'], 1000)
            self.assertEqual(len(report['looks'][-1]['pages']), 5)
            for e in report['equipment']:
                self.assertGreater(e['changed_vram_words'], 0, e['id'])
                self.assertTrue(all(len(m['source_sha256']) == 64 for m in e['moves']))
            self.assertEqual(report['non_costume_items']['l_cloth']['wearable'], False)
            self.assertTrue('original_texture_bindings' in report, 'Missing verified original texture mapping')
            self.assertEqual(report['original_texture_bindings']['musashi_Image_0_3.png']['clut'], 16982)
            self.assertEqual(report['original_texture_bindings']['musashi_Image_0_4.png']['clut'], 17174)
            self.assertEqual(len(report['original_material_bindings']), 12)
            for name, binding in report['original_texture_bindings'].items():
                recovered = Image.open(Path(folder) / report['looks'][0]['pages'][str(binding['clut'])])
                original = Image.open(PROJECT / 'assets/characters/recovered_musashi' / name)
                self.assertEqual(recovered.tobytes(), original.convert('RGBA').tobytes(), name)


if __name__ == '__main__':
    unittest.main()
