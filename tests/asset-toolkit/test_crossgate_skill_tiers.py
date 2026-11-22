"""Verify the lossless tier exports without requiring the preserved source checkout."""
import hashlib
import json
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


class SkillTierPreservation(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((ROOT / "assets/characters/crossgate/skill_tiers/manifest.json").read_text())

    def test_original_sheet_bytes_and_frame_layout(self):
        for ref, clip in self.manifest["clips"].items():
            with self.subTest(resource=ref):
                path = ROOT / clip["runtime_path"].removeprefix("res://")
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), clip["sha256"])
                with Image.open(path) as image:
                    self.assertEqual(image.width, clip["columns"] * clip["width"])
                    self.assertGreaterEqual(image.height // clip["height"] * clip["columns"], clip["frames"])
                self.assertEqual(len(clip["frame_bounds"]), clip["frames"])

    def test_chosen_tiers_and_shared_existing_masters(self):
        self.assertEqual(len(self.manifest["clips"]), 68)
        self.assertEqual(len({c["runtime_path"] for c in self.manifest["clips"].values()}), 60)
        for kind in ["fire", "ice", "wind", "meteor"]:
            self.assertEqual(len(self.manifest["elements"][kind]), 5)
        expected = {"fire": ["110149", "110146", "110143", "110140", "111008"],
                    "ice": ["110029", "110026", "110023", "110020", "111005"],
                    "wind": ["110047", "110046", "110045", "110044", "111011"],
                    "meteor": ["110041", "110038", "110035", "110032", "111002"]}
        for kind, refs in expected.items():
            self.assertEqual([tier["targets"][0] for tier in self.manifest["elements"][kind]], refs)
            self.assertEqual(self.manifest["elements"][kind][-1]["cast"], "111001")
        self.assertEqual(self.manifest["elements"]["fire"][-1]["targets"], ["111008", "111009", "111010"])
        self.assertEqual(self.manifest["elements"]["meteor"][-1]["targets"], ["111002", "111003", "111004"])
        self.assertEqual([r["target"] for r in self.manifest["recovery"]], ["110179", "110178", "110177", "110176", "111019"])
        self.assertEqual(self.manifest["recovery"][-1]["cast"], "111014")
        self.assertEqual(self.manifest["clips"]["110140"]["runtime_path"], "res://assets/characters/crossgate/elements/fire.png")
        self.assertEqual(self.manifest["clips"]["110176"]["runtime_path"], "res://assets/characters/crossgate/ruby/recovery-ring.png")
        self.assertEqual(self.manifest["meditation"], ["110183", "110182", "110181", "110180", "111017"])
        self.assertEqual(self.manifest["clips"]["110180"]["runtime_path"], "res://assets/characters/crossgate/shin/meditation.png")
        self.assertEqual([self.manifest["clips"][ref]["width"] for ref in self.manifest["meditation"]], [90, 157, 265, 340, 340])


if __name__ == "__main__":
    unittest.main()
