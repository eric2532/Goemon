"""Check solid tree reuse, native embedded paint and preservation of the editable source."""
import hashlib
from io import BytesIO
import json
from pathlib import Path
import struct
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/maps/falan/flora"
MODELS = ROOT / "assets/models/environments/wind_meadow"


def glb(path):
    raw = path.read_bytes()
    size = struct.unpack_from("<I", raw, 12)[0]
    return json.loads(raw[20:20+size]), raw[28+size:]


class CrossGateFloraTest(unittest.TestCase):
    def test_existing_trunks_and_every_leaf_triangle_survive(self):
        source, _ = glb(MODELS / "broadleaf_tree.glb")
        def topology(data):
            return {mesh["name"]: [data["accessors"][part["indices"]]["count"] for part in mesh["primitives"]]
                    for mesh in data["meshes"]}
        for name in ("cg_evergreen", "cg_woodland", "cg_silverleaf"):
            actual, _ = glb(MODELS / "crossgate_flora" / (name+".glb"))
            self.assertEqual(topology(actual), topology(source), name)
            self.assertFalse(actual.get("animations"))
            for mesh in actual["meshes"]:
                self.assertIn("TEXCOORD_0", mesh["primitives"][0]["attributes"])
                self.assertIn("NORMAL", mesh["primitives"][0]["attributes"])
                self.assertIn("COLOR_0", mesh["primitives"][0]["attributes"])

    def test_exported_models_embed_the_exact_native_paint(self):
        for name in ("cg_evergreen", "cg_woodland", "cg_silverleaf"):
            data, binary = glb(MODELS / "crossgate_flora" / (name+".glb"))
            expected = set()
            for paint in (name, "bark"):
                with Image.open(ART / (paint+".png")) as image:
                    expected.add((image.size, image.convert("RGB").tobytes()))
            actual = set()
            for image in data["images"]:
                view = data["bufferViews"][image["bufferView"]]
                start = view.get("byteOffset", 0)
                with Image.open(BytesIO(binary[start:start+view["byteLength"]])) as embedded:
                    actual.add((embedded.size, embedded.convert("RGB").tobytes()))
            self.assertEqual(actual, expected, name)

    def test_original_master_and_export_are_unchanged(self):
        report = json.loads((ROOT / "assets/blender/environments/wind_meadow/crossgate_flora/provenance.json").read_text())
        for path, expected in report["protected"].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), expected, path)


if __name__ == "__main__": unittest.main()
