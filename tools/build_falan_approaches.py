"""Join the city and Freyja surfaces and grade the three outer roads."""
from pathlib import Path
from math import hypot
import json
import sys

from PIL import Image, ImageDraw, ImageFilter

from build_freyja_outlying import build as build_outlying, il_bridge_deck, is_road, is_water, route
from build_freyja_destinations import build as build_destinations, draw_branches, load_map
from build_freyja_surface import build as build_surface

MAPS = Path(__file__).resolve().parents[1] / "assets/maps"
ORIGIN = (-480, -204)
END = (480, 480)
SOUTHEAST_TRAIL = (
    (3, 156), (3, 171), (-3, 183), (-3, 195), (-9, 207),
    (-30, 231), (-54, 249), (-66, 249), (-87, 285), (-99, 288),
    (-123, 282), (-135, 276), (-159, 276), (-171, 273), (-174, 261),
    (-186, 237), (-180, 213), (-171, 201), (-168, 165), (-174, 153),
    (-198, 144), (-222, 108), (-234, 96),
)
ROADS = {
    "west": (),
    "east": (SOUTHEAST_TRAIL[:16],),
    "south": (tuple((z - 18, -x - 15) for x, z in SOUTHEAST_TRAIL[9:]) + ((79, 222),),),
}


def distance_to_road(x, z, road):
    distance = float("inf")
    for (ax, az), (bx, bz) in zip(road, road[1:]):
        dx, dz = bx - ax, bz - az
        t = max(0, min(1, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
        distance = min(distance, hypot(x - ax - dx * t, z - az - dz * t))
    return distance


def city_point(side, x, z):
    if side == "south":
        return (168 + z, 3 - x)
    return (x - 141, z + 240) if side == "west" else (-135 - x, -225 - z)

def freyja_point(side, x, z):
    if side == "west":
        return 429 - z // 3, 194 + x // 3
    if side == "east":
        return 417 + z // 3, 197 - x // 3
    return 423 + x // 3, 202 + z // 3


def approach_point(side, x, z):
    if side == "west":
        return (z - 194) * 3, (429 - x) * 3
    if side == "east":
        return (197 - z) * 3, (x - 417) * 3
    return (x - 423) * 3, (z - 202) * 3


def build_east_scenery(magic_power, output):
    """Recover the East Gate–Il corridor without rewriting terrain or saved maps."""
    sys.path.insert(0, str(magic_power / "tools"))
    import cg_library

    width, _, ground, objects, _ = load_map(cg_library, 100)
    lookup = cg_library.serial_index()
    trees, details = [], []
    for y in range(34, 367):
        for x in range(472, 712):
            if not (x < 578 and 137 <= y < 258 or x >= 530 and y >= 215 or 568 <= x <= 710 and y <= 215):
                continue
            serial = objects[y * width + x]
            tile = ground[y * width + x]
            if not tile or is_water(tile):
                continue
            if 10058 <= serial <= 10094:
                kind = "cedar" if serial <= 10065 else "pine" if serial <= 10073 else "tree"
                trees.append(f' Vector2({x},{y}):"{kind}",')
                continue
            asset = None
            if 11661 <= serial <= 11679:
                asset = "grass_tall"
            elif serial in (11656, 11659, 11696, 11697, 11698, 12169, 12170, 12171):
                asset = "flowers_ivory"
            elif 12175 <= serial <= 12180:
                asset = "flowers_coral"
            elif 12107 <= serial <= 12130 or 12225 <= serial <= 12244:
                asset = "mossy_boulder"
            if asset:
                entry = lookup[serial]
                # Fit the existing small props to the original one-tile art footprint.
                scale = min(.75, entry["w"] / 110) if asset == "mossy_boulder" else min(2.2, entry["w"] / 24)
                details.append(f' [Vector2({x},{y}),{serial},"{asset}",{scale:.3f}],')
    assert trees and details
    (output / "east_gate_scenery_data.gd").write_text("\n".join([
        "extends RefCounted", "## Blue CG map 100 source tiles: East Gate (472–577,137–257), Il road (530–711,215–366), Alyut coast (568–710,34–215).",
        "const TREES={", *trees, "}", "const DETAILS=[", *details, "]", ""]))
    print(f"East Gate–Il: {len(trees)} source tree identities, {len(details)} small scenery anchors")


def build():
    magic_power = Path(sys.argv[1]) if len(sys.argv) > 1 else MAPS.parents[2] / "Magic Power"
    sys.path.insert(0, str(magic_power / "tools"))
    import cg_library

    archive_width, archive_height, freyja, objects, _ = cg_library.parse_map(cg_library.source_file(1119)[1].read_bytes())
    sokia = load_map(cg_library, 300)[:4]
    branches = build_destinations(magic_power, MAPS / "falan", cg_library, archive_width, archive_height, freyja, sokia)
    paths = build_outlying(MAPS / "falan", archive_width, archive_height, freyja, objects, branches, sokia)
    lookup = cg_library.serial_index()
    build_surface(magic_power, MAPS / "falan")
    def ground(x, z):
        return freyja[z * archive_width + x]

    def dry_ground(x, z):
        return ground(x, z) or 5000

    south_spine = route([(424, 259), (441, 274), (468, 289), (471, 310), (438, 344), (441, 347)], dry_ground)
    kobizen_spur = route([(468, 301), (447, 301)], dry_ground)
    approach_traces = {
        "west": route([(374, 195), (301, 181)], dry_ground) + paths["west_lakes"][0][:24],
        "east": route([(475, 196), (481, 198), (513, 230), (545, 233)], ground) + paths["east_coast"][0][:24],
        "south": south_spine + paths["south_lakes"][0][:18],
    }
    city = Image.open(MAPS / "falan/city_surface.png").convert("RGBA")
    scenery = ["extends RefCounted", "## Generated from the outdoor sides of the Blue CG Freyja crossings.", "const EXTERIORS={"]
    for side, roads in ROADS.items():
        south = side == "south"
        start_x, start_z = ORIGIN
        end_x, end_z = END
        if side == "west":
            original = Image.open(MAPS / "freyja_west_gate/layout_mask.png").convert("RGBA")
            ox, oz = -84, -90
        else:
            original = Image.open(MAPS / f"falan/{side}_gate_surface.png").convert("RGBA")
            ox, oz = -90, 21
        city_end = 36 if south else 54
        archive_start = 45 if south else 63
        bridge_left, bridge_right = (-9, 15) if south else (-6, 12)
        mask = Image.new("RGBA", ((end_x - start_x) // 3 + 1, (end_z - start_z) // 3 + 1))
        trace = Image.new("L", mask.size)
        traces = (approach_traces[side], kobizen_spur) if south else (approach_traces[side],)
        for path in traces:
            local_trace = [approach_point(side, x, z) for x, z in path]
            ImageDraw.Draw(trace).line([((x - start_x) // 3, (z - start_z) // 3) for x, z in local_trace],
                                      fill=208 if side == "east" else 148, width=5)
        trace_clearance = trace if side == "east" else trace.filter(ImageFilter.MaxFilter(5))
        local_branches = branches["freyja" if side=="west" else side+"_gate"]
        destinations = [path[-1] for path in local_branches]
        branch = draw_branches(mask.size, (start_x, start_z), local_branches,
                               lambda x,z: approach_point(side,x,z))
        branch_shoulders = branch.filter(ImageFilter.MaxFilter(19)).filter(ImageFilter.GaussianBlur(3))
        props = []
        forts = []
        lamps = []
        posts = []
        rocks = []
        crops = []
        stone = {"west": (96, 150), "east": (84, 144), "south": (105, 153)}
        near, far = stone.get(side, (0, 0))
        for j, z in enumerate(range(start_z, end_z + 1, 3)):
            for i, x in enumerate(range(start_x, end_x + 1, 3)):
                fade = max(0, min(1, (end_x - abs(x)) / 33, (z + 204) / 30, (end_z - z) / 27))
                # Keep the near-city terrain strip narrow where it represents the city.
                city_width = 168 + 156 * max(0, min(1, (z - city_end) / 90))
                fade = min(fade, max(0, (city_width - abs(x)) / 27))
                if z > archive_start:
                    fade = 1.0
                traced_road = trace.getpixel((i, j))
                side_road = branch.getpixel((i, j))
                fade = max(fade, min(1, branch_shoulders.getpixel((i,j)) / 145))
                if traced_road and z > 441:
                    fade = max(fade, min(1, (end_z - z) / 9))
                r, g, b, a = 0, 0, 0, round(255 * fade)
                if city_end < z <= archive_start:
                    sx, sy = freyja_point(side, x, z)
                    tile = ground(sx, sy)
                    r, g = (255 if is_water(tile) else 0), (176 if is_road(tile) else 0)
                    u, v = (x - ox) // 3, (z - oz) // 3
                    if 0 <= u < original.width and 0 <= v < original.height:
                        r, g, b, old_alpha = original.getpixel((u, v))
                        r = r if old_alpha > 128 else 0
                        g, b = round(g * old_alpha / 255), round(b * old_alpha / 255)
                if z <= city_end:
                    cx, cz = city_point(side, x, z)
                    u, v = (cx + 402) // 3, (cz + 438) // 3
                    if 0 <= u < city.width and 0 <= v < city.height:
                        r, g, b, _ = city.getpixel((u, v))
                    if city_end - 12 <= z and -6 <= x <= 12:
                        r, g, b = 0, 0, max(b, 200)
                if z > archive_start:
                    sx, sy = freyja_point(side, x, z)
                    tile = ground(sx, sy)
                    serial = objects[sy * archive_width + sx]
                    r = 255 if is_water(tile) or not tile else 0
                    g = 218 if is_road(tile) else 0
                    b = 215 if 1000 <= tile <= 1005 or 5954 <= tile <= 5988 else 0
                    if side == "east" and 499 <= sx <= 502 and 161 <= sy <= 164 and 3996 <= tile <= 3999:
                        g = 250
                        if serial:
                            crops.append(f"[Vector2({x},{z}),{serial}]")
                    if side == "east" and r == 0 and il_bridge_deck(sx,sy):
                        b = 215
                    if bridge_left <= x <= bridge_right and z <= far:
                        # The archive paints the deck flat. The separate mesh spans the water.
                        r, g, b = 255, 0, 0
                    if near <= z <= far and x in (bridge_left, bridge_right) and serial in (10620, 10626, 10628):
                        posts.append(f"Vector2({x},{z})")
                    if near <= z <= far and serial == (10422 if south else 10424):
                        lamps.append(f"Vector2({x},{z})")
                    if 10640 <= serial <= 10662 and serial != (10646 if south else 10662):
                        dx, dz = {"west":(-3,-3),"east":(3,3),"south":(3,-3)}[side]
                        model = {10640:10641,10641:10640}.get(serial, serial) if south else serial
                        forts.append(f"[Vector2({x+dx},{z+dz}),{model}]")
                    tall = 12536 <= serial <= 12565
                    shore = 12500 <= serial <= 12535
                    if (tall or shore) and fade == 1 and not any(abs(sx-a)<=6 and abs(sy-c)<=6 for a,c in destinations):
                        entry = lookup[serial]
                        width, depth = max(1,entry["south"])*3, max(1,entry["east"])*3
                        dx, dz = {"west":(-1,-1),"east":(1,1),"south":(1,-1)}[side]
                        if south:
                            width, depth = depth, width
                        px, pz = x+dx*(width-3)//2, z+dz*(depth-3)//2
                        height = max(9, (entry["h"]-46)*.050) if tall else min(1.4, entry["h"]*.012)
                        if tall and width == depth == 3:
                            height *= .63
                        clear = not trace_clearance.getpixel((i,j)) and not side_road
                        if not tall or clear:
                            rocks.append(f"[Vector2({px},{pz}),{serial},Vector2({width},{depth}),{height:.2f},{str(tall).lower()}]")
                    if r < 128 and z >= 165 and fade == 1 and not b:
                        tree = serial == 10000 or 10058 <= serial <= 10074 or 10085 <= serial <= 10094
                        if tree and not trace_clearance.getpixel((i,j)) and not side_road and all(distance_to_road(x,z,road)>=6 for road in roads[-1:]):
                            kind = "pine" if serial in (10058,10064,10072) else "tree"
                            size = 1.15 if serial >= 10085 else .9
                            props.append(f'["{kind}",Vector2({x},{z}),{size},{(x*4+z*11)%360}]')
                if z >= 156 and r < 128:
                    for road in roads[-1:]:
                        d = distance_to_road(x, z, road)
                        g = max(g, round(100 * max(0, min(1, (9 - d) / 4))))
                    g = max(g, traced_road)
                if r < 128:
                    g = max(g, side_road)
                mask.putpixel((i, j), (r, g, b, a))
        mask.save(MAPS / f"falan/{side}_approach_surface.png", optimize=True)
        key = "freyja" if side == "west" else side + "_gate"
        scenery.extend([f' "{key}":{{', '  "trees":['])
        scenery.extend(f"   {row}," for row in props)
        scenery.extend(["  ],", '  "rocks":['])
        scenery.extend(f"   {row}," for row in rocks)
        fixture = MAPS.parents[1] / "tests/forest-shrine/reference/maps" / f"forest_freyja_{side}_gate.json"
        saved = json.loads(fixture.read_text())
        scenery.extend(["  ],", '  "legacy":{'])
        for item in saved["props"] + saved["trees"]:
            if 140 <= item["z"] * 6 <= 240 or item.get("kind") in ("wall_piece", "round_gate_tower"):
                scenery.append(f'   Vector2i({item["x"]},{item["z"]}):["{item.get("kind","tree")}",{item["scale"]},{item["rotation"]}],')
        scenic_route=[f"Vector2({px},{pz})" for px,pz in (approach_point(side,x,z) for x,z in approach_traces[side])]
        scenery.extend(["  },", '  "route":[' + ",".join(scenic_route) + "],",
                        '  "forts":[' + ",".join(forts) + "],",
                        '  "lamps":[' + ",".join(lamps) + "],",
                        '  "posts":[' + ",".join(posts) + "],",
                        '  "crops":[' + ",".join(crops) + "],", " },"])
    (MAPS / "falan/gate_exterior_data.gd").write_text("\n".join(scenery + ["}", ""]))
    build_east_scenery(magic_power, MAPS / "falan")
    from build_east_road import build as east_road
    east_road(MAPS / "falan")


if __name__ == "__main__":
    build()
