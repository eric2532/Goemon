"""Recover native house contours and full-resolution paint for solid architecture."""
import argparse
from collections import Counter, deque
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter
from build_coastal_villages import atlas as pack_atlas
from build_freyja_destinations import load_map

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/maps/falan"
REVIEW = ROOT / "build/Other Files/Asset Toolkit/Falan Architecture"
# The supplied art has no 3D height units; retain the shared city fit.
PIXEL_HEIGHT=.045
GABLE_EDGE={10003:1,10005:1,10006:1,10007:1,10009:1,10049:1,10050:0,
            10076:0,10077:0,10078:0,10079:0,10080:0,10081:1,10082:1,
            10083:0,10084:0,10304:0,10305:1,10306:1,10308:1,10309:0,10310:1,10605:1,10609:0}

# The projecting porch, ivy, or chimney obscures these main gable boundaries.
# Reviewed points remain in native pixels rather than guessed world angles.
OCCLUDED_GABLES={
 10006:[(197,283),(215,258),(234,217),(244,184),(248,149),(254,126),(262,123),(270,134),(278,155),(300,165),(350,174)],
 10007:[(197,283),(215,258),(234,217),(244,184),(248,149),(254,126),(262,123),(270,134),(278,155),(300,165),(350,174)],
 10049:[(198,355),(217,328),(237,282),(249,235),(254,177),(259,129),(267,125),(276,148),(286,206),(308,242),(367,261)],
 10076:[(1,175),(25,173),(54,166),(70,159),(77,142),(81,125),(88,121),(96,126),(102,153),(111,187),(126,232),(143,263),(157,280)],
 10077:[(1,175),(25,173),(54,166),(70,159),(77,142),(81,125),(88,121),(96,126),(102,153),(111,187),(126,232),(143,263),(157,280)],
 10078:[(1,174),(27,172),(55,165),(73,156),(80,136),(84,123),(92,121),(99,129),(105,157),(115,194),(130,239),(146,266),(159,280)],
 10084:[(1,174),(27,172),(55,165),(73,156),(80,136),(84,123),(92,121),(99,129),(105,157),(115,194),(130,239),(146,266),(159,280)],
 10306:[(197,282),(216,255),(234,216),(245,179),(249,144),(255,123),(263,121),(272,136),(279,156),(304,167),(351,174)],
 # The blue balcony hood below this gable is not part of the main roof profile.
 10310:[(275,338),(290,321),(307,298),(325,267),(339,234),(344,204),(347,183),(351,164),
        (360,161),(370,166),(383,180),(391,200),(402,221),(420,231),(442,236),(462,242)],
}
OCCLUDED_GABLES[10050]=[(376-x,y)for x,y in reversed(OCCLUDED_GABLES[10049])]
OCCLUDED_GABLES[10304]=OCCLUDED_GABLES[10077]


# Projecting porch feet hide the main plinth corners on these facades.
FOUNDATIONS={
 10076:[(30,320),(159,408),(321,298)],
 10077:[(30,320),(158,407),(321,300)],
 10304:[(30,320),(158,407),(321,300)],
 10084:[(30,300),(156,410),(321,303)],
}
OCCLUDED_GABLES[10003]=[(198,283),(215,258),(234,217),(244,184),(248,149),(254,126),(262,123),(270,134),(278,155),(300,165),(350,174)]


def line(points, sign):
    rng = random.Random(10300+sign)
    candidates = {}
    for _ in range(1500):
        a,b = rng.sample(points,2)
        if abs(b[0]-a[0]) < 35:
            continue
        slope = (b[1]-a[1])/(b[0]-a[0])
        if not .45 < slope*sign < .90:
            continue
        offset = a[1]-slope*a[0]
        inliers = [p for p in points if abs(p[1]-slope*p[0]-offset)<2]
        span = max(p[0]for p in inliers)-min(p[0]for p in inliers)
        score = len(inliers)+span*.08
        key=(round(slope,2),round(offset/3))
        if key not in candidates or score>candidates[key][0]:candidates[key]=score,slope,offset,inliers
    assert candidates, "A native foundation edge must be visible"
    return sorted(candidates.values(),reverse=True)[:20]


