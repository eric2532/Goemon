"""Build the outer regions from the original Freyja and Sokia tile grids."""
from collections import defaultdict
from heapq import heappop, heappush
from math import hypot

from PIL import Image, ImageDraw, ImageFilter

# Tile coordinates in the source maps, at the existing 3 m tile scale.
RADIUS = 138
SOKIA_LANDING = (240, 265)
KILI_TRAILHEAD = (274, 294)
KILI_EAST_EXIT = (295, 325)
GREAT_WIND_MOUTH = (356, 334)
GREAT_WIND_EAST = (402, 304)
GHANA_SOUTH_GATE = (704, 148)
GHANA_NORTH_GATE = (704, 95)
GHANA_GRAVES = (715, 34)
SOKIA_EAST_REGIONS = {"sokia_desert", "ghana_road", "ghana_north_road"}
REGIONS = {
    "west_lakes": ("Western Lakes", (190, 181), []),
    "east_coast": ("East Coast", (647, 262), [
        [(648, 294), (669, 261), (677, 233), (686, 193), (685, 185)],
    ]),
    "north_coast": ("North Coast", (634, 111), [[
        (677, 233), (686, 193), (685, 185),
    ]]),
    "south_lakes": ("Southern Lakes", (387, 463), []),
    "sokia_coast": ("Sokia Coast", (258, 280), [[SOKIA_LANDING, (253, 278), KILI_TRAILHEAD]]),
    "sokia_desert": ("Sokia Desert", (474, 270), []),
    "ghana_road": ("Ghana Road", (627, 201), []),
    "ghana_north_road": ("Ghana North Coast", (705, 69), []),
}
COAST_ROUTES = {
    "west_lakes": ((114, 148, 322, 243), (301, 181), (289, 181), (134, 218)),
    "east_coast": ((530, 215, 711, 366), (545, 233), (554, 233), (681, 343)),
    "north_coast": ((568, 34, 710, 207), (691, 188), (688, 175), (596, 84)),
    "south_lakes": ((310, 325, 460, 504), (441, 347), (441, 351), (330, 481)),
}
# From, to, archive axis (0=x), outward sign, seam tile, center across seam.
LINKS = (
    ("freyja", "west_lakes", 0, -1, 289, 181),
    ("east_gate", "east_coast", 0, 1, 554, 234),
    ("south_gate", "south_lakes", 1, 1, 351, 441),
    ("east_coast", "north_coast", 1, -1, 193, 686),
)
NEIGHBORS = [(dx, dz, hypot(dx, dz)) for dz in (-1, 0, 1)
             for dx in (-1, 0, 1) if dx or dz]


def is_water(tile):
    return 5000 <= tile <= 5008


def is_road(tile):
    return 5198 <= tile <= 5233 or 6400 <= tile <= 6409


def il_bridge_deck(x, z):
    return 554 <= x <= 559 and 232 <= z <= 234


def route(anchors, ground, clearance=True):
    """Follow dirt tiles and join short gaps over dry land."""
    def dry(p):
        x, z = p
        return not is_water(ground(x, z)) and (not clearance or
            all(not is_water(ground(x + dx, z + dz)) for dx, dz, _ in NEIGHBORS))

    def nearest(p):
        x, z = p
        return min(((x + a, z + b) for a in range(-8, 9) for b in range(-8, 9)
                    if dry((x + a, z + b))), key=lambda at: hypot(at[0] - x, at[1] - z))

    result = []
    nodes = [nearest(p) for p in anchors]
    for start, end in zip(nodes, nodes[1:]):
        lx, hx = min(start[0], end[0]) - 35, max(start[0], end[0]) + 35
        lz, hz = min(start[1], end[1]) - 35, max(start[1], end[1]) + 35
        cost = {start: 0}
        came_from = {}
        queue = [(0, start)]
        while queue:
            distance, at = heappop(queue)
            if distance > cost[at]:
                continue
            if at == end:
                break
            for dx, dz, step in NEIGHBORS:
                if not clearance and dx and dz:
                    continue
                p = (at[0] + dx, at[1] + dz)
                if not (lx <= p[0] <= hx and lz <= p[1] <= hz and dry(p)):
                    continue
                next_cost = distance + step * (1 if is_road(ground(*p)) else 5)
                if next_cost >= cost.get(p, float("inf")):
                    continue
                came_from[p] = at
                cost[p] = next_cost
                heappush(queue, (next_cost, p))
        if end != start and end not in came_from:
            raise ValueError(f"No dry route from {start} to {end}")
        path = [end]
        while path[-1] != start:
            path.append(came_from[path[-1]])
        result.extend(reversed(path[1:]))
    return result + nodes[-1:]


