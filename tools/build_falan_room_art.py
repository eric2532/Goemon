"""Project archived Blue CG room tiles onto square floor UVs and locate 3D fixtures."""
import argparse
import base64
import json
import sys
import zlib
from array import array
from pathlib import Path

from PIL import Image, ImageOps
import build_freyja_tomato_farm as tomato

# Reviewed original graphics grouped by the geometry visible in the cache.
FIXTURES = {
    "bed": (17537, 17538),
    "counter": (17016, 17017, 17018, 17019, 17020, 17021, 17022, 17049, 17050, 17053, 17054,
                17051, 17200, 17201, 17202, 17203, 17204, 17527, 17529, 17568, 17570, 17595, 17596),
    "shelf": (10500, 17002, 17003, 17005, 17006, 17007, 17012, 17013, 17014, 17015,
              17141, 17541, 17543, 17544, 17545, 17546, 17548, 17549, 17550, 17551),
    "bench": (10407, 10408, 17524, 17525, 17532, 17533),
    "chair": (10405, 10406, 17023, 17025, 17026, 17510, 17511, 17512, 17516, 17517, 17534),
    "table": (17024, 17507, 17508, 17509, 17539, 17540, 17572, 17586),
    "rack": (17155, 17156, 17157, 17158, 17159, 17211, 17212, 17213, 17214, 17215),
    "plant": (10026, 10027, 10039, 11434, 11437, 11438, 11443, 16225, 16226, 16229, 17043,
              17518, 17519, 17535, 17536),
    "barrel": (10014, 10015, 10016, 10017, 10018, 10019, 10021, 10033, 10034),
}
KIND = {serial: kind for kind, serials in FIXTURES.items() for serial in serials}
PALACE_FIXTURES = {
    "table": (16067, 16068, 16072, 16073, 16075, 16076, 16077, *range(16115, 16121),
              16140, *range(16151, 16156), *range(16157, 16161), 16178, 16179, 16184, 16186),
    "shelf": (16004, 16005, *range(16078, 16083), 16086, *range(16088, 16098),
              16143, 16144, 16145, 16146, 16149, 16161),
    "counter": (16069, *range(16102, 16115), 16174, 16177),
    "chair": tuple(range(16122, 16127)),
    "plant": (11439, 11440, 11442, 16214, 16215, 16217, 16218, 16219, 16220, 16222, 16227, 16231),
    "royal_stool": (16201, 16202, 16203, 16204, 16205),
    "armor": tuple(range(16193, 16199)),
    "brazier": (17210,),
    "state_bed": (16026,),
    "fireplace": (16000, 16001, 16002, 16003),
}
PALACE_KIND = {serial: kind for kind, serials in PALACE_FIXTURES.items() for serial in serials}
CELLAR_FIXTURES = {
    "moon": (17237, 17238, 17239),
    "lectern": (17236,),
    "finial": (17241,),
    "grille": (10475, 10477, 10479, 10480, 10481, 17091),
    "rope": (17108,),
    "bust": (17092,),
    "crate": (10531, 11016, 11017, 11018, 11019, 11036, 11066, 11070, 11078),
    "chest": (10444, 10446, 10489),
    "barrel": (10032,),
    "table": (10519,),
}
CELLAR_KIND = {serial: kind for kind, serials in CELLAR_FIXTURES.items() for serial in serials}
CELLARS = {1522, 1530, 1531, 1539}
CIVIC_ROOMS = {1111, 1112, *range(1201, 1208)}
CIVIC_FIXTURES = {
    "civic_screen": (17531,),
    "civic_pew": (17141,),
    "civic_reredos": (17142, 17144),
    "civic_stall": (17143,),
    "civic_font": (17110,),
    "civic_globes": (17139, 17145, 17147),
    "civic_basin": (17140,),
    "civic_statue": (10401,),
    "civic_stool": (16201,),
    "rope": (17138,),
    "crate": (11016, 11017, 11018, 11069, 11070),
}
CIVIC_KIND = {serial: kind for kind, serials in CIVIC_FIXTURES.items() for serial in serials}
ARENA_ROOMS = {*range(1400, 1405), *range(1420, 1425)}
ARENA_FIXTURES = {
    "arena_counter": (17613, 17615, 17617, 17619, 17621),
    "arena_gallery": (17103, 17104, 17105, 17106, 17107),
    "arena_tree": (10086, 10087, 10091),
    "arena_statue": (17096, 17097),
    "arena_flower": (10403, 10404, *range(11627, 11634), *range(11651, 11655), 11696, 11697, 11698),
    "civic_stall": (17143,),
    "civic_globes": (17145, 17146, 17147),
    "civic_screen": (17531,),
    "armor": (17031, 17033, 17036),
    "rope": (17108, 17109),
    "bed": (16048, 16063),
    "bench": (16185, 16186),
    "chair": (16006, 16007, 16008, 16009, 17027, 17028),
    "table": (16029, 16140, 16562, 17029, 17030),
    "crate": (10530, 10531, 10532, 10533, 11018, 16174, 16175),
}
ARENA_KIND = {serial: kind for kind, serials in ARENA_FIXTURES.items() for serial in serials}
INN_ROOMS = set(range(1101, 1106))
INN_KIND = {
    **dict.fromkeys(range(17016, 17023), "inn_counter"),
    **dict.fromkeys((17196, 17197, 17199, 17202, 17203), "inn_counter"),
    16040: "bed", 16029: "inn_table", 16007: "chair", 16227: "plant",
    16511: "shelf", 16514: "inn_cupboard", 16004: "shelf", 16020: "inn_cupboard",
    10436: "bank_clock", 10495: "bank_clock",
    10530: "crate", 10549: "inn_produce", 11104: "inn_sign",
    10443: "inn_chest", 10444: "inn_chest", 10542: "inn_sack", 17211: "inn_display",
    16550: "inn_bucket", 16519: "inn_bucket",
}
INN_DETAILS = {
    1101: (17023, 17607), 1102: (16549,), 1103: (17195, 10415),
    1104: (17023, 16521, 10567), 1105: (),
}
GUILD_KIND = {
    **dict.fromkeys(range(17592, 17597), "guild_counter"),
    17539: "bank_desk", 17572: "bank_desk", 17587: "shelf",
    10531: "crate", 10542: "inn_sack", 16552: "guild_supply", 17028: "chair",
}
BANK_KIND = {
    **dict.fromkeys(range(17566, 17572), "bank_counter"),
    17539: "bank_desk", 17572: "bank_desk",
    10489: "bank_stand", 10495: "bank_clock", 17643: "bank_vault",
    17028: "chair", 17587: "shelf",
}
EMPLOYMENT_KIND = {
    **BANK_KIND, 17027: "chair", 10530: "crate", 17573: "shelf",
}
EMPLOYMENT_DETAILS = (17532, 17534, 17554, 17559, 17560, 17564)
MANSION_ROOMS = set(range(1301, 1306))
MANSION_KIND = {
    17502: "mansion_column", 17503: "mansion_column", 17506: "mansion_piano",
    17539: "mansion_desk", 17586: "mansion_desk",
    17657: "mansion_stair", 17658: "mansion_stair", 17659: "mansion_stair",
    10444: "chest", 10530: "crate",
}
MANSION_PICTURES = tuple(range(17520, 17524))
ARENA_MARKS = tuple(range(11799, 11804))
STAIRS = {12000, *range(17111, 17127)}
CELL_PIXELS = 32
GUTTER = 2
STRIDE = CELL_PIXELS + GUTTER * 2
COLS = 32
WALLS = {
    *range(16246, 16250), 16469, *range(16474, 16491), *range(16492, 16500),
    16691, *range(16716, 16719), *range(16721, 16724), 16934, 16935, 16948,
    16953, 16954, 16984, 16985, 16992, 16993, 16994, 16996, 16997,
    *range(17057, 17062), *range(17065, 17072), 17073, *range(17075, 17083),
    *range(17087, 17090), *range(17098, 17101), 17127, 17128, *range(17131, 17138),
    17148, 17149, 17150, 17161, 17186, 17187, 17190, 17191,
    *range(17500, 17502), 17504, 17505, 17530, 17552, 17583, 17584, 17585,
    17590, 17597, 17600, 17601, 17602, 17609, 17610, 17640, 17643,
}
FREYJA_WALLS = {*range(13000,13036), *range(13152,13188), *range(13324,13360), *range(13432,13468), *range(16939,16945),
                15803,15805,15809,15810,15815,15816,15817,15821,15822,
                *range(13080,13116), *range(16894,16928), 16947, 16949, 16950, 16951, 16955, 16974, 16978, 16979, 16980, 16981, 16982, 16995, 16998,
                16999} - {13004,13016,13028,13084,13096,13108,13328,13340,13352}