def foundation(image):
    mask=image.getchannel("A").point(lambda a:255 if a>200 else 0).filter(ImageFilter.MinFilter(3))
    pixels=mask.load();points=[]
    for x in range(image.width):
        ys=[y for y in range(round(image.height*.62),image.height)if pixels[x,y]]
        if ys:points.append((x,max(ys)+1))
    lowest=max(p[1]for p in points)
    bottom=[p[0]for p in points if p[1]>=lowest-2]
    front_x=sum(bottom)/len(bottom)
    candidates=[]
    for left in line([p for p in points if p[0]<front_x+5],1):
        for right in line([p for p in points if p[0]>front_x-5],-1):
            x=(right[2]-left[2])/(left[1]-right[1]);y=left[1]*x+left[2]
            if abs(y-lowest)>15 or abs(x-front_x)>25:continue
            score=left[0]+right[0]-abs(y-lowest)*3-abs(x-front_x)
            candidates.append((score,x,y,left,right))
    assert candidates, "Both native foundation edges must meet at the visible plinth"
    _,front_x,front_y,left,right=max(candidates,key=lambda row:row[0])
    front=(front_x,front_y)
    lx=min(p[0]for p in left[3]);rx=max(p[0]for p in right[3])
    a=(lx,left[1]*lx+left[2]);b=(rx,right[1]*rx+right[2])
    return [a,front,b,(a[0]+b[0]-front[0],a[1]+b[1]-front[1])]


def roof_mask(image, family):
    mask=set()
    for y in range(round(image.height*.80)):
        for x in range(image.width):
            r,g,b,a=image.getpixel((x,y))
            color=(r>g*1.12 and r>b*1.12)if family==4 else (g>r*1.06 and g>b*1.02)if family==5 else (b>r*1.12 and g>r*1.06 and b>g*.95)
            if a>200 and color:mask.add((x,y))
    joined=Image.new("L",image.size)
    for point in mask:joined.putpixel(point,255)
    joined=joined.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    mask={(x,y)for y in range(image.height)for x in range(image.width)if joined.getpixel((x,y))}
    biggest=set()
    while mask:
        seed=mask.pop();component={seed};todo=deque([seed])
        while todo:
            x,y=todo.popleft()
            for point in [(x+dx,y+dy)for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1),(-1,1),(1,1)]]:
                if point in mask:mask.remove(point);component.add(point);todo.append(point)
        if len(component)>len(biggest):biggest=component
    assert len(biggest)>1000, "Native main roof must remain distinguishable"
    return biggest


def contours(image,family,gable):
    floor=foundation(image);roof=roof_mask(image,family)
    columns={}
    for x,y in roof:columns.setdefault(x,[]).append(y)
    candidates=[]
    for edge in [0,1]:
        a,b=floor[edge:edge+2];samples=[]
        for x in range(math.ceil(a[0])+3,math.floor(b[0])-2,3):
            if x not in columns:continue
            t=(x-a[0])/(b[0]-a[0]);base=a[1]+(b[1]-a[1])*t
            visible=[y for y in columns[x]if(base-y)*.045>=2.5]
            if not visible:continue
            y=max(visible)
            samples.append((t,(base-y)*.045,x,y))
        if not samples:continue
        mean=sum(p[1]for p in samples)/len(samples)
        variation=sum((p[1]-mean)**2for p in samples)/len(samples)
        candidates.append((variation,edge,samples))
    _,edge,profile=next(row for row in candidates if row[1]==gable)
    return floor,edge,profile


def local(point,origin):
    across=(point[0]-origin[0])*3/32
    along=(point[1]-origin[1])/8
    return ((across-along)*.5,(across+along)*.5)


def projected(point,origin):
    return origin[0]+(point[0]+point[1])*32/3,origin[1]+(point[1]-point[0])*8


