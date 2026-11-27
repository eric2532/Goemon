"""Preserve native Lektal porch/wing paint and measured source anchors."""
import argparse
import base64
import hashlib
import io
import json
import sys
import zlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan/east_region/lektal_annexes'
IDS = (1233256, 1233257)


def products():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    catalog = json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
    result, graphics, images = {}, {}, {}
    for serial in IDS:
        g = catalog['graphics'][str(serial)]
        with lib.connection() as db:
            original = dict(db.execute('SELECT x,y,east,south FROM graphics WHERE pack=? AND row=?', (g['pack'],g['row'])).fetchone())
        assert g['origin'] == [original['x'],original['y']]
        assert g['footprint'] == [original['east'],original['south']]
        image = lib.image_from_record(g['pack'],g['row']).convert('RGBA')
        digest = hashlib.sha256(image.tobytes()).hexdigest()
        assert digest == g['rgba_sha256']
        images[serial] = image
        stream = io.BytesIO(); image.save(stream,format='PNG',optimize=True)
        result[f'{serial}.png'] = stream.getvalue()
        row = {key:g[key] for key in ['pack','row','origin','footprint']}
        row.update(size=list(image.size),source_rgba_sha256=digest)
        if serial == 1233256:
            row.update(form='porch',deck_height=1.2,tread_depth=.6,
                       deck_pixels=[[5,104],[50,130],[89,103],[49,75]],
                       door_plane=-2.28,
                       door_outline=[[10,42],[19,24],[34,5],[43,1],[52,11],[51,73],[12,101]],
                       rails=[[[5,104],[50,130]],[[50,130],[89,103]],[[89,103],[49,75]]],
                       # Source steps descend toward the unchanged South+1 warp cell.
                       steps=4,stairs_axis='south',native_door_cells=[[84,66],[73,36]])
        else:
            row.update(form='wing',front_plane=.8,hidden_depth=11.6,
                       # Literal source outline of the wooden gable and projecting bay.
                       gable_outline=[[139,209],[184,119],[239,159],[239,178],[220,254],[192,278],[161,258],[153,234]],
                       roof_front=[[144,185],[187,104],[272,151]],
                       roof_back=[[1,68],[41,0]],
                       roof_back_plane=-12.2,
                       window_outline=[[157,208],[184,188],[200,198],[200,236],[173,258],[157,246]],
                       window_depth=.24)
        graphics[str(serial)] = row
    atlas = Image.new('RGBA',(512,128))
    wood_source=ROOT/'assets/maps/original_crossgate/building-surfaces.png'
    wood=Image.open(wood_source).convert('RGBA').crop((256,1664,384,1792))
    samples = {'wood':{'reused_prepared_tile':'assets/maps/original_crossgate/building-surfaces.png::tina_fence_wood','source_native_graphic':11363,'source_native_quad':[[17,5],[19,5],[19,17],[17,17]],'source_rect':[256,1664,384,1792],'rgba_sha256':hashlib.sha256(wood.tobytes()).hexdigest(),'fixed_world_pitch_treads':1.5,'fixed_world_pitch_measured_edges':1.35},
               'roof':(1233257,[[31,47],[44,22],[77,44],[62,72]]),
               'dark':(1233256,[24,58,30,69]),
               'log':(1233257,[[210,204],[220,197],[220,235],[210,242]])}
    for i,(role,recipe) in enumerate(samples.items()):
        if role=='wood':
            assert wood.getchannel('A').getextrema()==(255,255)
            atlas.paste(wood,(0,0));continue
        serial,rect=recipe
        if isinstance(rect[0],list):
            ul,ur,lr,ll=rect
            patch=images[serial].transform((112,112),Image.Transform.QUAD,(*ul,*ll,*lr,*ur),Image.Resampling.BICUBIC)
        else:
            patch = images[serial].crop(rect).resize((112,112),Image.Resampling.BICUBIC)
        assert patch.getchannel('A').getextrema() == (255,255), role
        for axis in (0,1):
            original = patch.copy()
            for along in range(112):
                for edge in range(8):
                    for side in (edge,111-edge):
                        p=(side,along) if axis==0 else (along,side)
                        q=(111-side,along) if axis==0 else (along,111-side)
                        a=original.getpixel(p); b=original.getpixel(q); t=(8-edge)/16
                        patch.putpixel(p,tuple(round(a[k]*(1-t)+b[k]*t) for k in range(4)))
        for y in range(128):
            for x in range(128):
                atlas.putpixel((i*128+x,y),patch.getpixel((min(111,max(0,x-8)),min(111,max(0,y-8)))))
    stream=io.BytesIO(); atlas.save(stream,format='PNG',optimize=True)
    result['surfaces.png']=stream.getvalue()
    from build_freyja_destinations import load_map, warp_rows
    width,height,_,objects,_=load_map(lib,43700)
    warps=list(warp_rows(ROOT.parent/'Magic Power'))
    outgoing=[list(row) for row in warps if row[0]==43700]
    targets={row[3] for row in outgoing}
    placements=[{'source_cell':[index%width,index//width],'native_graphic':serial,
                 'runtime_graphic':1233256 if serial==33256 else 1233257}
                for index,serial in enumerate(objects) if serial in (33256,33257)]
    with lib.connection() as db:
        typo=db.execute('SELECT id FROM files WHERE path=?',('BlueCrossgate/map/0/23700.dat',)).fetchone()
    contract={'map':43700,'size':[width,height],'23700_archive_present':typo is not None,
              'placements':placements,'original_warps':outgoing,
              'original_returns':[list(row) for row in warps if row[0] in targets and row[3]==43700]}
    native_map=catalog['maps']['BlueCrossgate/map/0/43700.dat']
    walk=zlib.decompress(base64.b64decode(native_map['walk']))
    def opened(x,z):
        index=z*width+x
        return bool(walk[index>>3] & (1 << (index&7)))
    paths=[];walk_samples={};decorative=[]
    for placement in placements:
        if placement['runtime_graphic']!=1233256:continue
        x,z=placement['source_cell'];door=[row for row in outgoing if row[1:3]==[x,z+1]]
        if not door:
            decorative.append({'porch_cell':[x,z],'deck_open':opened(x,z),'south_two_open':opened(x,z+2),'support':False,'reason':'No original door/return and the far South approach is blocked; keep the decorative lateral apron route unchanged.'})
            continue
        assert not opened(x,z) and opened(x,z+1) and opened(x,z+2)
        paths.append({'porch_cell':[x,z],'door_cell':[x,z+1],'destination':door[0][3]})
        for v in range(z-1,z+4):
            for u in range(x-2,x+3):walk_samples[(u,v)]=opened(u,v)
    support={'source':43700,'size':[width,height],'origin':[-(width//2)*3,-(height//2)*3],
             'paths':paths,'decorative_exclusions':decorative,
             'sampling_cells':[{'cell':list(at),'open':value} for at,value in sorted(walk_samples.items())],
             'source_walk_sha256':hashlib.sha256(walk).hexdigest(),
             'rule':'Only original-open lower tread/apron cells on the two existing return routes. No support on blocked deck cells; entrance transfers at original2.1radius before ramp foot.'}
    data={'schema':1,'graphics':graphics,'tile_samples':samples,'support':support,
          'source_contract':contract,
          'reuse':['Il/Laruka closed timber bar and rail construction','Shapes.extrude closed native door/gable contours','Native blue roof and log paint, original masters unchanged','Clean existing Tina fence timber tile11363, preserved128px sample at fixed world pitch; no deck/rail features repeat across inferred wood backs'],
          'inferred':['Hidden gable depth, back log wall, rear roof slope and underside','Porch deck height1.2 joins the observed door-leaf bottom1.22715; four0.6deep treads and support thickness/hidden backs are inferred','Door leaf thickness, window bay depth and hidden joinery','Smooth lower-tread support reuses the existing Palace/Habaru contract only inside original-open return cells; no new route or reachable deck is created']}
    result['data.json']=(json.dumps(data,indent=2)+'\n').encode()
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--check',action='store_true'); args=parser.parse_args()
    stale=[]
    for name,payload in products().items():
        path=OUT/name
        if args.check:
            if not path.exists() or path.read_bytes()!=payload: stale.append(name)
        else:
            OUT.mkdir(parents=True,exist_ok=True)
            if not path.exists() or path.read_bytes()!=payload: path.write_bytes(payload)
    if stale: raise SystemExit('Stale native Lektal annex derivatives: '+','.join(stale))
    print(('Verified' if args.check else 'Prepared')+'2 native Lektal annexes; original source untouched.')


if __name__=='__main__': main()
