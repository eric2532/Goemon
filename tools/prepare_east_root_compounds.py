"""Exact six ancient-root compounds: native BGmosaic plus unchanged11699crown.

Private source preparation only. Hidden physical backs/ground will be authored
separately; no maps, source art, routes, collisions or runtime owner are changed.
"""
import hashlib,json,statistics
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
from review_east_backgrounds import Native,decode,ROOT,CATALOG

OUT=ROOT/'assets/maps/falan/east_region/root_compounds'
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Ancient Root Compounds'
MAPS=[11031,11039,11040,32276,33000,33298]
# Visible body/root outline in the native132-piece mosaic. Interior grass stays
# flat; unseen grass immediately below the reconstructed solid is inferred.
BODY_OUTLINE=[(384,0),(403,19),(419,62),(442,83),(466,98),(475,128),(510,145),(516,163),(535,184),(563,198),(616,219),(598,218),(561,207),(540,215),(561,224),(567,247),(605,266),(638,292),(602,278),(564,267),(516,253),(493,252),(502,272),(536,283),(573,302),(537,310),(499,296),(472,296),(464,319),(492,347),(523,385),(519,419),(497,394),(466,369),(445,359),(465,393),(462,421),(440,399),(392,371),(361,342),(342,320),(329,326),(315,323),(280,344),(271,322),(285,300),(273,269),(251,284),(231,308),(196,344),(160,365),(128,370),(151,346),(181,309),(221,276),(208,256),(190,253),(141,276),(92,285),(131,248),(176,216),(219,198),(196,190),(149,179),(207,170),(249,133),(280,113),(303,77),(345,30)]
def sha(raw):return hashlib.sha256(raw).hexdigest()

