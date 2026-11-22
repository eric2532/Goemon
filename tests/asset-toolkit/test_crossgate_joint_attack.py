import hashlib
import json
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT.parent / "Magic Power"
OUT = ROOT / "assets/characters/crossgate/hit_feedback"


class JointAttackArtTest(unittest.TestCase):
    def test_original_pixels_origins_and_native_layout(self):
        sys.path.insert(0, str(SOURCE / "tools"))
        import cg_library
        manifest = json.loads((OUT / "joint-attack.json").read_text())
        atlas = Image.open(OUT / "joint-attack.png").convert("RGBA")
        self.assertEqual(atlas.size, (17 * 96, 64))
        raw, _ = cg_library.cg.graphic_index("original")
        for index, glyph in enumerate(manifest["glyphs"]):
            row = cg_library.cg.RECORD.unpack_from(raw, glyph["row"] * 40)
            self.assertEqual([row[-1], list(row[3:5]), list(row[5:7])], [glyph["serial"], glyph["origin"], glyph["size"]])
            source = cg_library.image_from_record("original", glyph["row"]).convert("RGBA")
            x, y = index * 96 + 48 + row[3], 32 + row[4]
            self.assertEqual(atlas.crop((x, y, x + source.width, y + source.height)).tobytes(), source.tobytes())
            self.assertEqual(hashlib.sha256(source.tobytes()).hexdigest(), glyph["sha256"])
        self.assertEqual(manifest["offsets"], [0, 34, 54, 66, 88, 108, 131, 152, 171, 0])
        self.assertEqual(manifest["order"], [0, 8, 7, 6, 5, 4, 3, 2, 1, 9])

        split = Image.open(OUT / "hitcombo-01.png").convert("RGBA")
        recomposed = Image.new("RGBA", (36, 29))
        recomposed.alpha_composite(split.crop((1, 1, 16, 30)))
        recomposed.alpha_composite(split.crop((18, 1, 39, 30)), (14, 0))
        self.assertEqual(recomposed.tobytes(), atlas.crop((799, 16, 835, 45)).tobytes())


if __name__ == "__main__":
    unittest.main()
