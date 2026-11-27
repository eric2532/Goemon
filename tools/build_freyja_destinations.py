"""Recover Freyja's fixed entrances, branch paths, villages and first cave floors."""
from functools import lru_cache
from pathlib import Path
import struct

from PIL import Image, ImageDraw, ImageOps
import build_freyja_tomato_farm as tomato

from build_freyja_outlying import (
    REGIONS, GHANA_GRAVES, GHANA_NORTH_GATE, GHANA_SOUTH_GATE, GREAT_WIND_EAST, GREAT_WIND_MOUTH, KILI_EAST_EXIT, KILI_TRAILHEAD, SOKIA_LANDING,
    archive_walk, is_road, is_water, kili_road, route, route_between_warps,
)

# Original map ID, community name, owning outdoor area, first path junction in 100.dat.
SITES = {
    2000: ("Il Village", "east_coast", (686, 328)),
    2300: ("Saint Laruka", "west_lakes", (160, 207)),
    2400: ("Alyut Village", "north_coast", (621, 70)),
    2100: ("Venoa Village", "south_lakes", (338, 461)),
    11000: ("Venoa Cave, Falan Side", "south_gate", (438, 344)),
    11002: ("Venoa Cave, Village Side", "south_lakes", (441, 351)),
    11005: ("Habaru Cave, Alyut Side", "north_coast", (688, 175)),
    1155: ("Woodcutter's House", "east_gate", (481, 198)),
    11013: ("No. 24 Mine", "freyja", (347, 154)),
    11020: ("Komuramasa Cave", "east_gate", (509, 153)),
    11021: ("Kobizen Cave", "south_gate", (447, 301)),
    11003: ("Habaru Cave, Il Side", "east_coast", (677, 233)),
    11023: ("Sheol Cave", "north_coast", (686, 193)),
    11024: ("Mystery Cave", "freyja", (347, 154)),
    15005: ("Sokia Undersea Cave", "south_lakes", (330, 480)),
    5007: ("Forest Cottage", "south_lakes", (354, 367)),
    21051: ("Woodland Cavern", "south_lakes", (412, 407)),
    11029: ("Southern Cavern", "south_lakes", (346, 440)),
    15542: ("Water Cave", "south_lakes", (322, 506)),
    15595: ("Fire Cave", "south_lakes", (251, 478)),
    15592: ("Venoa Undersea Cave, Village Side", "south_lakes", (331, 481)),
    15594: ("Venoa Undersea Cave, Fire Cave Side", "south_lakes", (251, 478)),
    410: ("Zombie Cave", "north_coast", (545, 43)),
    16501: ("Alyut West Cave", "north_coast", (587, 50)),
    11033: ("Earth Cave", "east_coast", (578, 241)),
    3200: ("Kili Village", "sokia_coast", SOKIA_LANDING),
    3350: ("Fengnu's House", "sokia_coast", KILI_TRAILHEAD),
    3000: ("Ghana Village", "ghana_road", GHANA_SOUTH_GATE),
    13001: ("Great Wind Cave", "sokia_coast", KILI_EAST_EXIT),
}
VILLAGES = {2000: "il_village", 2300: "laruka", 2400: "alyut", 2100: "venoa", 3200: "kili", 3000: "ghana"}
COTTAGES = {1155, 5007, 3350}
VILLAGE_HOUSES = {11044, 11106, 11268, 11269, 11271, 11272, 11273, 11276, 11279,
                  11280, 11281, 11283, 11284, 11285, 11286}


def vec(x, z):
    return f"Vector2({x},{z})"


HABARU = {11003, 11004, 11005, 11028}
VENOA_CAVE = {11000, 11001, 11002, 11022}
VENOA_BEARS = {
    11000: [(23,23), (26,25), (22,30), (24,35), (22,40), (26,45), (26,52), (24,56)],
    11001: [(35,22), (30,22), (23,23), (17,22), (13,30), (14,38), (22,43), (27,48),
            (30,55), (29,66), (23,70)],
    11002: [(35,19), (33,25), (27,26), (25,32), (27,37), (24,44), (20,51), (23,56)],
}
VENOA_UNDERSEA = {15592, 15593, 15594}
SOKIA_UNDERSEA = {15003, 15004, 15005}
VENOA_BOSS = (11001, 23, 46)
VENOA_BEAR_COUNTS = {11000: 32, 11001: 40, 11002: 32}


def venoa_bears(ident, width, height, walk, stairs):
    """Append spaced bears in the main passage, preserving the old slain-slot IDs."""
    bears = VENOA_BEARS[ident].copy()
    reached = {bears[0]}
    queue = list(reached)
    for x, z in queue:
        for p in ((x-1,z), (x+1,z), (x,z-1), (x,z+1)):
            a, b = p
            if 0 <= a < width and 0 <= b < height and walk[b*width+a] and p not in reached:
                reached.add(p)
                queue.append(p)
    candidates = [(x,z) for z in range(1,height-1) for x in range(1,width-1)
                  if (x,z) in reached
                  and all(walk[(z+b)*width+x+a] for b in (-1,0,1) for a in (-1,0,1))
                  and all((x-a)**2+(z-b)**2 >= 9 for a,b in stairs)
                  and (ident != VENOA_BOSS[0] or (x-VENOA_BOSS[1])**2+(z-VENOA_BOSS[2])**2 >= 16)]
    while len(bears) < VENOA_BEAR_COUNTS[ident]:
        point = max(candidates, key=lambda p: min((p[0]-x)**2+(p[1]-z)**2 for x,z in bears))
        assert min((point[0]-x)**2+(point[1]-z)**2 for x,z in bears) >= 6.25, ident
        bears.append(point)
        candidates.remove(point)
    assert len(bears) < 99 and all(p in reached for p in bears), ident
    return bears


