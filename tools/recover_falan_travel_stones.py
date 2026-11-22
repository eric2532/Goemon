"""Recover Falan's six local travel stones from the preserved Blue CG study."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image


def recover(source, output):
    world = source / "godot/assets/exploration"
    stones = json.loads((world / "world.json").read_text())["stones"]
    assert len(stones) == 6 and all(row["mapId"] == 1000 for row in stones)
    clip = stones[0]["clip"]
    assert all(row["clip"] == clip for row in stones)
    assert (clip["frames"], clip["columns"], clip["width"], clip["height"]) == (8, 8, 56, 115)
    output.mkdir(parents=True, exist_ok=True)
    atlas = world / clip["file"]
    shutil.copyfile(atlas, output / "travel_stone.png")
    rows = ["extends RefCounted", "## Original city map 1000 cells; world X/Z = 3*(y-134,153-x).", "const STONES=["]
    for stone in stones:
        x, y = stone["mapCell"]
        rows.append(' [%s,Vector2i(%d,%d),Vector2(%d,%d)],' %
                    (json.dumps(stone["name"], ensure_ascii=False), x, y, 3*(y-134), 3*(153-x)))
    rows += ["]", ""]
    (output / "travel_stone_data.gd").write_text("\n".join(rows))
    sys.path.insert(0, str(source / "tools"))
    import cg_library as library
    lookup = library.serial_index()
    ornaments = Image.new("RGBA", (4*144, 2*144))
    art_rows = ["extends RefCounted", "## Exact original sprites and their authored pixel anchors.", "const ART={"]
    art_hashes = {}
    for i, serial in enumerate(range(17235, 17242)):
        record = lookup[serial]
        image = library.image_from_record(record["pack"], record["row"])
        x, y = i%4*144, i//4*144
        ornaments.paste(image, (x, y))
        art_rows.append(" %d:[Rect2(%d,%d,%d,%d),Vector2(%d,%d)]," %
                        (serial, x, y, image.width, image.height, record["x"], record["y"]))
        art_hashes[str(serial)] = hashlib.sha256(image.tobytes()).hexdigest()
    ornaments.save(output / "travel_stone_ornaments.png")
    (output / "travel_stone_art.gd").write_text("\n".join(art_rows + ["}", ""]))
    manifest = dict(ornament_pixel_hashes=art_hashes,source="BlueCrossgate original:3171, action 0; preserved Magic Power exploration recovery",
                    atlas_sha256=hashlib.sha256(atlas.read_bytes()).hexdigest(), clip=clip, stones=stones)
    (output / "travel_stone_source.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print("Recovered six city stones and the original eight-frame crystal.")


if __name__ == "__main__":
    recover(Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "Magic Power",
            Path(__file__).resolve().parents[1] / "assets/maps/falan")