def prepare():
    catalog=json.loads(CATALOG.read_text());native=Native();contexts=[];planes={}
    for mid in MAPS:
        row=catalog['maps'][f'BlueCrossgate/map/0/{mid}.dat'];w,h,raw,values,bits,aliases=decode(row);n=w*h
        crowns=[(i%w,i//w) for i,s in enumerate(values[n:]) if s==11699];assert len(crowns)==1,(mid,crowns)
        ax,ay=crowns[0];cells={(i%w-ax,i//w-ay):int(s) for i,s in enumerate(values[:n]) if 4100<=s<=4231}
        planes[mid]=(row,w,h,raw,values,bits,aliases,cells,(ax,ay))
    # The complete132drawing core is identical in all six originals. The three
    # ancient arenas additionally repeat nine ordinary4198grass tiles: keep them.
    base=planes[11031][7]
    core={p:s for p,s in base.items() if all(planes[mid][7].get(p)==s for mid in MAPS)}
    assert len(core)==132 and set(core.values())==set(range(4100,4232))
    pieces=[];left=top=10**9;right=bottom=-10**9
    for (dx,dy),serial in sorted(core.items(),key=lambda r:(r[0][1],r[0][0])):
        g=native.table[serial][0];x=(dx+dy)*32+g['origin'][0];y=(dy-dx)*24+g['origin'][1];w,h=g['rect'][2:]
        pieces.append(dict(relative_cell=[dx,dy],native_graphic=serial,source_rgba_sha256=g['rgba_sha256'],native_origin=g['origin'],draw_at=[x,y],size=[w,h]))
        left=min(left,x);top=min(top,y);right=max(right,x+w);bottom=max(bottom,y+h)
    bg=Image.new('RGBA',(right-left,bottom-top))
    for p in pieces:bg.alpha_composite(native.crop(p['native_graphic']),(p['draw_at'][0]-left,p['draw_at'][1]-top))
    crown_g=native.table[11699][0];crown=native.crop(11699);assert sha(crown.tobytes())==crown_g['rgba_sha256']
    cx,cy=crown_g['origin'];combined_left=min(left,cx);combined_top=min(top,cy);combined_right=max(right,cx+crown.width);combined_bottom=max(bottom,cy+crown.height)
    combined=Image.new('RGBA',(combined_right-combined_left,combined_bottom-combined_top));combined.alpha_composite(bg,(left-combined_left,top-combined_top));combined.alpha_composite(crown,(cx-combined_left,cy-combined_top))
    OUT.mkdir(parents=True,exist_ok=True);REPORT.mkdir(parents=True,exist_ok=True);(REPORT/'.gdignore').touch()
    bg.save(OUT/'native-bg-core.png');crown.save(OUT/'native-crown.png');combined.save(REPORT/'native-combined.png')
    leaf_paint=crown.copy();wood_paint=crown.copy();wood_boxes=[[275,485,335,542],[410,480,495,548]]
    for yy in range(crown.height):
        for xx in range(crown.width):
            r,green,b,alpha=crown.getpixel((xx,yy));inside=any(a<=xx<c and d<=yy<e for a,d,c,e in wood_boxes)
            wood=inside and r>green*1.08 and r>b*1.35
            leaf_paint.putpixel((xx,yy),(r,green,b,0 if wood else alpha));wood_paint.putpixel((xx,yy),(r,green,b,alpha if wood else 0))
    leaf_paint.save(OUT/'native-crown-leaves.png');wood_paint.save(OUT/'native-crown-wood.png')
    mask=Image.new('L',bg.size);ImageDraw.Draw(mask).polygon(BODY_OUTLINE,fill=255)
    # The initial hand outline included broad green ground wedges on root toes.
    # A bounded connected-wood silhouette moves those exact pixels back onto
    # the source floor. Interior vines remain inside the closed woody mass.
    wood=Image.frombytes('L',bg.size,bytes(255 if mask.getpixel((i%bg.width,i//bg.width)) and a>=128 and r>g*1.04 and r>b*1.16 else 0 for i,(r,g,b,a) in enumerate(bg.getdata()))).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    outside=set();queue=[]
    for x in range(bg.width):
        for y in [0,bg.height-1]:
            if not wood.getpixel((x,y)):outside.add((x,y));queue.append((x,y))
    for y in range(bg.height):
        for x in [0,bg.width-1]:
            if not wood.getpixel((x,y)):outside.add((x,y));queue.append((x,y))
    for x,y in queue:
        for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if 0<=p[0]<bg.width and 0<=p[1]<bg.height and p not in outside and not wood.getpixel(p):outside.add(p);queue.append(p)
    for y in range(bg.height):
        for x in range(bg.width):mask.putpixel((x,y),255 if (x,y) not in outside and mask.getpixel((x,y)) else 0)
    body=bg.copy();floor=bg.copy();ground=bg.copy();grain=Image.new('RGBA',(128,128))
    grass=bg.crop((306,457,370,505));assert grass.getchannel('A').getextrema()==(255,255)
    # The16x32Meadow bark was visibly coarse at this giant tree's source scale.
    # Reuse a bounded32x128native bark-only detail, not the complete root/front.
    bark_box=[332,70,364,198];bark_patch=bg.crop(tuple(bark_box)).convert('RGB');browns=[]
    for yy in range(bark_patch.height):
        for xx in range(bark_patch.width):
            red,green,blue=bark_patch.getpixel((xx,yy))
            if red>green*1.04 and red>blue*1.16 and red<150:browns.append((xx,yy,(red,green,blue)))
    grain_source=ROOT/'assets/models/edo/cherry_tree_wood.png';existing_grain=Image.open(grain_source).convert('RGB')
    luminance=lambda p:.2126*p[0]+.7152*p[1]+.0722*p[2]
    colors=sorted({p[2] for p in browns},key=luminance);values=[luminance(p) for p in existing_grain.getdata()];dark=min(values);light=max(values)
    bark=Image.new('RGBA',existing_grain.size)
    bark.putdata([(*colors[round((.05+.90*(v-dark)/(light-dark))*(len(colors)-1))],255) for v in values])
    for yy in range(bg.height):
        for xx in range(bg.width):
            p=bg.getpixel((xx,yy));inside=bool(mask.getpixel((xx,yy)))
            body.putpixel((xx,yy),(*p[:3],p[3] if inside else 0))
            ground.putpixel((xx,yy),(*p[:3],0 if inside else p[3]))
            if inside:floor.putpixel((xx,yy),grass.getpixel((xx%grass.width,yy%grass.height)))
    grain=bark
    for name,image in [('body-front',body),('source-ground',ground),('ground-reconstruction',floor),('bark-grain',grain)]:image.save(OUT/(name+'.png'))
    for mid in MAPS:
        row,w,h,raw,values,bits,aliases,cells,anchor=planes[mid];ax,ay=anchor
        exact=[]
        for (dx,dy),serial in core.items():
            x,y=ax+dx,ay+dy;i=y*w+x;assert int(values[i])==serial
            exact.append(dict(cell=[x,y],native_graphic=serial,original_open=bool(bits[i>>3]&(1<<(i&7)))))
        extras=[dict(cell=[ax+dx,ay+dy],native_graphic=s,role='Source family reuse outside exact core; retain original floor, never add another tree.') for (dx,dy),s in cells.items() if (dx,dy) not in core]
        contexts.append(dict(map=mid,title=row['title'],size=[w,h],source_raw_sha256=sha(raw),crown=dict(cell=list(anchor),native_graphic=11699,source_rgba_sha256=crown_g['rgba_sha256']),exact_bg_core=exact,retained_other_family_drawings=extras))
    data=dict(schema=1,scope='Private source-only preparation; not live and not visual acceptance.',catalog_sha256=sha(CATALOG.read_bytes()),source_catalogs=native.pins,
        body=dict(native_origin=[left,top],native_size=list(bg.size),native_rgba_sha256=sha(bg.tobytes()),source_pieces=pieces),
        crown=dict(native_origin=crown_g['origin'],native_size=list(crown.size),source_graphic=11699,source_rgba_sha256=crown_g['rgba_sha256'],leaf_rgba_sha256=sha(leaf_paint.tobytes()),wood_rgba_sha256=sha(wood_paint.tobytes()),wood_boxes=wood_boxes,
            partition='Only observed brown branch pixels within two bounded lower-crown regions move off the leaf dome onto traced3Dbranch parts. Native RGB and the original crown file remain unchanged; leaf/wood alpha sums exactly to the original.'),
        combined_reference=dict(native_origin=[combined_left,combined_top],size=list(combined.size),rgba_sha256=sha(combined.tobytes())),maps=contexts,
        prototype=dict(body_outline=BODY_OUTLINE,body_rgba_sha256=sha(body.tobytes()),source_ground_rgba_sha256=sha(ground.tobytes()),
            reconstructed_ground_rgba_sha256=sha(floor.tobytes()),bark_rgba_sha256=sha(grain.tobytes()),bark_patch=dict(source='native-bg-core.png',box=bark_box,native_rgba_sha256=sha(bg.crop(tuple(bark_box)).tobytes()),inference='Small native bark-only detail supplies the exact brown palette. The existing fine Edo tree-wood grain supplies hidden surface structure at source-scale pitch; the complete front is never wrapped around the model.'),ground_native_y=111,body_ground_role_inference='Bounded connected woody silhouette with closed interior vine regions; exact grass/toe-edge pixels move from elevated body to native floor. Original composite and every source RGB/alpha remain intact across the split.',
            base_pixel=[364,327],top_pixel=[385,0],crown_junction_pixel=[437,511],height_pixels=327,diameter_pixels=200,
            source_hollow_outline=[[340,250],[351,264],[367,286],[386,318],[366,324],[342,321],[319,326],[326,296],[334,272]],inferred_hollow_depth=2.8,
            rear_bark=dict(reused_source=str(grain_source.relative_to(ROOT)),source_file_sha256=sha(grain_source.read_bytes()),source_rgb_sha256=sha(existing_grain.tobytes()),native_palette_source='native-bg-core.png',native_source_rgba_sha256=sha(bg.tobytes()),source_patch=bark_box,source_patch_rgb_sha256=sha(bark_patch.tobytes()),
                inference='Reuse the existing128x128Edo tree-wood grain with the exact observed native-root brown palette. The finer grain pitch and rear root-rib continuation are inferred; original composite/body/crown pixels are untouched.'),
            inference='Body/ground alpha is traced from the observed silhouette. Only the hidden floor under that silhouette is reconstructed using a native grass patch. Hidden root depth, rear bark and cavity depth are inferred; no new navigation is authored.'),
        inferences_pending=['Separate exact source body/grass alpha; retain visible source floor and label reconstructed unseen ground.','Reuse existing living-trunk/root/branch parts; measure actual native axes before creating physical volume.','Continue bark/material around hidden sides without wrapping the complete front.','Join the physical trunk top to the native crown volume; canopy-only241candidate is not a completed compound.'])
    (OUT/'data.json').write_text(json.dumps(data,indent=2)+'\n');(REPORT/'source-assembly.json').write_text(json.dumps(data,indent=2)+'\n')
    print('ANCIENT_ROOT_SOURCE maps=',len(contexts),'core_native_drawings=',len(pieces),'BGsize=',bg.size,'combined=',combined.size)
if __name__=='__main__':prepare()
