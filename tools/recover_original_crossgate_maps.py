"""Recover original Blue Cross Gate map caches and unmodified isometric artwork.

Preserve source bytes and prepare native-paint surface derivatives for solid scenery.
No fixed layout generation or NPC scripts.
"""
import argparse
import base64
import hashlib
import json
import struct
import sys
import zlib
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/maps/original_crossgate"
REPORT = ROOT / "build/Other Files/Asset Toolkit/Original Isometric Maps"
PAGE = 2048
BEAST_SOURCE = ROOT / "build/Other Files/Asset Toolkit/Jenova Beast Recovery/Source"
TINA_SOURCE = ROOT / "assets/references/crossgate_tina"
TINA_DEPENDENCIES = set(range(14017,14026)) | set(range(14036,14040)) | {1850,32181,32183,32193,32194}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def encode(raw):
    return base64.b64encode(zlib.compress(raw, 9)).decode("ascii")


def identify(path, floor, objects):
    number = int(Path(path).stem) if Path(path).stem.isdecimal() else -1
    if "/map/0/" in path:
        if number in TINA_DEPENDENCIES:
            names={1850:"蒂娜村 · 租屋",14017:"海賊的巢穴",14018:"海賊的巢穴 · 地下6樓",14019:"海賊的巢穴 · 地下5樓",
                   14020:"海賊的巢穴 · 地下4樓",14021:"海賊的巢穴 · 地下3樓",14022:"海賊的巢穴 · 地下2樓",
                   14023:"海賊的巢穴 · 地下1樓",14024:"海賊的巢穴 · 頭目的房間",14025:"海賊的巢穴 · 1樓",
                   14036:"海賊的巢穴 · 解放後",14037:"海賊的巢穴 · 天書之間",14038:"海賊的巢穴 · 天書之間",
                   14039:"海賊的巢穴 · 出口",32181:"亞斯提亞",32183:"四方守護聖獸的回憶",32193:"往山的礦路",32194:"守護之花"}
            return "tina_quest",names[number]
        if number in (400, 402, 14000, 14001, 14002, 15000, 15001, 15002):
            names = {400:"莎蓮娜南路",402:"莎蓮娜雪原",14000:"莎蓮娜西方洞窟 1F",14001:"莎蓮娜西方洞窟 2F",14002:"莎蓮娜西方洞窟 3F",15000:"莎蓮娜海底洞窟 1F",15001:"莎蓮娜海底洞窟 2F",15002:"莎蓮娜海底洞窟 3F"}
            return "shalena", names[number]
        if 4000 <= number < 4100:
            return "jenova", "傑諾瓦鎮" if number==4000 else "傑諾瓦鎮 · 室內"
        if 16510 <= number <= 16515:
            return "beast", {16510:"神獸古城 · 入口",16511:"靜謐之間 · 神獸史雷普尼爾",16512:"靜謐之間 · 解放後",16513:"咒縛之帳",16514:"靜謐之間 · 僧侶的房間",16515:"靜謐之間 · 巫師的房間"}[number]
        if 4200 <= number < 4300:
            names = {4200:"蒂娜村",4201:"蒂娜村 · 夜晚",4206:"蒂娜村 · 食品店",4208:"蒂娜村 · 酒吧",
                     4209:"蒂娜村 · 酒吧地下",4210:"蒂娜村 · 醫院",4211:"蒂娜村 · 醫院內室",
                     4212:"蒂娜村 · 村長的家",4213:"蒂娜村 · 村長的家內室",4214:"蒂娜村 · 村長的家地下",
                     4220:"蒂娜村 · 民家",4221:"蒂娜村 · 民家內室",4222:"蒂娜村 · 民家內室",
                     4230:"蒂娜村 · 夜晚酒吧",4232:"蒂娜村 · 夜晚傳送點",4299:"蒂娜村 · 傳送點"}
            return "tina", names.get(number,"蒂娜村 · 室內")
        if 24000 <= number <= 24074:
            if 24009 <= number <= 24068:
                return "maze", "詛咒的迷宮 · %dF" % (number - 24008)
            if number >= 24069:
                return "maze", "詛咒的迷宮 · 第%d難關後" % (number - 24068)
            return "maze", "詛咒的迷宮 · 入口區域 %d" % number
        if 4300 <= number <= 4399:
            names = {4300: "阿巴尼斯村", 4308: "酒吧", 4309: "酒吧地下", 4310: "醫院",
                     4312: "村長的家", 4313: "村長的家", 4320: "民家", 4321: "民家",
                     4331: "民家地下", 4332: "民家地下", 4333: "民家", 4334: "民家地下",
                     4335: "民家地下", 4399: "傳送點"}
            return "abanis", names.get(number, "民家")
        if 4400 <= number <= 4499:
            names = {4400: "魔法大學", 4401: "實驗室", 4402: "地下實驗室", 4410: "魔法大學內部",
                     4411: "技術室", 4412: "更衣室", 4413: "調理室", 4414: "教室", 4415: "教室",
                     4416: "教師室", 4417: "音樂室", 4418: "禮堂", 4419: "學長室", 4420: "保健室",
                     4421: "合格房間", 4422: "家畜小屋", 4423: "家畜小屋", 4424: "家畜小屋",
                     4451: "魔法大學商店", 4452: "魔法大學商店", 4453: "魔法大學商店", 4454: "魔法大學商店", 4455: "魔法大學商店", 4430: "實驗室", 4431: "音樂室", 4432: "音樂室"}
            return "university", names.get(number, "青龍的洞窟")
        if number in (15522, 15523):
            return "snow", "雪山之頂" if number == 15522 else "雪山小屋"
    elif 8175 in floor and any(serial in objects for serial in (17956, 17957)):
        # Cache directory/number is an instance identity, not a verified floor number.
        return "snow", "積雪的山路 · 原始快取 " + "/".join(path.split("/")[-2:]).removesuffix(".dat")
    elif 1191 in floor and 17065 in objects:
        return "beast_cache", "貝茲雷姆系原始快取 · " + "/".join(path.split("/")[-2:]).removesuffix(".dat")
    return None