FREYJA_FIXTURES = {
    "table": (*range(16566,16578), 16561, 16562, 16563),
    "crate": (11016,11017,11018,10530,10531,16523,16552,16553,17625,17629),
    "shelf": (16511,16512,16514,16526,16583,16758,16795,16796,16811,16812,17635),
    "bed": (16517,16518,16503,16820,16821,17532),
    "chair": (16530,16531,16532,16786,16787,17534),
    "counter": (*range(16829,16839),16840,16841,16843,16844,16846,16847,16848,16850,16851,
                16856,16858,16861,16862,16863,16867,16870,16872,16874,16875,16877,*range(16885,16894)),
    "barrel": (16785,),
    "fireplace": (16554,16555),
    "inn_bucket": (16550,16551,17624),
    "inn_sack": (16173,17046,17047),
    "inn_chest": (10443,10518),
    "armor": (17031,17032),
    "rack": (16599,16756,17162,17163),
    "civic_font": (17228,),
    "plant": (16207,16210,16227,16504,16543),
}
FREYJA_KIND = {serial: kind for kind, serials in FREYJA_FIXTURES.items() for serial in serials}
GHANA_KIND = {
    16822: "bed", 16827: "shelf", 16880: "counter", 16808: "civic_basin", 16809: "civic_basin",
    16621: "civic_font", 16616: "inn_sack", 16617: "inn_sack", 16618: "inn_sack", 16819: "crate",
    16790: "barrel", 16649: "barrel", 16652: "barrel", 16788: "inn_table", 16637: "inn_bucket",
}
WALL_WIDTH, WALL_HEIGHT, WALL_COLS = 36, 100, 16


