import hashlib
from array import array
import json
from pathlib import Path
import sys
import tempfile
import unittest
import wave
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import prepare_crossgate_player_audio as audio


class PlayerAudioTest(unittest.TestCase):
    def test_current_roster_and_original_pcm_are_current(self):
        self.assertEqual(audio.check_local(), [])
        for line in (ROOT / 'export_presets.cfg').read_text().splitlines():
            if line.startswith('include_filter='):
                self.assertIn('assets/audio/crossgate/player-attacks.json', line)

    def test_changed_attack_and_missing_roster_coverage_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = root / 'fixture/motions.json'
            manifest.parent.mkdir()
            manifest.write_text('{}')
            index = root / 'audio.json'
            index.write_text(json.dumps(dict(profiles={'res://fixture/': []}, samples={},
                manifest_hashes={'res://fixture/': hashlib.sha256(manifest.read_bytes()).hexdigest()}, pcm_hashes={},
                mix_recipes=audio.ATTACK_MIXES, special_overrides=audio.SHIN_SPECIAL_AUDIO,
                kaz_fire_overrides=audio.KAZ_FIRE_AUDIO)))
            with patch.multiple(audio, ROOT=root, OUT=index), patch.object(audio, 'manifest_paths', return_value=[manifest]):
                self.assertEqual(audio.check_local(), [])
                manifest.write_text('{"new_attack":true}')
                self.assertTrue(any('source changed' in error for error in audio.check_local()))
            with patch.multiple(audio, ROOT=root, OUT=index), patch.object(audio, 'manifest_paths', return_value=[]):
                self.assertTrue(any('coverage is stale' in error for error in audio.check_local()))

    def test_layers_keep_full_tails_and_use_one_gain_without_clipping(self):
        with tempfile.TemporaryDirectory() as temporary:
            paths = []
            for i, values in enumerate(([20000, -20000, 4000], [20000, -20000])):
                path = Path(temporary) / f'{i}.wav'
                with wave.open(str(path), 'wb') as wav:
                    wav.setparams((1, 2, 22050, 0, 'NONE', 'not compressed'))
                    wav.writeframes(array('h', values).tobytes())
                paths.append(path)
            self.assertEqual(list(array('h', audio.mix_pcm(paths))), [30000, -30000, 3000])
            with wave.open(str(paths[0]), 'wb') as wav:
                wav.setparams((2, 2, 22050, 0, 'NONE', 'not compressed'))
                wav.writeframes(array('h', [1, 1]).tobytes())
            with self.assertRaises(AssertionError):
                audio.mix_pcm(paths)

    def test_numbered_layers_and_unchanged_regular_weapon_sources(self):
        data = json.loads(audio.OUT.read_text())
        root = 'res://assets/characters/crossgate/shin/'
        self.assertEqual(data['profiles'][root+'100050/'][1]['5:4'], [[104], [134]])
        self.assertEqual(data['profiles'][root+'100050/'][2]['5:4'], [[108], [138]])
        self.assertEqual(data['mix_recipes']['900006'], [102, 262, 267])
        for direction in range(8):
            self.assertEqual(data['profiles'][root+'118986/'][0][f'5:{direction}'], [[900006], [0]])
        self.assertEqual(data['mix_recipes']['900003'], [104, 282, 172])
        self.assertEqual(data['mix_recipes']['900004'], [134, 266, 290])
        self.assertEqual(data['mix_recipes']['900005'], [134, 290])
        for direction in range(8):
            self.assertEqual(data['profiles'][root+'111625/'][0][f'5:{direction}'], [[104], [900005]])
            self.assertEqual(data['profiles'][root+'118993/'][0][f'5:{direction}'], [[900001], [900004]])
            kaz = data['profiles']['res://assets/characters/crossgate/kazi/'][0][f'5:{direction}']
            sparks = data['profiles']['res://assets/characters/crossgate/kazi/skins/109146/'][0][f'5:{direction}']
            self.assertEqual(kaz, [[900007] + ([103] if direction else []), [133, 900008]])
            self.assertEqual(sparks, [[900001] + ([104] if direction else []), [104, 900009]])
        self.assertEqual(data['mix_recipes']['900007'], [103, 282])
        self.assertEqual(data['mix_recipes']['900008'], [133, 266])
        self.assertEqual(data['mix_recipes']['900009'], [104, 266])
        for ident, sources in data['mix_recipes'].items():
            paths = [ROOT / data['samples'][str(i)].removeprefix('res://') for i in sources]
            with wave.open(str(ROOT / data['samples'][ident].removeprefix('res://'))) as wav:
                self.assertEqual(wav.readframes(wav.getnframes()), audio.mix_pcm(paths))


if __name__ == '__main__':
    unittest.main()