def complete_recorded_map(path, raw, lib):
    """Fill uncached cells only; client variations always take precedence."""
    if "/map/0/" not in path:
        return raw, {}
    number = int(Path(path).stem)
    tina = 4200 <= number < 4300 or number in TINA_DEPENDENCIES
    if number != 400 and not 4000 <= number < 4100 and not 16510 <= number <= 16515 and not tina:
        return raw, {}
    folder = TINA_SOURCE if tina else BEAST_SOURCE
    matches = sorted(folder.glob(f"{number:05d}_*"))
    assert len(matches) == 1, (path, matches)
    reference = matches[0].read_bytes()
    manifests = sum((json.loads((folder / f).read_text()) for f in (("references.json",) if tina else ("references.json", "completion-references.json"))), [])
    proof = next(r for r in manifests if r.get("file",Path(r["path"]).name) == matches[0].name)
    assert digest(reference) == proof["sha256"], path
    assert reference[:6] == b"LS2MAP", path
    width, height, floor, objects, flags = lib.parse_map(raw)
    assert struct.unpack(">HH", reference[40:44]) == (width, height), path
    cells = width * height
    assert len(reference) == 44 + cells * 4, path
    values = struct.unpack(f">{cells * 2}H", reference[44:])
    known = [i for i in range(cells) if flags[i] & 0xC000]
    differences = [i for i in known if (floor[i], objects[i]) != (values[i], values[cells+i])]
    # Reject unrelated maps; retain every differing recorded BlueCG cell verbatim.
    assert len(known) >= 100 and len(differences) / len(known) < .005, (path, len(differences))
    restored = bytearray(raw)
    count = 0
    for i in range(cells):
        if flags[i] & 0xC000:
            continue
        if (floor[i], objects[i]) == (values[i], values[cells+i]):
            continue
        struct.pack_into("<H", restored, 20+i*2, values[i])
        struct.pack_into("<H", restored, 20+(cells+i)*2, values[cells+i])
        count += 1
    assert all(restored[20+i*2:22+i*2] == raw[20+i*2:22+i*2] and restored[20+(cells+i)*2:22+(cells+i)*2] == raw[20+(cells+i)*2:22+(cells+i)*2] for i in known)
    metadata = dict(restored_raw=encode(restored), restored_sha256=digest(restored), restored_cells=count,
                    completion_reference=proof, reference_compared_cells=len(known), preserved_client_variations=len(differences))
    return bytes(restored), metadata


