"""Recover Freyja's original floor tiles for the existing 3D terrain shader."""
import argparse
import sys
from pathlib import Path

from PIL import Image

from build_falan_room_art import COLS, STRIDE, project_tile
from build_freyja_destinations import load_map
from build_freyja_outlying import is_water


def build(magic, output, map_id=100):
    sys.path.insert(0, str(magic / "tools"))
    import cg_library as library

    width, height, ground, _, _ = load_map(library, map_id)
    name = {100:"freyja",300:"sokia",3200:"kili",2100:"venoa",2000:"il_village",2400:"alyut"}[map_id]
    lookup = library.serial_index()
    serials = sorted(serial for serial in set(ground) - {0, 100}
                     if serial in lookup and (lookup[serial]["w"], lookup[serial]["h"]) == (64, 47))
    atlas = Image.new("RGB", (COLS * STRIDE, ((len(serials) + COLS - 1) // COLS) * STRIDE))
    indices = {}
    for index, serial in enumerate(serials):
        entry = lookup[serial]
        tile = project_tile(library.image_from_record(entry["pack"], entry["row"]))
        atlas.paste(tile, (index % COLS * STRIDE, index // COLS * STRIDE))
        indices[serial] = index
    surface = Image.new("RGBA", (width, height))
    for cell, serial in enumerate(ground):
        if serial not in indices:
            continue
        index = indices[serial]
        surface.putpixel((cell % width, cell // width),
                         (index % COLS, index // COLS, 255 if is_water(serial) else 0, 255))
    atlas.save(output / f"{name}_ground_atlas.png", optimize=True)
    surface.save(output / f"{name}_ground_index.png", optimize=True)
    assert sum(surface.getchannel("A").histogram()[1:]) == sum(s in indices for s in ground)
    print(f"{name} {width} × {height}, {len(serials)} original floor graphics.")
    return indices


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("magic_power", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.magic_power.resolve(), args.output.resolve())
