"""Prepare Shin's native sword-run grip with Red Lightning's original blade/aura."""
import json
import math
from pathlib import Path
from shutil import copyfile
from tempfile import TemporaryDirectory

from PIL import Image, ImageChops, ImageDraw, ImageFilter

from recover_crossgate_kazi import pack_frames
from prepare_crossgate_kazi_attack import packed_frame

ROOT = Path(__file__).resolve().parents[1] / "assets/characters/crossgate/shin"
SIZE = (256, 224)
ORIGIN = (128, 160)
# Search bands traced on 100193's native white sword; actual pixels determine each axis.
RUN_BLADES = [((148,119),(162,113)), ((150,132),(184,133)),
              ((145,140),(177,157)), ((120,141),(132,166)),
              ((104,133),(88,158)), ((107,120),(74,137)),
              ((108,114),(87,115)), None]
WALK_BLADE = ((110,137),(141,156))
# Direction 4 supplies a complete visible Red Lightning blade, without hidden gaps.
SWORD_OUTLINE = [(99,121),(120,121),(174,160),(177,179),(154,179),(103,150)]

# Original walking sword/glow bounds; include the hilt bloom during replacement.
BLADES = [
 [(45,94),(140,94),(148,139),(89,140)],
 [(133,109),(159,109),(159,160),(133,160)],
 [(132,92),(211,92),(211,145),(131,151)],
 [(132,105),(219,105),(219,149),(132,149)],
 SWORD_OUTLINE,
 [(89,105),(123,105),(124,177),(89,177)],
 [(43,179),(87,107),(122,114),(81,188)],
 [(36,103),(127,103),(127,151),(36,151)],
]

def canvases(folder, manifest, stance, action, direction):
    pages = [Image.open(folder / f"atlas-{i}.png").convert("RGBA") for i in range(manifest["pages"])]
    result = []
    for page, x, y, w, h, ox, oy in stance["clips"][f"{action}:{direction}"]["frames"]:
        image = Image.new("RGBA", SIZE)
        image.alpha_composite(pages[page].crop((x, y, x + w, y + h)), (ORIGIN[0] + ox, ORIGIN[1] + oy))
        result.append(image)
    for page in pages:
        page.close()
    return result


def blade_axis(image, bare, hint):
    start, end = hint
    vx, vy = end[0]-start[0], end[1]-start[1]
    length = math.hypot(vx, vy)
    points = []
    mask = Image.new("L", SIZE)
    for y in range(max(0,min(start[1],end[1])-8), min(SIZE[1],max(start[1],end[1])+9)):
        for x in range(max(0,min(start[0],end[0])-8), min(SIZE[0],max(start[0],end[0])+9)):
            r,g,b,a = image.getpixel((x,y))
            along = ((x-start[0])*vx+(y-start[1])*vy)/length
            across = abs((x-start[0])*vy-(y-start[1])*vx)/length
            if a and (r,g,b,a)!=bare.getpixel((x,y)) and min(r,g,b)>80 and max(r,g,b)-min(r,g,b)<42 and -4<along<length+6 and across<7:
                points.append((x,y));mask.putpixel((x,y),255)
    assert len(points)>=8, (hint, points)
    cx = sum(p[0] for p in points)/len(points)
    cy = sum(p[1] for p in points)/len(points)
    xx = sum((x-cx)**2 for x,y in points)
    yy = sum((y-cy)**2 for x,y in points)
    xy = sum((x-cx)*(y-cy) for x,y in points)
    angle = .5*math.atan2(2*xy,xx-yy)
    ux,uy = math.cos(angle),math.sin(angle)
    if ux*vx+uy*vy<0:ux,uy=-ux,-uy
    projected = [(x-cx)*ux+(y-cy)*uy for x,y in points]
    near,far = min(projected),max(projected)
    assert far-near>7
    return ((cx+near*ux,cy+near*uy), (cx+far*ux,cy+far*uy), len(points)/(far-near)),mask


def move_blade(image, source, target, size=SIZE):
    sa,sb,sw = source;ta,tb,tw = target
    sx,sy = sb[0]-sa[0],sb[1]-sa[1]
    tx,ty = tb[0]-ta[0],tb[1]-ta[1]
    sl,tl = math.hypot(sx,sy),math.hypot(tx,ty)
    su,sv = sx/sl,sy/sl;tu,tv = tx/tl,ty/tl
    along,across = sl/tl,sw/tw
    a = along*su*tu+across*sv*tv
    b = along*su*tv-across*sv*tu
    c = along*sv*tu-across*su*tv
    d = along*sv*tv+across*su*tu
    return image.transform(size,Image.Transform.AFFINE,
                           (a,b,sa[0]-a*ta[0]-b*ta[1],c,d,sa[1]-c*ta[0]-d*ta[1]),
                           resample=Image.Resampling.NEAREST)


