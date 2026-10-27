"""Illidan recovery, prepared combat timing, and slot-32 asset contracts."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from asset_pipeline.glb import GLB

PACKAGE = ROOT.parent / "Warcraft/assets/Illidan"
RUNTIME = ROOT / "assets/characters/warcraft/demon-hunter"


class IllidanTest(unittest.TestCase):
    def test_meta_missile_sources(self):
        package = ROOT.parent / "Warcraft/assets/DemonHunter/original"
        source = json.loads((RUNTIME / "missile/source.json").read_text())
        self.assertEqual(hashlib.sha256((package / source["source"]).read_bytes()).hexdigest(), source["sha256"])
        for native, output in [("ReplaceableTextures/Weather/Clouds8x8.png", "clouds.png"), ("Textures/Flame4.png", "flame.png"), ("Textures/EQ_Rock2.png", "rock.png")]:
            self.assertEqual((package / native).read_bytes(), (RUNTIME / "missile" / output).read_bytes())
        self.assertEqual([p["Name"] for p in source["emitters"]], ["BlizParticle01x02", "BlizParticle01x01", "BlizParticle02"])
        self.assertEqual([s["Name"] for s in source["sequences"]], ["Stand", "Birth", "Death"])
        original = json.loads((ROOT.parent / "Warcraft/work/DemonHunterMissile.mdx.json").read_text())
        rock = source["rock"]
        self.assertEqual(rock["geoset"], original["Geosets"][1])
        self.assertEqual(rock["bone"], original["Bones"][2])
        self.assertEqual(rock["duration"], original["GlobalSequences"][rock["bone"]["Rotation"]["GlobalSeqId"]])
        samples = {s["time"]: s["rotation"] for s in rock["samples"]}
        for key in rock["bone"]["Rotation"]["Keys"]:
            self.assertEqual(samples[key["Frame"]], key["Vector"])
        self.assertGreaterEqual(len(samples), 81)

    def test_recovered_files_and_editable_master(self):
        for record in json.loads((PACKAGE / "extraction-manifest.json").read_text()):
            original = (PACKAGE / "original" / record["path"]).read_bytes()
            self.assertEqual(hashlib.sha256(original).hexdigest(), record["sha256"])
        motion = json.loads((RUNTIME / "motion.json").read_text())
        self.assertEqual(Path(motion["source"]), PACKAGE / "Illidan.blend")
        self.assertEqual(hashlib.sha256(Path(motion["source"]).read_bytes()).hexdigest(), motion["sha256"])

    def test_native_clips_and_prepared_attack_recovery(self):
        motion = json.loads((RUNTIME / "motion.json").read_text())
        source = json.loads((PACKAGE / "animation-index.json").read_text())["IllidanEvil"]
        glb = GLB.read(ROOT / "assets/models/characters/warcraft/demon-hunter/demon-hunter.glb")
        native = {s["name"] for s in source["sequences"]}
        self.assertEqual(len(native), 24)
        self.assertEqual(set(motion["clips"]), native)
        self.assertEqual({a["name"] for a in glb.doc["animations"]}, native)
        self.assertEqual(len(motion["meshes"]), 17)
        for animation in glb.doc["animations"]:
            if animation["name"] in ["Attack", "Attack 2"]:
                duration = max(glb.accessor(s["input"])[-1][0] for s in animation["samplers"])
                self.assertAlmostEqual(duration, .9, places=5)
                self.assertEqual(len(motion["clips"][animation["name"]]), 28)
        self.assertEqual(len(motion["particles"]), 64)
        for particle in motion["particles"]:
            self.assertTrue((RUNTIME / particle["texture"]).is_file())
        for name in ["Morph", "Morph Alternate", "Attack Alternate", "Walk Swim", "Walk Swim Alternate"]:
            self.assertTrue(any(frame["particles"] for frame in motion["clips"][name]), name)
        self.assertFalse(any(frame["particles"] for frame in motion["clips"]["Stand"]))
        effects = json.loads((RUNTIME.parent / "effects/sources.json").read_text())
        self.assertEqual(len(effects["billboards"]["32"]), 76)


if __name__ == "__main__":
    unittest.main()
