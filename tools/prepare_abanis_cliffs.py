"""Measure western cliff contours and shallow relief from unchanged client graphics."""
import argparse
import base64
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import tempfile
import zlib

from PIL import Image, ImageDraw, ImageFilter, ImageOps
from build_coastal_villages import atlas as pack_atlas
from recover_falan_architecture import opaque_paint
from recover_falan_forts import native_stone

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "assets/maps/original_crossgate"
OUTPUT = FOLDER / "cliff-profiles.json"
PAINT = FOLDER / "cliff-paint.png"
MAPS = (400, 402, 14000, 14001, 14002)


def edge_paint(image,background=None,snow=None):
    """Keep enclosed dark crevices; extend only transparent/border shadow regions."""
    width,height = image.size
    void = Image.new("L",image.size)
    for y in range(height):
        for x in range(width):
            r,g,b,a = image.getpixel((x,y))
            if a < 128 or max(r,g,b) <= 45 and max(r,g,b)-min(r,g,b) < 3:void.putpixel((x,y),255)
    for x,y in [(x,y) for x in range(width) for y in (0,height-1)]+[(x,y) for y in range(height) for x in (0,width-1)]:
        if void.getpixel((x,y)) == 255:ImageDraw.floodfill(void,(x,y),128)
    masked = image.copy()
    for y in range(height):
        for x in range(width):
            if void.getpixel((x,y)) == 128:
                masked.putpixel((x,y),(*masked.getpixel((x,y))[:3],0))
    result = opaque_paint(masked)
    if background is not None:
        for y in range(height):
            tile = snow if snow is not None and y < height*.4 else background
            for x in range(width):
                if masked.getpixel((x,y))[3] < 128:
                    result.putpixel((x,y),tile.getpixel((x%tile.width,y%tile.height)))
    return result