def beast_encounters(source):
    tables = ROOT / "build/Other Files/Asset Toolkit/Map Encounters/Source"
    def rows(path):
        return [r for line in path.read_text(encoding="gb18030").splitlines() if line and not line.startswith("#") and len(r:=line.split("\t")) > 3]
    config_path = REPORT / "reference-dungeonconf.txt"
    config = next(r for r in rows(config_path) if r[3] == "400" and r[9] == "16510")
    assert list(map(int, (config[15],config[39],config[40],config[22],config[25],config[34],config[35]))) == [16511,12,12,1191,17065,12000,12002]
    groups = {r[2]:r for r in rows(tables/"group.txt")}
    enemies = {r[2]:r for r in rows(tables/"enemy.txt")}
    bases = {r[1]:r for r in rows(tables/"enemybase.txt")}
    encounter = next(r for r in rows(tables/"encount.txt") if r[0] == config[49])
    species = {int(bases[enemies[e][3]][30]) for g in filter(None,encounter[14:24]) for e in groups[g][5:15] if e not in ("", "0")}
    assert species == {101522,101710}
    actors = json.loads((source/"data/crossgate/catalog.json").read_text())["entries"]
    def key(ident):
        keys = [r["key"] for r in actors if r["id"] == ident and r["key"].startswith("original:") and 2800 <= int(r["key"].split(":")[1]) < 3000]
        assert len(keys) == 1
        return keys[0]
    boss = enemies[groups["260065"][5]]
    assert int(bases[boss[3]][30]) == 101032 and int(boss[4]) == 50
    return dict(patrols=[[key(101522),"大炸彈"],[key(101710),"大地翼龍"]], levels=list(map(int,config[50:52])),
                boss=dict(key=key(101032),name="神獸史雷普尼爾",level=int(boss[4]),ai=int(boss[8]),raw=boss),
                dungeon_config=config,encounter=encounter,groups={g:groups[g] for g in (*filter(None,encounter[14:24]),"260065")},
                source_hashes={p.name:digest(p.read_bytes()) for p in [config_path,*(tables/f for f in ("encount.txt","group.txt","enemy.txt","enemybase.txt"))]},
                limits="Pinned reference identities and dungeon levels; real-time patrol posts and combat balance are adaptations. BlueCG server AI was not supplied.")


