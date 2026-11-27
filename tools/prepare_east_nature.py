"""Prepare source-preserving East nature: existing masters, timber and rounded contours."""
import argparse
import ast
from collections import deque
import hashlib
import json
import math
from pathlib import Path

from PIL import Image,ImageChops,ImageDraw,ImageFilter
from recover_venoa_walls import native_without_ground_shadow
from east_region_tree_families import prepare as prepare_tree,palette_transfer
from prepare_abanis_cliffs import measured_profile

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/maps/original_crossgate'
OUT=ROOT/'assets/maps/falan/east_region/nature'
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature'
TREES=[10000,*range(11152,11165)]
STUMPS=[11027,11046]
CACTI=[*range(11169,11188),11564,11565,11743,11744,11745,11746,11747,11748,11749,11750,11751,11752,11754,11758,11759,11760,11762,11763,11764,11765,11767,11772,11782,11785,11786]
POTS=[10024,10025,10028,10030,16206,16212,16216,16232]
LOGS=[11008,11009,11011,11165,11167]
FLORA=[11516,*range(11532,11547),11548,11774,11775,11776,11779,11787,11792,11793,11794,12156,12157,12158,12159,12186,12190,12191,16334,16335,11095,11096,11097]
BONES_LARGE=[11209,11210,11211,11217,11218]
BONES_SMALL=[15179,15180,15181,15182,15183,15188,15201,15212,15216,15217,15218,15219,15220,15221,15222,15223,15224,15225,15226,15227,15228,15229,15230]
BEDS=list(range(1233051,1233055))
URN=1233055
TYPED_PLANTS=[*range(11625,11699),*range(12160,12181)]
TYPED_WOODY=[11692,11693,11694,12172,12173,12174]
TYPED_STUMPS=[12164,12165]
ALL=sorted([11699]+TYPED_PLANTS+BEDS+[URN]+BONES_LARGE+BONES_SMALL+TREES+STUMPS+CACTI+POTS+LOGS+FLORA+[1233103,1230041])
assert len(ALL)==241 and len(set(ALL))==241


def digest(raw):return hashlib.sha256(raw).hexdigest()


def sources():
    result={};pages={};pins={}
    for path in [ART/'catalog.json',ART/'university/catalog.json',ROOT/'assets/maps/falan/sokia/fixed/catalog.json',ART/'elsa/catalog.json',ART/'east/catalog.json']:
        catalog=json.loads(path.read_text());pins[str(path.relative_to(ROOT))]=digest(path.read_bytes())
        offset=catalog.get('page_offset',13 if path.parent.name=='university' else 17 if path.parent.name=='elsa' else 0)
        for token,g in catalog['graphics'].items():
            name=catalog['pages'][int(g['page'])-offset]
            page=path.parent/name
            if not page.exists():page=ART/name
            result[int(token)]=(g,page)
    return result,pages,pins


def outline(image):
    definition=next(n for n in ast.parse((ROOT/'tools/prepare_elsa_scenery.py').read_text()).body if isinstance(n,ast.FunctionDef) and n.name=='outline')
    scope={'math':math,'Image':Image};exec(compile(ast.Module(body=[definition],type_ignores=[]),'prepare_elsa_scenery.py','exec'),scope)
    return scope['outline'](image)


def contour_depth(image,factor=.075):
    """Distance to native alpha edge rounds a pad/column without replacing its silhouette."""
    w,h=image.size;mask={(x,y) for y in range(h) for x in range(w) if image.getpixel((x,y))[3]>=128}
    distance={p:0 for p in mask};queue=deque()
    for x,y in mask:
        if any((x+dx,y+dy) not in mask for dx,dy in [(0,1),(0,-1),(1,0),(-1,0)]):distance[x,y]=1;queue.append((x,y))
    while queue:
        p=queue.popleft()
        for dx,dy in [(0,1),(0,-1),(1,0),(-1,0)]:
            q=(p[0]+dx,p[1]+dy)
            if q in distance and not distance[q]:distance[q]=distance[p]+1;queue.append(q)
    # Measured source-width depth is deliberately bounded for thin pads and pot walls.
    grid=[]
    for y in range(0,h+4,4):
        row=[]
        for x in range(0,w+4,4):
            px=min(x,w-1);py=min(y,h-1);row.append(round(max(0,distance.get((px,py),0))*factor,6))
        grid.append(row)
    return grid