def prepare():
    catalog = json.loads((FOLDER / "catalog.json").read_text())
    serials = set()
    for ident in MAPS:
        row = catalog["maps"][f"BlueCrossgate/map/0/{ident}.dat"]
        width, height = row["size"]
        raw = zlib.decompress(base64.b64decode(row.get("restored_raw", row["raw"])))
        objects = struct.unpack_from(f"<{width*height}H", raw, 20+width*height*2)
        serials.update(s for s in objects if (12720 <= s <= 12803 or 13360 <= s <= 13395)
                       and s not in (12834, 12839, 13268, 13269, 13270, 13271)
                       and not catalog["graphics"][str(s)]["ground"])
    pages = {};paintings = {}
    def patch(serial,box):
        g = catalog["graphics"][str(serial)]
        if g["page"] not in pages:pages[g["page"]] = Image.open(FOLDER / catalog["pages"][g["page"]]).convert("RGBA")
        x,y,w,h = g["rect"]
        art = pages[g["page"]].crop((x,y,x+w,y+h)).crop(box)
        native = native_stone(opaque_paint(art),.75)
        tile = Image.new("RGBA",(native.width*2,native.height*2))
        tile.paste(native,(0,0));tile.paste(ImageOps.mirror(native),(native.width,0))
        tile.paste(ImageOps.flip(tile.crop((0,0,tile.width,native.height))),(0,native.height))
        return tile
    rock = patch(12775,(80,160,150,290))
    cave = patch(13360,(20,55,50,150))
    snow = patch(12802,(60,140,140,280))
    profiles = {};coverage_ratios = {}
    paint_serials = serials | {12834,12839}
    for serial in sorted(paint_serials):
        g = catalog["graphics"][str(serial)]
        page = g["page"]
        if page not in pages:
            pages[page] = Image.open(FOLDER / catalog["pages"][page]).convert("RGBA")
        x, y, width, height = g["rect"]
        image = pages[page].crop((x, y, x+width, y+height))
        assert hashlib.sha256(image.tobytes()).hexdigest() == g["rgba_sha256"]
        background = cave if serial >= 13360 else snow if 12780 <= serial <= 12834 else rock
        paintings[serial] = edge_paint(image,background,snow if 12756 <= serial <= 12839 else None)
        if serial not in serials:continue
        pixels = image.load()
        top = [];bottom = [];coverage = []
        for u in range(width):
            marks = [v for v in range(height) if pixels[u, v][3] >= 128 and max(pixels[u, v][:3]) > 45]
            top.append(marks[0] if marks else None)
            bottom.append(marks[-1] if marks else height-1);coverage.append(len(marks))
        visible = [u for u, value in enumerate(top) if value is not None]
        coverage_ratios[serial] = sum(coverage)/(width*height)
        assert visible, serial
        for u, value in enumerate(top):
            if value is None:
                top[u] = top[min(visible, key=lambda candidate: abs(candidate-u))]
        # Remove isolated one-pixel flecks without replacing the measured silhouette.
        top = [sorted(top[max(0,u-2):min(width,u+3)])[len(top[max(0,u-2):min(width,u+3)])//2] for u in range(width)]
        fx, fz = g["footprint"]
        extent = (fx*3.0, fz*3.0)
        origin = (-1.5, 1.5-extent[1])
        count = 6 if max(fx, fz) > 1 else 3
        relief = image.convert("L").filter(ImageFilter.GaussianBlur(3))

        def sample(px, py):
            return max(0, min(width-1, round(px))), max(0, min(height-1, round(py)))

        roof = []
        for iz in range(count+1):
            for ix in range(count+1):
                px = origin[0]+extent[0]*ix/count
                pz = origin[1]+extent[1]*iz/count
                u, _ = sample((px+pz)*32/3-g["origin"][0], 0)
                roof.append(round(max(.12, ((pz-px)*8-top[u]-g["origin"][1])*.045), 4))
        span = fx+fz
        ground_span = (span-2)*12+span*12*min(1, width/(span*32))
        native_height = max(.15, (-g["origin"][1]-ground_span)*.045)
        scale = native_height/max(roof)
        pixel_height = .045*scale
        center = (origin[0]+extent[0]/2, origin[1]+extent[1]/2)
        vertices = [];uv_pixels = []
        ceilings = []
        for side in range(16):
            angle = side*math.tau/16
            px, pz = center[0]+math.cos(angle)*extent[0]/2, center[1]+math.sin(angle)*extent[1]/2
            u, _ = sample((px+pz)*32/3-g["origin"][0], 0)
            ceilings.append(min(native_height, max(.12, ((pz-px)*8-top[u]-g["origin"][1])*.045)*scale))
        ceilings = [sorted((ceilings[(i-1)%16],ceilings[i],ceilings[(i+1)%16]))[1] for i in range(16)]
        for level in range(7):
            for side in range(16):
                angle = side*math.tau/16
                dx, dz = math.cos(angle)*extent[0]/2, math.sin(angle)*extent[1]/2
                px, pz = center[0]+dx, center[1]+dz
                u, _ = sample((px+pz)*32/3-g["origin"][0], 0)
                # A one-view silhouette must not turn an unseen cap into a crater below its rim.
                ceiling = max(native_height*.92,ceilings[side])
                py = ceiling*(level/6 if level < 6 else .94)
                radius = .4
                for step in range(20, 5, -1):
                    candidate = step/20
                    px, pz = center[0]+dx*candidate, center[1]+dz*candidate
                    uu = (px+pz)*32/3-g["origin"][0]
                    vv = (pz-px)*8-py/pixel_height-g["origin"][1]
                    u, v = sample(uu, vv)
                    if 0 <= uu < width and 0 <= vv < height and pixels[u,v][3] >= 128 and max(pixels[u,v][:3]) > 45:
                        radius = candidate
                        if level not in (0,6):
                            radius = max(.3, min(1, radius+(relief.getpixel((u,v))/255-.5)*.04))
                        break
                vertices.append([round(center[0]+dx*radius,4), round(py,4), round(center[1]+dz*radius,4)])
                # Rectify native columns around the solid instead of projecting a grazing face to one pixel column.
                angle = angle if math.pi/4 <= angle <= 5*math.pi/4 else math.pi/2-angle if angle < math.pi/4 else 5*math.pi/2-angle
                uu = .5+(width-1)*(1-(angle-math.pi/4)/math.pi)
                column = min(width-1,max(0,round(uu)))
                lo,hi = (top[column],bottom[column]) if coverage[column] > height*.25 else (0,height-1)
                uv_pixels.append([round(uu,4),round(.5+hi+(lo-hi)*level/6,4)])
        profiles[str(serial)] = dict(sides=16, levels=7, vertices=vertices,
                                    crown=[center[0],round(native_height,4),center[1]],
                                    uv_pixels=uv_pixels,crown_uv=[width/2,.5+top[width//2]],bottom_uv=[width/2,height-.5],
                                    columns=[[top[u],bottom[u]] if coverage[u]>height*.25 else [0,height-1] for u in range(width)],
                                    pixel_height=pixel_height, height=native_height, rgba_sha256=g["rgba_sha256"])
    for serial in serials:
        base = 13360 if serial >= 13360 else 12720
        family = base+(serial-base)//12*12
        profiles[str(serial)]["paint_source"] = family if coverage_ratios[serial] < .2 else serial
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(ROOT.parent / "Magic Power/tools"))
    import cg_library as library
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "paint.png"
        placements = pack_atlas(library, library.serial_index(), paint_serials, path, 2048)
        with Image.open(path) as packed:
            paint = Image.new("RGBA", (packed.width,packed.height+132))
            cap_y = packed.height+2
        entrances = {}
        for serial, box in placements.items():
            paint.paste(paintings[serial],box[:2])
            if str(serial) in profiles:profiles[str(serial)]["paint_rect"] = list(box)
            else:entrances[str(serial)] = list(box)
        caps = {}
        for i,(name,tile) in enumerate((("rock",rock),("snow",snow),("cave",cave))):
            at = (2+i*132,cap_y)
            paint.paste(tile.resize((128,128),Image.Resampling.BICUBIC),at)
            caps[name] = [*at,128,128]
    return dict(schema=1, source_maps=list(MAPS),entrance_paint=entrances,cap_paint=caps,paint_rgba_sha256=hashlib.sha256(paint.tobytes()).hexdigest(),
                method="Native visible upper contours; shallow luminance relief. Footprints and cell anchors unchanged. Hidden volume is reconstructed.",
                profiles=profiles),paint


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data, paint = prepare()
    if args.check:
        assert json.loads(OUTPUT.read_text()) == data, "Stale cliff profiles"
        assert Image.open(PAINT).convert("RGBA").tobytes() == paint.tobytes(), "Stale cliff paint"
    else:
        OUTPUT.write_text(json.dumps(data, separators=(",", ":"))+"\n")
        paint.save(PAINT)
    print(f"PASS: {len(data['profiles'])} original cliff profiles and source hashes")


if __name__ == "__main__":
    main()
