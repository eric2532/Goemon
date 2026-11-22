"""Recover the two coastal villages' original architecture and complete room fixtures."""
import sys
from pathlib import Path
from PIL import Image
import build_falan_room_art as rooms
from build_freyja_destinations import load_map, VENOA_ROOMS, KILI_ROOMS

# Wall/eave and roof rise, measured in pixels at the original near corner.
BUILDINGS = {
    11290:(155,0),11289:(145,0),11292:(160,0),11293:(132,0),
    11294:(160,0),11295:(145,0),11298:(145,0),11297:(95,0),
    11279:(125,115),11276:(135,118),11284:(165,130),
    11280:(125,120),11286:(125,118),11283:(140,120),
}
WALLS = rooms.WALLS | rooms.FREYJA_WALLS | {
    *range(16767,16773),16783,16795,16799,16800,16801,16802,16810,
    16930,16931,16932,16936,16937,16938,16945,16946,16988,16989,16990,16991,
}
KINDS = {
    **rooms.KIND,**rooms.FREYJA_KIND,**rooms.GHANA_KIND,**rooms.CELLAR_KIND,
    16500:'bench',16501:'bench',16502:'bed',17532:'bench',17534:'coast_stool',
    16530:'coast_stool',16786:'coast_stool',16787:'coast_stool',
    16527:'coast_dining',16528:'coast_dining',16537:'coast_desk',16558:'coast_desk',16560:'coast_desk',
    16788:'inn_table',16640:'coast_rug',16641:'coast_rug',16642:'coast_rug',16582:'coast_rug',
    16808:'coast_basin',16809:'coast_basin',16612:'coast_trough',16613:'coast_trough',
    16619:'coast_stove',16620:'coast_stove',16621:'coast_stove',
    16789:'coast_counter',16826:'coast_counter',16842:'coast_counter',16856:'coast_counter',
    16811:'coast_weapons',16812:'coast_weapons',16815:'coast_weapons',16748:'coast_display',16751:'coast_weapons',16752:'coast_weapons',
    16753:'coast_weapons',16755:'coast_weapons',16757:'coast_weapons',16759:'coast_weapons',
    16761:'coast_weapons',16762:'coast_display',16764:'coast_display',
    16773:'coast_goods',16774:'coast_goods',16775:'coast_goods',16776:'coast_goods',
    16777:'coast_goods',16778:'coast_counter',16779:'coast_counter',
    16780:'coast_robe',16781:'coast_robe',16782:'coast_robe',
    10539:'coast_pot',16520:'coast_pot',16790:'coast_pot',16791:'coast_pot',16793:'coast_pot',16794:'coast_pot',
    16524:'crate',10540:'inn_produce',16869:'coast_counter',
    10542:'inn_sack',10543:'coast_basket',11007:'coast_basket',16601:'coast_basket',
    16623:'coast_basket',16625:'inn_sack',10533:'inn_produce',10549:'inn_produce',16176:'inn_produce',
    16509:'coast_basket',16174:'crate',16181:'coast_bin',16535:'coast_bin',
    16505:'coast_cabinet',16507:'coast_cabinet',16525:'coast_shelf',16526:'coast_shelf',
    16578:'coast_apothecary',16583:'coast_cabinet',16584:'coast_apothecary',16827:'coast_apothecary',
    17004:'coast_cabinet',17587:'coast_apothecary',16579:'chest',17531:'civic_screen',
    16540:'coast_clock',16541:'coast_clock',16548:'coast_tool',16549:'coast_tool',
    11063:'coast_tool',11065:'coast_tool',16816:'coast_tool',
    10524:'coast_picture',11105:'coast_picture',11117:'coast_picture',11118:'coast_picture',
    16556:'coast_picture',16585:'coast_picture',16586:'coast_picture',16600:'coast_picture',16653:'coast_picture',
    16803:'coast_picture',17604:'coast_picture',16797:'coast_picture',16798:'coast_picture',
    16597:'coast_wreath',16598:'coast_wreath',16622:'coast_lute',16647:'coast_bird',
    16605:'coast_wheel',16630:'coast_hammock',16928:'coast_post',
    16564:'coast_hanging',16635:'coast_hanging',
    10541:'coast_shelf',10554:'coast_scale',10561:'coast_candles',10574:'chest',10577:'chest',
    11001:'coast_logs',16208:'plant',16210:'plant',16221:'coast_flowers',16222:'coast_flowers',
    16228:'plant',16230:'plant',11435:'coast_flowers',12173:'plant',
    16608:'coast_dining',17235:'lectern',17240:'moon',
    16628:'coast_stair',16629:'coast_stair',16590:'coast_stair',16592:'coast_stair',16594:'coast_stair',16595:'coast_stair',
    10020:'coast_side_barrel',10498:'coast_open_crate',17626:'coast_open_crate',
    10509:'coast_book',10548:'coast_embers',16172:'coast_cushion',16547:'coast_fruit',
    16624:'inn_sack',16639:'coast_rug',16650:'coast_pot',16814:'coast_display',
    16817:'coast_tool',17195:'coast_candles',17561:'coast_picture',
}
STAIRS={12000,12001,12002}