def roof_profile(image,family,floor,edge,origin,serial):
    mask=roof_mask(image,family);columns={}
    for x,y in mask:columns.setdefault(x,[]).append(y)
    a,b=floor[edge:edge+2]
    length=math.dist(a,b);direction=((b[0]-a[0])/length,(b[1]-a[1])/length)
    a=(a[0]-direction[0]*2,a[1]-direction[1]*2)
    b=(b[0]+direction[0]*2,b[1]+direction[1]*2)
    pa,pb=projected(a,origin),projected(b,origin)
    # Bays can skew the plinth fit. Roof axes follow the original 32/24 tile basis.
    slope=-.75 if edge==1 else .75
    pb=(pb[0],pa[1]+(pb[0]-pa[0])*slope)
    b=local(pb,origin)
    profile=[]
    if serial in OCCLUDED_GABLES:
        pixels=OCCLUDED_GABLES[serial]
        a=(a[0],a[1]);b=(b[0],b[1])
        # Roof eaves extend to the original painted boundary at either end.
        first=(pixels[0][0],pa[1]+(pixels[0][0]-pa[0])*slope)
        last=(pixels[-1][0],pa[1]+(pixels[-1][0]-pa[0])*slope)
        a=local(first,origin);b=local(last,origin)
        return a,b,[((x-first[0])/(last[0]-first[0]),(first[1]+(x-first[0])*slope-y)*PIXEL_HEIGHT)for x,y in pixels]
    for x in range(max(0,math.ceil(pa[0])),min(image.width-1,math.floor(pb[0]))+1,3):
        if x not in columns:continue
        u=(x-pa[0])/(pb[0]-pa[0])
        base=pa[1]+(pb[1]-pa[1])*u
        candidates=[y for y in columns[x]if(base-y)*.045>=2.5]
        if not candidates:continue
        height=(base-max(candidates))*PIXEL_HEIGHT
        profile.append((u,height))
    assert len(profile)>12 and min(h for _,h in profile)>0
    # Small pixel gaps in the original ridge outline must not make vertical spikes.
    smooth=[]
    for i,(u,h)in enumerate(profile):
        nearby=sorted(p[1]for p in profile[max(0,i-1):i+2])
        smooth.append((u,nearby[len(nearby)//2]))
    return a,b,smooth


def opaque_paint(image):
    """Extend native edge colors onto hidden solids without changing visible RGB."""
    result=image.copy();pixels=result.load();queue=deque();known=set()
    for y in range(image.height):
        for x in range(image.width):
            r,g,b,a=pixels[x,y]
            if a>=128:
                pixels[x,y]=(r,g,b,255);known.add((x,y))
    for x,y in known:
        if any((x+dx,y+dy)not in known for dx,dy in [(-1,0),(1,0),(0,-1),(0,1)]):queue.append((x,y))
    while queue:
        x,y=queue.popleft()
        for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if not(0<=nx<image.width and 0<=ny<image.height)or(nx,ny)in known:continue
            pixels[nx,ny]=pixels[x,y];known.add((nx,ny));queue.append((nx,ny))
    return result


def prepare(source):
    sys.path.insert(0,str(source/"tools"))
    import cg_library as library
    meta=json.loads((OUT/"city_building_surfaces.json").read_text())
    graphics={r["reference_graphic"]:r["runtime_family"]for r in meta["bindings"]}
    # This house has no saved placeholder; its NPC-based conditional interior remains unverified.
    graphics[10310]=17
    REVIEW.mkdir(parents=True,exist_ok=True)
    result={};images={}
    for serial,family in sorted(graphics.items()):
        print("Tracing",serial,flush=True)
        entry=library.serial_index()[serial]
        original=library.image_from_record(entry["pack"],entry["row"])
        images[serial]=original
        floor,edge,profile=contours(original,family,GABLE_EDGE[serial])
        if serial in FOUNDATIONS:
            a,front,b=FOUNDATIONS[serial]
            floor=[a,front,b,(a[0]+b[0]-front[0],a[1]+b[1]-front[1])]
        canvas=Image.new("RGB",original.size,"#46565c");canvas.paste(original,(0,0),original)
        draw=ImageDraw.Draw(canvas)
        draw.line(floor+[floor[0]],fill="#ffb64a",width=2)
        draw.line([(p[2],p[3])for p in profile],fill="#ff67eb",width=2)
        for i,p in enumerate(floor):draw.text(p,str(i),fill="white")
        canvas.save(REVIEW/f"trace-{serial}.png")
        origin=(-entry["x"]+(entry["east"]-entry["south"])*16,-entry["y"]-(entry["east"]+entry["south"]-2)*12)
        local_floor=[local(p,origin)for p in floor]
        a,b,roof=roof_profile(original,family,local_floor,edge,origin,serial)
        wall=min(h for _,h in roof)-.02
        result[serial]={"family":family,"floor_pixels":floor,"floor":local_floor,"origin":origin,"gable_edge":edge,"profile":roof,"roof_a":a,"roof_b":b,"wall":wall,"graphic":dict(entry),"rgba_sha256":hashlib.sha256(original.tobytes()).hexdigest()}
    (REVIEW/"contour-review.json").write_text(json.dumps(result,indent=2)+"\n")
    with tempfile.TemporaryDirectory()as directory:
        target=Path(directory)/"architecture.png"
        placements=pack_atlas(library,library.serial_index(),graphics,target,2048)
        image=Image.open(target).convert("RGBA");image.load()
    solid_image=image.copy()
    for serial,original in images.items():solid_image.paste(opaque_paint(original),placements[serial][:2])
    rows=["extends RefCounted","## Generated by tools/recover_falan_architecture.py; native geometry controls and paint.",f"const PIXEL_HEIGHT={PIXEL_HEIGHT:.12f}","const GRAPHICS={"]
    vectors=lambda points:",".join(f"Vector2({x:.6f},{y:.6f})"for x,y in points)
    for serial,record in result.items():
        rect=placements[serial];origin=record["origin"]
        rows.append(f' {serial}:[Rect2{rect},Vector2{origin},[{vectors(record["floor"])}],{record["gable_edge"]},[{vectors(record["profile"])}],Vector2{record["roof_a"]},Vector2{record["roof_b"]},{record["wall"]:.6f},{record["family"]},Vector2({record["graphic"]["south"]*3},{record["graphic"]["east"]*3})],')
    rows += ["}","const BINDINGS={"]
    for binding in meta["bindings"]:
        marker=binding["marker"];x,z=binding["source_center"]
        rows.append(f' Vector2i({marker["x"]},{marker["z"]}):[{binding["reference_graphic"]},Vector2({x:g},{z:g})],')
    rows.append("}")
    represented={(r["reference_graphic"],*r["source_center"])for r in meta["bindings"]}
    width,_,_,objects,_=load_map(library,1000)
    unmarked=[]
    rows.append("const UNMARKED=[")
    for i,serial in enumerate(objects):
        if serial not in graphics:continue
        entry=library.serial_index()[serial]
        x=3*(i//width-134)-1.5*(entry["south"]-1)
        z=3*(153-i%width)-1.5*(entry["east"]-1)
        if(serial,x,z)in represented:continue
        unmarked.append({"reference_graphic":serial,"source_center":[x,z]})
        rows.append(f' [{serial},Vector2({x:g},{z:g})],')
    rows.append("]")
    return image,solid_image,"\n".join(rows)+"\n",{"graphics":result,"bindings":meta["bindings"],"unmarked":unmarked,"method":"Opaque source foundation and native main-roof contours; original full-resolution RGBA paint. Hidden surfaces are reconstructed."}


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source",type=Path,default=ROOT.parent/"Magic Power")
    parser.add_argument("--check",action="store_true")
    args=parser.parse_args()
    image,solid_image,data,meta=prepare(args.source)
    path=OUT/"city_architecture"
    if args.check:
        with Image.open(path.with_suffix(".png"))as actual:assert actual.convert("RGBA").tobytes()==image.tobytes()
        with Image.open(OUT/"city_architecture_solid.png")as actual:assert actual.convert("RGBA").tobytes()==solid_image.tobytes()
        assert path.with_suffix(".gd").read_text()==data
        assert json.loads(path.with_suffix(".json").read_text())==json.loads(json.dumps(meta))
        print("PASS: original house contours, source placements and native paint reproduce")
    else:
        image.save(path.with_suffix(".png"),optimize=True)
        solid_image.save(OUT/"city_architecture_solid.png",optimize=True)
        path.with_suffix(".gd").write_text(data)
        path.with_suffix(".json").write_text(json.dumps(meta,indent=2)+"\n")
        print("Recovered",len(meta["graphics"]),"native graphics for",len(meta["bindings"]),"protected markers and",len(meta["unmarked"]),"unmarked original houses")