def rear_paint(image):
    # Repeating body-only samples continue ribs/thorn grain; no complete front is wrapped.
    colors=[p[:3] for p in image.getdata() if p[3]>=128 and max(p[:3])>45 and max(p[:3])-min(p[:3])>12]
    tone=[round(sum(p[c] for p in colors)/len(colors)) for c in range(3)]
    alpha=image.getchannel('A');w,h=image.size
    best=max(((sum(alpha.getpixel((xx,yy))>=128 for yy in range(max(0,y-4),min(h,y+5)) for xx in range(max(0,x-4),min(w,x+5))),x,y) for y in range(h//5,h*4//5,3) for x in range(w//5,w*4//5,3)))
    cx,cy=best[1:];tile=Image.new('RGB',(8,16))
    for y in range(16):
        for x in range(8):
            p=image.getpixel((max(0,min(w-1,cx+x-4)),max(0,min(h-1,cy+y-8))))
            tile.putpixel((x,y),p[:3] if p[3]>=128 else tuple(tone))
    palette=image.resize((4,4),Image.Resampling.BOX).resize(image.size,Image.Resampling.BILINEAR)
    grain=tile.convert('L');values=list(grain.getdata());mean=max(1,sum(values)/len(values))
    result=image.copy()
    for y in range(h):
        for x in range(w):
            color=palette.getpixel((x,y));base=color[:3] if color[3]>=32 else tone
            shade=max(.60,min(1.40,grain.getpixel((x%8,y%16))/mean))
            result.putpixel((x,y),(*(max(0,min(255,round(v*shade))) for v in base),image.getpixel((x,y))[3]))

    return result


def prepare():
    table,pages,pins=sources();OUT.mkdir(parents=True,exist_ok=True);REPORT.mkdir(parents=True,exist_ok=True)
    data={'schema':1,'graphics':{},'source_catalogs':pins,'inferences':['Original RGBA, source origins, footprints and map positions are preserved.','Only unseen volume/reverse surfaces, compatible tree-master depth and crossed fine-leaf depth are inferred.','No navigation, actors, quest gates or collision are authored by this scenery preparer.'],'height_per_pixel':.045}
    for serial in ALL:
        g,page=table[serial]
        if page not in pages:pages[page]=Image.open(page).convert('RGBA')
        x,y,w,h=map(int,g['rect']);original=pages[page].crop((x,y,x+w,y+h));assert digest(original.tobytes())==g['rgba_sha256'],serial
        clean,shadow=native_without_ground_shadow(original);visible=list(clean.getbbox());clean.save(OUT/f'{serial}-front.png')
        spec=dict(graphic_id=serial,graphic=g,native_rgba_sha256=g['rgba_sha256'],source_serial=g.get('source_serial',serial),visible=visible,ground_offset=float(g['origin'][1])+visible[3]-2,texture_root='res://assets/maps/falan/east_region/nature/',removed_ground_shadow=len(shadow))
        if serial==10000:
            spec.update(kind='seasonal_tree',asset='crossgate_flora/cg_woodland');prepare_tree(spec,g,clean,OUT,ROOT)
        elif serial in TREES or serial in TYPED_WOODY:
            wood=clean.copy();leaves=clean.copy()
            for y in range(wood.height):
                for x in range(wood.width):
                    r,gr,b,a=clean.getpixel((x,y));is_wood=r>gr*1.05 and r>b*1.15 and (serial not in TYPED_WOODY or y>=clean.height*.5)
                    if not is_wood:wood.putpixel((x,y),(r,gr,b,0))
                    if is_wood:leaves.putpixel((x,y),(r,gr,b,0))
            branch_spec=dict(spec,kind='native_branch_tree',branch_min_radius=1);prepare_tree(branch_spec,g,wood,OUT,ROOT);spec.update(branch_spec);spec['kind']='source_canopy_tree'
            leaves.save(OUT/f'{serial}-foliage.png')
        elif serial in BONES_SMALL:spec['kind']='native_loose_bones'
        elif serial in BONES_LARGE:
            branch_spec=dict(spec,kind='native_branch_tree');prepare_tree(branch_spec,g,clean,OUT,ROOT);spec.update(branch_spec);spec['kind']='source_skeleton'
        elif serial==1233103:
            spec['kind']='native_branch_tree';prepare_tree(spec,g,clean,OUT,ROOT)
        elif serial==11699:
            spec.update(kind='source_leaf_dome',height_frame='original-owner',edges=outline(clean),base_height=max(1.2,(24-float(g['origin'][1])-visible[3])*.045),dome_height=(visible[2]-visible[0])/(32/3*math.sqrt(2))*.10,depth=.65)
            rear_paint(clean).save(OUT/f'{serial}-back.png')
        elif serial in BEDS:
            spec.update(kind='source_flowerbed',height_frame='original-owner',height=.35,edges=outline(clean));rear_paint(clean).save(OUT/f'{serial}-back.png')
        elif serial==URN:
            spec.update(kind='potted_shrub',pot_top=38,pot_base=74,pot_width=24,pot_center=26,pot_color=[140,144,139],pot_material='stone',pot_profile=[[0,.7],[.10,1.1],[.20,1.1],[.28,.55],[.42,.35],[.55,.65],[.70,1.1],[.90,1.2],[1,.8]])
            leaves=clean.copy();ImageDraw.Draw(leaves).rectangle((0,38,clean.width,clean.height),fill=(0,0,0,0));leaves.save(OUT/f'{serial}-leaves.png')
        elif serial in STUMPS or serial in TYPED_STUMPS:
            profile,coverage=measured_profile(clean,g);spec.update(kind='source_stump',profile=profile,source_coverage=coverage,material='bark',height_frame='original-owner')
        elif serial in CACTI or serial in [11165,11167]:
            spec.update(kind='rounded_native_contour',depth_grid=contour_depth(clean,.045 if serial in [11169,11170,11171,11173,11174,11758,11759] else .075),edges=outline(clean),depth=.12)
            rear_paint(clean).save(OUT/f'{serial}-back.png')
        elif serial in POTS:
            # Native pot and leaves are separate; the bowl is the existing round-profile part.
            bounds=clean.getbbox();base=bounds[3];pot_top=round(base-(bounds[3]-bounds[1])*(.24 if serial<10100 else .22))
            tone=[p[:3] for y in range(pot_top,base) for x in range(clean.width) if (p:=clean.getpixel((x,y)))[3]>=128 and p[0]>p[1]*1.1]
            spec.update(kind='potted_shrub',pot_top=pot_top,pot_base=base,pot_width=round((bounds[2]-bounds[0])*.68),pot_center=(bounds[0]+bounds[2])*.5,pot_color=[round(sum(p[c] for p in tone)/len(tone)) for c in range(3)])
            leaves=clean.copy();ImageDraw.Draw(leaves).rectangle((0,pot_top,clean.width,clean.height),fill=(0,0,0,0));leaves.save(OUT/f'{serial}-leaves.png')
        elif serial in [11008,11009,11011]:
            axes=[]
            if serial==11008:
                axes=[[[.09,.79],[.78,.10]],[[.18,.86],[.87,.18]],[[.27,.94],[.96,.26]]]
            elif serial==11009:
                axes=[[[.06,.25],[.75,.94]],[[.14,.17],[.84,.86]],[[.22,.09],[.93,.78]]]
            else:
                for row in range(3):
                    for col in range(4-row):axes.append([[(.10+col*.12),(.71+col*.085-row*.085)],[(.70+col*.075),(.07+col*.085-row*.01)]])
            spec.update(kind='source_logs',axes=[[[round(p[0]*w,3),round(p[1]*h,3)] for p in axis] for axis in axes],radius_pixels=6 if serial!=11011 else 5)
        elif serial==1230041:
            spec.update(kind='basin_tree',basins=[dict(center=[62,111],diameter=77,height_pixels=20),dict(center=[29,176],diameter=39,height_pixels=15),dict(center=[101,154],diameter=49,height_pixels=18)])
            wood=clean.copy()
            for y in range(wood.height):
                for x in range(wood.width):
                    r,gr,b,a=wood.getpixel((x,y))
                    if not(r>gr*.95 and r>b*1.1):wood.putpixel((x,y),(r,gr,b,0))
            branch_spec=dict(spec,kind='native_branch_tree');prepare_tree(branch_spec,g,wood,OUT,ROOT)
            leaves=clean.copy()
            for y in range(leaves.height):
                for x in range(leaves.width):
                    r,gr,b,a=leaves.getpixel((x,y))
                    if not(gr>r*.9 and gr>b*1.1):leaves.putpixel((x,y),(r,gr,b,0))
            leaves.save(OUT/f'{serial}-foliage.png');spec.update({k:branch_spec[k] for k in ['branches','bark_color','branch_depth','branch_segments','removed_neutral_shadow_pixels']})
        elif serial in [11095,11096,11097]:
            cut=round(h*.80);soil=clean.copy();crop=clean.copy()
            ImageDraw.Draw(soil).rectangle((0,0,w,cut-1),fill=(0,0,0,0));ImageDraw.Draw(crop).rectangle((0,cut,w,h),fill=(0,0,0,0))
            soil.save(OUT/f'{serial}-soil.png');crop.save(OUT/f'{serial}-crop.png');spec.update(kind='native_crop',ground_offset=float(g['origin'][1])+cut)
        else:spec['kind']='native_flora'
        if spec['kind']=='potted_shrub':spec['support_inference']='Short unseen green stems connect the observed native plant art to its original pot rim.'
        data['graphics'][str(serial)]=spec
    (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
    (REPORT/'source-preservation.json').write_text(json.dumps({'graphics':len(data['graphics']),'ids':ALL,'source_catalogs':pins,'originals_overwritten':False,'inferences':data['inferences']},indent=2)+'\n')
    print('EAST_NATURE_PREPARED',len(ALL),'source-preserving families')
    return data


if __name__=='__main__':prepare()