def project_tile(image):
    """Sample the native 64 × 47 diamond along the two source grid axes."""
    tile = Image.new("RGB", (STRIDE, STRIDE))
    for y in range(STRIDE):
        for x in range(STRIDE):
            u = (max(0, min(CELL_PIXELS - 1, x - GUTTER)) + .5) / CELL_PIXELS - .5
            v = (max(0, min(CELL_PIXELS - 1, y - GUTTER)) + .5) / CELL_PIXELS - .5
            px = int(32 + 31 * (u - v))
            py = int(23.5 + 22 * (u + v))
            tile.putpixel((x, y), image.getpixel((px, py))[:3])
    return tile


def project_boss_overlay(image, center_x, center_y):
    """Lay a cave bank or pool tile flat using its original isometric footprint."""
    tile = Image.new("RGBA", (CELL_PIXELS, CELL_PIXELS))
    for y in range(CELL_PIXELS):
        for x in range(CELL_PIXELS):
            u = (x + .5) / CELL_PIXELS - .5
            v = (y + .5) / CELL_PIXELS - .5
            px = int(center_x + 31 * (u - v))
            py = int(center_y + 22 * (u + v))
            if 0 <= px < image.width and 0 <= py < image.height:
                tile.putpixel((x, y), image.getpixel((px, py)))
    return tile


def project_wall(image, entry, right, cave=False, background=(127, 115, 94)):
    """Undo the 24-pixel diagonal rise of one vertical face of a wall sprite."""
    tile = Image.new("RGBA" if cave else "RGB", (WALL_WIDTH, WALL_HEIGHT))
    center = -entry["x"]
    base = 22 - entry["y"]
    for y in range(WALL_HEIGHT):
        v = (max(0, min(95, y - GUTTER)) + .5) / 96
        for x in range(WALL_WIDTH):
            u = (max(0, min(31, x - GUTTER)) + .5) / 32
            dx = (u if right else u - 1.0) * 29
            px = max(0, min(image.width-1, int(center + dx)))
            py = max(0, min(image.height-1, int(base - abs(dx)*.75 - (1-v)*(base-46))))
            pixel = image.getpixel((px, py))
            if pixel[3] < 128:
                # Beveled corners and shadows leave gaps at the sprite's silhouette.
                # Sample back toward the opaque center of the same face.
                face_center = center + (14 if right else -14)
                for step in range(1, 15):
                    qx = px + max(-step, min(step, face_center-px))
                    qy = py + round((abs(dx)-abs(qx-center))*.75)
                    pixel = image.getpixel((qx, max(0, min(image.height-1, qy))))
                    if pixel[3] >= 128:
                        break
            if cave:
                # The back faces of the isometric sprites are solid shadow.
                tile.putpixel((x, y), (*pixel[:3], pixel[3] if max(pixel[:3]) > 39 else 0))
            else:
                tile.putpixel((x, y), pixel[:3] if pixel[3] >= 128 else background)
    return tile


def cave_rock_atlas(library, lookup, out):
    """Sample opaque stone from the visible sides of each cave tileset."""
    families = [
        ((13355, 32, 38), (13337, 32, 26)),  # Venoa and Alyut West
        ((13432, 26, 54), (13463, 32, 42)),  # Habaru
        ((13019, 28, 28), (13007, 18, 96)),  # Undersea
        ((13099, 32, 50), (13105, 24, 106)),  # Great Wind
    ]
    atlas = Image.new("RGB", (256, 256))
    for family, samples in enumerate(families):
        for variant, (serial, x, y) in enumerate(samples):
            entry = lookup[serial]
            graphic = library.image_from_record(entry["pack"], entry["row"])
            patch = graphic.crop((x, y, x + 18, y + 58))
            assert patch.getchannel("A").getextrema() == (255, 255), serial
            patch = patch.convert("RGB").resize((32, 64), Image.Resampling.BICUBIC)
            strip = Image.new("RGB", (64, 64))
            strip.paste(patch, (0, 0))
            strip.paste(ImageOps.mirror(patch), (32, 0))
            offset = (family * 64, variant * 128)
            atlas.paste(strip, offset)
            atlas.paste(ImageOps.flip(strip), (offset[0], offset[1] + 64))
    atlas.save(out / "cave_rock_atlas.png", optimize=True)


