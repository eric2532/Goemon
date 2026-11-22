"""Rebuild Ruby and her escorts outside assets, then compare the live sprite preparation."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import recover_habaru_encounter as recovery


class BlackPrayerSourceTest(unittest.TestCase):
    def test_original_boss_and_escort_preparation(self):
        actual = ROOT / 'assets/characters/crossgate/black_prayer'
        evidence = ROOT / 'build/Other Files/Asset Toolkit/Ruby Dungeon Recovery'
        evidence.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='sprite-check-', dir=evidence) as folder:
            with patch.object(recovery, 'OUT', Path(folder) / 'habaru'):
                recovery.recover(ROOT.parent / 'Magic Power', ruby=True)
            rebuilt = Path(folder) / 'black_prayer'
            expected = json.loads((rebuilt / 'motions.json').read_text())
            self.assertEqual([v['id'] for v in expected['variants']], [100654,101600,101121])
            self.assertEqual(expected, json.loads((actual / 'motions.json').read_text()))
            self.assertEqual((rebuilt / 'frames.bin').read_bytes(), (actual / 'frames.bin').read_bytes())
            for path in rebuilt.glob('*.png'):
                with Image.open(path) as source, Image.open(actual / path.name) as live:
                    self.assertEqual((source.mode, source.size, source.tobytes()), (live.mode, live.size, live.tobytes()), path.name)


if __name__ == '__main__':
    unittest.main()
