"""Shin skins and equipped weapons retain their original animation frames."""
import json
import sys
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "assets/characters/crossgate/shin"


class ShinCasting(unittest.TestCase):
    @unittest.skipUnless((ROOT.parents[3].parent / "Magic Power/tools/cg_assets.py").exists(),
                         "Original source archive is not attached")
    def test_all_shin_animation_frames_and_weapon_routes_match_source(self):
        sys.path.insert(0, str(ROOT.parents[3].parent / "Magic Power/tools"))
        import cg_assets as cg
        paths = set(ROOT.glob("*/motions.json"))
        catalog = json.loads((ROOT.parent / "weapons/catalog.json").read_text())
        for character in ("37", "38"):
            for routes in catalog[character].values():
                for route in routes.values():
                    if "root" in route:
                        paths.add(ROOT.parents[3] / route["root"].removeprefix("res://") / "motions.json")
        checked = 0
        for path in sorted(paths):
            manifest = json.loads(path.read_text())
            pages = [Image.open(path.parent / f"atlas-{i}.png").convert("RGBA")
                     for i in range(manifest["pages"])]
            pages += [Image.open(path.parent / f"cast-{i}.png").convert("RGBA")
                      for i in range(manifest.get("cast_pages", 0))]
            for stance in [manifest] + manifest.get("weapons", []):
                originals = {(c["action"], c["direction"]): c
                             for c in cg.actor(stance["key"])[2] if c["frames"]}
                for action in (0, 1, 3, 5, 6, 8, 10):
                    for direction in range(8):
                        clip = (manifest["original_run"] if action == 3 and manifest.get("run_reuse") else stance["clips"])[f"{action}:{direction}"]
                        original = originals[action, direction]
                        with self.subTest(path=path, weapon=stance["weapon"], action=action, facing=direction):
                            self.assertEqual(clip["source_clip"], original["index"])
                            self.assertEqual(len(clip["frames"]), len(original["frames"]))
                            self.assertGreater(clip["duration"], 0)
                            if action in (0, 1, 3, 8, 10):
                                self.assertEqual(clip["duration"], original["duration"] / 1000)
                            for index, (page, x, y, w, h, px, py) in enumerate(clip["frames"]):
                                image, ox, oy = cg.frame_parts(stance["key"], original["index"], index)
                                box = image.getbbox()
                                expected = image.crop(box)
                                actual = pages[page].crop((x, y, x + w, y + h))
                                self.assertEqual((px, py), (ox + box[0], oy + box[1]))
                                self.assertEqual(actual.size, expected.size)
                                self.assertEqual(actual.tobytes(), expected.tobytes())
                                checked += 1
            for page in pages:
                page.close()
        print(f"SHIN_SOURCE_ANIMATIONS profiles={len(paths)} frames={checked}")

    def test_all_skins_and_stances_have_eight_valid_casts(self):
        skins = json.loads((ROOT / "skins.json").read_text())
        for skin_id, *_ in skins:
            folder = ROOT / str(skin_id)
            manifest = json.loads((folder / "motions.json").read_text())
            with self.subTest(skin=skin_id):
                self.assertTrue(manifest["has_cast_atlas"])
                sizes = []
                for i in range(manifest["cast_pages"]):
                    with Image.open(folder / f"cast-{i}.png") as image:
                        sizes.append(image.size)
                for stance in [manifest] + manifest.get("weapons", []):
                    for direction in range(8):
                        clip = stance["clips"][f"6:{direction}"]
                        self.assertGreater(clip["duration"], 0)
                        self.assertTrue(clip["frames"])
                        for page, x, y, w, h, *_ in clip["frames"]:
                            self.assertGreaterEqual(page, manifest["pages"])
                            width, height = sizes[page - manifest["pages"]]
                            self.assertTrue(0 <= x < x + w <= width)
                            self.assertTrue(0 <= y < y + h <= height)

    @unittest.skipUnless((ROOT.parents[3].parent / "Magic Power/tools/cg_assets.py").exists(),
                         "Original source archive is not attached")
    def test_special_attacks_preserve_every_original_frame_and_origin(self):
        sys.path.insert(0, str(ROOT.parents[3].parent / "Magic Power/tools"))
        import cg_assets as cg
        for skin_id, _, _, special in json.loads((ROOT / "skins.json").read_text()):
            if not special:
                continue
            folder = ROOT / str(skin_id)
            manifest = json.loads((folder / "motions.json").read_text())
            pages = [Image.open(folder / f"atlas-{i}.png").convert("RGBA")
                     for i in range(manifest["pages"])]
            for stance in [manifest] + manifest.get("weapons", []):
                self.assertIn(stance["weapon"], ("sword", "polearm", "unarmed"))
                originals = {(c["action"], c["direction"]): c
                             for c in cg.actor(stance["key"])[2] if c["frames"]}
                for direction in range(8):
                    clip = stance["clips"][f"5:{direction}"]
                    original = originals[5, direction]
                    self.assertNotIn("effects", clip)
                    self.assertEqual(len(clip["frames"]), len(original["frames"]))
                    for index, frame in enumerate(clip["frames"]):
                        with self.subTest(skin=skin_id, direction=direction, frame=index):
                            image, ox, oy = cg.frame_parts(stance["key"], original["index"], index)
                            box = image.getbbox()
                            expected = image.crop(box)
                            page, x, y, w, h, px, py = frame
                            actual = pages[page].crop((x, y, x + w, y + h))
                            self.assertEqual((px, py), (ox + box[0], oy + box[1]))
                            self.assertEqual(actual.size, expected.size)
                            self.assertEqual(actual.tobytes(), expected.tobytes())
            for page in pages:
                page.close()


if __name__ == "__main__":
    unittest.main()