def prepare(source):
    from build_falan_room_art import KIND, PALACE_KIND, CELLAR_KIND, CIVIC_KIND, ARENA_KIND, FREYJA_KIND
    from build_coastal_villages import KINDS, WALLS
    furniture = {**KIND, **PALACE_KIND, **CELLAR_KIND, **CIVIC_KIND, **ARENA_KIND, **FREYJA_KIND, **KINDS}
    furniture.update({s: "room_wall" for s in WALLS if s >= 16000})
    sys.path.insert(0, str(source / "tools"))
    import cg_library as lib
    from prepare_field_assets import navigation_grid

    lookup = dict(lib.serial_index())
    with lib.connection() as db:
        files = list(db.execute("SELECT id,path FROM files WHERE path LIKE 'BlueCrossgate/map/%' ORDER BY path"))
    files = [(row["path"], lib.source_file(row["id"])[1], row["id"], {}) for row in files]
    # Rooms lacking client snapshots retain explicit pinned-reference provenance.
    from build_freyja_destinations import read_housing_map
    cached_paths={row[0] for row in files}
    for ident in (4206,4232,*sorted(TINA_DEPENDENCIES)):
        if f"BlueCrossgate/map/0/{ident}.dat" in cached_paths:continue
        proof = next(r for r in json.loads((TINA_SOURCE / "references.json").read_text()) if r["file"].startswith(f"{ident:05d}_"))
        reference = (TINA_SOURCE / proof["file"]).read_bytes()
        assert digest(reference) == proof["sha256"]
        width,height,floor,objects,_ = read_housing_map(reference,ident)
        cells = width*height
        raw = b"MAP\x01"+bytes(8)+struct.pack("<II",width,height)+struct.pack(f"<{cells*3}H",*floor,*objects,*([0xC000]*cells))
        files.append((f"BlueCrossgate/map/0/{ident}.dat",raw,0,dict(reference_only=True,layout_reference=proof)))
    maps, used = {}, set()
    for path, payload, file_id, provenance in files:
        raw = payload.read_bytes() if isinstance(payload, Path) else payload
        if raw[:4] != b"MAP\x01":
            continue
        width, height, floor, objects, flags = lib.parse_map(raw)
        group = identify(path, floor, objects)
        if group is None:
            continue
        restored, completion = complete_recorded_map(path, raw, lib)
        _, _, floor, objects, _ = lib.parse_map(restored)
        serials = {s for s in floor if s} | {s for s in objects if s >= 1000}
        missing=(serials-lookup.keys())|{s for s in serials if "fallback_serial" in lookup.get(s,{})}
        assert not missing or int(Path(path).stem) in {32181,32183,32193,32194},(path,missing)
        # User-approved access approximation: keep source planes; reuse existing paint/forms only for absent artwork.
        for serial in sorted(missing):
            fallback=8155 if serial in floor else 16727
            lookup[serial]=dict(lookup[fallback],fallback_serial=fallback)
        used.update(serials)
        walk = navigation_grid(width, height, floor, objects, lookup)
        mask = bytearray((width * height + 7) // 8)
        for i, opened in enumerate(walk):
            if opened:
                mask[i >> 3] |= 1 << (i & 7)
        maps[path] = dict(
            group=group[0], title=group[1], size=[width, height],
            id=int(Path(path).stem) if "/map/0/" in path else 700000 + file_id,
            raw=encode(raw), sha256=digest(raw), bytes=len(raw), walk=encode(mask),
            recorded=sum(bool(f & 0xC000) for f in flags), cells=width * height,
            warp_cells=[[i % width, i // width] for i, value in enumerate(flags) if value & 2],
            **completion, **provenance,
            **(dict(unavailable_graphics=sorted(missing),artwork_approximation=True) if missing else {}),
        )

    pages, graphics, images = pack_graphics(used, lookup, furniture, lib)
    catalog = dict(schema=1, basis="Original client snapshots; Jenova/Beast uncached cells completed from the pinned matching reference. No recovered BlueCG server AI.",
                   maps=maps, graphics=graphics, pages=[f"atlas-{i}.png" for i in range(len(pages))])
    # The pinned recovery reference supplies fixed warp endpoints, never NPC scripts.
    warp_file = REPORT / "reference-warp.txt"
    warps = []
    if warp_file.exists():
        for line in warp_file.read_text(errors="replace").splitlines():
            fields = line.split()
            if len(fields)>=7 and all(v.isdecimal() for v in fields[:7]):
                warps.append(list(map(int,fields[1:7])))
    assert warps, "Missing pinned fixed-warp recovery reference"
    catalog["warps"] = warps
    catalog["warp_reference_sha256"] = digest(warp_file.read_bytes())
    templates = []
    for path, row in maps.items():
        if row["group"] != "beast_cache":
            continue
        width, height, _, objects, _ = lib.parse_map(zlib.decompress(base64.b64decode(row["raw"])))
        up = [i for i, s in enumerate(objects) if s == 12000]
        down = [i for i, s in enumerate(objects) if s == 12002]
        if len(up) != 1 or len(down) != 1:
            continue
        bits = zlib.decompress(base64.b64decode(row["walk"]))
        opened = lambda i: bool(bits[i >> 3] & (1 << (i & 7)))
        if not opened(up[0]) or not opened(down[0]):
            continue
        seen = {up[0]}; queue = deque(seen)
        while queue:
            i = queue.popleft()
            for j in (i-1 if i%width else -1, i+1 if i%width<width-1 else -1, i-width, i+width):
                if 0 <= j < width*height and j not in seen and opened(j):
                    seen.add(j); queue.append(j)
        if down[0] in seen:
            templates.append(dict(path=path, up=[up[0]%width,up[0]//width], down=[down[0]%width,down[0]//width]))
    assert len(templates) >= 12, "Beast route needs twelve distinct connected original layouts"
    catalog["beast_templates"] = templates
    catalog["beast_encounters"] = beast_encounters(source)
    # Self-check every source byte and every original RGBA rectangle before publishing.
    for path, row in maps.items():
        raw = zlib.decompress(base64.b64decode(row["raw"]))
        assert len(raw) == row["bytes"] and digest(raw) == row["sha256"], path
        assert len(zlib.decompress(base64.b64decode(row["walk"]))) == (row["cells"] + 7) // 8, path
    for key, row in graphics.items():
        x, y, w, h = row["rect"]
        assert pages[row["page"]].crop((x, y, x + w, y + h)).tobytes() == images[int(key)].tobytes(), key
    return catalog, pages, lib


def pack_graphics(used, lookup, furniture, lib):
    pages, graphics, images = [], {}, {}
    page = Image.new("RGBA", (PAGE, PAGE))
    x = y = row_height = 0
    for serial in sorted(used):
        entry = lookup[serial]
        art = lib.image_from_record(entry["pack"], entry["row"])
        assert art.width + 4 <= PAGE and art.height + 4 <= PAGE, serial
        if x + art.width + 4 > PAGE:
            x = 0
            y += row_height
            row_height = 0
        if y + art.height + 4 > PAGE:
            pages.append(page)
            page = Image.new("RGBA", (PAGE, PAGE))
            x = y = row_height = 0
        page.paste(art, (x + 2, y + 2))
        graphics[str(serial)] = dict(page=len(pages), rect=[x + 2, y + 2, *art.size],
            origin=[entry["x"], entry["y"]], footprint=[entry["east"], entry["south"]],
            ground=entry["ground"], family=furniture.get(serial,""), pack=entry["pack"], row=entry["row"], rgba_sha256=digest(art.tobytes()))
        if "fallback_serial" in entry:
            graphics[str(serial)]["fallback_serial"]=entry["fallback_serial"]
            graphics[str(serial)]["family"]="floor" if entry["fallback_serial"]==8155 else "room_wall"
        if art.getbbox() is None:
            graphics[str(serial)]["family"] = "void"
        if serial in (10045,10046,16468,16467):
            left, right = [], []
            for py in range(0,art.height,2):
                visible = [px for px in range(art.width) if art.getpixel((px,py))[3]>=128]
                if visible:
                    left.append([min(visible),py]);right.append([max(visible)+1,py])
            graphics[str(serial)]["solid_outline"] = left+right[::-1]
        if entry["ground"] and 12500 <= serial < 13400 and art.height > 60 and entry["y"] >= -36:
            # These walkable land cells paint their cliff and water below the cap.
            graphics[str(serial)]["shore_bank"] = True
        if 16303 <= serial <= 16332:
            # Native stone banks occupy particular edges; keep connected water edges open.
            edges = []
            for axis, side in ((0,-1),(0,1),(1,-1),(1,1)):
                blues = 0
                for step in (-.7,-.35,0,.35,.7):
                    gx,gz = (side*1.25,step) if axis==0 else (step,side*1.25)
                    px=round(-entry["x"]+(gx+gz)*32/3)
                    py=round(-entry["y"]+(gz-gx)*8)-4
                    r,g,b,a=art.getpixel((min(art.width-1,max(0,px)),min(art.height-1,max(0,py))))
                    blues += bool(a and g-r>35 and b-g>20)
                edges.append(blues<3)
            graphics[str(serial)]["channel_edges"] = edges
        images[serial] = art
        if serial in (17065,17098,17099,17100,17101,17102,17109,17110,17111,17148,17149,17150,17190):
            candidates = [(abs(px-art.width*.25)+abs(py-art.height*.6),px,py)
                          for py in range(art.height//3,art.height*4//5,2) for px in range(4,art.width//2,2)
                          if (c:=art.getpixel((px,py)))[3] == 255 and min(c[:3]) > 140 and max(c[:3])-min(c[:3]) < 45]
            assert candidates, serial
            _,cx,cy = min(candidates)
            graphics[str(serial)]["cap_pixel"] = [cx,cy]
        x += art.width + 4
        row_height = max(row_height, art.height + 4)
    pages.append(page)
    return pages, graphics, images


def solid_pages(catalog, pages):
    """Extend native edge paint into transparent areas for reconstructed solid faces."""
    output = [Image.new("RGB", page.size) for page in pages]
    for graphic in catalog["graphics"].values():
        x, y, w, h = graphic["rect"]
        art = pages[graphic["page"]].crop((x,y,x+w,y+h))
        source = art.load()
        filled = Image.new("RGB", art.size)
        pixels = filled.load()
        occupied = []
        for row in range(h):
            marks = [col for col in range(w) if source[col,row][3] and max(source[col,row][:3])>40]
            if not marks:
                continue
            occupied.append(row)
            cursor = 0
            for col in range(w):
                while cursor+1<len(marks) and abs(marks[cursor+1]-col)<abs(marks[cursor]-col):
                    cursor += 1
                pixels[col,row] = source[marks[cursor],row][:3]
        if not occupied:
            if graphic.get('family') == 'room_wall':
                output[graphic['page']].paste(art.convert('RGB'), (x, y), art.getchannel('A').point(lambda value: 255 if value else 0))
            continue
        cursor = 0
        for row in range(h):
            while cursor+1<len(occupied) and abs(occupied[cursor+1]-row)<abs(occupied[cursor]-row):
                cursor += 1
            if row not in occupied:
                filled.paste(filled.crop((0,occupied[cursor],w,occupied[cursor]+1)),(0,row))
        if graphic.get('family') == 'room_wall':
            # Dark mortar and baked wall faces are original paint, not cast-shadow gaps.
            filled.paste(art.convert('RGB'), (0, 0), art.getchannel('A').point(lambda value: 255 if value else 0))
        output[graphic["page"]].paste(filled,(x,y))
    return output


def rock_surfaces(catalog, pages):
    """Reuse native stone interiors as surface tiles; a sprite outline is not a cliff face."""
    output = []
    slot = 0
    walls = {15827,15828,15829,15833,15834,*range(17685,17699)}
    for key, graphic in catalog["graphics"].items():
        serial = int(key)
        if serial not in walls and not 12500<=serial<13400:
            continue
        x,y,w,h = graphic["rect"]
        native = pages[graphic["page"]].crop((x,y,x+w,y+h))
        pixels = native.load()
        span = min(32,w,h)
        records = []
        for top in (False,True):
            best = None
            for py in range(0,max(1,h-span+1),16):
                for px in range(0,max(1,w-span+1),16):
                    colors = [pixels[px+dx,py+dy] for dy in range(0,span,8) for dx in range(0,span,8)]
                    valid = sum(c[3]>0 and max(c[:3])>40 for c in colors)
                    snow = sum(min(c[:3])>160 for c in colors)
                    preference = -abs(py-(h*.12 if top else h*.60))*.01
                    score = valid*100+(snow if top else -snow)+preference
                    if best is None or score>best[0]:best=(score,px,py)
            _,px,py = best
            patch = native.crop((px,py,px+span,py+span)).convert("RGB").resize((128,128),Image.Resampling.NEAREST)
            if slot%256==0:output.append(Image.new("RGB",(2048,2048)))
            at=((slot%16)*128,((slot%256)//16)*128)
            output[-1].paste(patch,at);records.extend(at);slot+=1
        graphic["surfaces"]=[len(output)-1,*records]
    catalog["surface_pages"]=[f"surfaces-{i}.png" for i in range(len(output))]
    return output


def beast_castle(catalog, pages, lib):
    from build_village_building_surfaces import surface_atlas
    row = catalog["maps"]["BlueCrossgate/map/0/400.dat"]
    raw = zlib.decompress(base64.b64decode(row.get("restored_raw", row["raw"])))
    width, _, floor, objects, _ = lib.parse_map(raw)
    placed = []
    for layer, plane in enumerate((floor, objects)):
        for i, serial in enumerate(plane):
            if not (1600 <= serial <= 1692 if layer == 0 else serial == 10011):
                continue
            g = catalog["graphics"][str(serial)]
            x, z = i % width-135, i // width-333
            placed.append((layer, (x+z)*32+g["origin"][0], (z-x)*24+g["origin"][1], serial))
    assert len(placed) == 71 and sum(p[3] == 10011 for p in placed) == 1
    left = min(p[1] for p in placed); top = min(p[2] for p in placed)
    right = max(p[1]+catalog["graphics"][str(p[3])]["rect"][2] for p in placed)
    bottom = max(p[2]+catalog["graphics"][str(p[3])]["rect"][3] for p in placed)
    image = Image.new("RGBA", (right-left, bottom-top))
    for _, x, y, serial in sorted(placed):
        g = catalog["graphics"][str(serial)]; px,py,w,h = g["rect"]
        image.alpha_composite(pages[g["page"]].crop((px,py,px+w,py+h)), (x-left,y-top))
    catalog["beast_castle"] = dict(anchor=[135,333], origin=[-left,-top], size=list(image.size),
                                    rgba_sha256=digest(image.tobytes()), source_pieces=len(placed))
    patches = {
        "stone": (0,[(265,495),(277,503),(277,535),(265,527)],False,(48,64)),
        "plaster": (0,[(289,362),(297,367),(297,377),(289,372)],False,(32,48)),
        "blue_roof": (0,[(402,365),(437,389),(447,381),(412,357)],False,(96,48)),
        "floor": (0,[(113,194),(121,194),(121,202),(113,202)],False,(64,64)),
        "trim": (0,[(290,258),(294,258),(294,266),(290,266)],False,(32,64)),
        "banner": (0,[(460,363),(479,352),(479,461),(460,472)],True,(40,115)),
        "window": (0,[(201,77),(237,100),(237,178),(201,155)],True,(45,105)),
        "lower_window": (0,[(187,335),(211,351),(211,395),(187,379)],True,(45,90)),
        "buttress": (0,[(43,411),(71,429),(71,482),(43,464)],True,(48,96)),
        "buttress_relief": (0,[(111,313),(139,331),(139,380),(111,362)],True,(48,96)),
        "tower_stone": (0,[(147,192),(165,203),(165,228),(147,217)],False,(64,64)),
        "keep_frieze": (0,[(201,64),(244,92),(244,111),(201,83)],True,(112,48)),
    }
    tiles, _ = surface_atlas({0:image}, patches)
    # These wall quads already carry the source aspect ratio; fill their UV tile.
    for i, (_, (_, quad, feature, _)) in enumerate(patches.items()):
        if not feature:
            continue
        ul,ur,lr,ll = quad
        patch = image.transform((111,111), Image.Transform.QUAD, (*ul,*ll,*lr,*ur), Image.Resampling.BICUBIC)
        padded = patch.resize((128,128), Image.Resampling.NEAREST)
        padded.paste(patch,(8,8));tiles.paste(padded,(i%4*128,i//4*128))
    catalog["beast_castle"]["tiles"] = {name:[i%4*128,i//4*128] for i,name in enumerate(patches)}
    catalog["beast_castle"]["patches"] = patches
    return {"beast-castle.png":image, "beast-castle-surfaces.png":tiles}


def preview(catalog, pages, key, level=0):
    """Independent compositing from the recovered bytes, following the archived painter order."""
    from array import array
    row = catalog["maps"][key]
    raw = zlib.decompress(base64.b64decode(row["raw"]))
    width, height = row["size"]
    cells = width * height
    values = array("H")
    values.frombytes(raw[20:])
    if sys.byteorder != "little":
        values.byteswap()
    placed = []
    for layer in (0, 1):
        for i, serial in enumerate(values[layer * cells:(layer + 1) * cells]):
            if not serial or layer and serial < 1000:
                continue
            graphic = catalog["graphics"][str(serial)]
            x, y = i % width, i // width
            px = (x + y) * 32 + graphic["origin"][0]
            py = (y - x) * 24 + graphic["origin"][1]
            depth = 11 * y - 9 * x - min(graphic["footprint"]) * 10
            placed.append((0 if layer == 0 or graphic["ground"] else 1, depth, px, py, serial))
    placed.sort(key=lambda p: (p[0], p[1], p[2]))
    left = min(p[2] for p in placed)
    top = min(p[3] for p in placed)
    right = max(p[2] + catalog["graphics"][str(p[4])]["rect"][2] for p in placed)
    bottom = max(p[3] + catalog["graphics"][str(p[4])]["rect"][3] for p in placed)
    factor = 1 << level
    canvas = Image.new("RGBA", ((right - left + factor - 1) // factor, (bottom - top + factor - 1) // factor))
    art = {}
    for _, _, px, py, serial in placed:
        if serial not in art:
            g = catalog["graphics"][str(serial)]
            x, y, w, h = g["rect"]
            im = pages[g["page"]].crop((x, y, x + w, y + h))
            if level:
                im = im.resize(((w + factor - 1) // factor, (h + factor - 1) // factor), Image.Resampling.NEAREST)
            art[serial] = im
        canvas.alpha_composite(art[serial], ((px - left) // factor, (py - top) // factor))
    return canvas


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT.parent / "Magic Power")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    catalog, pages, lib = prepare(args.source.resolve())
    surfaces = rock_surfaces(catalog, pages)
    solids = solid_pages(catalog, pages)
    castle = beast_castle(catalog, pages, lib)
    catalog["solid_pages"] = [f"solid-{i}.png" for i in range(len(solids))]
    text = json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n"
    if args.check:
        assert (OUT / "catalog.json").read_text() == text, "Original map catalog differs from the source"
        for i, expected in enumerate(pages):
            with Image.open(OUT / f"atlas-{i}.png") as actual:
                assert actual.size == expected.size and actual.tobytes() == expected.tobytes(), i
    else:
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / "catalog.json").write_text(text)
        for i, page in enumerate(pages):
            page.save(OUT / f"atlas-{i}.png")
    for name, expected in castle.items():
        if args.check:
            with Image.open(OUT / name) as actual:
                assert actual.tobytes() == expected.tobytes(), name
        else:
            expected.save(OUT / name)
    for i, expected in enumerate(surfaces):
        if args.check:
            with Image.open(OUT / f"surfaces-{i}.png") as actual:
                assert actual.tobytes() == expected.tobytes(), ("surfaces",i)
        else:
            expected.save(OUT / f"surfaces-{i}.png")
    for i, expected in enumerate(solids):
        if args.check:
            with Image.open(OUT / f"solid-{i}.png") as actual:
                assert actual.tobytes() == expected.tobytes(), ("solid",i)
        else:
            expected.save(OUT / f"solid-{i}.png")
    REPORT.mkdir(parents=True, exist_ok=True)
    counts = {g: sum(m["group"] == g for m in catalog["maps"].values()) for g in sorted({m["group"] for m in catalog["maps"].values()})}
    comparisons = []
    samples = ["BlueCrossgate/map/0/%d.dat" % i for i in (24009, 24018, 24069, 24074, 4300, 4400, 4410, 15522, 15523, 4000, 15000, 15001, 15002, 16510, 16511, 16512, 16513, 16514, 16515)]
    samples += [next(k for k, m in catalog["maps"].items() if m["group"] == "snow" and "/map/1/" in k)]
    for key in samples:
        with lib.connection() as db:
            ident = db.execute("SELECT id FROM files WHERE path=?", (key,)).fetchone()[0]
        plan = lib.map_plan(ident)
        assert not plan["missingSerials"] and not plan["unavailableGraphics"], key
        level = max(0, (max(plan["pixelWidth"], plan["pixelHeight"]) - 1).bit_length() - 11)
        recovered = preview(catalog, pages, key, level)
        original = lib.render_map(ident, 0, level, 0, 0, recovered.width, recovered.height)
        assert recovered.tobytes() == original.tobytes(), key
        name = key.removeprefix("BlueCrossgate/map/").replace("/", "-").removesuffix(".dat") + ".png"
        recovered.save(REPORT / name)
        comparisons.append(dict(source=key, pixel_equal=True, size=recovered.size, level=level, image=name))
    report = dict(maps=len(catalog["maps"]), groups=counts, graphics=len(catalog["graphics"]), pages=len(pages),
                  checked_from_original=True, source_pixel_comparisons=comparisons,
                  limits=["Original client bytes are preserved; Jenova/Beast/Tina uncached cells use the pinned, overlap-checked reference.",
                          "Tina food shop 4206, night teleport room 4232 and crystal result rooms 32193/32194 are reference-only layouts without client snapshots.",
                          "Beast layouts retain client bytes; their palette is shared with another dungeon and does not establish original floor order.",
                          "Random snow cache identities do not establish original floor order.",
                          "Native fixed warp endpoints are retained; retired NPC gameplay records remain as excluded reference material. Missing graphics in 32181/32183/32193/32194 use marked local scenery substitutes without altering source map planes."])
    (REPORT / "recovery.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "source_pixel_comparisons"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