ZOMBIE_MOUTH = (541, 39)
ZOMBIE_EXIT = (21, 27)
ZOMBIE_FORMATIONS = {
    410: [(36,34,1), (44,22,2), (15,35,1), (24,32,2), (27,18,1), (20,12,2),
          (42,29,3), (17,37,3), (23,21,3)],
    15505: [(21,18,0), (16,15,1), (24,17,2), (24,22,2)],
}
ALYUT_ROOMS = {2400, 2401, 2410, 2412, 2420, 2421, 2499}
ALYUT_BUILDINGS = {
    (47,34): ("falan_townhouse", .9), # Residence, original footprint 11275.
    (37,39): ("falan_shop", .88),
    (35,57): ("falan_townhouse", .85),
    (55,67): ("falan_townhouse", .95),
    (59,49): ("falan_townhouse", 1.0),
}
VENOA_ROOMS = {2100, 2101, 2110, 2111, 2112, 2113, 2120, 2121, 2198, 2199}
KILI_HOMES = {
    3801: ((56,86), 3801, (12,16)),
    3802: ((69,89), 3802, (3,9)),
    3803: ((38,59), 3803, (10,16)),
    3807: ((37,70), 3807, (2,11)),
}
KILI_ROOMS = {3200, 3201, 3202, 3208, 3210, 3212, 3213, 3214, 3220, 3221, 3299} | KILI_HOMES.keys()
GHANA_HOMES = {
    3804: ((76,79), 3804, (3,10)),
    3805: ((85,69), 3805, (12,16)),
    3806: ((38,63), 3806, (10,14)),
}
HOUSING = KILI_HOMES | GHANA_HOMES
GHANA_ROOMS = {3000, 3001, 3002, 3008, 3010, 3012, 3013, 3014, 3020, 3021, 3099} | GHANA_HOMES.keys()
GHANA_GATES = {
    (704,147): ("ghana_road", "South Gate", GHANA_SOUTH_GATE, -1),
    (704,96): ("ghana_north_road", "North Gate", GHANA_NORTH_GATE, 1),
}
# Match the six building graphics, with facades on the original door side.
GHANA_BUILDINGS = [
    ("kili_tavern", 53, 34, 1.02, -90),      # 11292: Pub
    ("kili_chief", 39, 40, 1.24, -90),       # 11294: Chief
    ("kili_house", 34, 50.7, 1.12, 0),       # 11290: House of Inheritance
    ("kili_house", 62, 50, 1.05, -90),       # 11289: Archaeologist
    ("kili_shop", 65.3, 61.5, 1.02, -90),    # 11295: Equipment shop
    ("ghana_hospital", 54.3, 72, 1.08, -90), # 11293: Hospital
    ("ghana_well", 53, 55, 1.0, 0),
]
KILI_BUILDINGS = [
    ("kili_house", 48.5, 51.6, .92, 0),      # Wachi's home.
    ("kili_house", 66.4, 56.7, 1.12, -90),  # Hospital.
    ("kili_chief", 53.4, 63, 1.0, -90),
    ("kili_house", 73.5, 63, 1.0, -90),     # Minelpa's home.
    ("kili_tavern", 48.5, 79, .94, -90),
    ("kili_shop", 68.1, 77.5, 1.0, -90),
    ("kili_house", 56, 83.6, .88, 0),
    ("kili_house", 71.5, 89, .84, -90),
    ("kili_house", 38, 56.7, .84, 0),
    ("kili_house", 37, 72.5, .86, 180),
]
KILI_PALMS = {11190,11191,11192,11194,11196,11198,11200,11202,11203,11204,11206,11207,11208}
KILI_WALLS = set(range(11230,11251)) - {11235,11236,11242}
# Match the original building footprints and face their recorded door tiles.
IL_BUILDINGS = [
    ("falan_townhouse", 37.5, 24, .88, -90),  # Equipment shop
    ("falan_shop", 52, 36.5, .91, 0),        # Hospital
    ("falan_shop", 35, 39.5, .91, 0),        # General store
    ("falan_townhouse", 34.5, 64, .88, -90), # San Francisco Bar
    ("falan_townhouse", 42, 58.5, 1, 0),     # Residence
    ("falan_townhouse", 44.5, 71, .88, -90), # Church
    ("falan_shop", 73, 72, 1, 0),
    ("falan_townhouse", 50.5, 83, 1.08, -90), # Chief's house
]
VENOA_BUILDINGS = [
    ("falan_townhouse", 40, 33, .98, 0),       # Chief's house (11279).
    ("falan_shop", 56, 39, 1.02, 0),           # Two storefronts of the equipment shop (11284).
    ("falan_shop", 62, 39, 1.02, 0),
    ("falan_townhouse", 64, 53.5, .94, -90),   # Hospital (11286).
    ("falan_shop", 52, 58.5, .88, -90),        # Curry shop (11283).
    ("falan_townhouse", 40, 52, .85, -90),     # Residence (11276).
]
TITLES = {1155: "Woodcutter's House", 2001: "Equipment Shop", 2002: "San Francisco Bar", 2010: "Hospital",
          2012: "Village Chief's House", 2013: "General Store", 2014: "Church", 2099: "Teleport Room",
          2101: "Equipment Shop", 2110: "Hospital", 2111: "Hospital Annex",
          2112: "Village Chief's House", 2113: "Chief's Side Room", 2120: "Curry Shop",
          2121: "Village Residence", 2198: "Chief's Passage", 2199: "Teleport Room",
          2301: "Equipment Shop", 2302: "Equipment Shop, Landing", 2303: "Underground Workshop",
          2306: "Food Shop · 食品店", 2307: "Materials Shop · 原料店", 2308: "Village Tavern",
          2310: "Hospital", 2311: "Hospital, Inner Room", 2312: "Village Chief's House",
          2313: "Chief's House, Inner Room", 2320: "Village House", 2399: "Teleport Room",
          2401: "General Store", 2410: "Hospital", 2412: "Village Chief's House",
          2420: "Village Residence", 2421: "Nancy's House", 2499: "Teleport Room",
          3001: "Equipment Shop", 3002: "General Store", 3008: "Ghana Pub",
          3010: "Ghana Hospital", 3012: "Village Chief's House", 3013: "Chief's Side Room",
          3014: "Chief's Inner Room", 3020: "Archaeologist's House", 3021: "House of Inheritance",
          3099: "Ghana Teleport Room", 3804: "Southeast Residence", 3805: "East Residence",
          3806: "West Residence",
          3201: "Equipment Shop", 3202: "Lower General Store", 3208: "Kili Tavern",
          3210: "Kili Hospital", 3212: "Chief's House", 3213: "Lina's Room",
          3214: "Chief's Inner Room", 3220: "Minelpa's Family Home", 3221: "Wachi's Home",
          3299: "Kili Teleport Room", 3801: "South Residence", 3802: "Southeast Residence",
          3803: "West Residence", 3807: "Southwest Residence",
          11000: "Venoa Cave, Falan Side", 11001: "Venoa Cave, Lower Floor",
          11002: "Venoa Cave, Village Side", 11022: "Venoa Cave, Miners' Shortcut",
          15592: "Venoa Undersea Cave, Village Side", 15593: "Venoa Undersea Cave, B2",
          15594: "Venoa Undersea Cave, Fire Cave Side",
          15005: "Sokia Undersea Cave, Freyja Side", 15003: "Sokia Undersea Cave, B2",
          15004: "Sokia Undersea Cave, Kili Side",
          13001: "Great Wind Cave",
          410: "Zombie Cave, B1", 15505: "Zombie Cave, B2 · Arubas's Laboratory",
          16501: "Alyut West Cave", 16502: "Alyut West Cave, Low Tide",
          16500: "Pirate Shrine", 16505: "Pirate Cave Entrance",
          16516: "Pirate Cave, B1", 16517: "Pirate Cave, B2",
          16518: "Pirate Cave, B3", 16519: "Pirate Cave, B4",
          16503: "Wolf Captain's Hall", 16504: "Wolf Captain's Memorial",
          11003: "Habaru Cave, Il Side", 11004: "Habaru Cave, B2", 11005: "Habaru Cave, Alyut Side",
          11028: "Ozunack's Hidden Room"}
