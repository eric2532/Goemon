"""Recover the six city rooms omitted by the old blocked-cell fixture filter."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory

from PIL import Image
from build_coastal_villages import KINDS, atlas
from build_falan_room_art import WALLS
from build_freyja_destinations import load_map

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan'
ROOMS = (1810, 1811, 1156, 1182, 1181, 1172)
# Reviewed against the original sprites, including walkable benches and stools.
FAMILIES = {
    **KINDS,
    10031:'city_conifer',10036:'city_plant_table',10038:'city_bench',10043:'city_flower_cart',
    10426:'city_planter',10436:'city_clock',10452:'city_planter',10453:'city_planter',
    **dict.fromkeys((10454,10456,10457,10458,10459,10460,10461),'city_fence'),
    10541:'coast_shelf',10567:'city_panel',11000:'coast_logs',11002:'coast_basin',11005:'detail_drying',
    11020:'detail_hay',11035:'detail_hay',
    **dict.fromkeys((11087,11088,11089,11090,11091,11092),'city_crop'),
    **dict.fromkeys((11017,11018,11019,11066,16552,16553),'city_crate'),
    16006:'chair',16007:'chair',16008:'chair',16009:'chair',16014:'city_wardrobe',16021:'city_wardrobe',
    16024:'city_drawers',16060:'city_bed',16063:'city_bed',16076:'table',16128:'regional_royal_fixture',
    16133:'city_panel',16136:'city_panel',16164:'city_kitchen_counter',16179:'table',16190:'coast_basket',
    16203:'city_red_stool',16219:'coast_flowers',16231:'plant',16501:'city_bench',16503:'city_bed',16521:'coast_tool',16522:'coast_tool',
    16533:'coast_cabinet',16534:'shelf',16541:'city_panel',16557:'city_panel',16585:'city_panel',
    16602:'detail_food',16604:'detail_spinning',16636:'coast_hanging',16875:'city_counter_tile',
    17011:'city_vanity',17194:'detail_books',17520:'city_panel',17532:'city_bench_segment',17563:'city_panel',
}
PANELS = {
    # Native quad corners; x-constant faces rise to the left, z-constant to the right.
    16133: [False, [[0,0],[15,11],[15,37],[0,26]]],
    16136: [False, [[0,0],[35,26],[35,84],[0,58]]],
    16557: [False, [[0,0],[55,40],[55,108],[0,68]]],
    16585: [False, [[0,0],[31,23],[31,75],[0,52]]],
    17520: [True, [[0,53],[75,0],[75,59],[0,112]]],
    17563: [True, [[0,18],[23,0],[23,50],[0,68]]],
    10567: [False, [[0,0],[27,20],[27,68],[0,48]]],
    16541: [False, [[0,0],[35,24],[35,63],[0,39]]],
}


def prepare(library, destination):
    lookup = library.serial_index()
    maps = {}; used = set()
    for ident in ROOMS:
        w,h,_,objects,_ = load_map(library,ident)
        rows=[]
        for i,serial in enumerate(objects):
            if serial < 1000 or serial in WALLS: continue
            assert serial in FAMILIES, ('unclassified original city fixture',ident,serial)
            e=lookup[serial];ew,ns=max(1,e['east']),max(1,e['south'])
            x,y=i%w,i//w
            rows.append({'graphic':serial,'source_cell':[x,y],
                         'cell':[y-ns+1,w-x-ew],'span':[ns,ew]})
            used.add(serial)
        with library.connection() as db:
            fid=db.execute('SELECT id FROM files WHERE path=?',(f'BlueCrossgate/map/0/{ident}.dat',)).fetchone()[0]
        path=library.source_file(fid)[1]
        maps[str(ident)]={'source':f'BlueCrossgate/map/0/{ident}.dat',
                         'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                         'source_size':[w,h],'placements':rows}
    assert sum(len(m['placements']) for m in maps.values()) == 193
    assert len(used) == 100
    rects=atlas(library,lookup,used,destination/'city_room_fixtures.png',2048)
    graphics={}
    for serial in sorted(used):
        e=lookup[serial];im=library.image_from_record(e['pack'],e['row'],0)
        graphics[str(serial)]={'rect':rects[serial],'origin':[e['x'],e['y']],
            'footprint':[max(1,e['east']),max(1,e['south'])],'ground':False,'family':FAMILIES[serial],
            'pack':e['pack'],'row':e['row'],'rgba_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
        bounds=im.getchannel('A').getbbox()
        if serial==16533:bounds=(0,0,59,91)
        graphics[str(serial)]['visible_rect']=[bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]]
        if serial in (16219,16533,16534,16579,17195):
            # 16533 has a detached two-pixel archive fragment at rows201/202; its cabinet ends at91.
            bottom=91 if serial==16533 else im.height
            graphics[str(serial)]['raised_base_pixels']=max(0,-e['y']-bottom)
        if serial in PANELS:graphics[str(serial)]['panel']=PANELS[serial]
        if serial in (10567,16541):graphics[str(serial)]['panel_depth']=.24
    result={'maps':maps,'graphics':graphics,
            'confirmed':'Original cells, footprint, sprite pixels, floor/wall/navigation and warp owners.',
            'inferred':'Solid depth, furniture backs and prepared reusable model continuation.'}
    (destination/'city_room_fixtures.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power')
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args();sys.path.insert(0,str(args.source/'tools'))
    import cg_library as library
    if args.check:
        with TemporaryDirectory() as temp:
            target=Path(temp);prepare(library,target)
            assert (target/'city_room_fixtures.json').read_bytes()==(OUT/'city_room_fixtures.json').read_bytes()
            with Image.open(target/'city_room_fixtures.png') as a,Image.open(OUT/'city_room_fixtures.png') as b:
                assert a.size==b.size and a.tobytes()==b.tobytes()
    else:prepare(library,OUT)
    print('Falan city fixtures: six source maps,193 placements,100 original graphics verified.')


if __name__=='__main__':main()
