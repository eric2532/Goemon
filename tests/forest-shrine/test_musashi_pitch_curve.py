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

    def test_skullpion_absolute_pitch_and_release(self):
        notes=driver_pitch_notes(0x4000,[0,0x100,0x4300,0x3c00,0x200,5],8)
        self.assertEqual(notes[:4],[0x4000,0x4100,0x4200,0x4300])
        self.assertEqual(notes[5:8],[0x4300,0x4100,0x3f00])

    def test_skullpion_relative_delay_and_constant_keyoff(self):
        notes=driver_pitch_notes(0x4000,[8,2,0x100,0xff00,0xfe00,0x80,5],8)
        self.assertEqual(notes[:4],[0x4000,0x4000,0x4000,0x3f00])
        self.assertEqual(notes[6],0x3e80)
        self.assertEqual(driver_pitch_notes(0x4000,[2,45],8),[0x4000]*9)

    def test_unsupported_curves_are_not_guessed(self):
        with self.assertRaises(ValueError):
            driver_pitch_notes(0x4700, [3, 10, 8, 1], 20)

    def test_delayed_absolute_and_undelayed_relative_forms(self):
        self.assertEqual(driver_pitch_notes(0x4000,[5,2,0x100,0x4300,0x3c00,0x200,8],12),
                         driver_pitch_notes(0x4000,[8,2,0x100,0x300,0xfc00,0x200,8],12))
        self.assertEqual(driver_pitch_notes(0x4000,[6,2,0x100,0x4300,0x80,0x4200,0x3c00,0x200,8],12),
                         driver_pitch_notes(0x4000,[10,2,0x100,0x300,0x80,0x200,0xfc00,0x200,8],12))
        for absolute,relative in [([0,0x100,0x4300,0x3c00,0x200,8],[7,0x100,0x300,0xfc00,0x200,8]),
                                  ([1,0x100,0x4300,0x80,0x4200,0x3c00,0x200,8],[9,0x100,0x300,0x80,0x200,0xfc00,0x200,8])]:
            self.assertEqual(driver_pitch_notes(0x4000,absolute,12),driver_pitch_notes(0x4000,relative,12))

    def test_constant_pitch_reproduces_original_samples(self):
        import array
        pcm = array.array('h', [0, 100, 200, 300]).tobytes()
        # Table constant0x1000 means exactly one original sample per44.1kHz frame.
        self.assertEqual(render_pitch(pcm, 60 << 8, 60, [], [4096] * 85), pcm)


if __name__ == '__main__':
    unittest.main()
