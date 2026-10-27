"""The new spirit reuses Iwa's bind pose and motion; donor geometry stays separate."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from asset_pipeline.glb import GLB


class KnightLionMotion(unittest.TestCase):
    def test_reused_motion_and_skin(self):
        source = GLB.read(ROOT / "assets/models/dogs/iwa.glb")
        lion = GLB.read(ROOT / "assets/vfx/knight_lion/energy_lion.glb")

        def motions(model):
            result = {}
            for clip in model.doc["animations"]:
                for channel in clip["channels"]:
                    target = channel["target"]
                    sampler = clip["samplers"][channel["sampler"]]
                    key = (clip["name"], model.doc["nodes"][target["node"]]["name"], target["path"])
                    result[key] = (model.accessor(sampler["input"]), model.accessor(sampler["output"]))
            return result

        before, after = motions(source), motions(lion)
        self.assertEqual(before.keys(), after.keys())
        largest_error = 0.0
        for key in before:
            self.assertEqual(before[key][0], after[key][0], key)
            self.assertEqual(len(before[key][1]), len(after[key][1]), key)
            for old, new in zip(before[key][1], after[key][1]):
                largest_error = max(largest_error, max(abs(a - b) for a, b in zip(old, new)))
        self.assertLess(largest_error, 0.000002, "Only float32 export rounding may differ")
        print("Lion motion maximum export error:", largest_error)
        source_skin, lion_skin = source.doc["skins"][0], lion.doc["skins"][0]
        self.assertEqual([source.doc["nodes"][i]["name"] for i in source_skin["joints"]],
                         [lion.doc["nodes"][i]["name"] for i in lion_skin["joints"]])
        bind_error = max(abs(a - b) for old, new in zip(source.accessor(source_skin["inverseBindMatrices"]),
                                                       lion.accessor(lion_skin["inverseBindMatrices"]))
                         for a, b in zip(old, new))
        self.assertLess(bind_error, 0.000002)
        self.assertEqual(len(lion.doc["meshes"]), 1)
        self.assertEqual(len(lion.doc["meshes"][0]["primitives"]), 1)
        attributes = lion.doc["meshes"][0]["primitives"][0]["attributes"]
        self.assertIn("COLOR_0", attributes)
        self.assertGreater(len(set(lion.accessor(attributes["COLOR_0"]))), 1)


if __name__ == "__main__":
    unittest.main()