def running_frame(original, body, bare, walks, direction, blade, source_axis, target_axis, blade_mask):
    old_body = Image.new("L", SIZE)
    for walk in walks:old_body=ImageChops.lighter(old_body,walk.getchannel("A"))
    old_body=ImageChops.offset(old_body.filter(ImageFilter.MaxFilter(13)),0,1)
    # Remove the walking blade as well as the old body; outer lightning stays fixed.
    old_blade=Image.new("L",SIZE)
    ImageDraw.Draw(old_blade).polygon(BLADES[direction],fill=255)
    old_body=ImageChops.lighter(old_body,old_blade)
    aura=original.copy();aura.putalpha(ImageChops.subtract(aura.getchannel("A"),old_body))
    clean=body.copy()
    if target_axis is not None:
        cut=blade_mask.filter(ImageFilter.MaxFilter(3))
        for y in range(SIZE[1]):
            for x in range(SIZE[0]):
                pixel=body.getpixel((x,y))
                if max(pixel[:3])>=80 or pixel==bare.getpixel((x,y)):cut.putpixel((x,y),0)
        clean.putalpha(ImageChops.subtract(clean.getchannel("A"),cut))
        shifted=((target_axis[0][0],target_axis[0][1]+1),(target_axis[1][0],target_axis[1][1]+1),target_axis[2])
        aura=Image.alpha_composite(aura,move_blade(blade,source_axis,shifted))
    # Native hand/body pixels occlude the blade, including the hidden west-facing carry.
    return Image.alpha_composite(aura,ImageChops.offset(clean,0,1))


def prepare(folder=ROOT / "118993"):
    path = folder / "motions.json"
    manifest = json.loads(path.read_text())
    donor = json.loads((ROOT / "100181/motions.json").read_text())
    sword = next(s for s in donor["weapons"] if s["weapon"] == "sword")
    reference = json.loads((ROOT / "100193/motions.json").read_text())
    white_sword = next(s for s in reference["weapons"] if s["weapon"] == "sword")
    red_sources = canvases(folder, manifest, {"clips": manifest.get("original_run",manifest["clips"])}, 3, 4)
    white_walks = canvases(ROOT / "100193", reference, white_sword, 1, 4)
    bare_walks = canvases(ROOT / "100193", reference, reference, 1, 4)
    blade_art = Image.new("L",SIZE)
    ImageDraw.Draw(blade_art).polygon(SWORD_OUTLINE,fill=255)
    blades=[];source_axes=[]
    for image,white,bare in zip(red_sources,white_walks,bare_walks):
        art=image.copy();art.putalpha(ImageChops.multiply(art.getchannel("A"),blade_art));blades.append(art)
        axis,_=blade_axis(white,bare,WALK_BLADE)
        source_axes.append(((axis[0][0],axis[0][1]+1),(axis[1][0],axis[1][1]+1),axis[2]))
    original = manifest.setdefault("original_run", {f"3:{d}": manifest["clips"][f"3:{d}"] for d in range(8)})
    base_cast_pages = manifest.get("run_reuse", {}).get("cast_pages", manifest["cast_pages"])
    unique, clips = {}, {}
    for direction in range(8):
        sources = canvases(folder, manifest, {"clips": original}, 3, direction)
        walks = canvases(ROOT / "100181", donor, sword, 1, direction)
        strides = canvases(ROOT / "100181", donor, sword, 3, direction)
        bare = canvases(ROOT / "100181", donor, donor, 3, direction)
        references = canvases(ROOT / "100193", reference, white_sword, 3, direction)
        bare_references = canvases(ROOT / "100193", reference, reference, 3, direction)
        axes = [blade_axis(image,bare_image,RUN_BLADES[direction]) if RUN_BLADES[direction] else (None,None) for image,bare_image in zip(references,bare_references)]
        frames = [packed_frame(running_frame(sources[i * len(sources) // len(strides)], stride, bare[i], walks, direction,
                                                        blades[i],source_axes[i],*axes[i]),
                               -ORIGIN[0], -ORIGIN[1], unique) for i, stride in enumerate(strides)]
        assert all(frames)
        clips[f"3:{direction}"] = {"duration": donor["clips"][f"3:{direction}"]["duration"], "frames": frames}
    with TemporaryDirectory(prefix="goemon-shin-run-") as staging:
        count = pack_frames(clips, unique, Path(staging))
        for i in range(count):
            copyfile(Path(staging) / f"atlas-{i}.png", folder / f"cast-{base_cast_pages + i}.png")
    for clip in clips.values():
        for frame in clip["frames"]:
            frame[0] += manifest["pages"] + base_cast_pages
    manifest["clips"].update(clips)
    manifest["cast_pages"] = base_cast_pages + count
    manifest["run_reuse"] = {"skin": 100181, "source_id": sword["source_id"], "key": sword["key"],
                             "action": 3, "part": "sword_run", "blade_source_direction": 4, "occluded_facings": [7], "cast_pages": base_cast_pages, "pages": count}
    path.write_text(json.dumps(manifest, separators=(",", ":")) + "\n")
    print(f"Red Lightning: eight reused sword-run grips, {len(unique)} frames, {count} prepared page(s)")


if __name__ == "__main__":
    prepare()
