"""Recover Venoa-road cliff paint from the original Freyja crag sprite."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
CROPS = {"cliff_stone": (80,330,100,350), "cliff_moss": (75,290,95,315)}
CAVE_CROPS = ((24,18,40,34),(26,94,42,110))


def prepare(source):
    sys.path.insert(0,str(source / "tools"))
    import cg_library as library
    entry = library.serial_index()[12543]
    original = library.image_from_record(entry["pack"],entry["row"])
    images = {}
    for name,bounds in CROPS.items():
        patch = original.crop(bounds)
        assert patch.getchannel("A").getextrema() == (255,255)
        patch = patch.convert("RGB")
        tile = Image.new("RGB",(patch.width*2,patch.height*2))
        tile.paste(patch,(0,0));tile.paste(ImageOps.mirror(patch),(patch.width,0))
        tile.paste(ImageOps.flip(tile.crop((0,0,tile.width,patch.height))),(0,patch.height))
        images[name] = tile
    provenance = {"serial":12543,"pack":entry["pack"],"row":entry["row"],
                  "source_rgba_sha256":hashlib.sha256(original.tobytes()).hexdigest(),
                  "crops":CROPS,"method":"Native opaque crop; mirrored edges; no resampling or repainting."}
    entry = library.serial_index()[13355]
    original = library.image_from_record(entry["pack"],entry["row"])
    atlas = Image.new("RGB",(256,256))
    for variant,bounds in enumerate(CAVE_CROPS):
        patch = original.crop(bounds)
        assert patch.getchannel("A").getextrema() == (255,255)
        patch = patch.convert("RGB")
        stone = [(x,y) for y in range(16) for x in range(16)
                 if sum(patch.getpixel((x,y))) >= 225]
        assert stone
        clean = patch.copy()
        for y in range(16):
            for x in range(16):
                if sum(patch.getpixel((x,y))) < 225:
                    at = min(stone,key=lambda p:(p[0]-x)**2+(p[1]-y)**2)
                    clean.putpixel((x,y),patch.getpixel(at))
        assert set(clean.getdata()).issubset(set(patch.getdata()))
        tile = Image.new("RGB",(32,32))
        tile.paste(clean,(0,0));tile.paste(ImageOps.mirror(clean),(16,0))
        tile.paste(ImageOps.flip(tile.crop((0,0,32,16))),(0,16))
        for y in range(variant*128,(variant+1)*128,32):
            for x in range(0,256,32):atlas.paste(tile,(x,y))
    images["cave_rock_atlas"] = atlas
    provenance["cave_stone"] = {"serial":13355,"pack":entry["pack"],"row":entry["row"],
        "source_rgba_sha256":hashlib.sha256(original.tobytes()).hexdigest(),"crops":CAVE_CROPS,
        "method":"Replace baked dark crevices (RGB sum <225) with nearest stone pixel from the same native crop; mirror/repeat without resampling."}
    return images,provenance


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source",type=Path,default=ROOT.parent / "Magic Power")
    parser.add_argument("--check",action="store_true")
    args = parser.parse_args()
    images,provenance = prepare(args.source.resolve())
    out = ROOT / "assets/maps/falan/venoa_scenery"
    if args.check:
        assert json.loads((out / "provenance.json").read_text()) == json.loads(json.dumps(provenance))
        for name,image in images.items():
            actual = Image.open(out / (name+".png")).convert("RGB")
            assert actual.size == image.size and actual.tobytes() == image.tobytes(),name
        print("PASS: Venoa cliff/cave paint reproduces its native source recipes exactly")
    else:
        out.mkdir(parents=True,exist_ok=True)
        for name,image in images.items():image.save(out / (name+".png"))
        (out / "provenance.json").write_text(json.dumps(provenance,indent=2)+"\n")
        print("Recovered original Freyja cliff and Venoa stone paint")


if __name__ == "__main__":main()