def arena_inlay_detail(library, lookup, out):
    """Recover finer survival-arena detail without changing the original city atlas."""
    edge = 256
    atlas = Image.new("RGBA", (edge * len(ARENA_MARKS), edge))
    for index, serial in enumerate(ARENA_MARKS):
        entry = lookup[serial]
        image = library.image_from_record(entry["pack"], entry["row"])
        assert image.size == (292, 217), f"Unexpected original arena sprite {serial}"
        tile = image.transform((edge, edge), Image.Transform.AFFINE,
                               (145 / edge, -145 / edge, 146,
                                107 / edge, 107 / edge, 1),
                               resample=Image.Resampling.BICUBIC)
        atlas.paste(tile, (index * edge, 0))
    assert atlas.getchannel("A").getextrema() == (255, 255), "Detail projection must cover each carving patch"
    atlas.save(out / "arena_inlays_detail.png", optimize=True)


def arena_inlays(library, lookup, out):
    """Unproject the original wide arena emblems to an alpha-masked square."""
    edge = 128
    atlas = Image.new("RGBA", (edge*len(ARENA_MARKS), edge))
    for index, serial in enumerate(ARENA_MARKS):
        entry = lookup[serial]
        image = library.image_from_record(entry["pack"], entry["row"])
        tile = Image.new("RGBA", (edge, edge))
        for y in range(edge):
            for x in range(edge):
                u = (x+.5)/edge-.5
                v = (y+.5)/edge-.5
                tile.putpixel((x,y), image.getpixel((int(146+145*(u-v)), int(108+107*(u+v)))))
        atlas.paste(tile, (index*edge, 0))
    atlas.save(out / "arena_inlays.png", optimize=True)


def mansion_pictures(library, lookup, out):
    """Straighten the archived diagonal wall hangings into a horizontal atlas."""
    width, height = 96, 64
    atlas = Image.new("RGB", (width * len(MANSION_PICTURES), height))
    for index, serial in enumerate(MANSION_PICTURES):
        entry = lookup[serial]
        source = library.image_from_record(entry["pack"], entry["row"])
        alpha = source.getchannel("A").point(lambda a: 255 if a >= 192 else 0)
        left, _, right, _ = alpha.getbbox()
        for x in range(width):
            px = int(left + 2 + (right - left - 4) * (x + .5) / width)
            _, top, _, bottom = alpha.crop((px, 0, px + 1, source.height)).getbbox()
            for y in range(height):
                py = int(top + (bottom - top) * (y + .5) / height)
                atlas.putpixel((index * width + x, y), source.getpixel((px, py))[:3])
    atlas.save(out / "mansion_pictures.png", optimize=True)


def pack_grid(values):
    indices = array("H", values)
    if sys.byteorder == "big":
        indices.byteswap()
    return base64.b64encode(zlib.compress(indices.tobytes())).decode("ascii")


# Keep the original chamber and its immediate walls while widening the approach outside it.
BOSS_ARENAS = {
    11001: (14, 39, 20, 17),
    11004: (10, 13, 19, 18),
    15505: (8, 10, 28, 18),
    16503: (13, 13, 22, 19),
}
CAVE_FLOORS = {
    11000, 11001, 11002, 11003, 11004, 11005, 11013, 11020, 11021, 11022,
    11023, 11024, 11029, 13001, 15003, 15004, 15005, 15592, 15593, 15594,
    *range(16500, 16506), *range(16516, 16520), 21051,
}
HABARU_PROP_FLOORS = {11004, 11028}
HABARU_WALLS = {
    **dict.fromkeys((11000, 11001, 11002, 11022), set(range(13324, 13360))),
    **dict.fromkeys((11003, 11004, 11005), set(range(13432, 13468))),
    11028: set(range(13324, 13396)),
}
CAVE_BANKS = {*range(13036, 13072), *range(13288, 13324), *range(13396, 13504)}
CAVE_WATER = {*range(7664, 7680), *range(7788, 7804)}


