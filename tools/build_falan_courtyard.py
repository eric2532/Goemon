"""Recover the castle courtyard paving and scenery anchors from Blue CG map 1500."""
import argparse
from itertools import groupby
import json
import sys
from pathlib import Path

from PIL import Image

from build_falan_room_art import GUTTER, STRIDE, project_tile


def build(magic, output):
    sys.path.insert(0, str(magic / "tools"))
    import cg_library as library

    exploration = magic / "godot/assets/exploration"
    source = json.loads((exploration / "world.json").read_text())["maps"]["1500"]["file"]
    path = json.loads((exploration / source).read_text())["map"]["source"]
    with library.connection() as db:
        key = db.execute("SELECT id FROM files WHERE path = ?", (path,)).fetchone()[0]
    width, height, ground, objects, _ = library.parse_map(library.source_file(key)[1].read_bytes())
    assert (width, height) == (80, 120)
    lookup = library.serial_index()
    size = 16
    atlas = Image.new("RGBA", (height * size, width * size))
    tiles = {}
    for serial in sorted(set(ground) - {0, *range(5000, 5009)}):
        item = lookup.get(serial)
        if not item or (item["w"], item["h"]) != (64, 47):
            continue
        image = library.image_from_record(item["pack"], item["row"])
        tile = project_tile(image).crop((GUTTER, GUTTER, STRIDE-GUTTER, STRIDE-GUTTER))
        tiles[serial] = tile.resize((size, size), Image.Resampling.LANCZOS)
    for i, serial in enumerate(ground):
        if serial in tiles:
            atlas.paste(tiles[serial], (i // width * size, (width - 1 - i % width) * size))
    atlas.save(output / "castle_courtyard_paving.png", optimize=True)

    scenery = {
        "WALLS": (10640, 10641),
        "SQUARE_TOWERS": (10644, 10645, 10647, *range(10648, 10654), 10661),
        "ROUND_TOWERS": tuple(range(10656, 10661)),
        "GATE_BEAMS": (10646, 10662),
        "PARAPETS": tuple(range(10620, 10631)),
        "ANNEXES": (10013,),
        "HEDGES": tuple(range(10465, 10472)),
        "LAMPS": (10422, 10423, 10612, 17083),
        "FLOWERS": (10039, 10403, 10404, 11434, 11641, 11643, 11644, 11647, 12169, 12170,
                    12171, 12178, 12179, 12180, 16229),
        "BENCHES": (10406, 10408, 10451),
        "TABLES": (10541, 16566, 16567, 16568, 16569, 16574, 16575, 16576, 16577),
        "MONUMENTS": (10045, 10046, 10400, 10462),
        "TREES": (*range(10085, 10091), 10094),
        "IRONWORK": (10672, 10675, 10679, 10684),
        "PILLARS": (10463,),
        "SIGNS": (10415,),
    }
    rows = ["extends RefCounted", "", "# Generated from Blue CG castle map 1500."]
    count = 0
    for group, serials in scenery.items():
        rows.append(f"const {group}=[")
        for i, serial in enumerate(objects):
            if serial not in serials:
                continue
            item = lookup[serial]
            x = 3*(i // width - 56) - 1.5*(max(1, item["south"])-1)
            z = 3*(41 - i % width) - 1.5*(max(1, item["east"])-1)
            rows.append(f" [Vector2({x:g},{z:g}),{serial}],")
            count += 1
        rows.append("]")
    # The central keep has a nominal one-tile sprite anchor. Its actual base
    # is drawn in two numbered runs of ground graphics in the source map.
    rows.append("const KEEP_BASE=[")
    _, keep = next((i % width, i // width) for i, serial in enumerate(objects) if serial == 10012)
    for z in range(keep-9, keep+1):
        cells = [x for x in range(width) if (1081 <= ground[z*width+x] <= 1149
                                             or 1693 <= ground[z*width+x] <= 1797)]
        for _, run in groupby(enumerate(cells), lambda pair: pair[1]-pair[0]):
            span = [x for _, x in run]
            rows.append(f" [Vector2({3*(z-56)},{3*(41-(span[0]+span[-1])/2):g}),{3*len(span)}],")
    rows.append("]")
    rows.append("const FOUNTAINS=[")
    for i, serial in enumerate(objects):
        if serial == 250 and ground[i] == 3369:
            rows.append(f" Vector2({3*(i//width-56)+1.5:g},{3*(41-i%width)-1.5:g}),")
    rows.append("]")
    (output / "castle_courtyard_data.gd").write_text("\n".join(rows) + "\n")
    print(f"{len(tiles)} courtyard ground graphics, {count} scenery anchors")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("magic_power", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.magic_power.resolve(), args.output.resolve())
