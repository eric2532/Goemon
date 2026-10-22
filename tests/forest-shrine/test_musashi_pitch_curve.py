import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
from musashi_pitch import driver_pitch_notes, render_pitch


class DriverPitchTest(unittest.TestCase):
    def test_retail_death_curve_and_keyoff(self):
        curve = [10, 8, 512, 2304, 30, 2048, 256, 16, 24]
        notes = driver_pitch_notes(0x4700, curve, 26)
        self.assertEqual(notes[:9], [0x4700] * 9)
        self.assertEqual(notes[9:14], [0x4900, 0x4B00, 0x4D00, 0x4F00, 0x5000])
        self.assertEqual(notes[22:25], [0x4F00] * 3)
        self.assertEqual(notes[25], 0x4EF0)

    def test_unsupported_curves_are_not_guessed(self):
        with self.assertRaises(ValueError):
            driver_pitch_notes(0x4700, [3, 10, 8, 1], 20)

    def test_constant_pitch_reproduces_original_samples(self):
        import array
        pcm = array.array('h', [0, 100, 200, 300]).tobytes()
        # Table constant0x1000 means exactly one original sample per44.1kHz frame.
        self.assertEqual(render_pitch(pcm, 60 << 8, 60, [], [4096] * 85), pcm)


if __name__ == '__main__':
    unittest.main()
