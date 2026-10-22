"""Normal Rotation and the charged guard counter are distinct retail moves."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[2]
ROOT = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')


class ChargedActionsTest(unittest.TestCase):
    def test_normal_scroll_module_and_counter_are_distinguished(self):
        path = PROJECT / 'tools/recover_musashi_charged_actions.py'
        self.assertTrue(path.exists(), 'Missing byte-verified normal scroll and Mighty Strike recovery')
        spec = importlib.util.spec_from_file_location('charged_recovery', path)
        tool = importlib.util.module_from_spec(spec); spec.loader.exec_module(tool)
        with tempfile.TemporaryDirectory() as folder:
            result = tool.recover(ROOT, Path(folder))
            normal = result['lumina_rotation']; counter = result['mighty_strike']
            self.assertEqual(normal['windup']['source_address'], '0x800d5360')
            self.assertEqual(normal['windup']['ticks'], 8)
            self.assertEqual(normal['recovery']['source_address'], '0x800d53a4')
            self.assertEqual(normal['spin']['cumulative_angle_samples'], [286,602,948,1324,1730,2166,2632,3128,3654,4210])
            self.assertIn('blade_scale', normal, 'Missing part25-only source scale evidence')
            self.assertEqual(normal['blade_scale']['part_index'], 25)
            self.assertEqual(normal['blade_scale']['timer_values_fixed12'], [4242,4388,4534,4681,4827,4973,5120])
            self.assertEqual(normal['blade_scale']['holds_after_timer'], 7)
            self.assertEqual(counter['blade_scale']['fixed12'], 0x19EB)
            self.assertEqual(normal['ribbon_actor'], 5)
            self.assertEqual(normal['ribbon_descriptor'], 8)
            self.assertEqual(normal['sound_id'], '0x450')
            self.assertEqual(counter['body']['source_address'], '0x800d552c')
            self.assertEqual(counter['counter_window_source_ticks'], 8)
            self.assertEqual(counter['effect_spawn_tick'], 11)
            self.assertEqual(counter['ribbon_descriptor'], 7)
            self.assertEqual(counter['name'], 'Mighty Strike')
            self.assertEqual(result['sources']['norm_module']['sha256'], 'f9d3559e59926092f513e1b425b26ef43d192a344e050c3c7f6d09eec13c91e7')


if __name__ == '__main__':
    unittest.main()
