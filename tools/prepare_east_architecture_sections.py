"""Prepare50 exact source-cap wall sections; candidate only until image review."""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from east_architecture_sections import closed_wall,rectified_material

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/classic_architecture/sections'
STONE=[15804,15805,15809,15810,15811,15815,15816,15819,15823,15835,15840,15846,15851,15852,15853,15857,15858,15860,15863,15864,15865,15867,15869,15870,15875,15876,15877,15882]
PLASTER=[16710,16712,16736,16956,16958,16959,16961,16962,16963,16964,16965,16966,16967,16968,16969,16970,16971,16972,16973,16986,16987,17599]


def products():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from recover_venoa_walls import native_without_ground_shadow
    catalog={}
    for path in ['assets/maps/original_crossgate/catalog.json','assets/maps/falan/sokia/fixed/catalog.json','assets/maps/original_crossgate/university/catalog.json','assets/maps/original_crossgate/elsa/catalog.json','assets/maps/original_crossgate/east/catalog.json']:
        catalog.update(json.loads((ROOT/path).read_text())['graphics'])
    results={};graphics={}
    def png(name,image):
        stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);results[name]=stream.getvalue()
    for serial in STONE+PLASTER:
        g=catalog[str(serial)]
        with lib.connection() as db:
            native=dict(db.execute('SELECT x,y,east,south FROM graphics WHERE pack=? AND row=?',(g['pack'],g['row'])).fetchone())
        assert g['origin']==[native['x'],native['y']] and g['footprint']==[native['east'],native['south']]
        original=lib.image_from_record(g['pack'],g['row']).convert('RGBA')
        digest=hashlib.sha256(original.tobytes()).hexdigest();assert digest==g['rgba_sha256'],serial
        clean,shadow=native_without_ground_shadow(original)
        peer_id=15851 if serial>=15851 and serial in STONE else 15804
        peer_g=catalog[str(peer_id)];peer=lib.image_from_record(peer_g['pack'],peer_g['row']).convert('RGBA')
        try:row,front=closed_wall(clean,g,wood_trim=serial in PLASTER and serial not in [16710,16712,16956,16961,16986,16987])
        except Exception as error:raise RuntimeError(f'Native section{serial}: {error}') from error
        if serial in PLASTER:
            peer_id=16710 if serial in [16710,16712,16736] else 16958
            peer_g=catalog[str(peer_id)];peer=lib.image_from_record(peer_g['pack'],peer_g['row']).convert('RGBA')
        atlas,material=rectified_material(peer,peer_g,wood=serial in PLASTER)
        row['rectified_material']=material
        row.update({'serial':serial,'kit':'native_cap_wall','size':list(original.size),'origin':g['origin'],'footprint':g['footprint'],
                    'pack':g['pack'],'row':g['row'],'source_rgba_sha256':digest,'visible':list(clean.getbbox()),'removed_ground_shadow_pixels':len(shadow),
                    'material_sample_graphic':peer_id})
        graphics[str(serial)]=row
        png(f'{serial}.png',original);png(f'{serial}-front.png',front);png(f'{serial}-surfaces.png',atlas)
    results['data.json']=(json.dumps({'schema':1,'graphics':graphics,'status':'Candidate source/reverse review; no runtime dispatch yet.',
        'inferred':['Native cap mask, source anchor and footprint are observed. Its horizontal reconstruction uses the existing48px tile-cap band and24px midpoint.',
                    'Unseen wall faces, cap undersides and top material continue independent native material samples; fully masked faces name a compatible native material peer.',
                    'Window frames reuse closed timber parts at the native glass bounds. Thickness and unseen joints are inferred. No window/door becomes a route.',
                    'Cap-only15819/15867 retain source height and a thin closed underside; no full wall is invented below them.'],
        'scope':'Exact50 structural source forms only; original source flags, placement, collision, walk bits and routes unchanged.'},indent=2)+'\n').encode()
    return results


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();bad=[]
    for name,payload in products().items():
        path=OUT/name
        if args.check:
            if not path.exists() or path.read_bytes()!=payload:bad.append(name)
        else:
            OUT.mkdir(parents=True,exist_ok=True)
            if not path.exists() or path.read_bytes()!=payload:path.write_bytes(payload)
    if bad:raise SystemExit('Stale measured native wall sections: '+','.join(bad))
    print(('Verified' if args.check else 'Prepared')+'50 source-cap wall candidates; original files unchanged.')


if __name__=='__main__':main()
