"""Recover the paving and public street furniture of Blue CG city map 1000."""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image

from build_falan_room_art import COLS, STRIDE, project_tile

MAP_ORIGIN = (153, 134)
GROUPS = {
    "LAMPS": (10422, 10423, 10424, 10428, 10429, 10611, 10612),
    "BENCHES": (10405, 10406, 10407, 10408, 10448, 10449, 10450, 10451),
    "FLOWERS": (10040, 10041, 10042, 10403, 10404, 11691, 11696, 11697,
                12169, 12170, 12171, 12175, 12176, 12178, 12179, 12180),
    "PLANTERS": (10426, 10427, 10452, 10453),
    "PARAPETS": tuple(range(10620, 10631)),
    "QUAY_WALLS": (10631, 10632),
    "FORTIFICATIONS": tuple(range(10640, 10654)) + tuple(range(10655, 10663)),
    "GARDEN_TREES": (10000, 10058, *range(10060, 10069), *range(10071, 10075),
                     *range(10085, 10095)),
    "GARDEN_HEDGES": tuple(range(10465, 10474)),
    "GARDEN_RAILS": tuple(range(10474, 10489)) + tuple(range(10670, 10680)) + tuple(range(10681, 10685)),
    "GARDEN_STATUES": (10400, 10401, 10402, 10462),
    "GARDEN_ORNAMENTS": (10028, 10035, 10036, *range(17235, 17242)),
    "MARKET_GOODS": (10014, 10015, 10016, 10017, 10018, 10021, 10022,
                     10032, 10033, 10034, 10043, 10044, 10053, 10055, 10056, 10057,
                     10413, 10415, 10416, 10417, 10419, 10536, 10540, 10541, 10553,
                     11017, 11018, 11019, 11020, 11496, 11497),
    "MARKET_PICKETS": tuple(range(10454, 10462)),
}
LEGACY_LAYOUT = Path(__file__).resolve().parents[1] / "tests/forest-shrine/reference/maps/forest_falan_city.json"


def garden_edges(objects, i, width, height, serial, family):
    """Direction bits in world order: negative X, positive X, positive Z, negative Z."""
    if serial in (10454, 10467, 10474, 10670):
        return 3
    if serial in (10456, 10466, 10475, 10671):
        return 12
    x, y = i % width, i // width
    result = 0
    for bit, (dx, dy) in enumerate(((0, -1), (0, 1), (-1, 0), (1, 0))):
        if 0 <= x+dx < width and 0 <= y+dy < height and objects[(y+dy)*width+x+dx] in family:
            result |= 1 << bit
    return result


