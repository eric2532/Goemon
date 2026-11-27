"""Prepare Il/Laruka's native footprints, visible roof profiles and complete object inventory."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image
from build_freyja_destinations import load_map, warp_rows
from build_coastal_villages import KINDS, WALLS, STAIRS
import build_coastal_villages as coastal
from build_falan_room_art import PALACE_KIND, CIVIC_KIND, ARENA_KIND, project_tile, pack_grid, COLS, STRIDE
from build_freyja_surface import build as ground_surface
from recover_venoa_walls import solid_native_paint
from recover_original_crossgate_maps import rock_surfaces
from build_village_building_surfaces import PATCHES, surface_atlas

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan/il_laruka'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Il and Laruka'
BUILDINGS = {11268,11272,11273,11275,10607,11279,11286,11106,11284,11285,11281,10603}
WATERFRONT = {38043,38044,38046,38051}
# Visible feet, end roof and matching far ridge, in unmodified source pixels.
FORMS = {
    11272: dict(floor=[[30,282],[185,403],[337,294]],end='right',
                roof=[[179,314],[198,280],[221,232],[247,185],[270,144],[300,164],[330,183],[359,202]],peak=4,rear=[103,24],
                dormers=[dict(face='left',anchor=[83,145],roof=[[59,81],[72,69],[88,81],[105,93]],peak=1,rear=[124,31]),
                         dict(face='left',anchor=[219,220],roof=[[197,177],[210,162],[228,175],[244,187]],peak=1,rear=[262,112])]),
    11273: dict(floor=[[32,280],[205,407],[364,294]],end='right',
                roof=[[198,321],[216,282],[241,232],[267,183],[292,140],[320,157],[356,180],[389,200]],peak=4,rear=[112,22],
                dormers=[dict(face='left',anchor=[169,190],roof=[[135,121],[157,101],[175,112],[200,131]],peak=1,rear=[223,52])]),
    11275: dict(floor=[[89,313],[180,398],[365,270]],end='left',
                roof=[[13,200],[35,181],[57,163],[80,149],[104,184],[129,223],[152,262],[174,301]],peak=3,rear=[261,20],
                canopies=[[[[17,243],4.5],[[72,216],6.3],[[112,244],6.3],[[54,272],4.5]]],
                dormers=[dict(face='right',anchor=[235,169],roof=[[211,102],[226,89],[245,100],[264,114]],peak=1,rear=[183,59]),
                         dict(face='right',anchor=[335,155],roof=[[306,39],[321,25],[340,35],[357,50]],peak=1,rear=[278,0])]),
    11106: dict(floor=[[42,315],[209,446],[353,341]],end='right',
                roof=[[201,335],[222,291],[245,242],[271,192],[299,141],[324,158],[351,180],[378,202]],peak=4,rear=[116,15],
                dormers=[dict(face='left',anchor=[113,133],roof=[[92,72],[103,52],[119,38],[137,62],[145,89]],peak=2,rear=[175,0]),
                         dict(face='left',anchor=[245,211],roof=[[227,179],[239,157],[254,142],[269,162],[279,189]],peak=2,rear=[310,104])]),
    11281: dict(floor=[[21,290],[188,414],[333,314]],end='right',
                roof=[[192,328],[211,290],[236,241],[263,193],[289,145],[316,161],[341,181],[360,197]],peak=4,rear=[125,32],
                pots=[dict(base=[110,92],top=[110,39],width=2.5,holes=[[102,15],[122,7]]),
                      dict(base=[253,187],top=[253,128],width=2.5,holes=[[242,105],[263,96]])]),
    11285: dict(floor=[[39,339],[189,467],[365,340]],end='right',
                roof=[[182,364],[204,321],[232,266],[258,211],[286,154],[313,177],[348,204],[393,236]],peak=4,rear=[119,53],
                porches=[dict(face='left',anchor=[98,343],roof=[[12,258],[55,229],[104,253],[147,290]],peak=1,rear=[98,198])]),
}

EXTRA = {
 'coast_counter':[10492,16102,16110,16536,17622], 'coast_cabinet':[10442,10490,16506,16513,16533,16534,17000,17637],
 'coast_picture':[10527,11121,16557,17565,17607,17608], 'coast_tool':[16521,16522],
 'coast_pot':[10553,10564,10581,16519], 'coast_basket':[10546,16580,16581],
 'coast_goods':[10535,10536,10537,10538], 'coast_weapons':[16749,16750,16754],
 'coast_display':[16763,17166], 'coast_clock':[10495], 'coast_stair':[16593],
 'coast_rug':[17603,17605,17606], 'coast_shelf':[10534,16587], 'coast_dining':[16565],
 'coast_hanging':[16555], 'coast_logs':[11010,11011,11012], 'coast_robe':[16654,16655,16656],
 'chest':[10445,10447], 'crate':[10532,16818], 'plant':[16209,16211,16215,16231,10036],
 'bench':[10038], 'chair':[16006], 'table':[10523], 'armor':[17033],
 'room_wall':list(range(16952,16988))+[17612,17613,17621,17639],
 'detail_flat_panel':[10555,10556,10573,16546,17193,17562],
 'detail_tools':[17627,17628,17634], 'detail_bellows':[17631], 'detail_boiler':[16643],
 'detail_round_table':[16529], 'detail_empty_basket':[16539],
 'detail_bust':[17171,17173,17174,17216,17217,17218,17220,17229,16128],
 'detail_piano':[16515,16516], 'detail_spinning':[16603,16604],
 'coast_stove':[16538,17636,17638], 'coast_desk':[17633], 'boulder':[11035,17630],
 'void':[17644,17649],
}

def prepare_surfaces(source):
    sys.path.insert(0,str(source/'tools'))
    import cg_library as lib
    lookup=laruka_lookup(lib)
    patches={**PATCHES,
        'timber':(11281,[(180,290)]*4,False,(64,64)),
        'trim':(11272,[(95,117)]*4,False,(64,64)),
        'pink_roof':(11106,[(35,148),(67,170),(91,127),(60,105)],False,(64,64)),
        'slate_roof':(11285,[(129,160),(185,199),(213,152),(157,114)],False,(64,64)),
        'woodwall':(11281,[(35,246)]*4,False,(64,64)),
        'blue_plaster':PATCHES['plaster'],
        'laruka_window':(11281,[(54,220),(87,243),(87,279),(54,256)],True,(60,92)),
        'laruka_door':(11281,[(155,260),(185,283),(185,352),(155,329)],True,(48,110)),
        'pub_sign':(11285,[(51,217),(145,263),(145,309),(51,263)],True,(112,64)),
        'flue_dark':(11281,[(114,18)]*4,False,(64,64)),
        'ridge_cap':(11272,[(149,35)]*4,False,(64,64)),
        'equipment_sign':(11284,[(408,294),(443,274),(443,326),(408,347)],True,(55,96)),
        'fruit_orange':(11106,[(32,322)]*4,False,(64,64)),
        'fruit_green':(11106,[(62,338)]*4,False,(64,64)),
        'fruit_yellow':(11106,[(41,328)]*4,False,(64,64)),
        'quay_brick':(38043,[(2,43),(27,59),(27,128),(2,112)],False,(64,112)),
        'quay_paving':(25290,[(32,1),(63,24),(32,46),(1,24)],False,(96,96))}
    images={}
    for s in {r[0] for r in patches.values()}:
        e=lookup[s];images[s]=solid_native_paint(lib.image_from_record(e['pack'],e['row']))[0]
    atlas,rows=surface_atlas(images,patches)
    atlas.save(OUT/'building-surfaces.png',optimize=True)
    (OUT/'building-surfaces.gd').write_text('\n'.join(rows+['}'])+'\n')
    (OUT/'building-surfaces.json').write_text(json.dumps(patches,indent=2)+'\n')
    e=lookup[11268]
    lib.image_from_record(e['pack'],e['row']).crop((167,0,208,58)).save(OUT/'chief-rooster.png',optimize=True)

def lower_floor(lib,lookup):
    """The server-only 2307 plan uses the existing room-floor projection contract."""
    w,h,ground,_,_=load_map(lib,2307)
    tiles={};images=[]
    for serial in sorted(set(ground)-{0}):
        e=lookup[serial]
        assert (e['w'],e['h'])==(64,47),serial
        tiles[serial]=len(images)+1
        images.append(project_tile(lib.image_from_record(e['pack'],e['row'])))
    atlas=Image.new('RGB',(COLS*STRIDE,STRIDE))
    for i,image in enumerate(images):atlas.paste(image,(i*STRIDE,0))
    atlas.save(OUT/'lower-floor.png',optimize=True)
    return pack_grid(tiles.get(serial,0) for serial in ground)

def laruka_lookup(lib):
    # DAT stores expansion map IDs minus 200000; unexpanded IDs can collide with UI art.
    _,_,ground,objects,_=load_map(lib,2300)
    compressed={s for s in ground if s>=20000}|{s for s in objects if s==25290 or s>=30000}
    lookup=lib.serial_index().copy()
    with lib.connection() as db:
        for serial in sorted(compressed):
            row=db.execute('SELECT pack,row,serial,x,y,w,h,east,south,ground FROM graphics WHERE serial=? ORDER BY pack_order,row LIMIT 1',
                           (serial+200000,)).fetchone()
            assert row is not None,('Unresolved Laruka expansion graphic',serial)
            lookup[serial]={**dict(row),'source_serial':serial+200000}
    return lookup

def waterfront_mask(lib):
    w,h,_,objects,_=load_map(lib,2300)
    mask=Image.open(ROOT/'assets/maps/falan/freyja_laruka.png').convert('RGBA')
    assert mask.size==(w,h)
    for i,serial in enumerate(objects):
        if serial in WATERFRONT:mask.putpixel((i%w,i//w),(0,0,0,255))
    mask.save(OUT/'laruka-mask.png',optimize=True)

def quay_cells(lib):
    w,_,ground,objects,_=load_map(lib,2300)
    cells=[(i%w,i//w) for i,s in enumerate(ground) if s==25290]
    assert len(cells)==60
    caps=[(i%w,i//w) for i,s in enumerate(objects) if s in WATERFRONT]
    (OUT/'quay-cells.gd').write_text('extends RefCounted\n## Original 2300 paving cells; generated by prepare_il_laruka.py.\nconst CELLS={\n'+
        '\n'.join(f' Vector2i({x},{z}):true,' for x,z in cells)+'\n}\nconst CAPS={\n'+
        '\n'.join(f' Vector2i({x},{z}):true,' for x,z in caps)+'\n}\n')

def prepare(source):
    sys.path.insert(0,str(source/'tools'))
    import cg_library as lib
    lookup=laruka_lookup(lib)
    warps=list(warp_rows(source));ids={2000,2300}
    while True:
        extra={r[3] for r in warps if r[0] in ids and (2000<=r[3]<2100 or 2300<=r[3]<2400)}-ids
        if not extra:break
        ids |= extra
    shared_kinds={s:getattr(coastal,'NATIVE_FAMILIES',{}).get(s,k) if k=='coast_native' else k for s,k in KINDS.items()}
    kinds={**shared_kinds,**PALACE_KIND,**CIVIC_KIND,**ARENA_KIND,**{s:k for k,ss in EXTRA.items() for s in ss}}
    maps={};used=set();sources={};summary={};missing=[]
    for ident in sorted(ids):
        w,h,floor,objects,_=load_map(lib,ident)
        rows=[]
        for i,s in enumerate(objects):
            if s<1000 or s in STAIRS:continue
            if s not in lookup:
                missing.append([ident,i%w,i//w,s]);continue
            kind='room_wall' if s in WALLS else kinds.get(s,'')
            if ident not in [2000,2300]:assert kind,('Unreviewed room graphic',ident,s)
            rows.append([i%w,i//w,s,kind]);used.add(s)
        maps[ident]=rows
        summary[ident]={'size':[w,h],'objects':len(rows),'buildings':sum(r[2] in BUILDINGS for r in rows),
                        'blocked_source':False,'ground_sha256':hashlib.sha256(bytes().join(int(s).to_bytes(2,'little') for s in floor)).hexdigest()}
        if ident==2307:
            path=ROOT/'assets/references/crossgate_laruka_basement/02307_sozai'
            sources[ident]={'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                            'url':'https://github.com/linv2/Crossgate_Docker/blob/dd8690ed3df11e4eb5a038a54079a8f40d8e93b3/gmsv/data/map/02307_sozai'}
            continue
        with lib.connection() as db:
            fid=db.execute('SELECT id FROM files WHERE path=?',(f'BlueCrossgate/map/0/{ident}.dat',)).fetchone()[0]
        info,path=lib.source_file(fid)
        sources[ident]={'path':info['path'],'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    # Separate opaque paint from the lossless original source. Original RGB remains untouched.
    images={};records={};x=y=row_h=0
    for s in sorted(used):
        e=lookup[s];im=lib.image_from_record(e['pack'],e['row'])
        if x+im.width+4>4096:x=0;y+=row_h;row_h=0
        paint,_=solid_native_paint(im)
        records[s]={'rect':[x+2,y+2,im.width,im.height],'origin':[e['x'],e['y']],'page':0,
                    'footprint':[max(1,e['east']),max(1,e['south'])],'ground':e['ground'],'family':kinds.get(s,''),
                    'rgba_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
        if 'source_serial' in e:
            records[s].update(source_serial=e['source_serial'],pack=e['pack'],row=e['row'],shore_bank=s in WATERFRONT)
        images[s]=(paint,(x+2,y+2));x+=im.width+4;row_h=max(row_h,im.height+4)
    atlas=Image.new('RGBA',(4096,y+row_h))
    for s,(im,at) in images.items():atlas.paste(im,at)
    OUT.mkdir(parents=True,exist_ok=True);REPORT.mkdir(parents=True,exist_ok=True)
    atlas.save(OUT/'paint.png',optimize=True)
    surfaces=rock_surfaces({'graphics':records},[atlas])
    for i,surface in enumerate(surfaces):surface.save(OUT/f'surfaces-{i}.png',optimize=True)
    forms={}
    for s,form in FORMS.items():
        form=json.loads(json.dumps(form));g=records[s];e=lookup[s]
        for pot in form.get('pots',[]):
            original=lib.image_from_record(e['pack'],e['row'])
            assert all(0<=p[0]<original.width and 0<=p[1]<original.height for p in pot['holes'])
        forms[s]={**form,'rect':g['rect'],'origin':[-e['x']+(e['east']-e['south'])*16,-e['y']-(e['east']+e['south']-2)*12]}
    lines=['extends RefCounted','## Generated by tools/prepare_il_laruka.py. Source is read only.',
           'const ATLAS=preload("res://assets/maps/falan/il_laruka/paint.png")',
           'const SURFACES=['+','.join(f'preload("res://assets/maps/falan/il_laruka/surfaces-{i}.png")' for i in range(len(surfaces)))+']',
           'const GRAPHICS='+json.dumps(records,separators=(',',':')),
           'const FORMS={']
    lines += [f' {s}:'+json.dumps(form,separators=(',',':'))+',' for s,form in forms.items()]
    lines += ['}','const MAPS={']+[f' {i}:'+json.dumps(rows,separators=(',',':'))+',' for i,rows in maps.items()]+['}']
    lines += ['const SIZES={']+[f' {i}:Vector2i({r["size"][0]},{r["size"][1]}),' for i,r in summary.items()]+['}']
    lines += ['const BUILDINGS='+str(sorted(BUILDINGS))]
    lines += ['const LOWER_FLOOR_ATLAS=preload("res://assets/maps/falan/il_laruka/lower-floor.png")',
              'const LARUKA_MASK=preload("res://assets/maps/falan/il_laruka/laruka-mask.png")',
              'const FLOORS={2307:'+json.dumps(lower_floor(lib,lookup))+'}']
    (OUT/'data.gd').write_text('\n'.join(lines)+'\n')
    manifest={'sources':sources,'maps':summary,'graphics':records,'warps':[r for r in warps if r[0] in ids or r[3] in [2000,2300]],
              'expansion_map_ids':{s:{'source_serial':e['source_serial'],'pack':e['pack'],'row':e['row'],
                                      'rgba_sha256':hashlib.sha256(lib.image_from_record(e['pack'],e['row']).tobytes()).hexdigest()}
                                   for s,e in lookup.items() if 'source_serial' in e},
              'blockers':{},
              'missing_graphics':missing,
              'limits':'Visible feet and roof profiles traced from original art. Hidden depth/reverse paint inferred, not recovered original 3D.'}
    (OUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
    ground_surface(source,OUT,2300,lookup)
    waterfront_mask(lib)
    quay_cells(lib)
    prepare_surfaces(source)
    print('Prepared',len(ids),'maps,',len(used),'graphics;',summary)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power')
    args=parser.parse_args();prepare(args.source.resolve())