ALYUT_PIRATE_ROOMS = {16500, 16502, 16503, 16504, 16505, 16516, 16517, 16518, 16519}
CAPTAIN_FORMATION = [(22,21,0), (21,20,1), (23,20,1), (20,25,2), (24,26,2)]
GRAVE_ENTRY, GRAVE_BOSS = 47010, 47017
GRAVE_ROUTE = [
    (47010, (14,12), (17,12)), (47040, (5,19), (24,7)),
    (47011, (23,24), (19,18)), (47041, (5,19), (24,7)),
    (47013, (15,12), (48,10)), (47042, (5,19), (24,7)),
    (47014, (10,35), (36,15)), (47043, (5,19), (24,7)),
    (47017, (22,23), (31,14)),
]
GRAVE_TREES = {47010, 47011, 47013, 47014, 47017, *range(47040,47044)}
GRAVE_FORMATION = [(27,13), (28,12), (26,12), (23,17), (31,17)]
RUBY_FORMATION = [(24,11,0), (20,21,1), (22,23,1), (24,23,1), (26,23,1), (28,21,1),
                  (19,24,2), (21,25,2), (27,26,2), (29,24,2)]
TITLES.update({47010:"Imur Forest I", 47011:"Imur Forest II", 47013:"Imur Forest III",
               47014:"Imur Forest IV", 47017:"Forest Graveyard",
               **{i:f"Forest Maze {i-47039}" for i in range(47040,47044)}})
TITLES.update({3350:"Fengnu's House", 3351:"Attack Absorption Room", 3352:"Fengnu's Study",
               3353:"Magic Absorption Room", 16508:"Black Prayer · Ruby's Palace"})
TITLES.update({ident:title for ident, (_,title,_) in tomato.LAND.items()})
TITLES[tomato.STOREHOUSE] = "Tomato Storehouse · 蕃茄保管庫"


