"""Private shrine-only architectural paint masks; original compound stays exact."""
import hashlib
import json
from pathlib import Path
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/living_house_paint'
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Living Paint Prototype'
# Measured source door/window faces, not guessed new openings. The separately
# owned canopy/trunk remains outside these architectural feature polygons.
FEATURES=[
 [[(70,593),(96,596),(95,629),(73,623)],[(137,601),(163,585),(171,597),(169,630),(152,650),(135,638)]],
 [[(236,406),(258,394),(268,406),(263,442),(248,452),(234,436)]],
 [[(397,459),(423,447),(433,460),(430,488),(411,507),(396,490)]],
]
FLAGS=[([148,510,175,595],1),([285,337,311,433],-46),([391,309,420,445],-25)]
def sha(data):return hashlib.sha256(data).hexdigest()
def prepare():
    catalog=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
    g=catalog['graphics']['1230040'];x,y,w,h=g['rect']
    page=ROOT/'assets/maps/original_crossgate'/catalog['pages'][g['page']]
    original=Image.open(page).convert('RGBA').crop((x,y,x+w,y+h));assert sha(original.tobytes())==g['rgba_sha256']
    spec=json.loads((ROOT/'assets/maps/falan/east_region/landmarks/profiles.json').read_text())['graphics']['1230040']
    OUT.mkdir(parents=True,exist_ok=True);REPORT.mkdir(parents=True,exist_ok=True);(REPORT/'.gdignore').touch()
    images=[];rows=[]
    for index,house in enumerate(spec['houses']):
        roof=Image.new('1',original.size);draw=ImageDraw.Draw(roof);draw.polygon([tuple(house['eaves'][0]),tuple(house['apex']),tuple(house['eaves'][2]),tuple(house['eaves'][1])],fill=1)
        features=Image.new('1',original.size);draw=ImageDraw.Draw(features)
        for polygon in FEATURES[index]:draw.polygon(polygon,fill=1)
        paint=original.copy();kept=0
        for yy in range(h):
            for xx in range(w):
                r,green,b,a=original.getpixel((xx,yy))
                # This source has three blue ceramic roofs. Bounded roof-only
                # selection preserves blue/ivory paint; no leaf/window color key
                # is applied to the complete compound or to other house types.
                ceramic=(b>=r*1.02 and b>=green*.90) or(min(r,green,b)>125 and max(r,green,b)-min(r,green,b)<75)
                keep=features.getpixel((xx,yy)) or(roof.getpixel((xx,yy)) and ceramic)
                paint.putpixel((xx,yy),(r,green,b,a if keep else 0));kept+=bool(a and keep)
        name=f'1230040-house-{index}.png';paint.save(OUT/name);images.append(paint)
        feature_paint=original.copy()
        for yy in range(h):
            for xx in range(w):
                pixel=original.getpixel((xx,yy));feature_paint.putpixel((xx,yy),(*pixel[:3],pixel[3] if features.getpixel((xx,yy)) else 0))
        feature_file=f'1230040-features-{index}.png';feature_paint.save(OUT/feature_file)
        rows.append(dict(index=index,file=name,features=FEATURES[index],native_rgba_sha256=sha(paint.tobytes()),kept_pixels=kept,
            feature_file=feature_file,feature_rgba_sha256=sha(feature_paint.tobytes()),
            inference='Only measured original door/window and bounded blue ceramic roof pixels remain on the house. Source-overlapping leaves/branches remain with their separate compound layers; occluded architecture continues independent existing bark and ceramic materials.'))
    flags=[]
    for index,(box,ground) in enumerate(FLAGS):
        flag=original.crop(tuple(box));p=flag.load()
        for yy in range(flag.height):
            for xx in range(flag.width):
                r,green,b,a=p[xx,yy]
                if not((r>green*1.08 and r>b*1.12) or(b>r*1.12 and b>green*.92) or(r>130 and green>110 and b<green*.75)):p[xx,yy]=(r,green,b,0)
        file=f'1230040-flag-{index}.png';flag.save(OUT/file);flags.append(dict(box=box,ground=ground,file=file,rgba_sha256=sha(flag.tobytes())))
    # This unobstructed native patch contains the shrine's blue curved tiles and
    # gold seams. It replaces the rejected noisy bamboo-house palette sample.
    blue_patch=original.crop((418,420,450,452));assert blue_patch.getchannel('A').getextrema()==(255,255)
    atlas=Image.open(ROOT/'assets/maps/falan/east_region/landmarks/surfaces.png').convert('RGBA');surfaces=(ROOT/'assets/maps/falan/east_region/landmarks/surfaces.gd').read_text()
    import re
    match=re.search(r'"roof_blue":Vector2\((\d+),(\d+)\)',surfaces);assert match;sx,sy=map(int,match.groups())
    atlas.paste(blue_patch.resize((128,128),Image.Resampling.NEAREST),(sx,sy));atlas.save(OUT/'surfaces.png')
    data=dict(schema=1,scope='PRIVATE source-layer prototype; no live dispatch.',source_rgba_sha256=g['rgba_sha256'],source_origin=g['origin'],source_size=[w,h],houses=rows,flags=flags,
        private_roof_material=dict(source_graphic=1230040,source_rgba_sha256=g['rgba_sha256'],patch=[418,420,450,452],patch_rgba_sha256=sha(blue_patch.tobytes()),atlas_tile=[sx,sy],inference='The exact observed blue/gold ceramic patch repeats on inferred hidden roof slopes. No recoloring/random replacement; shared atlas and native front pixels stay unchanged.'),
        root_hubs=[dict(base=[137,650],level_pixels=0,height_pixels=115,diameter=165),dict(base=[300,464],level_pixels=133,height_pixels=108,diameter=155),dict(base=[445,522],level_pixels=97,height_pixels=112,diameter=155)],
        root_hub_inference='The original shrine has doors within connected organic roots. Reuse tapered round root sections beneath the measured roofs, instead of the rejected rectangular house cages. Hidden depth/profile and root continuity are inferred; original features, stairs, origins and routes are unchanged.')
    (OUT/'data.json').write_text(json.dumps(data,indent=2)+'\n')
    contact=Image.new('RGBA',(w*4,h),(35,40,40,255));contact.alpha_composite(original,(0,0))
    for index,paint in enumerate(images):contact.alpha_composite(paint,(w*(index+1),0))
    contact.convert('RGB').save(REPORT/'native-and-three-house-masks.jpg',quality=94)
    print('PRIVATE_SHRINE_HOUSE_PAINT',len(rows),'original source RGBA retained')
if __name__=='__main__':prepare()
