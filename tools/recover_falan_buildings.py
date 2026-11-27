"""Recover original city house paint and bind only unchanged saved house markers."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
from PIL import Image, ImageChops, ImageDraw
from build_village_building_surfaces import surface_atlas
from build_freyja_destinations import load_map

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/maps/falan"
PATCHES = {
    "villa_stone": (10312, [(227,324),(235,324),(235,332),(227,332)], False, (64,64)),
    "10300_roof": (10300, [(110,118),(140,136),(153,125),(123,107)], False, (96,64)),
    "10300_emblem": (10300, [(55,195),(143,195),(143,294),(55,294)], True, (95,106)),
    "10300_scroll": (10300, [(247,176),(312,214),(312,292),(247,254)], True, (90,108)),
    "10300_window": (10300, [(157,324),(178,336),(178,375),(157,363)], True, (45,90)),
    "special_brick": (10300, [(204,410),(212,410),(212,418),(204,418)], False, (64,64)),
    "10606_window": (10606, [(66,322),(91,336),(91,382),(66,368)], True, (50,90)),
    "10606_gate": (10606, [(297,326),(342,299),(342,399),(297,426)], True, (50,110)),
    "10311_window": (10311, [(310,239),(337,223),(337,261),(310,277)], True, (50,90)),
    "10311_cloth": ("10311_blanket", [(240,139),(283,168),(283,217),(240,188)], True, (85,100)),
    "10312_window": (10312, [(39,190),(62,204),(62,254),(39,240)], True, (45,90)),
    "10312_vines": (10312, [(270,393),(291,405),(291,465),(270,453)], True, (35,100)),
    "10313_window": (10313, [(97,388),(123,404),(123,451),(97,435)], True, (45,90)),
    "10313_emblem": ("10313_clock", [(294,405),(330,383),(330,431),(294,453)], True, (75,85)),
    "10314_window": (10314, [(235,448),(257,435),(257,476),(235,489)], True, (50,90)),

    "magic_stone": (10075, [(52,320),(60,320),(60,328),(52,328)], False, (64,64)),
    "magic_roof": (10075, [(200,200),(216,200),(216,216),(200,216)], False, (96,64)),
    "magic_sign": ("magic_sign", [(101,229),(150,260),(150,302),(101,271)], True, (90,85)),
    "magic_window": (10075, [(10,355),(36,371),(36,390),(10,374)], True, (80,60)),
    "smith_sign": (10301, [(220,270),(272,239),(272,275),(220,306)], True, (110,65)),
    "workshop_trade_sign": (10301, [(332,184),(385,152),(385,186),(332,218)], True, (110,65)),
    "workshop_window": (10301, [(50,284),(72,298),(72,328),(50,314)], True, (40,95)),
    "plaster": (10605, [(44,245),(51,245),(51,255),(44,255)], False, (64,64)),
    "blue_roof": (10605, [(93,105),(137,135),(155,112),(111,82)], False, (96,64)),
    "timber": (10605, [(224,290),(230,290),(230,304),(224,304)], False, (64,64)),
    "trim": (10605, [(66,108),(70,108),(70,118),(66,118)], False, (32,64)),
    "stone": (10605, [(165,330),(173,330),(173,340),(165,340)], False, (64,64)),
    "window": (10081, [(84,268),(102,280),(102,330),(84,318)], True, (64,100)),
    "door": (10605, [(204,277),(250,246),(250,313),(204,344)], True, (70,104)),
    "dormer_window": (10605, [(27,111),(49,126),(49,148),(27,133)], True, (64,76)),
    "10609_window": (10609, [(223,218),(230,214),(230,252),(223,256)], True, (24,108)),
    "10605_window": (10605, [(42,186),(50,191),(50,228),(42,223)], True, (24,108)),
    "10003_window": (10003, [(47,216),(72,231),(72,278),(47,263)], True, (54,96)),
    "10003_door": (10003, [(100,260),(120,272),(120,330),(100,318)], True, (40,104)),
    "10003_wood": (10003, [(300,255),(306,255),(306,261),(300,261)], False, (64,64)),
    "10003_base": (10003, [(60,285),(70,285),(70,295),(60,295)], False, (64,64)),
    "10003_bay_window": (10003, [(257,293),(280,279),(280,329),(257,343)], True, (50,100)),
    "10006_roof": (10006, [(85,125),(109,125),(109,149),(85,149)], False, (96,64)),
    "10007_roof": (10007, [(85,125),(109,125),(109,149),(85,149)], False, (96,64)),
    "10081_grille": (10081, [(62,251),(157,306),(157,368),(62,313)], True, (110,72)),
    "10081_bay": (10081, [(235,272),(265,255),(265,323),(235,340)], True, (50,100)),
    "10308_flowers": (10308, [(80,249),(132,279),(132,317),(80,287)], True, (110,65)),
    "architecture_blue_roof": (10083, [(244,172),(304,208),(334,178),(274,142)], False, (96,64)),
    "architecture_green_roof": (10006, [(124,230),(184,266),(214,236),(154,200)], False, (96,64)),
    "architecture_red_roof": (10007, [(124,230),(184,266),(214,236),(154,200)], False, (96,64)),
    "shop_medallion": ("shop_medallion", [(73,150),(114,175),(114,226),(73,201)], True, (64,80)),
    "shop_shield": ("shop_shield", [(235,156),(280,140),(280,211),(235,227)], True, (64,96)),
    "10003_gable_rosette": ("10003_gable_rosette", [(243,170),(275,151),(275,211),(243,230)], True, (64,112)),
    "native_bar_sign": (10049, [(53,159),(110,196),(110,228),(53,191)], True, (112,64)),
    "native_baker_sign": ("native_baker_sign", [(45,196),(103,232),(103,263),(45,227)], True, (112,64)),
    "native_weapon_sign": ("native_weapon_sign", [(235,204),(283,174),(283,208),(235,238)], True, (112,64)),
    "native_inn_sign": ("native_inn_sign", [(247,174),(299,141),(299,170),(247,203)], True, (112,64)),
    "native_house_sign": (10003, [(21,216),(37,225),(37,254),(21,245)], True, (48,96)),
    "magic_side_window": (10075, [(301,349),(329,332),(329,391),(301,408)], True, (48,104)),
    "10311_stripes": ("10311_stripes", [(125,123),(151,139),(151,183),(125,167)], True, (60,100)),
    "10311_shirt": ("10311_shirt", [(173,89),(207,109),(207,163),(173,143)], True, (72,100)),
    "10311_socks": ("10311_socks", [(152,140),(174,153),(174,185),(152,172)], True, (72,80)),
    "10311_trousers": ("10311_trousers", [(185,164),(219,184),(219,238),(185,218)], True, (72,100)),
}
FEATURE_MASKS = {
    "10311_blanket": (10311, [(241,146),(248,150),(256,151),(265,156),(276,166),(281,175),(280,211),(273,208),(263,200),(252,190),(242,184)]),
    "10311_stripes": (10311, [(127,126),(149,138),(149,177),(128,166)]),
    "10311_shirt": (10311, [(176,98),(184,102),(190,100),(202,109),(204,121),(198,123),(197,150),(179,144),(180,118),(173,116)]),
    "10311_socks": (10311, [(154,143),(160,146),(163,152),(163,162),(160,163),(160,168),(156,173),(152,172),(152,166),(154,156)]),
    "10311_trousers": (10311, [(187,175),(205,184),(216,183),(218,190),(218,220),(209,226),(205,218),(204,201),(199,224),(190,219),(189,197),(186,185)]),
    "10313_clock": (10313, [(318,398),(324,399),(328,404),(328,411),(325,420),(319,428),(311,433),(304,433),(299,428),(298,420),(302,411),(310,403)]),
    "magic_sign": (10075, [(103,233),(109,230),(120,233),(132,241),(144,253),(150,263),(149,300),(143,303),(102,276)]),
    "native_baker_sign": (10005, [(42,196),(52,196),(63,205),(90,220),(105,232),(110,245),(105,259),(96,261),(74,247),(53,234),(42,225)]),
    "native_inn_sign": (10080, [(247,176),(250,165),(263,161),(267,154),(281,151),(286,144),(298,142),(303,146),(301,160),(298,171),(282,179),(278,188),(264,192),(258,202),(249,203),(244,197)]),
    "10003_gable_rosette": (10003, [(244,204),(246,187),(251,174),(259,164),(267,160),(274,166),(274,184),(268,202),(259,216),(250,224),(244,219)]),
    "native_weapon_sign": (10078, [(235,204),(283,174),(279,201),(270,215),(242,235)]),
    "shop_medallion": (10079, [(83,159),(93,165),(103,175),(109,188),(112,199),(110,209),
                               (104,214),(96,211),(87,203),(80,192),(76,178),(77,166)]),
    "shop_shield": (10079, [(237,164),(244,168),(251,169),(260,166),(270,159),(276,150),
                            (275,186),(272,201),(265,208),(247,205),(242,194),(239,181)]),
}
FAMILIES = {10009:3,10049:15,10050:15,10309:16,10605:2,10609:12,10005:13,10080:14,
    **dict.fromkeys((10003,10076,10077,10304,10306),3),
    **dict.fromkeys((10007,10078),4), **dict.fromkeys((10006,10079),5),
    **{serial:i+6 for i,serial in enumerate((10081,10082,10083,10084,10305,10308))}}
HOUSES = set(FAMILIES)
CIVIC = {(-52,2),(-28,36),(-28,-34),(8,-14),(-12,-44),(1,-35),(-39,40),(-42,-23),(14,18)}
CENTERED = {(-46,-33),(-42,-26),(-28,42),(-14,36),(-7,23),(-6,-22),(6,-24),(18,-21),(24,22)}


def prepare(source):
    sys.path.insert(0, str(source / "tools"))
    import cg_library as library
    lookup = library.serial_index()
    images, provenance = {}, {}
    for serial in {p[0] for p in PATCHES.values()}:
        native = FEATURE_MASKS[serial][0] if serial in FEATURE_MASKS else serial
        entry = lookup[native]
        image = library.image_from_record(entry["pack"], entry["row"])
        provenance[native] = {"pack": entry["pack"], "row": entry["row"], "rgba_sha256": hashlib.sha256(image.tobytes()).hexdigest()}
        if serial in FEATURE_MASKS:
            mask = Image.new('L', image.size)
            ImageDraw.Draw(mask).polygon(FEATURE_MASKS[serial][1], fill=255)
            image = image.copy()
            image.putalpha(ImageChops.multiply(image.getchannel('A'), mask))
            if serial in ("10003_gable_rosette", "native_baker_sign"):
                # Keep the warm carving/plaque, excluding the slate that occludes its edge.
                image.putdata([(r,g,b,0 if b>r*.88 and b>g*.93 else a) for r,g,b,a in image.getdata()])
            if serial == "native_inn_sign":
                # Its pale grey face is part of the plaque, not blue roof slate.
                image.putdata([(r,g,b,0 if b>r*1.25 and b>g*1.10 else a) for r,g,b,a in image.getdata()])
                assert image.getpixel((270,170))[3] == 255
            if serial == "10003_gable_rosette":
                # Isolated pixels belong to the neighbouring timber, not the carved medallion.
                alpha=image.getchannel('A');todo=set((x,y) for y in range(image.height) for x in range(image.width) if alpha.getpixel((x,y))>40)
                groups=[]
                while todo:
                    group={todo.pop()};pending=list(group)
                    for x,y in pending:
                        for point in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                            if point in todo:todo.remove(point);group.add(point);pending.append(point)
                    groups.append(group)
                keep=max(groups,key=len);assert len(keep)>100
                alpha.putdata([alpha.getpixel((x,y)) if (x,y) in keep else 0 for y in range(image.height) for x in range(image.width)])
                image.putalpha(alpha)
        images[serial] = image
    atlas, rows = surface_atlas(images, PATCHES)
    rows[1] = "## Generated by tools/recover_falan_buildings.py using shared native surface recovery."
    rows += ["}", "const CLOTH_TOP={"]
    for index,feature in enumerate(PATCHES):
        if feature not in ('10311_cloth','10311_stripes','10311_shirt','10311_socks','10311_trousers'):continue
        x=index%(atlas.width//128)*128;y=index//(atlas.width//128)*128
        top=atlas.crop((x,y,x+128,y+128)).getchannel('A').getbbox()[1]/128
        rows.append(f' "{feature}":{top:.9f},')
    rows += ["}", "const LEGACY={"]
    width, _, _, objects, _ = load_map(library, 1000)
    buildings = []
    for i, serial in enumerate(objects):
        entry = lookup.get(serial, {})
        if entry.get("w",0) <= 260 or entry.get("h",0) <= 300 or min(entry.get("east",0),entry.get("south",0)) < 3: continue
        x = 3*(i//width-134)-1.5*(entry["south"]-1)
        z = 3*(153-i%width)-1.5*(entry["east"]-1)
        buildings.append((serial,x,z))
    layout = json.loads((ROOT / "tests/forest-shrine/reference/maps/forest_falan_city.json").read_text())
    bindings = []
    unresolved = []
    composites = []
    retired = []
    for prop in layout["props"]:
        if prop["kind"] not in ("falan_townhouse","falan_shop") or (prop["x"],prop["z"]) in CIVIC: continue
        serial,x,z = min(buildings, key=lambda p:(p[1]-prop["x"]*6)**2+(p[2]-prop["z"]*6)**2)
        distance = math.hypot(x-prop["x"]*6,z-prop["z"]*6)
        if serial not in HOUSES or distance > 15:
            record={"marker":prop,"reference_graphic":serial,"source_center":[x,z],"source_footprint":[lookup[serial]["south"]*3,lookup[serial]["east"]*3],"distance":distance}
            if (prop["x"],prop["z"])==(-49,-16):
                assert serial==10077 and distance>15
                record["reason"]="Native city has a garden/path gap here; no additional source house."
                retired.append(record)
            elif serial in {10300,10301,10075,10606,10311,10312,10313,10314}:composites.append(record)
            else:unresolved.append(record)
            continue
        family = FAMILIES[serial]
        rows.append(f' Vector2i({prop["x"]},{prop["z"]}):["{prop["kind"]}",{prop["rotation"]},{prop["scale"]},{family},{serial}],')
        bindings.append({"marker":prop,"reference_graphic":serial,"runtime_family":family,"source_center":[x,z],"source_footprint":[lookup[serial]["south"]*3,lookup[serial]["east"]*3],"distance":distance})
    assert len(bindings) > 40
    rows += ["}", "const SOURCE_CENTERS={"]
    for record in bindings:
        prop = record["marker"]
        if (prop["x"],prop["z"]) in CENTERED:
            x,z = record["source_center"]
            rows.append(f' Vector2i({prop["x"]},{prop["z"]}):Vector2({x:g},{z:g}),')
    rows.append("}")
    return atlas, "\n".join(rows)+"\n", {"graphics":provenance,"masks":{"10300_emblem":"Native face ellipse plus native gold/purple ornament pixels; original colors retained","10300_scroll":"Pale source carving strokes with transparent background","10312_vines":"Native green foliage pixels with transparent masonry background"},"patches":PATCHES,"bindings":bindings,"unresolved":unresolved,"composites":composites,"retired":retired,
        "centered_markers":sorted(CENTERED),"feature_masks":FEATURE_MASKS,
        "method":"Shared rectified native paint and protected legacy bindings. city_architecture owns current source-contour ordinary houses; unseen surfaces remain reconstructed."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT.parent / "Magic Power")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    atlas, data, provenance = prepare(args.source.resolve())
    if args.check:
        with Image.open(OUT / "city_building_surfaces.png") as actual: assert actual.tobytes() == atlas.tobytes()
        assert (OUT / "city_building_surfaces.gd").read_text() == data
        assert json.loads((OUT / "city_building_surfaces.json").read_text()) == json.loads(json.dumps(provenance))
        print("PASS: original city house paint and protected marker bindings reproduce exactly")
    else:
        atlas.save(OUT / "city_building_surfaces.png", optimize=True)
        (OUT / "city_building_surfaces.gd").write_text(data)
        (OUT / "city_building_surfaces.json").write_text(json.dumps(provenance,indent=2)+"\n")
        print("Recovered",len(provenance["bindings"]),"city house references and",len(PATCHES),"native surface patches")


if __name__ == "__main__": main()
