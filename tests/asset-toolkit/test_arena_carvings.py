import sys
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from prepare_arena_carvings import ROOT, CARVING_EDGE, carving_depth, shallow_depth


class ArenaCarvings(unittest.TestCase):
    def test_rectangular_relief_seals_every_edge_and_preserves_source(self):
        stone=Image.new("L",(48,96),80)
        ImageDraw.Draw(stone).ellipse((12,20,36,76),outline=220,width=4)
        before=stone.tobytes()
        depth=shallow_depth(stone)
        self.assertEqual(stone.tobytes(),before)
        self.assertEqual(depth.getextrema(),(0,255))
        self.assertTrue(all(depth.getpixel((x,y))==0 for x in range(48) for y in (0,95)))
        self.assertTrue(all(depth.getpixel((x,y))==0 for y in range(96) for x in (0,47)))

    def test_original_art_reproduces_sealed_recesses_without_modifying_source(self):
        atlas = Image.open(ROOT / "assets/maps/falan/arena_inlays_detail.png").convert("RGB")
        original = atlas.tobytes()
        depth = carving_depth(atlas)
        prepared = Image.open(ROOT / "assets/maps/falan/arena_carving_depth.png")
        self.assertEqual(depth.tobytes(), prepared.tobytes())
        self.assertEqual(atlas.tobytes(), original)
        self.assertEqual(depth.size, (256, 256))
        self.assertEqual(depth.getextrema(), (0, 255))
        for i in range(CARVING_EDGE):
            self.assertTrue(all(depth.getpixel(p) == 0
                                for p in ((i, 0), (i, CARVING_EDGE - 1),
                                          (0, i), (CARVING_EDGE - 1, i))))
        self.assertGreater(max(depth.crop((160, 70, 220, 170)).getdata()), 220)


if __name__ == "__main__":
    unittest.main()
