"""Catch the detached unarmed outline that valid atlas/clock checks cannot see."""
import json
from functools import lru_cache
from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/characters/crossgate/fighters/emilia"


@lru_cache(None)
def manifest(skin):
    return json.loads((ART / str(skin) / "motions.json").read_text())


@lru_cache(None)
def atlas(skin, page):
    return Image.open(ART / str(skin) / f"atlas-{page}.png").convert("RGBA")


def frame(skin, direction, source_frame):
    clip = manifest(skin)["clips"][f"5:{direction}"]
    page, x, y, w, h, ox, oy = clip["frames"][clip["frame_map"].index(source_frame)]
    return atlas(skin, page).crop((x, y, x + w, y + h)), ox, oy


def pixel(part, x, y):
    image, ox, oy = part
    return image.getpixel((x - ox, y - oy)) if 0 <= x - ox < image.width and 0 <= y - oy < image.height else (0, 0, 0, 0)


class EmiliaStaffOutlineTest(unittest.TestCase):
    def test_ice_pixels_beside_the_old_outline_are_preserved(self):
        for skin in (120387, 120388):
            for direction, source_frame, x, y, color in (
                    (3, 4, 26, 2, (93, 116, 146, 255)),
                    (5, 4, -18, -6, (121, 152, 194, 255)),
                    (6, 5, -34, -2, (133, 159, 199, 255))):
                self.assertEqual(pixel(frame(skin, direction, source_frame), x, y), color)

    def test_vacated_head_outline_is_transparent(self):
        # Reviewed side-facing windup/turn samples; these were the floating old head.
        for skin in (120387, 120388):
            for source_frame, point in ((0, (-17, -71)), (2, (-15, -70)), (3, (-18, -68)),
                                        (2, (-27, -20)), (3, (-28, -20))):
                with self.subTest(skin=skin, source_frame=source_frame):
                    self.assertEqual(pixel(frame(skin, 4, source_frame), *point)[3], 0)

    def test_staff_body_has_no_unfilled_outline(self):
        source = ROOT.parent / "Magic Power/tools"
        if not source.exists():
            self.skipTest("Preserved compiler archive is not available")
        sys.path.insert(0, str(source))
        import cg_assets as cg
        poses = {(c["action"], c["direction"]): c for c in cg.actor("puk3:533")[2]}
        for direction in range(8):
            for index in range(9):
                image, ox, oy = cg.frame_parts("puk3:533", poses[5, direction]["index"], index)
                points = [(ox + x, oy + y) for y in range(image.height) for x in range(image.width)
                          if image.getpixel((x, y))[3]]
                for skin in (120387, 120388, 111669):
                    prepared = frame(skin, direction, index)
                    self.assertTrue(all(pixel(prepared, x, y)[3] for x, y in points),
                                    (skin, direction, index))

    def test_puck_keeps_every_original_attack_pixel(self):
        source = ROOT.parent / "Magic Power/tools"
        if not source.exists():
            self.skipTest("Preserved compiler archive is not available")
        sys.path.insert(0, str(source))
        import cg_assets as cg
        poses = {key: {(c["action"], c["direction"]): c for c in cg.actor(key)[2]}
                 for key in ("update-ex:1916", "update-ex:1911")}
        count = 0
        for direction in range(8):
            for index in range(9):
                puck = cg.frame_parts("update-ex:1916", poses["update-ex:1916"][5, direction]["index"], index)
                plain = cg.frame_parts("update-ex:1911", poses["update-ex:1911"][5, direction]["index"], index)
                image, ox, oy = puck
                prepared = frame(120387, direction, index)
                for y in range(image.height):
                    for x in range(image.width):
                        color = image.getpixel((x, y))
                        if color[3] and color != pixel(plain, ox + x, oy + y):
                            self.assertEqual(pixel(prepared, ox + x, oy + y), color,
                                             (direction, index, ox + x, oy + y))
                            count += 1
        self.assertEqual(count, 40573)


if __name__ == "__main__":
    unittest.main()
