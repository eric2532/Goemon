"""Il/Alyut source prop inventory and alpha paint, reusing established native geometry owners."""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path
from PIL import Image, ImageOps
from build_freyja_destinations import load_map
from build_coastal_villages import KINDS
from prepare_il_laruka import EXTRA
from recover_venoa_walls import native_without_ground_shadow
from prepare_elsa_scenery import outline

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_village_props'
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props'
BUILDINGS={10603,10607,11268,11269,11271,11272,11273,11275}
GATES={11032,11077,11078,11140,11141,11142,11144,11147,11148}
THIN={10551,11014,11024,11031,11043,11057,11104,11112,11113,11116,11122,11126,11496,11497,11065,11066,16549,11075,11076,11079,11080,11149,*range(10454,10462)}
FLORA={10040,10042,11087,11088,11089,11090,11091,11092,11095,11096,11097,11100,11101,11108,11109,11626,12198,*range(12164,12186)}
CROWNS={12172:[{'foot':[40,59],'height':2.6,'width':2.25},{'foot':[17,66],'height':2.0,'width':1.8}],
        12173:[{'foot':[18,61],'height':2.65,'width':2.2},{'foot':[43,69],'height':2.1,'width':1.8}],
        12174:[{'foot':[21,61],'height':2.65,'width':2.2}]}
OVERRIDES={11044:'well_housing',11072:'roofed_well',11082:'stable',11014:'logstore',11037:'pond',11002:'tub',10034:'relief',
           10452:'planter',10453:'planter',11019:'hay',11020:'hay',11021:'hay',11094:'hay',
           12165:'stump',12167:'stump',12168:'stump',12155:'ground',11034:'ground',11067:'ground'}
FAMILIES={**KINDS,**{s:kind for kind,ids in EXTRA.items() for s in ids}}


def mode(serial):
    if serial in CROWNS:return 'flowering_tree'
    if serial in OVERRIDES:return OVERRIDES[serial]
    if serial in THIN:return 'relief'
    if serial in FLORA:return 'flora'
    if serial in [11022,11023]:return 'shared_cart'
    if serial in [11016,11017,11018,10530]:return 'crate'
    if serial in [10014,10016,10017,10018,11139]:return 'barrel'
    if serial in [11001,11011,11012]:return 'logs'
    if serial in [11035,11036,12112,12114,12130,12148,12233,12236,12238,12240,12244]:return 'boulder'
    return 'existing'


