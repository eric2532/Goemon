"""Prepare recovered-map patrol data from the pinned CGMSV encounter reference.

Run with the directory containing encount/group/enemy/enemybase.txt. Positions
are Goemon real-time adaptations; the reference describes random battles.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image

from build_freyja_outlying import REGIONS, SOKIA_EAST_REGIONS

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/maps/falan"
REFERENCE = "https://github.com/linv2/Crossgate_Docker/tree/dd8690ed3df11e4eb5a038a54079a8f40d8e93b3/gmsv/data"
# Preserve the five existing native skin IDs. Heights are relative to Kaz.
SPECIES = [
    (101242, "迷你蝙蝠", .8), (101800, "哥布林", .7),
    (101820, "盜賊", 1.), (101313, "黃蜂", .8), (101400, "樹精", 1.9),
    (101020, "大地鼠", .55), (101022, "火焰鼠", .55),
    (101203, "小惡魔", .85), (101250, "大蝙蝠", .85),
    (101300, "藍蠍", .65), (101302, "黃蠍", .65),
    (101311, "異型蜂", .8), (101312, "虎頭蜂", .8),
    (101320, "螳螂", 1.1), (101322, "赤目螳螂", 1.1),
    (101331, "水蜘蛛", .6), (101404, "冰冷樹精", 1.9),
    (101410, "妖草", .8), (101421, "黃色口臭鬼", 1.),
    (101431, "武術仙人掌", 1.), (101432, "兔耳仙人掌", 1.),
    (101433, "印地安仙人掌", 1.), (101632, "鐵剪螃蟹", .7),
    (101722, "火龍蜥", 1.05), (101801, "紅帽哥布林", .7),
    (101821, "山賊", 1.), (101822, "海盜", 1.),
    (101830, "鳥人", 1.1), (101832, "狠毒鳥人", 1.1),
]


def read_tables(source):
    def rows(name):
        return [line.split("\t") for line in (source / name).read_text(encoding="gb18030").splitlines()
                if line and not line.startswith("#")]
    enemies = {r[2]: r for r in rows("enemy.txt")}
    bases = {r[1]: r for r in rows("enemybase.txt")}
    groups = {r[2]: r for r in rows("group.txt")}
    zones = []
    for row in rows("encount.txt"):
        if int(row[3]) not in (100, 300, 13001, 15004, 15005, 15592, 15594):
            continue
        members = {}
        for group in filter(None, row[14:24]):
            for enemy in groups[group][5:15]:
                if enemy in ("", "0"):
                    continue
                variant = enemies[enemy]
                ident = int(bases[variant[3]][30])
                members[ident] = min(members.get(ident, 999), int(variant[4]))
        zones.append(dict(id=int(row[0]), map=int(row[3]), bounds=list(map(int, row[4:8])), members=members))
    return zones


def zone_at(zones, map_id, x, y):
    matches = [z for z in zones if z["map"] == map_id
               and z["bounds"][0] <= x <= z["bounds"][2]
               and z["bounds"][1] <= y <= z["bounds"][3]]
    # Use the most local reference rectangle rather than its whole-island fallback.
    return min(matches, key=lambda z: ((z["bounds"][2]-z["bounds"][0]+1)
                                      * (z["bounds"][3]-z["bounds"][1]+1), -z["id"]), default=None)


def build(source, archive):
    zones = read_tables(source)
    skins = {ident: i for i, (ident, _, _) in enumerate(SPECIES)}
    assert len(skins) == 29
    assert set(skins) == {ident for z in zones if z["map"] in (100, 300, 13001) for ident in z["members"]}
    catalog = json.loads((archive / "data/crossgate/catalog.json").read_text())["entries"]
    records = []
    for ident, name, ratio in SPECIES:
        keys = [r["key"] for r in catalog if r["id"] == ident and r["key"].startswith("original:")
                and 2800 <= int(r["key"].split(":")[1]) < 3000]
        assert len(keys) == 1, (ident, keys)
        records.append(dict(id=ident, key=keys[0], name=name, height=ratio))
    (OUT / "frontier_species.json").write_text(json.dumps(records, ensure_ascii=False, indent=2)+"\n")
    posts = {}
    for area, (_, center, _) in REGIONS.items():
        image = Image.open(OUT / (area + "_surface.png")).convert("RGBA")
        map_id = 300 if area == "sokia_coast" or area in SOKIA_EAST_REGIONS else 100
        # Keep the established road/beginner posts; complete the outer fields.
        points = []
        for py in range(4, image.height-4, 8):
            for px in range(4, image.width-4, 8):
                r, g, _, a = image.getpixel((px, py))
                if r >= 128 or a < 128 or g >= 143:
                    continue
                x = round(center[0] + px - (image.width-1)/2)
                y = round(center[1] + py - (image.height-1)/2)
                zone = zone_at(zones, map_id, x, y)
                if zone is None:
                    continue
                members = sorted(zone["members"])
                if ident := next((i for i in members if i == 101820), None):
                    roadside = any(image.getpixel((xx,yy))[1] >= 143
                                   for yy in range(max(0,py-12),min(image.height,py+13))
                                   for xx in range(max(0,px-12),min(image.width,px+13))
                                   if (xx-px)**2+(yy-py)**2 < 169)
                    if roadside:
                        members.remove(ident)
                if not members:
                    continue
                ident = members[len(points) % len(members)]
                points.append((x, y, skins[ident], zone["id"]))
        # Bound setup/population work while sampling the entire recovered mask.
        if len(points) > 144:
            points = [points[i*len(points)//144] for i in range(144)]
        posts[area] = points
    # Sample original open floor cells; the runtime rechecks actual scenery clearance.
    rooms = (OUT / "freyja_destinations_data.gd").read_text()
    room_posts = {}
    for floor in (13001, 15004, 15005, 15592, 15594):
        match = re.search(rf' {floor}:\[Vector2i\((\d+),(\d+)\),Vector2\(([-\d]+),([-\d]+)\),"([a-f0-9]+)"', rooms)
        assert match, floor
        width, height, ox, oy = map(int, match.groups()[:4])
        bits = bytes.fromhex(match[5])
        points = []
        for y in range(2, height-2, 4):
            for x in range(2, width-2, 4):
                if not bits[(y*width+x)//8] & (1 << ((y*width+x)%8)):
                    continue
                zone = zone_at(zones, floor, x, y)
                if zone is None:
                    continue
                members = sorted(zone["members"])
                ident = members[len(points) % len(members)]
                skin = skins[ident] if floor == 13001 else 1 if ident == 101721 else 2
                points.append((ox+x*3, oy+y*3, skin, zone["id"]))
        room_posts[floor] = points
        assert points, floor
    lines = ["extends RefCounted", "## Generated by tools/build_map_encounters.py; random-battle regions adapted to real-time posts.", "const POSTS={"]
    for area, points in posts.items():
        lines += [f' "{area}":[', *(f"  Vector4i({x},{y},{s},{z})," for x,y,s,z in points), " ],"]
    lines += ["}", "const ROOM_POSTS={"]
    for floor, points in room_posts.items():
        lines += [f" {floor}:[", *(f"  Vector4i({x},{y},{s},{z})," for x,y,s,z in points), " ],"]
    lines += ["}", "const UNDERSEA_POSTS={"]
    for floor, points in room_posts.items():
        if floor == 13001:
            continue
        lines += [f" {floor}:[", *(f"  [Vector2({x},{y}),{s}]," for x,y,s,z in points), " ],"]
    lines += ["}", "const ZONES={"]
    for zone in zones:
        if zone["map"] not in (100, 300, 13001):
            continue
        x,y,xx,yy = zone["bounds"]
        mask = sum(1 << skins[ident] for ident in zone["members"])
        lines.append(f' {zone["id"]}:[Rect2i({x},{y},{xx-x+1},{yy-y+1}),{mask}],')
    lines += ["}", "const NAMES="+json.dumps([r[1] for r in SPECIES], ensure_ascii=False),
              "const HEIGHTS="+json.dumps([r[2] for r in SPECIES])]
    (OUT / "map_encounter_data.gd").write_text("\n".join(lines)+"\n")
    report = dict(reference=REFERENCE, note="CGMSV reference, not verified BlueCG server spawn data. Counts and posts are Goemon adaptations.",
                  source_hashes={name: hashlib.sha256((source/name).read_bytes()).hexdigest()
                                 for name in ("encount.txt", "group.txt", "enemy.txt", "enemybase.txt")},
                  zones=zones, posts={area:len(p) for area,p in posts.items()}, rooms={str(k):len(p) for k,p in room_posts.items()})
    (OUT / "map_encounter_provenance.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(dict(species=len(records), posts=report["posts"], rooms=report["rooms"])))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    build(args.source, args.archive)
