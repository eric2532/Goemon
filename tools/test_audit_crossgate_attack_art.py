import unittest
from PIL import Image
from audit_crossgate_attack_art import matches_frame, source_location, uncorrected_green_pixels


class AttackArtAuditTest(unittest.TestCase):
    def test_source_frame_maps(self):
        self.assertEqual(source_location({"source_clip": 7, "frame_map": [2, 0]}, 1), (7, 0))
        self.assertEqual(source_location({"source_clip": 7, "source_frames": [2, 0]}, 0), (7, 2))
        self.assertEqual(source_location({"source_frames": [[9, 4], [8, 3]]}, 1), (8, 3))
        self.assertEqual(source_location({"source_clip": 7, "source_frames": [[100, 0, 0, 1]]}, 0), (7, 0))
        self.assertEqual(source_location({"source_clip": 7}, 2, 13), (7, 15))

    def test_extra_outline_and_wrong_anchor_are_rejected(self):
        source = Image.new("RGBA", (5, 5)); source.putpixel((2, 2), (230, 220, 250, 255))
        prepared = source.crop((2, 2, 3, 3))
        self.assertTrue(matches_frame((prepared, -8, -18), (source, -10, -20)))
        self.assertFalse(matches_frame((prepared, -7, -18), (source, -10, -20)))
        ghost = source.copy(); ghost.putpixel((0, 1), (20, 20, 20, 255))
        self.assertFalse(matches_frame((ghost, -10, -20), (source, -10, -20)))

    def test_transparent_green_needs_edge_correction(self):
        image = Image.new("RGBA", (2, 1), (0, 255, 0, 0))
        image.putpixel((0, 0), (0, 255, 0, 255))
        self.assertEqual(uncorrected_green_pixels(image, False), 1)
        self.assertEqual(uncorrected_green_pixels(image, True), 0)


if __name__ == "__main__":
    unittest.main()
