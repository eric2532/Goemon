"""Source gates remain inert; mixed prepared banks retain their rendered pixels/timing."""
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from prepare_east_region_population import append_native_bank, compile_script


class EastPopulationTest(unittest.TestCase):
    def test_script_keeps_gates_and_window_order(self):
        source = b"# original comment\nblock Level < 15\n\tEndWindow 12\n\nblock\n\tWindow 13,YES,NO\n\tWindow_Yes Item 42 >= 1\n\tWarp 0,11034,74,72\n"
        result = compile_script(source)
        self.assertEqual([b["condition"] for b in result["blocks"]], ["Level < 15", ""])
        self.assertEqual(result["blocks"][1]["lines"][-2:],
                         [[7, "\tWindow_Yes Item 42 >= 1"], [8, "\tWarp 0,11034,74,72"]])

    def test_append_preserves_old_bank_and_selected_source_pixels(self):
        parent = ROOT / "build/Other Files/Asset Toolkit/East Gate Region/Native Merge Test"
        parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=parent) as directory:
            folder = Path(directory); old = folder / "old"; source = folder / "source"
            actions = [0, 3, 5, 8, 10, 1, 9]
            def bank(path, ids, order, rgba):
                path.mkdir(); clip_count = len(ids) * len(order) * 8
                clips = [(i, 1, 1.25 + i / 1000, .075) for i in range(clip_count)]
                frames = [row for _ in clips for row in [(0, 0, 1, 1), (3, -4, 0, 0)]]
                table = clips + frames; table += [(0, 0, 0, 0)] * (-len(table) % 512)
                (path / "frames.bin").write_bytes(b"".join(struct.pack("<4f", *row) for row in table))
                Image.new("L", (4, 4), 1).save(path / "atlas-0.png")
                palette = Image.new("RGBA", (256, 1)); palette.putpixel((1, 0), rgba); palette.save(path / "palette.png")
                manifest = dict(actions=order, table_width=512, clip_count=clip_count, pages=1,
                    variants=[dict(id=i, standing_height=3) for i in ids],
                    timelines=[value for _ in range(len(ids) * 8) for value in [30, 1, 15, 135] + [0] * 28],
                    sounds={})
                (path / "motions.json").write_text(json.dumps(manifest))
                (path / "species.json").write_text(json.dumps([dict(id=i) for i in ids]))
            bank(old, [10], actions, (21, 42, 63, 255))
            bank(source, [99, 20], list(reversed(actions)), (79, 101, 123, 255))
            manifest = json.loads((source / "motions.json").read_text())
            manifest["sounds"] = {"106": "res://native/106.wav", "1:112": "res://native/112.wav"}
            (source / "motions.json").write_text(json.dumps(manifest))
            old_pixels = (old / "atlas-0.png").read_bytes()
            append_native_bank(old, source, [1], [dict(id=20)])
            manifest = json.loads((old / "motions.json").read_text())
            table = list(struct.iter_unpack("<4f", (old / "frames.bin").read_bytes()))
            palette = Image.open(old / "palette.png")
            self.assertEqual([r["id"] for r in manifest["variants"]], [10, 20])
            self.assertEqual(manifest["timeline_stride"], 42)
            self.assertEqual(manifest["sounds"], {"1:106": "res://native/106.wav", "1:112": "res://native/112.wav"})
            self.assertEqual((old / "atlas-0.png").read_bytes(), old_pixels)
            for skin, expected in [(0, (21, 42, 63, 255)), (1, (79, 101, 123, 255))]:
                for action in actions:
                    clip = table[(skin * len(actions) + actions.index(action)) * 8 + 4]
                    rect, metadata = table[manifest["clip_count"] + int(clip[0]) * 2:manifest["clip_count"] + int(clip[0]) * 2 + 2]
                    image = Image.open(ROOT / manifest["atlas_paths"][int(metadata[2])].removeprefix("res://"))
                    index = image.getpixel((int(rect[0]), int(rect[1])))
                    self.assertEqual(palette.getpixel((index, int(metadata[3]))), expected)
                    source_action = actions.index(action) if skin == 0 else 7 + list(reversed(actions)).index(action)
                    self.assertAlmostEqual(clip[2], 1.25 + (source_action * 8 + 4) / 1000, places=6)


if __name__ == "__main__":
    unittest.main()
