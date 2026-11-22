"""Recover unchanged Blue CG chest and food sprites from the preserved library."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

OUT = Path(__file__).resolve().parents[1] / "assets/items/crossgate"
ROWS = {"chest": 15614, "black-chest": 15616, "white-chest": 15618,
        "bread": 14982, "roast-chicken": 15054, "bento": 15012,
        "hot-pot": 15076, "stew": 15011, "noodles": 15014,
        "fruit-salad": 14986, "dumplings": 15022, "oyakodon": 15013}


def recover(source):
    sys.path.insert(0, str(source / "tools"))
    import cg_library

    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for name, row in ROWS.items():
        image = cg_library.image_from_record("original", row)
        path = OUT / (name + ".png")
        image.save(path)
        manifest[name] = {"pack": "original", "row": row,
                          "size": list(image.size),
                          "rgba_sha256": hashlib.sha256(image.tobytes()).hexdigest(),
                          "png_sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        assert image.getbbox() is not None and image.mode == "RGBA"
        # Keep transparent-edge pixels intact on the first Godot import too.
        settings = path.with_suffix(".png.import")
        if not settings.exists():
            settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n'
                                '[deps]\nsource_file="res://assets/items/crossgate/' + path.name +
                                '"\n[params]\ncompress/mode=0\n'
                                'process/fix_alpha_border=false\nmipmaps/generate=false\n')
    (OUT / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Recovered {len(ROWS)} unchanged Blue CG loot sprites")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    recover(parser.parse_args().source.resolve())