def gd_point(x, z):
    return f"Vector2({x},{z})"


def route_between_warps(anchors, ground):
    path = route(anchors, ground)
    if path[0] != anchors[0]:
        path = route([anchors[0], path[0]], ground, clearance=False)[:-1] + path
    if path[-1] != anchors[-1]:
        path += route([path[-1], anchors[-1]], ground, clearance=False)[1:]
    assert path[0] == anchors[0] and path[-1] == anchors[-1], (anchors, path[0], path[-1])
    assert all(not is_water(ground(*point)) for point in path)
    return path


def archive_walk(bounds, width, tiles, objects, lookup):
    from prepare_field_assets import navigation_grid

    left, top, right, bottom = bounds
    columns = right-left
    indices = [z*width+x for z in range(top,bottom) for x in range(left,right)]
    walk = navigation_grid(columns, bottom-top, [tiles[i] for i in indices],
                           [objects[i] for i in indices], lookup)

    def ground(x, z):
        if left <= x < right and top <= z < bottom and walk[(z-top)*columns+x-left]:
            return tiles[z*width+x]
        return 5000

    return ground


def kili_road(width, tiles, objects, lookup):
    walk = archive_walk((226, 251, 301, 315), width, tiles, objects, lookup)
    def ground(x, z):
        tile = walk(x, z)
        return 5198 if 6777 <= tile <= 6798 else tile
    path = route_between_warps([SOKIA_LANDING, (253,278), KILI_TRAILHEAD], ground)
    assert all(walk(*point) and not is_water(walk(*point)) for point in path)
    return path


