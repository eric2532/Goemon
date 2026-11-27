"""Append native southwest Freyja columns without changing the existing Southern Lakes mask."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import sys
from PIL import Image
from build_freyja_outlying import is_road, is_water

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/venoa_field'
BASE=ROOT/'assets/maps/falan/south_lakes_surface.png'
GROUND_INDEX=ROOT/'assets/maps/falan/freyja_ground_index.png'
SOURCE=ROOT.parent/'Magic Power'
OCEAN_INDEX_IMPORT={'compress/mode':'0','mipmaps/generate':'false','process/fix_alpha_border':'false','process/premult_alpha':'false','process/hdr_as_srgb':'false'}


def configure_ocean_index_import(check=False):
    path=OUT/'ocean-index.png.import'
    text=path.read_text()if path.exists()else'[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://assets/maps/falan/venoa_field/ocean-index.png"\n[params]\n'
    for key,value in OCEAN_INDEX_IMPORT.items():
        pattern=r'(?m)^'+re.escape(key)+r'=.*$'
        if check:assert re.search(pattern,text).group(0)==key+'='+value,key
        elif re.search(pattern,text):text=re.sub(pattern,key+'='+value,text)
        else:text+=key+'='+value+'\n'
    if not check:path.write_text(text)


def source_water_surfaces(w,h,ground,source_index):
    """Reuse the source100 water/background forms for a validated floor index."""
    water=Image.new('RGBA',(w,h))
    water.putdata([(255 if is_water(tile)else 0,255 if tile>=1000 and not is_water(tile)else 0,0,255)for tile in ground])
    backdrop=Image.new('RGBA',(w,624),(255,0,0,255))
    for i,tile in enumerate(ground):
        backdrop.putpixel((i%w,i//w),water.getpixel((i%w,i//w))if tile else(255,0,0,255))
    assert source_index.size==(w,h)
    source_pixels=list(source_index.getdata())
    encoded_water={source_pixels[i]for i,tile in enumerate(ground)if tile==5000}
    assert len(encoded_water)==1,'Original graphic5000 must have one existing atlas encoding'
    encoded_water=encoded_water.pop();assert encoded_water[2:]==(255,255)
    ocean_index=Image.new('RGBA',(w,624),encoded_water)
    for i,tile in enumerate(ground):
        if tile:ocean_index.putpixel((i%w,i//w),source_pixels[i])
    assert all(ocean_index.getpixel((i%w,i//w))==(source_pixels[i]if tile else encoded_water)for i,tile in enumerate(ground))
    assert all(pixel==encoded_water for pixel in ocean_index.crop((0,h,w,624)).getdata())
    return water,backdrop,ocean_index,encoded_water


def prepare():
    sys.path.insert(0,str(SOURCE/'tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    with lib.connection()as db:ident=db.execute("SELECT id FROM files WHERE path='BlueCrossgate/map/0/100.dat'").fetchone()[0]
    source_raw=lib.source_file(ident)[1].read_bytes()
    w,h,ground,objects,_=lib.parse_map(source_raw)
    walk=navigation_grid(w,h,ground,objects,lib.serial_index())
    original=Image.open(BASE).convert('RGBA')
    assert original.size==(321,321),'Audit a changed source mask before extending it'
    mask=Image.new('RGBA',(347,321))
    mask.paste(original,(26,0))
    new_open=[];art=[]
    for py in range(321):
        y=303+py
        for px in range(26):
            x=201+px;inside=0<=x<w and 0<=y<h
            tile=ground[y*w+x]if inside else 0
            wet=not tile or is_water(tile)
            pave=220 if 1000<=tile<=1099 or 5954<=tile<=5988 else 0
            mask.putpixel((px,py),(255 if wet else 0,224 if not wet and is_road(tile)else 0,pave,255))
            if inside and walk[y*w+x]:new_open.append([x,y])
            if inside and objects[y*w+x]>=1000:art.append([x,y,objects[y*w+x]])
    assert mask.crop((26,0,347,321)).tobytes()==original.tobytes()
    assert len(new_open)==672,'Re-audit changed source topology before expanding the field'
    visibility=Image.new('RGBA',(1,1),(0,255,0,255))
    # Match the existing Sokia full-source-water convention. Empty/unknown source
    # ground is not silently relabelled as confirmed ocean.
    water,backdrop,ocean_index,encoded_water=source_water_surfaces(w,h,ground,Image.open(GROUND_INDEX).convert('RGBA'))
    for tile,pixel in zip(ground,water.getdata()):
        assert pixel==(255 if is_water(tile)else 0,255 if tile>=1000 and not is_water(tile)else 0,0,255)
    # User-authorized unseen-surface judgment is a separate visual derivative.
    # Preserve all known source pixels; infer ocean only for source0 and the
    # inherited 14 rows beyond original client height. It supplies no new ground.
    for i,tile in enumerate(ground):
        assert backdrop.getpixel((i%w,i//w))==(water.getpixel((i%w,i//w))if tile else(255,0,0,255))
    assert all(pixel==(255,0,0,255)for pixel in backdrop.crop((0,h,w,624)).getdata())
    # Reuse the original graphic5000 atlas index for the inferred background.
    # The canonical index and every nonzero source cell remain unchanged.
    metadata=dict(schema=1,source_map=100,source_dimensions=[w,h],source_sha256=hashlib.sha256(source_raw).hexdigest(),
                  source_bounds=[201,303,347,321],old_source_bounds=[227,303,321,321],old_pixel_offset=[26,0],
                  protected_mask=str(BASE.relative_to(ROOT)),protected_mask_sha256=hashlib.sha256(BASE.read_bytes()).hexdigest(),
                  preserved_rgba_sha256=hashlib.sha256(original.tobytes()).hexdigest(),new_decoder_open_cells=new_open,
                  new_source_art_anchors=art,source_art_status='Required open work; this package extends terrain only',
                  water_dimensions=[w,h],water_rgba_sha256=hashlib.sha256(water.tobytes()).hexdigest(),
                  water_known_tiles=sum(is_water(tile)for tile in ground),water_empty_tiles=sum(tile==0 for tile in ground),
                  water_classification='Full source map100; red=original is_water, green=known non-water ground>=1000. Empty ground0 is not confirmed ocean; no unseen water fill.',
                  ocean_backdrop_dimensions=[w,624],ocean_backdrop_rgba_sha256=hashlib.sha256(backdrop.tobytes()).hexdigest(),
                  ocean_backdrop_inferred_source0_tiles=sum(tile==0 for tile in ground),ocean_backdrop_inferred_south_padding_rows=624-h,
                  ocean_backdrop_known_source_pixels_preserved=sum(tile!=0 for tile in ground),
                  ocean_backdrop_status='Inferred visual background only: original source0 plus south rows610-623 are ocean. Every known source pixel is unchanged; no terrain, route, navigation, support or encounter coverage added.',
                  protected_ground_index=str(GROUND_INDEX.relative_to(ROOT)),protected_ground_index_sha256=hashlib.sha256(GROUND_INDEX.read_bytes()).hexdigest(),
                  ocean_index_dimensions=[w,624],ocean_index_rgba_sha256=hashlib.sha256(ocean_index.tobytes()).hexdigest(),
                  ocean_index_known_source_pixels_preserved=sum(tile!=0 for tile in ground),
                  ocean_index_inferred_tiles=sum(tile==0 for tile in ground)+w*(624-h),
                  ocean_index_reused_graphic=5000,ocean_index_encoded_water=list(encoded_water),
                  ocean_index_first_inferred_source0_cell=[next(i for i,tile in enumerate(ground)if tile==0)%w,next(i for i,tile in enumerate(ground)if tile==0)//w],
                  ocean_index_status='Inferred visual background using original graphic5000 art: only source0 and rows610-623 are filled. Every nonzero source cell retains its canonical index RGBA bytes; no terrain, support, route, navigation or encounter change.',
                  ocean_index_import_contract=OCEAN_INDEX_IMPORT,
                  layout_contract='Existing south_lakes owner and source frame retained; existing1.5field expansion used')
    data='''extends RefCounted
## Generated by tools/prepare_venoa_field.py; original map100 and unchanged legacy mask.
const MASK=preload("res://assets/maps/falan/venoa_field/south_lakes_surface.png")
const VISIBILITY=preload("res://assets/maps/falan/venoa_field/visibility.png")
const WATER=preload("res://assets/maps/falan/venoa_field/water.png")
const OCEAN_BACKDROP=preload("res://assets/maps/falan/venoa_field/ocean-backdrop.png")
const OCEAN_INDEX_PATH="res://assets/maps/falan/venoa_field/ocean-index.png"
const ORIGIN=Vector2(-558,-480)
const EXPANSION=1.5
'''
    return mask,visibility,water,backdrop,ocean_index,metadata,data


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    mask,visibility,water,backdrop,ocean_index,metadata,data=prepare()
    if args.check:
        for name,expected in [('south_lakes_surface.png',mask),('visibility.png',visibility),('water.png',water),('ocean-backdrop.png',backdrop),('ocean-index.png',ocean_index)]:
            actual=Image.open(OUT/name).convert('RGBA');assert actual.size==expected.size and actual.tobytes()==expected.tobytes(),name
        assert json.loads((OUT/'provenance.json').read_text())==metadata
        assert(OUT/'data.gd').read_text()==data
        configure_ocean_index_import(check=True)
    else:
        OUT.mkdir(parents=True,exist_ok=True)
        mask.save(OUT/'south_lakes_surface.png');visibility.save(OUT/'visibility.png');water.save(OUT/'water.png');backdrop.save(OUT/'ocean-backdrop.png');ocean_index.save(OUT/'ocean-index.png')
        (OUT/'provenance.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
        (OUT/'data.gd').write_text(data)
        configure_ocean_index_import()
    print('VENOA_FIELD_SOURCE_CHECK old_pixels=103041 appended_columns=26 new_native_open_cells=672 art_anchors_open='+str(len(metadata['new_source_art_anchors']))+' water_source_pixels='+str(water.width*water.height)+' backdrop_pixels='+str(backdrop.width*backdrop.height)+' ocean_index_known_pixels='+str(metadata['ocean_index_known_source_pixels_preserved'])+' original_water_graphic='+str(metadata['ocean_index_reused_graphic']))


if __name__=='__main__':main()
