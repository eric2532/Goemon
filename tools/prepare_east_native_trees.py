"""Preserve27 native tree silhouettes with the existing crown/timber recipe.

Whole Meadow masters were tried first, then rejected in the source/angle review:
they hid the observed tiers and open branches. Original masters remain intact.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image
from prepare_east_nature import sources
from east_region_tree_families import branch_centerlines
from recover_venoa_walls import native_without_ground_shadow

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/native_trees'
IDS=[*range(10058,10075),*range(10085,10095)]

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def linear(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
def mean(colors):
    assert colors
    return [sum(linear(p[c]/255.) for p in colors)/len(colors) for c in range(3)]

def foliage_colors(image):
    # Blue-gray needles are foliage too; a green-only selector lost their actual palette.
    return [p for y in range(round(image.height*.82)) for x in range(image.width)
            if (p:=image.getpixel((x,y)))[3]>=128 and max(p[:3])>45 and not(p[0]>p[1]*1.18 and p[0]>p[2]*1.25)]

def traced_tree(spec,g,clean):
    width,height=clean.size;rows=[]
    for y in range(round(height*.90)):
        count=sum((p:=clean.getpixel((x,y)))[3]>=128 and max(p[:3])>45 and not(p[0]>p[1]*1.18 and p[0]>p[2]*1.25) for x in range(width))
        if count>=max(4,width*.035):rows.append(y)
    assert rows,spec['graphic']
    bottom=max(rows)+2;wood=clean.copy();leaves=clean.copy();start=max(height*.42,bottom-height*.12)
    for y in range(height):
        for x in range(width):
            r,gr,b,a=clean.getpixel((x,y))
            if not(y>=start and r>gr*1.05 and r>b*1.08):wood.putpixel((x,y),(r,gr,b,0))
            if y>bottom:leaves.putpixel((x,y),(r,gr,b,0))
    branches,tone=branch_centerlines(wood,1);assert branches,spec['graphic']
    spec.update(kind='native_canopy_tree',graphic_id=spec['graphic'],ground_offset=float(g['origin'][1])+clean.getbbox()[3]-2,
        texture_root='res://assets/maps/falan/east_region/native_trees/',branches=branches,bark_color=tone,branch_depth=.45,
        branch_segments=sum(len(path)-1 for path in branches),crown_junction=[(clean.getbbox()[0]+clean.getbbox()[2])*.5,bottom],
        removed_neutral_shadow_pixels=0,rejected_master=spec['asset'],
        inferred='The whole compatible Meadow master was reviewed and rejected because it hid source tiers or open branches. Existing39-tree native crown/timber recipe retains exact painted crown pixels and open branch silhouette; only crossed crown depth and hidden round limb sections are inferred.')
    wood.save(OUT/f"{spec['graphic']}-branches.png");leaves.save(OUT/f"{spec['graphic']}-foliage.png")

def prepare():
    OUT.mkdir(parents=True,exist_ok=True)
    table,_,pins=sources();pages={};masters={};graphics={}
    for serial in IDS:
        g,page=table[serial]
        if page not in pages:pages[page]=Image.open(page).convert('RGBA')
        x,y,w,h=map(int,g['rect']);native=pages[page].crop((x,y,x+w,y+h))
        assert hashlib.sha256(native.tobytes()).hexdigest()==g['rgba_sha256'],serial
        clean,_=native_without_ground_shadow(native);visible=clean.getbbox()
        name='cg_evergreen' if serial<10074 else 'cg_woodland' if serial<10088 else 'cg_silverleaf'
        if name not in masters:
            folder=ROOT/'assets/models/environments/wind_meadow/crossgate_flora'
            leaf=folder/f'{name}_{name}.png';bark=folder/f'{name}_bark.png';mesh=folder/f'{name}.glb'
            leaf_image=Image.open(leaf).convert('RGBA');bark_image=Image.open(bark).convert('RGBA')
            masters[name]=dict(asset='crossgate_flora/'+name,leaf_mean_linear=mean(foliage_colors(leaf_image)),
                bark_mean_linear=mean([p for p in bark_image.getdata() if p[3]>=128 and max(p[:3])>40]),
                source_pins={str(path.relative_to(ROOT)):digest(path) for path in [mesh,leaf,bark]})
        master=masters[name];native_leaf=mean(foliage_colors(clean))
        native_bark=[p for yy in range(clean.height//2,clean.height) for xx in range(clean.width)
                     if (p:=clean.getpixel((xx,yy)))[3]>=128 and p[0]>p[1]*1.08 and p[0]>p[2]*1.15 and max(p[:3])>50]
        bark_mean=mean(native_bark) if native_bark else master['bark_mean_linear']
        graphics[str(serial)]=dict(graphic=serial,kind='whole_master_tree',source_rgba_sha256=g['rgba_sha256'],origin=g['origin'],footprint=g['footprint'],visible=visible,
            asset=master['asset'],native_leaf_mean_linear=native_leaf,foliage_tint=[native_leaf[c]/max(.0001,master['leaf_mean_linear'][c]) for c in range(3)],
            bark_tint=[bark_mean[c]/max(.0001,master['bark_mean_linear'][c]) for c in range(3)],native_bark_samples=len(native_bark),
            inferred='Whole existing mesh/UVs retained; hidden volume and per-ID palette tint inferred from native source. Source rectangle and ownerY=.045/pixel are authoritative; no exact leaf-by-leaf pixel claim.')
        traced_tree(graphics[str(serial)],g,clean)
    assert len(graphics)==27
    data=dict(schema=1,graphics=graphics,masters=masters,source_catalogs=pins,scope='Private source-fit candidate. East object-layer only after existing contextual owners. No source planes, navigation, colliders, actors, shared masters or original paint changed.')
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'data.json').write_text(json.dumps(data,indent=2)+'\n')
    print('Prepared27 source-traced crown/timber trees; original masters and native source pixels untouched')
if __name__=='__main__':prepare()
