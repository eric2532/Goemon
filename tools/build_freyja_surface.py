"""Recover Freyja's original floor tiles for the existing 3D terrain shader."""
import argparse
import sys
from pathlib import Path

from PIL import Image

from build_falan_room_art import COLS, STRIDE, project_tile
from build_freyja_destinations import load_map
from build_freyja_outlying import is_water


def build(magic, output, map_id=100, lookup=None):
    sys.path.insert(0, str(magic / "tools"))
    import cg_library as library

    width, height, ground, _, _ = load_map(library, map_id)
    name = {100:"freyja",300:"sokia",3200:"kili",2100:"venoa",2000:"il_village",2300:"laruka",2400:"alyut",3000:"ghana"}[map_id]
    if lookup is None:lookup = library.serial_index()
    serials = sorted(serial for serial in set(ground) - {0, 100}
                     if serial in lookup and (lookup[serial]["w"], lookup[serial]["h"]) == (64, 47))
    indices = {}
    old_atlas=None
    if map_id in (100,300):
        base=Path(__file__).resolve().parents[1]/'assets/maps/falan'
        if (base/f'{name}_ground_index.png').exists():
            old_index=Image.open(base/f'{name}_ground_index.png').convert('RGBA')
            old_atlas=Image.open(base/f'{name}_ground_atlas.png').convert('RGB')
            assert old_index.size==(width,height)
            for i,serial in enumerate(ground):
                if serial not in serials:continue
                r,g,_,a=old_index.getpixel((i%width,i//width))
                if not a:continue
                slot=r+g*COLS
                assert serial not in indices or indices[serial]==slot
                indices[serial]=slot
            for serial,slot in indices.items():
                entry=lookup[serial];tile=project_tile(library.image_from_record(entry['pack'],entry['row']))
                x,y=slot%COLS*STRIDE,slot//COLS*STRIDE
                assert old_atlas.crop((x,y,x+STRIDE,y+STRIDE)).tobytes()==tile.tobytes(),'Existing source tile pixels must remain exact'
    next_slot=max(indices.values(),default=-1)+1
    for serial in serials:
        if serial not in indices:indices[serial]=next_slot;next_slot+=1
    atlas = Image.new("RGB", (COLS * STRIDE, max(old_atlas.height if old_atlas else 0,((next_slot + COLS - 1) // COLS) * STRIDE)))
    if old_atlas:atlas.paste(old_atlas,(0,0))
    for serial,index in indices.items():
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
    parser.add_argument("--map", dest="map_id", type=int, choices=[100,300], default=100)
    args = parser.parse_args()
    build(args.magic_power.resolve(), args.output.resolve(), args.map_id)
