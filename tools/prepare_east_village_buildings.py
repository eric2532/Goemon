"""Isolated native building paint for Il/Alyut; existing maps and masters remain intact."""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path
from PIL import Image
from build_freyja_destinations import load_map, warp_rows
from prepare_il_laruka import FORMS

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/maps/falan/east_region/village_buildings'
IDS = (11269, 11271, 11272, 11273, 11275)


def products():
    sys.path.insert(0, str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    lookup = lib.serial_index()
    result = {}; graphics = {}; maps = {}; native_images = {}
    for serial in (*IDS,11268,10607):
        row = lookup[serial]
        image = lib.image_from_record(row['pack'], row['row']).convert('RGBA')
        native_images[serial] = image
        output = io.BytesIO(); image.save(output, format='PNG', optimize=True)
        if serial in IDS: result[f'{serial}.png'] = output.getvalue()
        east, south = max(1, row['east']), max(1, row['south'])
        entry = {'pack': row['pack'], 'row': row['row'], 'size': list(image.size),
                 'origin': [row['x'], row['y']], 'footprint': [east, south],
                 'center': [-row['x']+(east-south)*16, -row['y']-(east+south-2)*12],
                 'source_rgba_sha256': hashlib.sha256(image.tobytes()).hexdigest()}
        if serial in FORMS: entry['form'] = FORMS[serial]
        if serial==11271:
            entry['left_wing_fit']={'floor_pixels':[[13,411],[80,459],[141,416]],
                                   'roof_pixels':[[0,310],[64,242],[137,294],[81,373]],
                                   'inferred_wall_roof_height':9.2,
                                   'note':'Visible native ground feet and timber eaves; height/depth are reconstructed. Source map footprint and doors are unchanged.'}
        if serial in (11269,11271):
            bounds = image.crop((0,0,image.width,56)).getbbox()
            assert bounds is not None
            rooster = image.crop(bounds)
            output = io.BytesIO(); rooster.save(output, format='PNG', optimize=True)
            result[f'{serial}-rooster.png'] = output.getvalue()
            entry['rooster_rect'] = list(bounds)
        graphics[str(serial)] = entry
    round_patch = (11269, [(91,236),(139,259),(170,238),(123,215)], False, (96,64))
    _,quad,_,_ = round_patch
    ul,ur,lr,ll=quad
    patch=native_images[11269].transform((112,112),Image.Transform.QUAD,(*ul,*ll,*lr,*ur),Image.Resampling.BICUBIC)
    assert patch.getchannel('A').getextrema()==(255,255)
    # Keep straw flowing in one direction; four mirrored quadrants form a false diamond pattern.
    for axis in (0,1):
        original=patch.copy()
        for along in range(112):
            for edge in range(8):
                for side in (edge,111-edge):
                    point=(side,along) if axis==0 else (along,side)
                    opposite=(111-side,along) if axis==0 else (along,111-side)
                    a=original.getpixel(point);b=original.getpixel(opposite);blend=(8-edge)/16
                    patch.putpixel(point,tuple(round(a[k]*(1-blend)+b[k]*blend) for k in range(4)))
    tile=Image.new('RGBA',(128,128))
    for y in range(128):
        for x in range(128):tile.putpixel((x,y),patch.getpixel((min(111,max(0,x-8)),min(111,max(0,y-8)))))
    shared = Image.open(ROOT/'assets/maps/falan/il_laruka/building-surfaces.png').convert('RGBA')
    # Reuse the existing atlas layout; only the round houses' hidden straw receives their own native paint.
    shared.paste(tile, (128,0))
    output = io.BytesIO();shared.save(output,format='PNG',optimize=True)
    result['round-surfaces.png'] = output.getvalue()
    warps = list(dict.fromkeys(warp_rows(ROOT.parent/'Magic Power')))
    for ident in (2000,2400):
        w,h,_,objects,_ = load_map(lib,ident)
        with lib.connection() as db:
            record = dict(db.execute('SELECT * FROM files WHERE path=?', (f'BlueCrossgate/map/0/{ident}.dat',)).fetchone())
        raw = (lib.SOURCE/record['path']).read_bytes()
        placements = []
        for i,serial in enumerate(objects):
            if serial not in (*IDS,11268,10607):continue
            x,z=i%w,i//w; east,south=graphics[str(serial)]['footprint']
            center=[x+(east-1)*.5,z-(south-1)*.5]
            placements.append({'cell':[x,z],'graphic':serial,'footprint':[east,south],
                               'center_cell':center,'center_local':[(center[0]-w//2)*3,(center[1]-h//2)*3],
                               'collision_size':[east*3-.35,12,south*3-.35],
                               'appearance_owner':'approved_existing' if serial in (11268,10607) else 'east_village_buildings'})
        doors=[]
        for source,x,z,dest,tx,tz in warps:
            if source!=ident or dest//100!=ident//100 or dest==ident:continue
            def distance(p):
                bx,bz=p['cell'];bw,bh=p['footprint']
                return max(bx-x,0,x-(bx+bw-1))**2+max(bz-bh+1-z,0,z-bz)**2
            building=min(placements,key=distance)
            returns=[list(row) for row in warps if row[0]==dest and row[3]==ident]
            doors.append({'source_cell':[x,z],'destination':dest,'arrival_cell':[tx,tz],
                          'building_cell':building['cell'],'graphic':building['graphic'],'return_warps':returns})
        assert len(placements)==(8 if ident==2000 else 5)
        maps[str(ident)] = {'size': [w,h], 'path': record['path'], 'sha256': hashlib.sha256(raw).hexdigest(),
                           'placements': placements,'doors':doors}
    proof = {'schema':1, 'graphics':graphics, 'maps':maps,
             'round_roof_surface':{'patch':round_patch,'reused_atlas_layout':'il_laruka/building-surfaces.gd','reason':'The green round-house straw stays distinct from the yellow rectangular-house straw.'},
             'reused_parts':['forest_il_chief.gd source projection and octagonal/thatch construction',
                             'forest_il_laruka_buildings.gd timber/window/roof/dormer parts',
                             'assets/maps/falan/il_laruka/building-surfaces.png separate native material patches'],
             'inferred':['Hidden walls, roof slopes and wooden wing backs use native part paint at fixed world scale.',
                         'Thatch depth, eave irregularity, rafters, rear window rhythm and ridge cap thickness are inferred.',
                         'Only observed source faces receive the source-camera paint; no whole front image is wrapped onto unseen sides.',
                         'No new entrance, route, collider, interior, NPC or quest owner is added.']}
    result['data.json'] = (json.dumps(proof, ensure_ascii=False, indent=2)+'\n').encode()
    return result


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    files=products()
    if args.check:
        assert all((OUT/name).read_bytes()==value for name,value in files.items()), 'Stale East village building derivatives'
    else:
        OUT.mkdir(parents=True,exist_ok=True)
        for name,value in files.items():(OUT/name).write_bytes(value)
    data=json.loads(files['data.json'])
    print('EAST_VILLAGE_BUILDINGS five exact native copies;',sum(len(row['placements']) for row in data['maps'].values()),'original building placements; source maps unchanged.')


if __name__=='__main__':main()