def finish_building_plots(ground, width, height):
    """Dress flat under-building tiles that are exposed around the 3D façades."""
    remaining = {i for i, serial in enumerate(ground) if serial == 100}
    turf = tuple(range(5027, 5036))
    while remaining:
        plot = [remaining.pop()]
        paving = greenery = 0
        for cell in plot:
            x, y = cell % width, cell // width
            for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if not (0 <= nx < width and 0 <= ny < height):
                    continue
                neighbor = ny*width+nx
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    plot.append(neighbor)
                    continue
                serial = ground[neighbor]
                paving += 1000 <= serial < 1100 or 5954 <= serial <= 5988
                greenery += 5009 <= serial < 5954
        for cell in plot:
            ground[cell] = 1004 if paving > greenery else turf[(cell*17+cell//width) % len(turf)]


def pond_art(magic):
    sys.path.insert(0, str(magic / "tools"))
    import cg_library as library

    atlas = Image.new("RGB", (2*STRIDE, STRIDE))
    for index, serial in enumerate((3880, 5002)):
        item = library.serial_index()[serial]
        atlas.paste(project_tile(library.image_from_record(item["pack"], item["row"])), (index*STRIDE, 0))
    return atlas


def build(magic, output):
    sys.path.insert(0, str(magic / "tools"))
    import cg_library as library

    pond_art(magic).save(output / "city_pond_atlas.png", optimize=True)

    source = magic / "godot/assets/exploration/manifest.json"
    path = json.loads(source.read_text())["map"]["source"]
    with library.connection() as db:
        key = db.execute("SELECT id FROM files WHERE path = ?", (path,)).fetchone()[0]
    width, height, ground, objects, _ = library.parse_map(library.source_file(key)[1].read_bytes())
    ground = list(ground)
    # The paving beside the east hospital NPC is stored on the original object plane.
    hospital_paving = 83*width+232
    assert ground[hospital_paving] == 0 and objects[hospital_paving] == 1004
    ground[hospital_paving] = objects[hospital_paving]
    finish_building_plots(ground, width, height)
    # The cathedral sprite is split between a tall object and these base tiles.
    # Its new 3D plinth replaces the baked façade and shadow around the footprint.
    for y in range(15, 30):
        for x in range(148, 160):
            i = y*width+x
            if 1422 <= ground[i] <= 1525:
                ground[i] = 1004
    for y in range(147, 161):
        for x in range(118, 127):
            i = y*width+x
            if 1526 <= ground[i] <= 1621:
                ground[i] = 1004
    # The three mansion domes replace the baked rotunda and pavilion foundations.
    for y in range(143, 156):
        for x in range(177, 193):
            i = y*width+x
            if 6707 <= ground[i] <= 6776:
                ground[i] = 5027 + (x*17+y) % 9
    surface_path = output / "city_surface.png"
    with Image.open(surface_path) as source_surface:
        surface = source_surface.convert("RGBA")
    cols, rows = surface.size
    assert cols <= height and rows == width
    surface.putpixel((83, rows-1-232), (0, 0, 255, 255))
    ponds = [(i % width, i // width) for i, serial in enumerate(ground[:cols*width]) if serial == 3880]
    for x, y in ponds:
        surface.putpixel((y, rows-1-x), (255, 0, 0, 255))
    surface.save(surface_path, optimize=True)
    lookup = library.serial_index()
    serials = {ground[y*width+x] for y in range(cols) for x in range(rows)}
    tiles = {}
    projected = []
    for serial in sorted(serials - {0, 3880, *range(5000, 5009)}):
        item = lookup.get(serial)
        if not item or (item["w"], item["h"]) != (64, 47):
            continue
        image = library.image_from_record(item["pack"], item["row"])
        tiles[serial] = len(projected)
        projected.append(project_tile(image))
    assert len(projected) <= COLS * 256
    atlas = Image.new("RGB", (COLS*STRIDE, ((len(projected)+COLS-1)//COLS)*STRIDE))
    for index, tile in enumerate(projected):
        atlas.paste(tile, (index % COLS * STRIDE, index // COLS * STRIDE))
    grid = Image.new("RGBA", (cols, rows))
    for y in range(cols):
        for x in range(rows):
            index = tiles.get(ground[y*width+x])
            if index is not None:
                grid.putpixel((y, rows-1-x), (index % COLS, index // COLS, 0, 255))
    atlas.save(output / "city_paving_atlas.png", optimize=True)
    grid.save(output / "city_paving_index.png", optimize=True)

    lines = ["extends RefCounted", "", "# Generated from Blue CG city map 1000."]
    ox, oy = MAP_ORIGIN
    for group, serials in GROUPS.items():
        lines.append(f"const {group}=[")
        for i, serial in enumerate(objects[:cols*width]):
            if serial not in serials:
                continue
            item = lookup[serial]
            x = 3*(i//width-oy) - 1.5*(max(1, item["south"])-1)
            z = 3*(ox-i%width) - 1.5*(max(1, item["east"])-1)
            edges = f",{garden_edges(objects, i, width, height, serial, serials)}" if group in (
                "GARDEN_HEDGES", "GARDEN_RAILS", "MARKET_PICKETS") else ""
            lines.append(f" [Vector2({x:g},{z:g}),{serial}{edges}],")
        lines.append("]")
    lines.append("const LILY_TILES=[")
    for x, y in ponds:
        lines.append(f" Vector2({3*(y-oy)},{3*(ox-x)}),")
    lines.append("]")
    lines.append("const FOUNTAINS=[")
    for i, serial in enumerate(ground[:cols*width]):
        if serial in (3352, 3374):
            offset = 1.5 if serial == 3374 else 0
            lines.append(f" Vector2({3*(i//width-oy)-offset:g},{3*(ox-i%width)-offset:g}),")
    lines.append("]")
    lines.append("const LEGACY_FORTS={")
    legacy = json.loads(LEGACY_LAYOUT.read_text())
    for prop in legacy["props"]:
        if prop["kind"] in ("wall_piece", "round_gate_tower"):
            signature = "tower" if prop["kind"] == "round_gate_tower" else f"wall{prop['rotation']}"
            lines.append(f' Vector2i({prop["x"]},{prop["z"]}):"{signature}",')
    lines.append("}")
    for name, plants in (
        ("LEGACY_TREES", legacy["trees"]),
        ("LEGACY_SHRUBS", [prop for prop in legacy["props"] if prop["kind"] == "shrub"]),
    ):
        lines.append(f"const {name}={{")
        for plant in plants:
            lines.append(f' Vector2i({plant["x"]},{plant["z"]}):Vector2({plant["scale"]:g},{plant["rotation"]}),')
        lines.append("}")
    (output / "city_street_data.gd").write_text("\n".join(lines) + "\n")
    print(f"{len(projected)} original paving graphics on a {cols} × {rows} grid")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("magic_power", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.magic_power.resolve(), args.output.resolve())
