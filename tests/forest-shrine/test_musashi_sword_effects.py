"""Original source bytes catch swapped weapons, invented colors and timer guesses."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[2]
RECOVERY = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')


class SwordEffectRecoveryTests(unittest.TestCase):
    def module(self):
        path = PROJECT / 'tools/recover_musashi_sword_effects.py'
        self.assertTrue(path.exists(), 'Original sword-effect decoder is missing')
        spec = importlib.util.spec_from_file_location('musashi_sword_effects', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_quad_rgb_uses_original_per_vertex_age_and_flag_branch(self):
        module = self.module()
        self.assertEqual(module.quad_colors(0, False, 244, 2), [
            [[122, 122, 244]] * 2 + [[106, 106, 228]] * 2,
            [[106, 106, 228]] * 2 + [[90, 90, 212]] * 2])
        # Original alternate branch recomputes its newest vertex at every quad.
        self.assertEqual(module.quad_colors(1, True, 244, 2), [
            [[244, 244, 152]] * 2 + [[228, 228, 136]] * 2,
            [[228, 228, 142]] * 2 + [[212, 212, 126]] * 2])
        self.assertEqual(module.quad_colors(2, True, 244, 1), [
            [[244, 122, 122]] * 2 + [[228, 106, 106]] * 2])

    def test_recover_uses_disc_tables_pose_headers_and_additive_primitive(self):
        module = self.module()
        with tempfile.TemporaryDirectory() as folder:
            report = module.recover(RECOVERY, Path(folder), PROJECT / 'assets/characters/recovered_musashi/action_sources.json')
            self.assertEqual(report['weapons']['fusion']['descriptors'][0], {
                'descriptor': 0, 'delay_ticks': 2, 'record_ticks': 6,
                'length_divisor': 116, 'trail_index': 0})
            self.assertEqual(report['weapons']['fusion']['descriptors'][3]['record_ticks'], 24)
            self.assertEqual(report['weapons']['lumina']['descriptors'][0]['length_divisor'], 60)
            self.assertEqual(report['weapons']['lumina']['descriptors'][5]['record_ticks'], 12)
            self.assertEqual(report['primitive']['gpu_blend'], 'background_plus_foreground')
            self.assertEqual(report['primitive']['flags'], '0x50000000')
            self.assertEqual(report['ring']['capacity_pairs'], 16)
            self.assertEqual(report['ring']['maximum_segments'], 15)
            fusion = report['clips']['fusion_1']
            self.assertEqual(fusion['effect_descriptor'], 0)
            self.assertEqual(fusion['frames'][0]['endpoints_source'], [[7, 0, -19], [-16, -16, -8]])
            self.assertEqual(fusion['frames'][1]['endpoints_source'], [[34, -23, -13], [3, -26, -18]])
            self.assertEqual(report['clips']['air_fusion']['effect_descriptor'], 5)
            self.assertEqual(report['clips']['moving_air_fusion']['effect_descriptor'], 5)
            self.assertEqual(report['clips']['lumina']['frames'][0]['endpoints_source'], [[-41, -19, -2], [21, -23, 25]])
            self.assertEqual(report['clips']['air_lumina']['effect_descriptor'], 5)
            disk = json.loads((Path(folder) / 'sword_sources.json').read_text())
            self.assertEqual(disk, report)
            for asset in report['raw_assets']:
                self.assertTrue((Path(folder) / asset['path']).exists())
                self.assertEqual(len(asset['sha256']), 64)

    def test_decoder_rejects_a_different_overlay_before_exporting(self):
        module = self.module()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            overlay = root / module.OVERLAY
            overlay.parent.mkdir(parents=True)
            overlay.write_bytes(b'not the supplied USA overlay')
            with self.assertRaisesRegex(ValueError, 'overlay.*SHA-256'):
                module.recover(root, root / 'output', PROJECT / 'assets/characters/recovered_musashi/action_sources.json')
            self.assertFalse((root / 'output').exists())

    def test_rotation_and_mighty_strike_use_distinct_original_lumina_descriptors(self):
        module = self.module()
        with tempfile.TemporaryDirectory() as folder:
            report = module.recover(RECOVERY, Path(folder), PROJECT / 'assets/characters/recovered_musashi/action_sources.json')
            self.assertIn('rotation', tuple(report['clips']), 'Ordinary Lumina Rotation ribbon is missing')
            rotation = report['clips']['rotation']
            self.assertEqual(rotation['stream'], '0x800d5360')
            self.assertEqual(rotation['effect_descriptor'], 8)
            self.assertEqual(rotation['weapon'], 'lumina')
            self.assertEqual(rotation['terminal'], 'pause')
            self.assertEqual(rotation['frames'][-1]['pose'], '0x800f26e8')
            self.assertEqual(rotation['frames'][-1]['endpoints_source'], [[-5, -33, -94], [13, -32, -12]])
            tail = report['clips']['rotation_end']
            self.assertEqual(tail['stream'], '0x800d53a4')
            self.assertEqual(tail['continuation_of'], 'rotation')
            self.assertEqual(tail['effect_descriptor'], 8)
            counter = report['clips']['counter']
            self.assertEqual(counter['stream'], '0x800d552c')
            self.assertEqual(counter['effect_descriptor'], 7)
            self.assertEqual(counter['frames'][0]['endpoints_source'], [[-75, -16, -17], [21, -23, 25]])


if __name__ == '__main__':
    unittest.main()