def build(output, width, height, tiles, objects, branches, sokia):
    freyja = width, height, tiles, objects
    sokia_width, sokia_height, sokia_tiles, sokia_objects = sokia

    def sokia_walkable(x, z):
        if 0 <= x < sokia_width and 0 <= z < sokia_height:
            index = z * sokia_width + x
            if sokia_tiles[index] and sokia_objects[index] != 2:
                return sokia_tiles[index]
        return 5000

    # Follow the dry side of Sokia's north coast, including the detour around the inlet.
    ghana_road = [GREAT_WIND_EAST] + route([
        (402, 305), (445, 260), (475, 226), (540, 226), (562, 247),
        (655, 231), (690, 196), GHANA_SOUTH_GATE,
    ], sokia_walkable)
    assert ghana_road[-1] == GHANA_SOUTH_GATE
    assert all(not is_water(sokia_walkable(x, z)) for x, z in ghana_road)
    seam_x = 550
    seam_z = next(z for x, z in ghana_road if x == seam_x)

    # The coastal footpath narrows to a single original tile beside the graves.
    from cg_library import serial_index
    from prepare_field_assets import navigation_grid
    lookup = serial_index()
    left, top, right, bottom = 680, 28, 733, 114
    indices = [z*sokia_width+x for z in range(top,bottom) for x in range(left,right)]
    walk = navigation_grid(right-left, bottom-top, [sokia_tiles[i] for i in indices],
                           [sokia_objects[i] for i in indices], lookup)
    def north_ground(x, z):
        if left <= x < right and top <= z < bottom and walk[(z-top)*(right-left)+x-left]:
            return sokia_walkable(x,z)
        return 5000

    north_road = route([(704,96), GHANA_NORTH_GATE, (709,88), (711,72), (708,58),
                        (715,51), (716,39), GHANA_GRAVES], north_ground, clearance=False)
    assert north_road[:2] == [(704,96), GHANA_NORTH_GATE] and north_road[-1] == GHANA_GRAVES
    assert all(not is_water(north_ground(*point)) for point in north_road)
    # The 3D height mesh interpolates between tile centers. Support one
    # neighboring tile on either side of the original narrow path.
    north_shoulder = {(x+dx,z+dz) for x,z in north_road for dx in (-1,0,1) for dz in (-1,0,1)}

    def ground(x, z):
        return tiles[z * width + x] if 0 <= x < width and 0 <= z < height else 0

    lines = ["extends RefCounted", "## Generated by tools/build_falan_approaches.py from Freyja 100.dat and Sokia 300.dat.", "const REGIONS={"]
    for region, (title, (ox, oz), _) in REGIONS.items():
        lines.append(f' "{region}":["{title}",{gd_point(ox * 3, oz * 3)},preload("res://assets/maps/falan/{region}_surface.png")],')
    lines += ["}", "const LINKS=["]
    for a, b, axis, sign, edge, across in LINKS + (("sokia_desert", "ghana_road", 0, 1, seam_x, seam_z),):
        lines.append(f' ["{a}","{b}",{axis},{sign},{edge * 3},{across * 3}],')
    lines += ["]", "const TREES={"]
    paths = {}
    ridges = {}
    for region, (_, (ox, oz), road_anchors) in REGIONS.items():
        on_sokia = region == "sokia_coast" or region in SOKIA_EAST_REGIONS
        south = region == "south_lakes"
        east = region == "east_coast"
        north = region == "north_coast"
        west = region == "west_lakes"
        traced_coast = region in COAST_ROUTES
        width, height, tiles, objects = sokia if on_sokia else freyja
        paths[region] = [route(anchors, ground) for anchors in road_anchors]
        if region == "sokia_coast":
            paths[region][0] = kili_road(width, tiles, objects, lookup)
        if traced_coast:
            bounds, start, seam, village = COAST_ROUTES[region]
            coastal_walk = archive_walk(bounds, width, tiles, objects, lookup)

            if north:
                path = route_between_warps([start, seam, village], coastal_walk)
            else:
                path = route([start, seam, village], coastal_walk)
                path += route([path[-1], village], coastal_walk, clearance=False)[1:]
            assert seam in path and path[-1] == village and all(not is_water(coastal_walk(*point)) for point in path)
            paths[region].insert(0, path)
            if east:
                paths[region].append(route_between_warps([village, (672, 223)], coastal_walk))
            if north:
                paths[region].append(route_between_warps([(621, 70), (587, 51)], coastal_walk))
            if west:
                paths[region].append(route([village, (111, 227)], lambda x, z: ground(x, z) or 5000))
            ridges[region] = []
        if region in {"sokia_desert", "ghana_road"}:
            paths[region].append(ghana_road)
        if region == "sokia_coast":
            assert all(ground(x, z) and not is_water(ground(x, z)) for x, z in paths[region][0])
        radius = 160 if traced_coast else {"sokia_coast": 120, "sokia_desert": 104, "ghana_road": 102,
                                         "ghana_north_road": 82}.get(region, RADIUS)
        size = radius * 2 + 1
        trace = Image.new("L", (size, size))
        draw = ImageDraw.Draw(trace)
        for path in paths[region]:
            draw.line([(x - ox + radius, z - oz + radius) for x, z in path], fill=148 if traced_coast else 184, width=5)
        if region == "ghana_north_road":
            draw.line([(x - ox + radius, z - oz + radius) for x,z in north_road], fill=210, width=3)
            paths[region].append(north_road)
        narrow_shore = []
        for path in branches.get(region, []):
            if (north and path[-1][0] <= 550) or (south and path[-1] in {(299,538), (251,493), (260,449)}):
                narrow_shore.append(path)
                continue
            draw.line([(x - ox + radius, z - oz + radius) for x, z in path], fill=166, width=5)
        image = Image.new("RGBA", trace.size)
        trees = defaultdict(list)
        trace_pixels = trace.load()
        cliff_clearance = trace.filter(ImageFilter.MaxFilter(5)).load() if traced_coast else None
        # Archived footpaths skirt the cliff bases, so painting them must not carve out the cliffs.
        for path in narrow_shore:
            draw.line([(x - ox + radius, z - oz + radius) for x, z in path], fill=166, width=3)
        destinations = [path[-1] for path in branches.get(region, [])]
        if west or north:
            destinations.remove(village)
        pixels = image.load()
        for j in range(size):
            z = oz - radius + j
            for i in range(size):
                x = ox - radius + i
                tile = ground(x, z)
                wet = is_water(tile) or ((on_sokia or traced_coast) and not tile)
                archive_road = 224 if is_road(tile) else 0
                pave = 220 if 1000 <= tile <= 1099 or 5954 <= tile <= 5988 else 0
                if east and not wet and il_bridge_deck(x,z):
                    pave = 215
                if on_sokia:
                    pave = 220 if 6777 <= tile <= 6798 else 0
                if region == "ghana_north_road":
                    blocked = 0 <= x < width and 0 <= z < height and objects[z*width+x] == 2
                    shoulder = (x,z) in north_shoulder
                    wet = wet and not shoulder
                    if tile == 100 and blocked and not shoulder:
                        pave = 255
                    elif not wet and not 5045 <= tile <= 5053:
                        pave = 205
                fade = 255 if traced_coast else min(255, round(min(i, j, size - i - 1, size - j - 1) * 255 / 14))
                pixels[i, j] = (255 if wet else 0, 0 if wet else max(archive_road, trace_pixels[i, j]), pave, fade)
                if traced_coast and tile:
                    serial = objects[z*width+x]
                    tall = 12536 <= serial <= 12565
                    shore = 12500 <= serial <= 12535 and wet
                    if (tall or shore) and not any(abs(x-a)<=6 and abs(z-b)<=6 for a,b in destinations):
                        entry = lookup[serial]
                        ew, ns = max(1, entry["east"]), max(1, entry["south"])
                        if tall and any(cliff_clearance[min(i+a,size-1),max(j-b,0)] for a in range(ew) for b in range(ns)):
                            continue
                        center = gd_point((x-ox)*3+(ew-1)*1.5, (z-oz)*3-(ns-1)*1.5)
                        rise = max(9, (entry["h"]-46)*.050) if tall else min(1.4, entry["h"]*.012)
                        if tall and ew == ns == 1:
                            rise *= .63
                        ridges[region].append(f"  [{center},{serial},{gd_point(ew*3,ns*3)},{rise:.2f},{str(tall).lower()}],")
                if not (0 <= x < width and 0 <= z < height and fade == 255 and not wet and not pave):
                    continue
                item = objects[z * width + x]
                if item != 10000 and not (10058 <= item <= 10074 or 10085 <= item <= 10094):
                    continue
                if any(is_road(ground(x + a, z + b)) or is_water(ground(x + a, z + b))
                       or trace_pixels[max(0,min(i+a,size-1)), max(0,min(j+b,size-1))]
                       for a in range(-3, 4) for b in range(-3, 4)):
                    continue
                bucket = (x // 5, z // 5)
                if any((x - px)**2 + (z - pz)**2 < 16 for bx in range(bucket[0] - 1, bucket[0] + 2)
                       for bz in range(bucket[1] - 1, bucket[1] + 2) for px, pz, _ in trees.get((bx, bz), [])):
                    continue
                trees[bucket].append((x, z, item))
        image.save(output / f"{region}_surface.png", optimize=True)
        lines.append(f' "{region}":[')
        for tree in sorted(tree for group in trees.values() for tree in group):
            x, z, item = tree
            lines.append(f"  [{gd_point((x-ox)*3,(z-oz)*3)},{item}],")
        lines.append(" ],")
    lines += ["}", "const RIDGES={"]
    for region, rows in ridges.items():
        lines += [f' "{region}":[', *rows, " ],"]
    lines += ["}",
              f"const KILI_TRAILHEAD={gd_point(KILI_TRAILHEAD[0]*3,KILI_TRAILHEAD[1]*3)}",
              f"const GHANA_SOUTH_GATE={gd_point(GHANA_SOUTH_GATE[0]*3,GHANA_SOUTH_GATE[1]*3)}",
              f"const GHANA_NORTH_GATE={gd_point(GHANA_NORTH_GATE[0]*3,GHANA_NORTH_GATE[1]*3)}", ""]
    (output / "freyja_outlying_data.gd").write_text("\n".join(lines))
    return paths