def habaru_wall_faces(library, lookup, rooms, out):
    serials = sorted({serial for ident, walls in HABARU_WALLS.items()
                      for serial in set(rooms[ident][3]) & walls})
    indices = {serial: i + 1 for i, serial in enumerate(serials)}
    atlas = Image.new("RGBA", (16 * WALL_WIDTH, ((len(serials) * 2 + 17) // 16) * WALL_HEIGHT))
    for serial, index in indices.items():
        entry = lookup[serial]
        image = library.image_from_record(entry["pack"], entry["row"])
        for side in (0, 1):
            face = index * 2 + side
            atlas.paste(project_wall(image, entry, side, cave=True),
                        (face % 16 * WALL_WIDTH, face // 16 * WALL_HEIGHT))
    atlas.save(out / "habaru_wall_faces.png", optimize=True)
    return [f' {ident}:"{pack_grid(indices[serial] if serial in walls else 0 for serial in rooms[ident][3])}",'
            for ident, walls in HABARU_WALLS.items()]


def habaru_flat_prop(image, entry):
    width, height = entry["east"], entry["south"]
    tile = Image.new("RGBA", (width * CELL_PIXELS, height * CELL_PIXELS))
    for z in range(tile.height):
        for x in range(tile.width):
            u = (x + .5) / CELL_PIXELS - .5
            v = (z + .5) / CELL_PIXELS - height + .5
            px = int(-entry["x"] + (u + v) * 32)
            py = int(-entry["y"] + (v - u) * 24)
            if 0 <= px < image.width and 0 <= py < image.height:
                tile.putpixel((x, z), image.getpixel((px, py)))
    return tile


def habaru_stair_stone(library, lookup, out):
    # Straighten a visible stone face or rim from each original stair graphic.
    for serial, origin, across, down in (
        (17952, (4, 25), (27, -19), (5, 5)),
        (17953, (8, 30), (26, 18), (2, -3)),
        (17954, (4, 25), (27, -19), (5, 5)),
        (17955, (8, 30), (26, 18), (2, -3)),
        (12001, (26, 8), (29, 22), (0, 9)),
    ):
        entry = lookup[serial]
        image = library.image_from_record(entry["pack"], entry["row"])
        face = Image.new("RGB", (32, 32))
        for v in range(32):
            for u in range(32):
                point = tuple(round(origin[i] + (across[i] * u + down[i] * v) / 31) for i in (0, 1))
                pixel = image.getpixel(point)
                assert pixel[3] == 255, (serial, point)
                face.putpixel((u, v), pixel[:3])
        strip = Image.new("RGB", (64, 32))
        strip.paste(face, (0, 0))
        strip.paste(ImageOps.mirror(face), (32, 0))
        tile = Image.new("RGB", (64, 64))
        tile.paste(strip, (0, 0))
        tile.paste(ImageOps.flip(strip), (0, 32))
        tile.save(out / f"habaru_stair_{serial}.png", optimize=True)


def archived_props(library, lookup, rooms, out, name, arenas):
    placements = {}
    excluded = FREYJA_WALLS if name == "ruby_room_props" else WALLS | FREYJA_WALLS
    for ident, (width, _, _, objects, _, _) in rooms.items():
        rows = []
        for index, serial in enumerate(objects):
            if serial < 1000 or serial in excluded or serial in HABARU_WALLS.get(ident, ()):
                continue
            if ident in HABARU_PROP_FLOORS and serial in (12000,12001,12002):
                continue
            x, z = index % width, index // width
            cave_bank = name == "boss_room_props" and ident in CAVE_FLOORS and serial in CAVE_BANKS
            if name == "boss_room_props" and ident not in arenas and ident not in HABARU_PROP_FLOORS and not cave_bank:
                continue
            if ident in arenas and ident not in HABARU_PROP_FLOORS and not cave_bank:
                left, top, wide, tall = arenas[ident]
                east = max(1, lookup[serial]["east"])
                south = max(1, lookup[serial]["south"])
                if x >= left + wide or x + east <= left or z < top or z - south + 1 >= top + tall:
                    continue
            rows.append((x, z, serial))
        placements[ident] = rows
    images = {}
    flat = set()
    for serial in sorted({serial for rows in placements.values() for _, _, serial in rows}):
        entry = lookup[serial]
        image = library.image_from_record(entry["pack"], entry["row"]).convert("RGBA")
        if name == "boss_room_props" and (serial in CAVE_BANKS or 16306 <= serial <= 16320 or serial in (16642,16788)):
            flat.add(serial)
            center_y = min(image.height - 1, -entry["y"])
            if entry["ground"] and image.height >= 70:
                center_y = image.height - 23
            image = (habaru_flat_prop(image, entry) if serial in (16642, 16788)
                     else project_boss_overlay(image, -entry["x"], center_y))
        if image.getbbox():
            images[serial] = image if serial in flat else image.crop(image.getbbox())
    atlas_width = 1024
    x = z = 1
    row_height = 0
    rectangles = {}
    for serial, image in sorted(images.items(), key=lambda item: -item[1].height):
        if x + image.width >= atlas_width:
            x, z = 1, z + row_height + 2
            row_height = 0
        rectangles[serial] = (x, z)
        x += image.width + 2
        row_height = max(row_height, image.height)
    atlas = Image.new("RGBA", (atlas_width, z + row_height + 1))
    lines = ["extends RefCounted", "## Original furniture and architecture at their archived map cells.", "const ARENAS={"]
    lines.extend(f" {ident}:Rect2i({x},{z},{w},{h})," for ident, (x, z, w, h) in arenas.items())
    lines += ["}", "const GRAPHICS={"]
    for serial, image in images.items():
        x, z = rectangles[serial]
        atlas.paste(image, (x, z))
        entry = lookup[serial]
        lines.append(f" {serial}:[Rect2({x},{z},{image.width},{image.height}),"
                     f"Vector2i({max(1,entry['east'])},{max(1,entry['south'])}),{str(serial in flat).lower()}],")
    lines += ["}", "const PLACEMENTS={"]
    for ident, rows in placements.items():
        lines.append(f" {ident}:[")
        lines.extend(f"  [Vector2i({x},{z}),{serial}]," for x, z, serial in rows if serial in images)
        lines.append(" ],")
    (out / f"{name}.gd").write_text("\n".join(lines + ["}", ""]))
    atlas.save(out / f"{name}.png", optimize=True)


def build(magic, out):
    sys.path.insert(0, str(magic / "tools"))
    import cg_library as library

    exploration = magic / "godot/assets/exploration"
    world = json.loads((exploration / "world.json").read_text())
    npcs = json.loads((exploration / "npcs.json").read_text())["npcs"]
    from build_freyja_destinations import GHANA_ROOMS, TITLES, ZOMBIE_EXIT, entrances, interior_links, load_map
    from prepare_field_assets import navigation_grid

    lookup = library.serial_index()
    rooms = {}
    serials = set()
    with library.connection() as db:
        for id_, room in world["maps"].items():
            if not room["file"].startswith("interior-") or id_ == "1500":
                continue
            info = json.loads((exploration / room["file"]).read_text())["map"]
            key = db.execute("SELECT id FROM files WHERE path = ?", (info["source"],)).fetchone()[0]
            source = library.source_file(key)[1]
            width, height, ground, objects, _ = library.parse_map(source.read_bytes())
            navigation = info["navigation"]
            walk = (exploration / navigation["file"]).read_bytes()
            assert len(walk) == width * height
            protected = {tuple(n["mapCell"]) for n in npcs if n.get("mapId", 1000) == int(id_) and "mapCell" in n}
            protected.update(tuple(d["sourceCell"]) for d in world["portals"].get(id_, []))
            # Preserve arriving characters and NPCs from every floor connection.
            for doors in world["portals"].values():
                protected.update(tuple(d["destinationCell"]) for d in doors if d["destination"] == int(id_))
            rooms[int(id_)] = (width, height, ground, objects, walk, protected)
            serials.update(ground)

    freyja_doors = {}
    for source,x,z,dest,tx,tz in interior_links(magic):
        freyja_doors.setdefault(source, set()).add((x,z))
        freyja_doors.setdefault(dest, set()).add((tx,tz))
    sites = entrances(magic)
    for ident in (1155, 13001, 16501):
        freyja_doors.setdefault(ident,set()).update((x,z) for _,_,x,z in sites[ident])
    for ident, protected in freyja_doors.items():
        if ident not in TITLES or ident in tomato.LAND:
            continue
        width, height, ground, objects, _ = load_map(library, ident)
        walk = navigation_grid(width, height, ground, objects, lookup)
        rooms[ident] = (width, height, ground, objects, walk, protected)
        serials.update(ground)

    archived_props(library, lookup, {16508: rooms[16508]}, out, "ruby_room_props", {})
    archived_props(library, lookup, {ident: rooms[ident] for ident in sorted((CAVE_FLOORS | BOSS_ARENAS.keys() | HABARU_PROP_FLOORS) & rooms.keys())},
                   out, "boss_room_props", BOSS_ARENAS)
    habaru_stair_stone(library, lookup, out)

    tiles = {}
    atlas_tiles = [Image.new("RGB", (STRIDE, STRIDE), "#776855")]
    for serial in sorted(serials - {0}):
        if serial not in lookup:
            continue
        entry = lookup[serial]
        if (entry["w"], entry["h"]) != (64, 47):
            continue
        try:
            image = library.image_from_record(entry["pack"], entry["row"])
        except ValueError:
            continue
        tiles[serial] = len(atlas_tiles)
        atlas_tiles.append(project_tile(image))
    assert len(atlas_tiles) < 65535
    atlas = Image.new("RGB", (COLS * STRIDE, ((len(atlas_tiles) + COLS - 1) // COLS) * STRIDE))
    for index, tile in enumerate(atlas_tiles):
        atlas.paste(tile, (index % COLS * STRIDE, index // COLS * STRIDE))
    atlas.save(out / "room_floor_atlas.png", optimize=True)

    wall_serials = {serial for _, _, _, objects, _, _ in rooms.values() for serial in objects if serial in WALLS or serial in FREYJA_WALLS}
    wall_tiles = {}
    faces = []
    for serial in sorted(wall_serials):
        entry = lookup[serial]
        assert entry["east"] == entry["south"] == 1
        image = library.image_from_record(entry["pack"], entry["row"])
        wall_tiles[serial] = len(faces) // 2 + 1
        faces.extend(project_wall(image, entry, right) for right in (False, True))
    wall_atlas = Image.new("RGB", (WALL_COLS * WALL_WIDTH, ((len(faces) + WALL_COLS - 1) // WALL_COLS) * WALL_HEIGHT))
    for index, face in enumerate(faces):
        wall_atlas.paste(face, (index % WALL_COLS * WALL_WIDTH, index // WALL_COLS * WALL_HEIGHT))
    wall_atlas.save(out / "room_wall_atlas.png", optimize=True)
    cave_rock_atlas(library, lookup, out)
    arena_inlays(library, lookup, out)
    arena_inlay_detail(library, lookup, out)
    mansion_pictures(library, lookup, out)

    output = ["extends RefCounted", "", "const FLOORS={"]
    fixtures = []
    walls = []
    pools = []
    stairs = []
    marks = []
    flowers = []
    arena_forts = []
    arena_stairs = []
    arena_boards = []
    pictures = []
    settees = []
    bank_details = []
    inn_details = []
    guild_details = []
    employment_details = []
    freyja_stairs = []
    count = 0
    for id_, (width, height, ground, objects, walk, protected) in sorted(rooms.items()):
        freyja = id_ in freyja_doors
        coordinates = ([(x,z) for z in range(height) for x in range(width)] if freyja
                       else [(x,z) for x in reversed(range(width)) for z in range(height)])
        packed = pack_grid(tiles.get(ground[y * width + x], 0) + 1 if ground[y * width + x] or walk[y * width + x] else 0
                           for x,y in coordinates)
        output.append(f' {id_}:"{packed}",')
        if id_ in CAVE_FLOORS:
            water = pack_grid(int(ground[y * width + x] in CAVE_WATER) for x,y in coordinates)
            pools.append(f' {id_}:"{water}",')
        if freyja:
            rows = [f"  [Vector2i({i%width},{i//width}),{serial}],"
                    for i,serial in enumerate(objects)
                    if serial in (12000,12001,12002,13268,13269,13270,13271,13274,16590,16592,16594,17952,17953,17954,17955)]
            if id_ == 15505:
                rows.append(f"  [Vector2i({ZOMBIE_EXIT[0]},{ZOMBIE_EXIT[1]}),12000],")
            if rows:
                freyja_stairs.extend([f" {id_}:[", *rows, " ],"])
        packed = pack_grid(wall_tiles.get(objects[y * width + x], 0)
                           if not walk[y * width + x] and (x, y) not in protected
                           and (id_ != 1121 or objects[y * width + x] != 17643) else 0
                           for x,y in coordinates)
        walls.append(f' {id_}:"{packed}",')
        if id_ in CELLARS:
            stair_rows = [f'  [Vector2i({i//width},{width-1-i%width}),{serial}],'
                          for i, serial in enumerate(objects) if serial in STAIRS and walk[i]]
            if stair_rows:
                stairs.extend([f" {id_}:[", *stair_rows, " ],"])
        if id_ == 1401:
            marks = [f" [Vector2i({i//width},{width-1-i%width}),{serial-ARENA_MARKS[0]}],"
                     for i, serial in enumerate(objects) if serial in ARENA_MARKS]
            arena_forts = [f" [Vector2i({i//width-1},{width-2-i%width}),{serial}],"
                           for i, serial in enumerate(objects) if serial in (10640, 10641, 10648, 10649, 10650, 10653)]
        if id_ == 1403:
            flowers = [f" [Vector2i({i//width},{width-1-i%width}),{serial}],"
                       for i, serial in enumerate(objects) if ARENA_KIND.get(serial) == "arena_flower"
                       and (i%width,i//width) not in protected]
        if id_ in (1401, 1403):
            rows = [f"  [Vector2i({i//width},{width-1-i%width}),{serial}],"
                    for i, serial in enumerate(objects) if serial in range(17111, 17115) and walk[i]]
            arena_stairs.extend([f" {id_}:[", *rows, " ],"])
        if id_ in range(1420, 1425):
            rows = [f"  [Vector2i({i//width},{width-1-i%width}),{serial}],"
                    for i, serial in enumerate(objects) if serial in (11024, 11025)
                    and (i%width,i//width) not in protected]
            if rows:
                arena_boards.extend([f" {id_}:[", *rows, " ],"])
        if id_ in MANSION_ROOMS or id_ in (1092, 1104):
            rows = []
            for i, serial in enumerate(objects):
                if serial not in MANSION_PICTURES:
                    continue
                x, y = i % width, i // width
                # These sprites sit on the open cell in front of their wall.
                along_z = lookup[serial]["east"] == 2
                at = (y - .495, width - 1.5 - x) if along_z else (y - .5, width - .505 - x)
                rows.append(f'  [Vector2({at[0]:.3f},{at[1]:.3f}),{serial-17520},{str(along_z).lower()}],')
            if rows:
                pictures.extend([f" {id_}:[", *rows, " ],"])
        if id_ in (1301, 1302):
            rows = [f'  [Vector2i({i//width},{width-1-i%width}),{serial}],'
                    for i, serial in enumerate(objects) if serial in (17524, 17525, 17533)
                    and (i%width, i//width) not in protected]
            settees.extend([f" {id_}:[", *rows, " ],"])
        if id_ == 1121:
            bank_details = [f" [Vector2i({i//width},{width-1-i%width}),{serial}],"
                            for i, serial in enumerate(objects) if serial in (17533, 17641, 17642)]
        if id_ in INN_DETAILS:
            rows = [f"  [Vector2i({i//width},{width-1-i%width}),{serial}],"
                    for i, serial in enumerate(objects) if serial in INN_DETAILS[id_]
                    and (i%width, i//width) not in protected]
            if rows:
                inn_details.extend([f" {id_}:[", *rows, " ],"])
        if id_ == 1092:
            guild_details = [f" [Vector2i({i//width},{width-1-i%width}),{serial}],"
                             for i, serial in enumerate(objects) if serial in (17534, 17608)
                             and (serial == 17608 or (i%width,i//width) not in protected)]
        if id_ == 1091:
            employment_details = [f" [Vector2i({i//width},{width-1-i%width}),{serial}],"
                                  for i, serial in enumerate(objects) if serial in EMPLOYMENT_DETAILS
                                  and (serial not in (17532, 17534) or (i%width,i//width) not in protected)]
        entries = []
        used = set()
        anchors = range(len(objects))
        if id_ == 1101:
            # The curved bar overlays standard modules in the source.
            anchors = sorted(anchors, key=lambda i: objects[i] != 17018)
        for anchor in anchors:
            serial = objects[anchor]
            kind = PALACE_KIND.get(serial, KIND.get(serial)) if 1502 <= id_ <= 1531 else KIND.get(serial)
            if freyja:
                kind = FREYJA_KIND.get(serial, kind)
            if id_ in GHANA_ROOMS:
                kind = GHANA_KIND.get(serial, kind)
            if id_ == 3099:
                kind = CELLAR_KIND.get(serial, kind)
            if id_ == 2199:
                kind = "lectern" if serial == 17235 else CELLAR_KIND.get(serial, kind)
            if id_ in CELLARS:
                kind = CELLAR_KIND.get(serial, kind)
            if id_ in CIVIC_ROOMS:
                kind = CIVIC_KIND.get(serial, kind)
            if id_ in ARENA_ROOMS:
                kind = ARENA_KIND.get(serial, PALACE_KIND.get(serial, kind))
                if id_ == 1403 and kind == "arena_flower":
                    continue
            if id_ in MANSION_ROOMS:
                kind = MANSION_KIND.get(serial, kind)
            if id_ in INN_ROOMS:
                kind = INN_KIND.get(serial, kind)
            if id_ == 1091:
                kind = EMPLOYMENT_KIND.get(serial, kind)
            if id_ == 1092:
                kind = GUILD_KIND.get(serial, kind)
            if id_ == 1121:
                kind = BANK_KIND.get(serial, kind)
            if kind is None or serial not in lookup:
                continue
            x, y = anchor % width, anchor // width
            east, south = max(1, lookup[serial]["east"]), max(1, lookup[serial]["south"])
            limit = 5 if kind == "civic_reredos" else 4
            if x + east > width or y + 1 < south or east > limit or south > limit:
                continue
            footprint = {(a, b) for a in range(x, x + east) for b in range(y - south + 1, y + 1)}
            if footprint & (protected | used) or any(walk[b * width + a] for a, b in footprint):
                continue
            if kind not in ("mansion_stair", "inn_counter", "inn_sack", "inn_chest", "inn_display", "inn_sign") and not any(0 <= a + dx < width and 0 <= b + dy < height and walk[(b + dy) * width + a + dx]
                       for a, b in footprint for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0))):
                continue
            used.update(footprint)
            cell, span = ((x,y-south+1), (east,south)) if freyja else ((y-south+1,width-x-east), (south,east))
            entries.append(f'  [Vector2i({cell[0]},{cell[1]}),Vector2i({span[0]},{span[1]}),"{kind}",{serial}],')
        if entries:
            fixtures.extend([f" {id_}:[", *entries, " ],"])
            count += len(entries)
    output.extend(["}", "", "const CAVE_POOLS={", *pools, "}", "", "const HABARU_WALLS={",
                   *habaru_wall_faces(library, lookup, rooms, out), "}", "",
                   "const WALLS={", *walls, "}", "", "const WALL_HEIGHTS=[",
                   " " + ",".join(str(lookup[serial]["h"]) for serial in sorted(wall_tiles)),
                   "]", "", "const FIXTURES={", *fixtures, "}", "",
                   "const CELLAR_STAIRS={", *stairs, "}", "",
                   "const FREYJA_STAIRS={", *freyja_stairs, "}", "",
                   "const ARENA_MARKS=[", *marks, "]", "",
                   "const ARENA_FLOWERS=[", *flowers, "]", "",
                   "const ARENA_FORTS=[", *arena_forts, "]", "",
                   "const ARENA_STAIRS={", *arena_stairs, "}", "",
                   "const ARENA_BOARDS={", *arena_boards, "}", "",
                   "const ROOM_PICTURES={", *pictures, "}", "",
                   "const MANSION_SETTEES={", *settees, "}", "",
                   "const BANK_DETAILS=[", *bank_details, "]", "",
                   "const INN_DETAILS={", *inn_details, "}", "",
                   "const GUILD_DETAILS=[", *guild_details, "]", "",
                   "const EMPLOYMENT_DETAILS=[", *employment_details, "]"])
    (out / "room_art_data.gd").write_text("\n".join(output) + "\n")
    print(f"{len(rooms)} floor layouts, {len(tiles)} archived floor graphics, {len(wall_tiles)} wall graphics, {count} fitted furnishings")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("magic_power", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.magic_power.resolve(), args.output.resolve())
