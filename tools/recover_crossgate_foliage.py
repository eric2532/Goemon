"""Recover native foliage paint and crown samples for solid Cross Gate tree variants."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/maps/falan/flora"
RECIPES = {
    "cg_evergreen": (10058, (48, 104, 64, 120)),
    "cg_woodland": (10085, (80, 104, 96, 120)),
    "cg_silverleaf": (10088, (104, 64, 120, 80)),
    "bark": (10058, (82, 240, 90, 256)),
}


def prepare(source):
    sys.path.insert(0, str(source / "tools"))
    import cg_library as library
    images, records = {}, {}
    for name, (serial, crop) in RECIPES.items():
        entry = library.serial_index()[serial]
        original = library.image_from_record(entry["pack"], entry["row"])
        patch = original.crop(crop)
        assert patch.getchannel("A").getextrema() == (255, 255), name
        patch = patch.convert("RGB")
        tile = Image.new("RGB", (patch.width*2, patch.height*2))
        tile.paste(patch, (0, 0)); tile.paste(ImageOps.mirror(patch), (patch.width, 0))
        tile.paste(ImageOps.flip(tile.crop((0, 0, tile.width, patch.height))), (0, patch.height))
        images[name] = tile
        record = {"serial": serial, "pack": entry["pack"], "row": entry["row"],
                  "source_rgba_sha256": hashlib.sha256(original.tobytes()).hexdigest(), "crop": crop}
        if name != "bark":
            # Samples remain native pixel coordinates; no guessed crown profile or baked ground shadow.
            points, spans = [], {}
            for y in range(0, min(original.height, -entry["y"]-36), 3):
                xs = []
                for x in range(original.width):
                    r, g, b, a = original.getpixel((x, y))
                    if a == 255 and g > r*.95 and g > b*1.15:
                        xs.append(x)
                        if x % 3 == 0: points.append((x, y))
                if xs: spans[y] = (min(xs), max(xs))
            assert len(points) > 500 and spans
            def luminance(rgb):
                linear = [(v/255/12.92 if v <= 10 else ((v/255+.055)/1.055)**2.4) for v in rgb[:3]]
                return sum(v*w for v, w in zip(linear, (.2126, .7152, .0722)))
            light = sum(luminance(rgb) for rgb in patch.getdata())/(patch.width*patch.height)
            shades = [round(max(.42, min(1.0, luminance(original.getpixel(p))/light)), 5) for p in points]
            record.update(origin=(-entry["x"], -entry["y"]), points=points, spans=spans, shades=shades)
        records[name] = record
    return images, {"metres_per_pixel": .031, "method": "Native opaque paint crops with mirrored seams; native green crown samples, excluding trunk and ground shadow.", "graphics": records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT.parent / "Magic Power")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    images, records = prepare(args.source.resolve())
    if args.check:
        assert json.loads((OUT / "source.json").read_text()) == json.loads(json.dumps(records))
        for name, expected in images.items():
            with Image.open(OUT / (name+".png")) as actual:
                assert actual.size == expected.size and actual.convert("RGB").tobytes() == expected.tobytes(), name
        print("PASS: foliage paint and crown samples reproduce their original source")
    else:
        OUT.mkdir(parents=True, exist_ok=True)
        for name, image in images.items(): image.save(OUT / (name+".png"))
        (OUT / "source.json").write_text(json.dumps(records, separators=(",", ":"))+"\n")
        print("Recovered three original crown profiles, foliage paint and bark")


if __name__ == "__main__": main()
