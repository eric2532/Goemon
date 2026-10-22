"""Retail Rotation geometry and colours must survive recovery exactly."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[2]
ROOT = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')


class SpecialRecoveryTests(unittest.TestCase):
    def tool(self):
        path = PROJECT / 'tools/recover_musashi_special_effects.py'
        self.assertTrue(path.exists(), 'Missing original Rotation effect recovery tool')
        spec = importlib.util.spec_from_file_location('special_recovery', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_rom_geometry_colors_and_derived_ring_are_recovered(self):
        tool = self.tool()
        with tempfile.TemporaryDirectory() as directory:
            result = tool.recover(ROOT, Path(directory))
            self.assertEqual(result['rotation'].get('name'), 'Mighty Strike')
            mesh = result['rotation']['vortex_mesh']
            self.assertEqual(len(mesh['vertices']), 34)
            self.assertEqual(len(mesh['triangles']), 96)
            self.assertEqual(mesh['triangles'][0], [0, 1, 2])
            self.assertEqual(mesh['triangle_rgb8'][0], [[0, 0, 0], [255, 255, 0], [255, 0, 0]])
            self.assertEqual(mesh['vertices'][0], [30, -24, 13])
            self.assertEqual(set(tuple(rgb) for face in mesh['triangle_rgb8'] for rgb in face),
                             {(0, 0, 0), (255, 255, 0), (255, 0, 0), (255, 255, 255)})
            ring = result['rotation']['shock_ring']
            self.assertEqual(ring['outer_points_source'][0], [0, 96])
            self.assertEqual(ring['outer_points_source'][1], [47, 83])
            self.assertEqual(ring['inner_fraction_fixed12'], 0xCCC)
            self.assertEqual(ring['inner_rgb8'], [240, 240, 192])
            self.assertIn('metal_flash', result['contact'], 'Missing common metal-contact geometry')
            contact = result['contact']['metal_flash']
            self.assertEqual(contact['triangles'][0], [[0, 0, 2], [-3, 0, 36], [3, 0, 40]])
            self.assertEqual(contact['triangle_rgb8'], [[64, 64, 16], [255, 192, 64], [255, 192, 64]])
            self.assertEqual(contact['rotation_pairs_source'][0], [640, 512])
            self.assertEqual(contact['render_scales_fixed12'], [4096, 6144, 8192])
            self.assertEqual(result['rotation']['spawn_anchor_source'], [0, -6, -120])
            self.assertEqual(result['rotation']['spawn_tick'], 11)
            self.assertEqual(result['rotation']['actors'][0]['handler'], '0x80164744')
            self.assertEqual(result['rotation']['actors'][2]['handler'], '0x80164ba0')
            self.assertTrue((Path(directory) / 'special/rotation_vortex_mesh.json').exists())
            self.assertTrue((Path(directory) / 'special/rotation_vortex.tmd').exists())

    def test_packet_indices_and_source_hash_are_checked(self):
        tool = self.tool()
        resident = (ROOT / 'raw/MAIN.CD.dir/FILE_010.dir/1.1').read_bytes()
        malformed = bytearray(resident)
        struct.pack_into('<H', malformed, 0x800DE5A8 - tool.RESIDENT_BASE + 12 + 0x1C + 18, 99)
        with self.assertRaises(ValueError):
            tool.decode_vortex(bytes(malformed))
        with self.assertRaises(ValueError):
            tool.checked_source(b'changed', 'retail resident', tool.SOURCE_HASHES['resident'])


if __name__ == '__main__':
    unittest.main()
