"""Recovery must preserve the shipped rig and expose omitted source entries."""
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[2]
RECOVERY = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')


def read_glb(path):
    blob = path.read_bytes()
    size = struct.unpack_from('<I', blob, 12)[0]
    return json.loads(blob[20:20 + size]), blob[28 + size:]


class RecoveryTests(unittest.TestCase):
    def test_appended_actions_reproduce_source_without_changing_existing_assets(self):
        path = PROJECT / 'tools/recover_musashi_actions.py'
        self.assertTrue(path.exists(), 'Missing recovery tool for the omitted original action entries')
        spec = importlib.util.spec_from_file_location('musashi_actions', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        source = PROJECT / 'assets/characters/recovered_musashi/musashi.glb'
        original, binary = read_glb(source)
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'musashi.glb'
            target.write_bytes(source.read_bytes())
            report = module.recover(RECOVERY, target)
            after, expanded = read_glb(target)
            self.assertEqual(after['nodes'], original['nodes'])
            self.assertEqual(after['meshes'], original['meshes'])
            self.assertEqual(after['materials'], original['materials'])
            self.assertEqual(after['skins'], original['skins'])
            self.assertEqual(after['animations'][:len(original['animations'])], original['animations'])
            self.assertEqual(expanded[:len(binary)], binary)
            names = {a['name'] for a in after['animations']}
            for address in ['800d4d88','800d4da8','800d4db4','800d4dd4','800d4df4',
                            '800d4e6c','800d52a8','800d52e8','800d533c','800d5c6c','800d53a4']:
                self.assertIn('Recovered__' + address, names)
            self.assertGreater(report['joint_frame_checks'], 1000)
            self.assertLess(report['maximum_transform_error'], 0.00001)
            fourth = report['actions']['fusion_4']
            self.assertEqual(fourth['ticks'], 6)
            self.assertEqual(fourth['frames'][0]['pose'], '0x800e8ae8')
            self.assertEqual(report['actions']['lumina']['active_ticks'], [8, 14])
            self.assertEqual(report['actions']['air_lumina']['active_ticks'], [4, 10])
            self.assertEqual(report['actions']['rotation']['address'], '0x800d5360')
            self.assertEqual(report['actions']['counter']['address'], '0x800d552c')
            self.assertEqual(report['actions']['rotation_end']['ticks'], 4)
            before_repeat = target.read_bytes()
            module.recover(RECOVERY, target)
            self.assertEqual(target.read_bytes(), before_repeat, 'Recovery must be idempotent')

    def test_corrupted_stored_animation_is_detected(self):
        path = PROJECT / 'tools/recover_musashi_actions.py'
        spec = importlib.util.spec_from_file_location('musashi_actions', path)
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'musashi.glb'
            target.write_bytes((PROJECT / 'assets/characters/recovered_musashi/musashi.glb').read_bytes())
            module.recover(RECOVERY, target)
            doc, _ = read_glb(target)
            animation = next(a for a in doc['animations'] if a['name'] == 'Recovered__800d4d88')
            channel = next(c for c in animation['channels'] if c['target']['path'] == 'translation')
            accessor = doc['accessors'][animation['samplers'][channel['sampler']]['output']]
            view = doc['bufferViews'][accessor['bufferView']]
            raw = bytearray(target.read_bytes()); json_size = struct.unpack_from('<I', raw, 12)[0]
            offset = 28 + json_size + view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
            struct.pack_into('<f', raw, offset, struct.unpack_from('<f', raw, offset)[0] + .5)
            target.write_bytes(raw)
            with self.assertRaises(AssertionError, msg='Stored GLB keys must be compared to decoded source'):
                module.recover(RECOVERY, target)


if __name__ == '__main__':
    unittest.main()