def atlas(library, lookup, serials, path, width):
    placements={};x=y=row_h=0
    images=[]
    for serial in sorted(serials):
        e=lookup[serial];im=library.image_from_record(e['pack'],e['row'],0)
        assert im.width+4<=width
        if x+im.width+4>width:x=0;y+=row_h;row_h=0
        placements[serial]=(x+2,y+2,im.width,im.height)
        images.append((im,(x+2,y+2)));x+=im.width+4;row_h=max(row_h,im.height+4)
    image=Image.new('RGBA',(width,y+row_h))
    for im,p in images:image.alpha_composite(im,p)
    image.save(path,optimize=True)
    return placements


def build(library,lookup,output):
    interiors={};used=set();counts={};grounds={}
    for ident in sorted((VENOA_ROOMS|KILI_ROOMS)-{2100,3200}):
        w,h,ground,objects,_=load_map(library,ident)
        grounds[ident]=ground
        rows=[]
        for i,serial in enumerate(objects):
            if serial<1000 or serial in STAIRS:continue
            assert serial in lookup,(ident,serial)
            kind='coast_wall' if serial in WALLS else KINDS.get(serial)
            if kind=='counter' or kind=='table' and 16566<=serial<=16577:kind='coast_counter'
            assert kind is not None,('unclassified coastal furnishing',ident,serial)
            e=lookup[serial];ew,ns=max(1,e['east']),max(1,e['south'])
            rows.append(f'  [Vector2i({i%w},{i//w-ns+1}),Vector2i({ew},{ns}),"{kind}",{serial}],')
            used.add(serial)
        interiors[ident]=rows;counts[ident]=len(rows)
    floor_serials=sorted({s for ground in grounds.values() for s in ground if s})
    floor_index={s:i+1 for i,s in enumerate(floor_serials)}
    floor_atlas=Image.new('RGB',(rooms.COLS*rooms.STRIDE,((len(floor_serials)+rooms.COLS-1)//rooms.COLS)*rooms.STRIDE))
    for i,serial in enumerate(floor_serials):
        e=lookup[serial]
        assert e['w']==64 and e['h'] in (47,48),(serial,e['w'],e['h'])
        floor_atlas.paste(rooms.project_tile(library.image_from_record(e['pack'],e['row'],0)),(i%rooms.COLS*rooms.STRIDE,i//rooms.COLS*rooms.STRIDE))
    floor_atlas.save(output/'coastal_room_floors.png',optimize=True)
    files=[('coastal_building_art',set(BUILDINGS),2048),('coastal_room_props',used,2048)]
    for name,serials,width in files:
        placements=atlas(library,lookup,serials,output/(name+'.png'),width)
        lines=['extends RefCounted','## Recovered by build_coastal_villages.py; original palette and source anchors.','const GRAPHICS={']
        for serial in sorted(serials):
            e=lookup[serial];ew,ns=max(1,e['east']),max(1,e['south'])
            rect=','.join(map(str,placements[serial]))
            center=(-e['x']+(ew-ns)*16,-e['y']-(ew+ns-2)*12)
            lines.append(f' {serial}:[Rect2({rect}),Vector2({center[0]},{center[1]}),Vector2({ew*3},{ns*3}),{e["h"]}],')
        lines.append('}')
        if name=='coastal_building_art':
            lines+=['const PROFILES={']+[f' {s}:Vector2({h},{r}),' for s,(h,r) in BUILDINGS.items()]+['}']
        else:
            lines+=['const FLOORS={']+[f' {ident}:"{rooms.pack_grid(floor_index.get(s,0) for s in ground)}",' for ident,ground in grounds.items()]+['}']
            lines+=['const ROOMS={']
            for ident,rows in interiors.items():lines += [f' {ident}:[',*rows,' ],']
            lines+=['}']
        (output/(name+'.gd')).write_text('\n'.join(lines)+'\n')
    print('Coastal room source objects:',counts)
    print('Original graphic coverage:',len(used),'room graphics,',len(BUILDINGS),'building graphics')


if __name__=='__main__':
    source=Path(sys.argv[1]).resolve();sys.path.insert(0,str(source/'tools'))
    import cg_library
    build(cg_library,cg_library.serial_index(),Path(__file__).resolve().parents[1]/'assets/maps/falan')