def grave_reconstruction(ident):
    # shortcut: The final forest and cemetery tiles are absent from this cache.
    # Use the reference silhouettes. Maze templates supply door anchors and trail materials.
    if ident == 47014:
        size = (50,50)
        path = [(10,35),(14,35),(14,30),(24,30),(24,22),(31,22),(31,16),(36,16),(36,15)]
    elif ident == GRAVE_BOSS:
        size = (52,36)
        # Trace the public cemetery plan around the recorded (27,13) boss and (22,23) entry.
        path = [(27,13),(27,16),(24,19),(24,21),(22,23),(24,26),(27,29)]
    else:
        size = (30,26)
        bend = 8 + (ident-47040)*3
        path = [(5,19),(bend,19),(bend,12),(25-bend//3,12),(25-bend//3,7),(24,7)]
    mask = Image.new("L",size)
    draw = ImageDraw.Draw(mask)
    draw.line(path,fill=1,width=5)
    for x,z in path:
        draw.rectangle((x-2,z-2,x+2,z+2),fill=1)
    if ident == GRAVE_BOSS:
        draw.polygon([(24,9),(29,7),(34,8),(35,12),(33,17),(31,20),
                      (27,21),(23,23),(19,24),(19,21),(21,18),(22,14)],fill=1)
    track = Image.new("L",size)
    ImageDraw.Draw(track).line(path,fill=1,width=2)
    ground, objects = [], []
    for clear, dirt in zip(mask.getdata(),track.getdata()):
        ground.append(6415 if dirt else 5048)
        objects.append(0 if clear else 2)
    return *size,ground,objects,None


def warp_rows(magic):
    for line in (magic / "research/outdoor-recovery-20261031/warp.txt").read_bytes().splitlines():
        try:
            _, source, x, z, dest, tx, tz = map(int, line.split()[:7])
        except ValueError:
            continue
        yield source, x, z, dest, tx, tz


def interior_links(magic):
    groups = (range(2000, 2100), VENOA_ROOMS, range(2300, 2400), ALYUT_ROOMS, KILI_ROOMS, GHANA_ROOMS, HABARU,
              VENOA_CAVE, VENOA_UNDERSEA, SOKIA_UNDERSEA, ALYUT_PIRATE_ROOMS)
    links = list(dict.fromkeys(row for row in warp_rows(magic)
                               if any(row[0] in group and row[3] in group for group in groups)))
    links = [row for row in links if row[0] not in HOUSING]
    # The bed interaction is on (9,9). Its adjacent foot tile is the walk-in threshold.
    links += [(11004,9,10,11028,8,4)]
    # The archive records these entrances as NPC warps. Use the daytime destinations.
    links += [(3200,64,56,3210,3,9), (3200,50,63,3212,1,8), (3212,10,2,3213,7,13)]
    housing_returns = {source:(tx,tz) for source,_,_,dest,tx,tz in warp_rows(magic)
                       if source in HOUSING and dest in (3000,3200)}
    for village, homes in ((3200, KILI_HOMES), (3000, GHANA_HOMES)):
        for ident, ((x,z), _, (tx,tz)) in homes.items():
            rx,rz = housing_returns[ident]
            links += [(village,x,z,ident,tx,tz), (ident,tx,tz,village,rx,rz)]
    # Two B2/B3 stair pairs land on solid tiles in the cached client maps.
    links = [row for row in links if not ({row[0], row[3]} == {16517, 16518}
                                         and row[1:3] in ((31, 34), (20, 88)))]
    # Use the walkable tile in front of the original altar and the captain's event tile.
    links += [(16500,15,8,16505,12,16), (16505,12,16,16500,15,8),
              (16503,22,21,16504,22,24), (16504,22,24,16503,22,21)]
    # The original miner at (14,16) opens the fenced stair pocket. Use a silent door beside him.
    links += [(11000,15,16,11000,10,11), (11000,10,11,11000,15,16)]
    # Preserve the original guard's warp and use a silent return at the far side.
    links += [(15004,7,39,15004,8,42), (15004,8,42,15004,7,39)]
    # The archived return drops a digit and lands in solid rock. Its paired stair is at (25,36).
    links[links.index((15593,7,3,15594,25,6))] = (15593,7,3,15594,25,36)
    links += [(410,21,16,15505,40,6), (15505,40,6,410,21,16)]
    for (source,_,door),(dest,arrival,_) in zip(GRAVE_ROUTE,GRAVE_ROUTE[1:]):
        links += [(source,*door,dest,*arrival), (dest,*arrival,source,*door)]
    links += [(15003,34,7,16508,24,34), (16508,24,34,15003,34,7),
              (16508,26,10,3350,11,14),
              (16508,22,16,3351,9,8), (16508,25,16,3353,9,8),
              (3351,14,9,3350,11,14), (3353,2,8,3350,11,14),
              (3350,14,2,3352,9,16), (3352,9,16,3350,14,2)]
    return links + tomato.LINKS


def read_housing_map(raw, ident):
    if len(raw)<44 or raw[:6]!=b'LS2MAP' or struct.unpack_from('>H',raw,6)[0]!=ident:
        raise ValueError('Invalid original housing map identity')
    w,h=struct.unpack_from('>HH',raw,40)
    if not 0<w<=128 or not 0<h<=128 or len(raw)!=44+w*h*4:
        raise ValueError('Invalid original housing map dimensions or planes')
    cells=w*h
    values=struct.unpack_from(f'>{cells*2}H',raw,44)
    return w,h,list(values[:cells]),list(values[cells:]),None


def load_map(library, ident):
    if ident in (100,300):
        from prepare_sokia_outdoor_source import active_map
        completed=active_map(library,ident)
        if completed is not None:return completed
    if ident == 2307:
        source=Path(__file__).resolve().parents[1]/'assets/references/crossgate_laruka_basement/02307_sozai'
        return read_housing_map(source.read_bytes(),ident)
    if ident == tomato.STOREHOUSE:
        return tomato.storehouse()
    if ident in GRAVE_TREES - {47010,47011,47013}:
        return grave_reconstruction(ident)
    if ident in HOUSING:
        village = 'kili' if ident in KILI_HOMES else 'ghana'
        source=Path(__file__).resolve().parents[1]/f'assets/references/crossgate_{village}_houses'/f'{ident:05d}_room'
        return read_housing_map(source.read_bytes(),ident)
    path = "1/4/410" if ident == 410 else f"0/{ident}"
    with library.connection() as db:
        row = db.execute("SELECT id FROM files WHERE path=?", (f"BlueCrossgate/map/{path}.dat",)).fetchone()
    if row is not None:
        return library.parse_map(library.source_file(row[0])[1].read_bytes())
    raise ValueError(f"Missing archived map {ident}")


def entrances(magic):
    groups = {}
    for source, x, z, dest, tx, tz in warp_rows(magic):
        if source != (300 if dest in (3000, 3200, 3350, 13001) else 100):
            continue
        if dest not in SITES:
            continue
        if dest == 3200 and (x,z) not in (KILI_TRAILHEAD, (294,325)):
            continue
        if dest == 3000 and (x,z) not in GHANA_GATES:
            continue
        if dest == 13001 and (x,z) != GREAT_WIND_MOUTH:
            continue
        group = groups.setdefault(dest, [])
        if all(abs(x - a) + abs(z - b) > 3 for a, b, _, _ in group):
            group.append((x, z, tx, tz))
    # Event entrances use the matching return for the cave landing. Alyut West
    # uses the daytime layout. The Undersea soldier event corrects a missing digit.
    for source,x,z,dest,tx,tz in warp_rows(magic):
        if source in (11000, 15592, 16501) and dest == 100:
            groups[source] = [(tx,538 if source == 15592 else tz,x,z)]
    groups[410] = [(*ZOMBIE_MOUTH,43,41)]
    assert set(groups) == set(SITES)
    return groups


def build_entrance_scenery(output, rows, maps, library, lookup, paths):
    """Keep original cliff footprints and landmark props around each outdoor warp."""
    from collections import defaultdict

    scenery = defaultdict(dict)
    mouths = defaultdict(dict)
    for area, ident, kind, x, z, approach in rows:
        if kind not in {"cave", "diamond", "stairs"}:
            continue
        world = 300 if area.startswith(("sokia_", "ghana_")) else 100
        w, h, _, objects = maps[world]
        cliff_cells = set()
        for b in range(max(0, z-6), min(h, z+7)):
            for a in range(max(0, x-6), min(w, x+7)):
                serial = objects[b*w+a]
                cliff = 12536 <= serial <= 12565
                detail = (12500 <= serial <= 12535 or 11363 <= serial <= 11372
                          or 11625 <= serial <= 11710 or 12160 <= serial <= 12180
                          or 11188 <= serial <= 11208 or serial in {10062, *range(10085,10095)})
                if not cliff and not detail:
                    continue
                entry = lookup[serial]
                east, south = max(1, entry["east"]), max(1, entry["south"])
                corner = b-south+1
                footprint = [(u,v) for v in range(corner,b+1) for u in range(a,a+east)]
                scenery[area][a,b] = (serial, east, south, entry["h"], footprint)
                if cliff:
                    cliff_cells.update(footprint)
        if kind != "cave" or ident == 11000:
            continue
        # Prefer the rock directly past the approach when more than one face borders the warp.
        directions = [(dx,dz) for dx,dz in ((0,-1),(1,0),(0,1),(-1,0)) if (x+dx,z+dz) in cliff_cells]
        dx,dz = max(directions or [approach], key=lambda d:d[0]*approach[0]+d[1]*approach[1])
        mouths[area][x,z] = (dx,dz)
    lines = ["extends RefCounted", "## Blue CG 100.dat and 300.dat entrance scenery in archive coordinates.",
             "const SCENERY={"]
    for area, placed in sorted(scenery.items()):
        roads = {point for path in paths.get(area, ()) for point in path}
        roads.update((x,z) for key, _, _, x, z, _ in rows if key==area)
        lines.append(f' "{area}":[')
        for (x,z), (serial, east, south, height, footprint) in sorted(placed.items()):
            solid = serial >= 12536 and serial <= 12565 and roads.isdisjoint(footprint)
            lines.append(f"  [Vector2i({x},{z}),{serial},Vector2i({east},{south}),{height},{str(solid).lower()}],")
        lines.append(" ],")
    lines.extend(["}", "const MOUTHS={"])
    for area, placed in sorted(mouths.items()):
        lines.append(f' "{area}":{{')
        lines.extend(f"  Vector2i({x},{z}):Vector2({dx},{dz})," for (x,z),(dx,dz) in sorted(placed.items()))
        lines.append(" },")
    (output / "freyja_entrance_data.gd").write_text("\n".join(lines+["}", ""]))
    for name, serial, bounds in [
        ("freyja", 12543, (54, 153, 150, 249)),
        ("sokia", 12557, (66, 141, 142, 217)),
    ]:
        entry = lookup[serial]
        patch = library.image_from_record(entry["pack"], entry["row"]).crop(bounds)
        assert patch.getchannel("A").getextrema() == (255, 255), serial
        w, h = patch.size
        face = Image.new("RGB", (w*2, h*2))
        face.paste(patch, (0,0))
        face.paste(ImageOps.mirror(patch), (w,0))
        face.paste(ImageOps.flip(patch), (0,h))
        face.paste(ImageOps.flip(ImageOps.mirror(patch)), (w,h))
        face.save(output / f"{name}_cliff_face.png", optimize=True)


def build(magic_power, output, library, width, height, tiles, sokia):
    from prepare_field_assets import navigation_grid

    def ground(x, z):
        return tiles[z * width + x] if 0 <= x < width and 0 <= z < height else 0

    def sokia_ground(x, z):
        w, h, floor, _ = sokia
        return floor[z*w+x] if 0 <= x < w and 0 <= z < h else 0

    @lru_cache(None)
    def original(map_id):
        return load_map(library, map_id)

    field_objects = original(100)[3]
    lookup = library.serial_index()
    alyut_coast = archive_walk((515, 7, 635, 90), width, tiles, field_objects, lookup)
    venoa_coast = archive_walk((215, 325, 475, 565), width, tiles, field_objects, lookup)

    def shore_path(start, end, walkable):
        path = route([start, end], walkable, clearance=False)
        assert path[0] == start and path[-1] == end, (start, end)
        assert all(walkable(*point) and not is_water(walkable(*point)) for point in path)
        return path

    def local(map_id, x, z):
        if map_id in tomato.LAND:
            return vec(*tomato.local(map_id,x,z))
        w, h, *_ = original(map_id)
        return vec((x-w//2)*3, (z-h//2)*3)

    groups = entrances(magic_power)
    links = interior_links(magic_power)
    doors, seeds = {}, {}
    for source,x,z,dest,tx,tz in links:
        doors.setdefault(source, []).append(f'[{local(source,x,z)},{dest},{local(dest,tx,tz)}]')
        seeds.setdefault(source, set()).add((x,z))
        seeds.setdefault(dest, set()).add((tx,tz))
    # Keep Ozunack on the original interaction tile with the bears on the nearby shelf.
    formation = [(17,17),(13,19),(20,19),(15,21),(19,21),(16,23),(20,23),(23,23),(18,25),(22,25)]
    alyut_exits = []
    alyut_warps = [(x,z,tx,tz) for source,x,z,dest,tx,tz in warp_rows(magic_power)
                   if source == 2400 and dest == 100]
    for x,z,_,_ in groups[2400]:
        door = min(alyut_warps, key=lambda row: abs(row[2]-x)+abs(row[3]-z))
        outside = door[2:]
        alyut_exits.append(f"[{local(2400,*door[:2])},{vec(outside[0]*3,outside[1]*3)}]")
    kili_exits = []
    for x,z,_,_ in groups[3200]:
        door = min(((a,b,tx,tz) for source,a,b,dest,tx,tz in warp_rows(magic_power)
                    if source == 3200 and dest == 300), key=lambda row: abs(row[2]-x)+abs(row[3]-z))
        kili_exits.append(f"[{local(3200,*door[:2])},{vec(door[2]*3,door[3]*3)}]")
    connected_caves = VENOA_UNDERSEA | (SOKIA_UNDERSEA - {15004}) | ZOMBIE_FORMATIONS.keys() | (ALYUT_PIRATE_ROOMS - {16518}) | {13001}
    ghana_returns = {(tx,tz):(x,z) for source,x,z,dest,tx,tz in warp_rows(magic_power)
                     if source == 3000 and dest == 300}
    ghana_exits = [f'[{local(3000,*ghana_returns[landing])},"{area}",{vec(landing[0]*3,landing[1]*3)},"{label}"]'
                   for area,label,landing,_ in GHANA_GATES.values()]
    connected_rooms = connected_caves | GRAVE_TREES | (KILI_ROOMS | GHANA_ROOMS) - VILLAGES.keys()
    solid_roofs = VENOA_CAVE | connected_caves | {15004, 16501, 16518, 16508}
    exits = {source:(x,z) for source,x,z,dest,_,_ in warp_rows(magic_power) if source in HABARU | solid_roofs and dest==100}
    exits[410] = groups[410][0][2:]
    exits[15505] = ZOMBIE_EXIT
    exits.update({16504: (22, 14), 16505: (21, 24)})
    exits[15004] = (11, 44)
    exits[13001] = groups[13001][0][2:]
    exits[3350] = groups[3350][0][2:]
    east_door, = [(x,z) for source,x,z,dest,tx,tz in warp_rows(magic_power)
                  if source == 13001 and dest == 300 and (tx,tz) == GREAT_WIND_EAST]
    seeds.setdefault(13001, set()).add(east_door)
    exit_rows = {15004: ("sokia_coast", *SOKIA_LANDING, "cave")}
    exits.update({GRAVE_ENTRY: GRAVE_ROUTE[0][1], GRAVE_BOSS: GRAVE_ROUTE[-1][2]})
    for ident in (GRAVE_ENTRY, GRAVE_BOSS):
        exit_rows[ident] = ("ghana_north_road", *GHANA_GRAVES, "stairs")
    for ident, group in groups.items():
        seeds.setdefault(ident, set()).update((tx,tz) for _,_,tx,tz in group)
    for ident, cell in exits.items():
        seeds.setdefault(ident, set()).add(cell)
    rows = ["extends RefCounted", "## Generated by build_falan_approaches.py from the cached maps and fixed warp reference.",
            "const SITES=["]
    rooms, villages, props, il_shore = [], [], [], []
    paths = {}
    entrance_rows = []
    for dest, (title, area, junction) in SITES.items():
        map_width, map_height, floor, objects, _ = original(dest)
        origin = (map_width // 2, map_height // 2)
        kind = "village" if dest in VILLAGES else "house" if dest in COTTAGES else "diamond" if dest == 410 else "cave"
        entries = groups[dest]
        if dest == 3000:
            # Default village spawn remains at the south gate.
            entries = sorted(entries, key=lambda row: -row[1])
        for x, z, tx, tz in entries:
            if dest == 3000:
                gate_area, label, landing, sign = GHANA_GATES[x,z]
                gx, gz = (x,z) if sign == 1 else landing
                rows.append(f' ["{gate_area}","{title} · {label}",{dest},"village",{vec(gx*3,gz*3)},'
                            f'{vec(0,sign)},{local(dest,tx,tz)},{vec(gx*3,(gz-sign*6)*3)}],')
                continue
            fork = (587, 47) if dest == 2400 and z < 60 else junction
            if dest == 3200 and z > KILI_TRAILHEAD[1]:
                fork = KILI_TRAILHEAD
            if dest == 3200 and (x,z) == KILI_TRAILHEAD:
                branch = kili_road(sokia[0],sokia[2],sokia[3],lookup)
            elif dest in {410,16501} or (dest == 2400 and z < 60):
                branch = shore_path(fork, (x, z), alyut_coast)
            elif dest == 15592:
                # Stay one tile inland where the original shore drops into water.
                branch = route_between_warps([fork, (x, z)], venoa_coast)
            elif dest in {11002,15594,15595}:
                branch = shore_path(fork, (x, z), venoa_coast)
            else:
                branch = route([fork, (x, z)], sokia_ground if area == "sokia_coast" else ground)
            if dest == 13001:
                sokia_width, _, _, sokia_objects = sokia
                assert branch[0] == KILI_EAST_EXIT and branch[-1] == GREAT_WIND_MOUTH
                assert all(sokia_ground(a,b) and not is_water(sokia_ground(a,b))
                           and sokia_objects[b*sokia_width+a] != 2 for a,b in branch)
            paths.setdefault(area, []).append(branch)
            px, pz = branch[-1]
            ax, az = branch[max(0, len(branch)-5)]
            sx, sz = branch[min(5, len(branch)//2)]
            assert (ax, az) != (px, pz)
            dx, dz = tx-origin[0], tz-origin[1]
            rows.append(f' ["{area}","{title}",{dest},"{kind}",{vec(px*3,pz*3)},'
                        f'{vec(px-ax,pz-az)},{vec(dx*3,dz*3)},{vec(sx*3,sz*3)}],')
            entrance_rows.append((area, dest, kind, px, pz, (px-ax,pz-az)))
            if dest in exits:
                exit_rows.setdefault(dest, (area, px, pz, kind))
        if dest in VILLAGES:
            name = VILLAGES[dest]
            image = Image.new("RGBA", (map_width, map_height))
            pixels = image.load()
            placed = []
            if dest == 2000:
                placed = IL_BUILDINGS.copy()
            elif dest == 2400:
                placed = [(asset,x,z,scale,0) for (x,z),(asset,scale) in ALYUT_BUILDINGS.items()]
            elif dest == 2100:
                placed = VENOA_BUILDINGS.copy()
            elif dest == 3200:
                placed = KILI_BUILDINGS.copy()
            elif dest == 3000:
                placed = GHANA_BUILDINGS.copy()
                walk = navigation_grid(map_width, map_height, floor, objects, lookup)
                gates = {ghana_returns[landing] for _,_,landing,_ in GHANA_GATES.values()}
                assert all(walk[z*map_width+x] for x,z in seeds[dest] | gates), seeds[dest]
            buildings = placed.copy()
            tree_slots = set()
            for z in range(map_height):
                for x in range(map_width):
                    i = z * map_width + x
                    tile = floor[i]
                    wet = is_water(tile)
                    paving = 220 if 1000 <= tile <= 1099 or 5954 <= tile <= 5988 else 0
                    pixels[x, z] = (255 if wet else 0, 220 if is_road(tile) else 0, paving, 255 if tile else 0)
                    if dest == 2000 and not tile:
                        pixels[x,z] = (255,0,0,255)
                    if dest == 3200:
                        wet = wet or not tile
                        pixels[x,z] = (255 if wet else 0, 228 if 3980 <= tile <= 3990 else 0,
                                       210 if 6777 <= tile <= 6798 else 0, 255)
                    obj = objects[i]
                    if dest == 2000 and 12500 <= obj <= 12535:
                        il_shore.append(f"[{local(dest,x,z)},{obj}]")
                    if dest == 2000 and 11363 <= obj <= 11372:
                        placed.append(("fence",x,z,.50,90 if obj in (11363,11368,11370) else 0))
                        continue
                    if dest == 3000:
                        wet = wet or not tile
                        cliff = tile == 100 and not walk[i]
                        sand = 6777 <= tile <= 6794 or 6976 <= tile <= 7010
                        pixels[x,z] = (255 if wet else 0, 228 if 6777 <= tile <= 6785 else 0,
                                       255 if cliff else 205 if sand else 0, 255)
                        if 11234 <= obj <= 11246 and not wet:
                            placed.append(("wall_piece",x,z,.50,0))
                        elif obj in (11363,11364) and not wet:
                            placed.append(("fence",x,z,.50,90 if obj == 11363 else 0))
                        elif 11150 <= obj <= 11159 and not wet:
                            placed.append(("tree",x,z,.72,0))
                        elif 12307 <= obj <= 12319 and not wet and walk[i] and (x+z)%3==0:
                            placed.append(("shrub",x,z,.75,0))
                        continue
                    if dest == 3200 and obj in KILI_WALLS and not wet:
                        yaw = 90 if x > 0 and objects[i-1] not in KILI_WALLS and i+1 < len(objects) and objects[i+1] not in KILI_WALLS else 0
                        placed.append(("wall_piece",x,z,.50,yaw))
                        continue
                    asset = ("falan_townhouse" if obj in VILLAGE_HOUSES else
                             "falan_shop" if obj in {10603, 10607, 11275} else
                             "tree" if 10058 <= obj <= 10074 or 10085 <= obj <= 10094 else "")
                    if dest == 2100 and 12523 <= obj <= 12531 and not (paving or is_road(tile)):
                        asset = "moss_rock"
                    if dest == 3200 and obj in KILI_PALMS and not (3980 <= tile <= 3990):
                        asset = "kili_palm"
                    if not asset or wet or not tile or (asset == "tree" and (paving or is_road(tile))):
                        continue
                    if asset not in ("tree","moss_rock","kili_palm") and any(abs(x-a)<5 and abs(z-b)<5 for _,a,b,_,_ in buildings):
                        continue
                    if any(abs(x-a) < 4 and abs(z-b) < 4 for _, a, b, _, _ in placed):
                        continue
                    if asset == "tree":
                        key = (x//4,z//4)
                        if key in tree_slots:
                            continue
                        tree_slots.add(key)
                    placed.append((asset,x,z,.8,0))
            image.save(output / f"freyja_{name}.png", optimize=True)
            x, z = entries[0][2:]
            villages.append(f' "{name}":[{dest},"{title}",{vec(-origin[0]*3,-origin[1]*3)},'
                            f'preload("res://assets/maps/falan/freyja_{name}.png"),{vec((x-origin[0])*3,(z-origin[1])*3)}],')
            props.append(f' "{name}":[' + ",".join(
                f'["{asset}",{vec((x-origin[0])*3,(z-origin[1])*3)},{scale},{yaw}]' for asset,x,z,scale,yaw in placed) + "],")
    w, _, floor, objects = sokia
    ox, oz = REGIONS["ghana_north_road"][1]
    north_props = []
    for z in range(34,110):
        for x in range(689,723):
            i = z*w+x
            tile, obj = floor[i], objects[i]
            if not tile or is_water(tile):
                continue
            if 11234 <= obj <= 11246:
                asset, scale, yaw = "wall_piece", .5, 0
            elif 11363 <= obj <= 11372:
                asset, scale, yaw = "fence", .5, 90 if obj in (11363,11368,11370) else 0
            elif 11150 <= obj <= 11159 or 10085 <= obj <= 10094:
                asset, scale, yaw = "tree", .7, 0
            else:
                continue
            north_props.append(f'["{asset}",{vec((x-ox)*3,(z-oz)*3)},{scale},{yaw}]')
    props.append(' "ghana_north_road":[' + ",".join(north_props) + "],")
    x, z = SOKIA_LANDING
    rows.append(f' ["sokia_coast","Sokia Undersea Cave",15004,"cave",{vec(x*3,z*3)},'
                f'{vec(-1,0)},{local(15004,*exits[15004])},{vec((x+4)*3,z*3)}],')
    entrance_rows.append(("sokia_coast",15004,"cave",x,z,(-1,0)))
    x, z = GREAT_WIND_EAST
    rows.append(f' ["sokia_desert","Great Wind Cave",13001,"cave",{vec(x*3,z*3)},'
                f'{vec(0,-1)},{local(13001,*east_door)},{vec(x*3,(z+5)*3)}],')
    entrance_rows.append(("sokia_desert",13001,"cave",x,z,(0,-1)))
    x,z = GHANA_GRAVES
    rows.append(f' ["ghana_north_road","Enter Imur Forest",{GRAVE_ENTRY},"stairs",{vec(x*3,z*3)},'
                f'{vec(0,-1)},{local(GRAVE_ENTRY,*exits[GRAVE_ENTRY])},{vec(x*3,z*3)}],')
    entrance_rows.extend([
        ("ghana_north_road",GRAVE_ENTRY,"stairs",x,z,(0,-1)),
        ("north_coast",15505,"diamond",544,35,(0,0)),
        ("north_coast",16504,"stairs",550,19,(0,0)),
    ])
    paths["north_coast"].extend([
        shore_path(ZOMBIE_MOUTH, (544, 35), alyut_coast),
        shore_path((544, 35), (550, 19), alyut_coast),
    ])
    build_entrance_scenery(output, entrance_rows, {100:original(100)[:4],300:sokia}, library, lookup, paths)
    grave_trees = []
    bear_formations = {}
    for dest, cells in sorted(seeds.items()):
        if dest in VILLAGES or dest in tomato.LAND:
            continue
        map_width, map_height, floor, objects, _ = original(dest)
        origin = (map_width // 2, map_height // 2)
        walk = navigation_grid(map_width, map_height, floor, objects, lookup)
        seeds = [z*map_width+x for x,z in sorted(cells)]
        if dest in solid_roofs or dest in connected_rooms:
            assert all(walk[i] for i in seeds), (dest, cells)
        if dest in connected_rooms:
            start, *other_stairs = seeds
            seeds = [start]
        reachable = set(seeds)
        queue = list(seeds)
        for i in queue:
            x,z = i % map_width,i // map_width
            for nx,nz in [(x+1,z),(x-1,z),(x,z+1),(x,z-1)]:
                if not (0 <= nx < map_width and 0 <= nz < map_height):
                    continue
                j = nz*map_width+nx
                if walk[j] and j not in reachable:
                    reachable.add(j)
                    queue.append(j)
        assert len(reachable) > 5, (dest, len(reachable))
        if dest in connected_rooms:
            assert all(i in reachable for i in other_stairs), (dest, cells)
        if dest in GRAVE_TREES:
            trees = []
            for z in range(1,map_height-1,2):
                for x in range(1,map_width-1,2):
                    i = z*map_width+x
                    if i not in reachable and floor[i] and not is_water(floor[i]) and (x*7+z*11)%7<5:
                        trees.append(local(dest,x,z))
            grave_trees.append(f" {dest}:[{','.join(trees)}],")
        if dest == GRAVE_BOSS:
            assert all(z*map_width+x in reachable for x,z in GRAVE_FORMATION)
        if dest == 16508:
            assert all(walk[z*map_width+x] and z*map_width+x in reachable for x,z,_ in RUBY_FORMATION)
        if dest in VENOA_CAVE or dest in (11004,15505,16503,16508):
            # Retain isolated tiles in the exact Venoa layouts and archived boss maps.
            reachable.update(i for i, is_walkable in enumerate(walk) if is_walkable)
        if dest in ZOMBIE_FORMATIONS:
            assert all(z*map_width+x in reachable and walk[z*map_width+x] for x,z,_ in ZOMBIE_FORMATIONS[dest])
        if dest == 16503:
            assert all(z*map_width+x in reachable for x,z,_ in CAPTAIN_FORMATION)
        if dest in VENOA_BEARS:
            bear_formations[dest] = venoa_bears(dest, map_width, map_height, walk, cells)
            assert len(VENOA_BEARS[dest]) == len(set(VENOA_BEARS[dest]))
            assert all(z*map_width+x in reachable and walk[z*map_width+x]
                       for x,z in VENOA_BEARS[dest]), dest
        if dest == VENOA_BOSS[0]:
            _, x, z = VENOA_BOSS
            assert (x,z) not in VENOA_BEARS[dest] and (x,z) not in cells
            assert all((z+dz)*map_width+x+dx in reachable
                       for dx,dz in ((0,0),(1,0),(-1,0),(0,1),(0,-1)))
        if dest == 11004:
            assert len(set(formation)) == 10
            assert all(walk[z*map_width+x] and z*map_width+x in reachable for x,z in formation)
        bits = bytearray((map_width*map_height+7)//8)
        for i in reachable:
            bits[i>>3] |= 1 << (i&7)
        rooms.append(f' {dest}:[Vector2i({map_width},{map_height}),{vec(-origin[0]*3,-origin[1]*3)},"{bits.hex()}"],')
    build_npcs(magic_power, output, original)
    build_yellow_diamond(output)
    exit_rows[15505] = ("north_coast", 544, 35, "stairs")
    exit_rows[16502] = exit_rows[16501]
    for ident in (16504, 16505):
        exit_rows[ident] = ("north_coast", 550, 19, "stairs")
    tree = route([(301, 181), (298, 148)], ground)
    paths.setdefault("freyja", []).append(tree)
    tomato_villages, tomato_props = tomato.build_land(output)
    rows += ["]", "const VILLAGES={", *villages, *tomato_villages, "}", "const PROPS={", *props, *tomato_props,
             "}", "const ROOMS={", *rooms, "}", "const DOORS={",
             *(f" {key}:[{','.join(value)}]," for key,value in sorted(doors.items())), "}",
             "const TITLES={", *(f' {key}:"{value}",' for key,value in TITLES.items()), "}",
             "const IL_SHORE=[" + ",".join(il_shore) + "]",
             "const TOMATO_MAPS=[" + ",".join(map(str,(*tomato.LAND,tomato.STOREHOUSE))) + "]",
             "const TOMATO_WELL=" + local(tomato.FARM,*tomato.WELL),
             "const TOMATO_CROPS=[" + ",".join(f"[{local(tomato.FARM,x,z)},11090]"
                 for x0,z0,x1,z1 in tomato.BEDS for x in range(x0+1,x1,2) for z in range(z0+1,z1,2)) + "]",
             "const ALYUT_EXITS=[" + ",".join(alyut_exits) + "]",
             "const KILI_EXITS=[" + ",".join(kili_exits) + "]",
             "const GHANA_EXITS=[" + ",".join(ghana_exits) + "]",
             f"const GREAT_WIND_EAST=[{local(13001,*east_door)},{vec(GREAT_WIND_EAST[0]*3,GREAT_WIND_EAST[1]*3)}]",
             "const SOLID_ROOFS=[" + ",".join(map(str,sorted(solid_roofs))) + "]",
             "const ENCLOSED_CAVES=[" + ",".join(map(str,sorted(HABARU | solid_roofs))) + "]",
             "const CAVE_EXITS={", *(f' {key}:[{local(key,*cell)},"{area}",{vec(x*3,z*3)},{str(kind == "diamond").lower()}],'
                                   for key,cell in exits.items() for area,x,z,kind in [exit_rows[key]]), "}",
             "const HABARU_FORMATION=[" + ",".join(local(11004,*cell) for cell in formation) + "]",
             "const CAPTAIN_FORMATION=[" + ",".join(f"[{local(16503,x,z)},{skin}]" for x,z,skin in CAPTAIN_FORMATION) + "]",
             "const GRAVE_TREES={", *grave_trees, "}",
             "const GRAVE_FORMATION=[" + ",".join(local(GRAVE_BOSS,x,z) for x,z in GRAVE_FORMATION) + "]",
             "const RUBY_FORMATION=[" + ",".join(f"[{local(16508,x,z)},{skin}]" for x,z,skin in RUBY_FORMATION) + "]",
             "const VENOA_BOSS_FLOOR=" + str(VENOA_BOSS[0]),
             "const VENOA_BOSS_AT=" + local(*VENOA_BOSS),
             "const VENOA_BEARS={",
             *(f" {key}:[" + ",".join(local(key,x,z) for x,z in entries) + "],"
               for key,entries in sorted(bear_formations.items())), "}",
             "const ZOMBIE_FORMATIONS={",
             *(f" {key}:[" + ",".join(f"[{local(key,x,z)},{skin}]" for x,z,skin in entries) + "],"
               for key,entries in ZOMBIE_FORMATIONS.items()), "}", ""]
    (output / "freyja_destinations_data.gd").write_text("\n".join(rows))
    return paths


def build_npcs(magic, output, original):
    import cg_assets as cg
    import cg_library as library

    lookup = library.serial_index()

    keys = {}
    for row in cg.catalog()["entries"]:
        keys.setdefault(row["id"], row["key"])
    sprites, rooms = {}, {}
    outdoor_npcs = {(100,472,316,14163): ("south_gate", (423,202)),
                    (100,299,538,14058): ("south_lakes", REGIONS["south_lakes"][1]),
                    (300,707,58,101822): ("ghana_north_road", REGIONS["ghana_north_road"][1]),
                    (300,715,34,11054): ("ghana_north_road", REGIONS["ghana_north_road"][1])}
    reference = magic / "research/jobs-sharing-20261031/source/npc-utf8.txt"
    for line in reference.read_text().splitlines():
        row = line.split("\t")
        if len(row) < 21 or row[0].startswith("#") or row[6] != "1" or not row[8].isdigit() or not row[20].isdigit():
            continue
        ident = int(row[8])
        graphic = int(row[20])
        if not row[9].isdigit() or not row[10].isdigit():
            continue
        x,z = int(row[9]),int(row[10])
        if row[3] == "6048" and ident == 777:
            # The server places the nurse on a random floor. Keep her beside the B1 path.
            ident,x,z = 410,21,33
        outdoor_npc = outdoor_npcs.get((ident,x,z,graphic))
        scenery = (ident, graphic) in ((11002, 10409), (16504, 11049), (3200, 11554), (300, 11054))
        if not outdoor_npc and ident not in TITLES and ident not in VILLAGES:
            continue
        if (graphic < 14000 and not scenery) or row[0] == "StandEnemy":
            continue
        direction = int(row[19])
        token = graphic, direction
        if token not in sprites:
            if graphic < 100000 and graphic in lookup:
                entry = lookup[graphic]
                image = library.image_from_record(entry["pack"], entry["row"])
            elif graphic in keys:
                key = keys[graphic]
                _, _, clips = cg.actor(key)
                clip = next((c for c in clips if c["action"] == 0 and c["direction"] == direction), None)
                if clip is None:
                    continue
                image, _, _ = cg.frame_parts(key, clip["index"], 0)
            else:
                continue
            if not image.getbbox():
                continue
            sprites[token] = image.crop(image.getbbox())
        if outdoor_npc:
            area,(ox,oz) = outdoor_npc
            rooms.setdefault(area, []).append(((x-ox)*3,(z-oz)*3,token,row[1]))
            continue
        w,h,*_ = original(ident)
        if not (0 <= x < w and 0 <= z < h):
            continue
        area = VILLAGES.get(ident,str(ident))
        rooms.setdefault(area, []).append(((x-w//2)*3,(z-h//2)*3,token,row[1]))
    assert len(rooms) > 12
    stride = max(max(im.size) for im in sprites.values())+2
    atlas = Image.new("RGBA", (stride*8,stride*((len(sprites)+7)//8)))
    rects = {}
    for i,(token,image) in enumerate(sprites.items()):
        x,z = i%8*stride+1,i//8*stride+1
        atlas.paste(image,(x,z))
        rects[token] = (x,z,*image.size)
    atlas.save(output / "freyja_npc_atlas.png", optimize=True)
    import json
    lines = ["extends RefCounted", "const AREAS={"]
    for area, items in sorted(rooms.items()):
        lines.append(f' "{area}":[')
        for x,z,token,name in items:
            rect = ",".join(map(str,rects[token]))
            lines.append(f'  [{vec(x,z)},Rect2({rect}),{json.dumps(name,ensure_ascii=False)}],')
        lines.append(" ],")
    (output / "freyja_npc_data.gd").write_text("\n".join(lines+["}", ""]))


def build_yellow_diamond(output):
    import cg_assets as cg

    key = "original:3173"
    ident, _, clips = cg.actor(key)
    assert ident == 103012 and len(clips[0]["frames"]) == 8 and clips[0]["duration"] == 800
    atlas = Image.new("RGBA", (58 * 8, 64))
    for i in range(8):
        image, x, y = cg.frame_parts(key, 0, i)
        assert 0 <= x + 29 <= 58 - image.width and y == -101
        # Drop the isometric ground shadow so it doesn't float on the upright billboard.
        atlas.paste(image.crop((0,0,image.width,62)), (58*i + x + 29, 1))
    atlas.save(output / "freyja_yellow_diamond.png", optimize=True)

def draw_branches(size, origin, paths, convert):
    trace = Image.new("L", size)
    draw = ImageDraw.Draw(trace)
    for path in paths:
        points = [convert(x, z) for x, z in path]
        draw.line([((x-origin[0])//3,(z-origin[1])//3) for x,z in points], fill=166, width=5)
    return trace