def prepare(map_loader=load_map, source_overrides=None):
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    lookup=lib.serial_index();areas={};source_maps={};used=set();audits=[]
    for ident,name in [(2000,'il_village'),(2400,'alyut')]:
        w,h,ground,objects,flags=map_loader(lib,ident)
        with lib.connection() as db:record=dict(db.execute('SELECT * FROM files WHERE path=?',(f'BlueCrossgate/map/0/{ident}.dat',)).fetchone())
        raw=(lib.SOURCE/record['path']).read_bytes();source_maps[name]={'id':ident,'path':record['path'],'sha256':hashlib.sha256(raw).hexdigest(),'size':[w,h]}
        if source_overrides and ident in source_overrides:source_maps[name]=dict(source_overrides[ident],id=ident,size=[w,h])
        rows=[]
        for i,serial in enumerate(objects):
            if serial<1000:
                if serial:audits.append({'map':ident,'cell':[i%w,i//w],'graphic':serial,'status':'existing_map_marker_owner','mode':None})
                continue
            assert serial in lookup,('Missing native village graphic',ident,i%w,i//w,serial)
            reason='native_prop'
            if serial in BUILDINGS:reason='existing_building_owner'
            elif serial in GATES:reason='existing_gate_owner'
            elif serial in range(10050,10100):reason='existing_tree_owner'
            elif serial in range(12500,13400):reason='existing_shore_cliff_owner'
            elif serial==17644:reason='source_blank'
            elif lookup[serial]['ground'] and serial!=11067:reason='existing_ground_object_owner'
            audits.append({'map':ident,'cell':[i%w,i//w],'graphic':serial,'status':reason,'mode':mode(serial) if reason=='native_prop' else None})
            if reason!='native_prop':continue
            rows.append([i%w,i//w,serial]);used.add(serial)
        areas[name]=rows
    images={};graphics={}
    for serial in sorted(used):
        row=lookup[serial];original=lib.image_from_record(row['pack'],row['row']).convert('RGBA')
        clean,shadow=native_without_ground_shadow(original)
        assert all(original.getpixel((x,y))[:3]==clean.getpixel((x,y))[:3] for y in range(original.height) for x in range(original.width))
        images[serial]=clean
        graphics[str(serial)]={'origin':[row['x'],row['y']],'footprint':[max(1,row['east']),max(1,row['south'])],
            'ground':row['ground'],'family':FAMILIES.get(serial,''),'mode':mode(serial),'pack':row['pack'],'row':row['row'],
            'source_rgba_sha256':hashlib.sha256(original.tobytes()).hexdigest(),'prepared_rgba_sha256':hashlib.sha256(clean.tobytes()).hexdigest(),
            'shadow_pixels_removed':len(shadow),'bounds':list(clean.getbbox() or (0,0,1,1)),
            'outline':outline(clean) if mode(serial) in ['relief','flora','ground','pond'] else [],'crowns':CROWNS.get(serial,[])}
    positions={};x=y=line=0;width=2048
    for serial,im in images.items():
        if x+im.width+2>width:x=0;y+=line;line=0
        positions[serial]=[x+1,y+1,im.width,im.height];x+=im.width+2;line=max(line,im.height+2)
    atlas=Image.new('RGBA',(width,y+line))
    for serial,im in images.items():
        r=positions[serial];atlas.paste(im,(r[0],r[1]));graphics[str(serial)]['rect']=r
    blob=io.BytesIO();atlas.save(blob,format='PNG',optimize=True)
    shared=Image.open(ROOT/'assets/maps/falan/il_laruka/building-surfaces.png').convert('RGBA')
    surfaces=Image.new('RGBA',(shared.width,shared.height+256));surfaces.paste(shared,(0,0))
    stone_crop=[83,148,87,152]
    patch=images[11072].crop(stone_crop);assert patch.getchannel('A').getextrema()==(255,255)
    half=patch.resize((64,64),Image.Resampling.BICUBIC)
    tile=Image.new('RGBA',(128,128));tile.paste(half,(0,0));tile.paste(ImageOps.mirror(half),(64,0))
    tile.paste(ImageOps.flip(tile.crop((0,0,128,64))),(0,64));surfaces.paste(tile,(0,shared.height))
    wood=Image.open(ROOT/'assets/maps/original_crossgate/building-surfaces.png').convert('RGBA').crop((256,1664,384,1792))
    surfaces.paste(wood,(128,shared.height))
    cart_plank=Image.open(ROOT/'assets/maps/original_crossgate/building-surfaces.png').convert('RGBA').crop((128,2176,256,2304))
    surfaces.paste(cart_plank,(256,shared.height))
    original_surfaces=Image.open(ROOT/'assets/maps/original_crossgate/building-surfaces.png').convert('RGBA')
    log_bark=original_surfaces.crop((0,2304,128,2432));log_end=original_surfaces.crop((128,1792,256,1920))
    surfaces.paste(log_bark,(384,shared.height));surfaces.paste(log_end,(0,shared.height+128))
    surface_blob=io.BytesIO();surfaces.save(surface_blob,format='PNG',optimize=True)
    data={'schema':1,'areas':areas,'graphics':graphics,'source_maps':source_maps,
          'surface_patches':{'well_stone':{'graphic':11072,'crop':stone_crop,'tile':[0,shared.height],'source_crop_rgba_sha256':hashlib.sha256(patch.tobytes()).hexdigest()},
                            'fixture_wood':{'reused_prepared_tile':'assets/maps/original_crossgate/building-surfaces.png::tina_fence_wood','tile':[128,shared.height],'rgba_sha256':hashlib.sha256(wood.tobytes()).hexdigest()},
                            'cart_plank':{'reused_prepared_tile':'assets/maps/original_crossgate/building-surfaces.png::tina_box_plank','tile':[256,shared.height],'rgba_sha256':hashlib.sha256(cart_plank.tobytes()).hexdigest()},
                            'tina_log_bark':{'reused_prepared_tile':'assets/maps/original_crossgate/building-surfaces.png::tina_hollow_bark','tile':[384,shared.height],'rgba_sha256':hashlib.sha256(log_bark.tobytes()).hexdigest()},
                            'tina_log_end':{'reused_prepared_tile':'assets/maps/original_crossgate/building-surfaces.png::tina_log_end','tile':[0,shared.height+128],'rgba_sha256':hashlib.sha256(log_end.tobytes()).hexdigest()}},
          'audit':audits,'render_rule':'Every prop uses its source cell. Fine cutouts preserve source RGB and remove only the known checkerboard ground shadow. Geometry, hidden depth and source-crown-to-existing-tree fits are inferred.',
          'existing_models':['forest_original_map_details.gd::well','forest_coastal_buildings.gd','forest_il_laruka_buildings.gd::bar/roof','forest_falan_market_goods.gd::flower_cart wheel/rim/spokes','Wind Meadow cg_silverleaf/flora'],
          'preservation':'No source map, original artwork, collision, route, NPC, encounter or quest owner is edited.'}
    return {'native.png':blob.getvalue(),'surfaces.png':surface_blob.getvalue(),'data.json':(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args();products=prepare()
    if args.check:assert all((OUT/name).read_bytes()==body for name,body in products.items()),'Stale village-prop derivative'
    else:
        OUT.mkdir(exist_ok=True,parents=True)
        for name,body in products.items():(OUT/name).write_bytes(body)
    data=json.loads(products['data.json']);print('EAST_VILLAGE_PROPS',len(data['graphics']),'graphics;',*[f'{k}:{len(v)}' for k,v in data['areas'].items()])

if __name__=='__main__':main()
