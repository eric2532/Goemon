"""Source-native metadata for bounded East architecture reuse; no layout mutation."""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/classic_architecture'


def products():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from recover_venoa_walls import native_without_ground_shadow
    profiles=json.loads((OUT/'profiles.json').read_text())
    graphics={}
    for source,replace in [('assets/maps/original_crossgate/catalog.json',True),('assets/maps/falan/sokia/fixed/catalog.json',False),('assets/maps/original_crossgate/university/catalog.json',True),('assets/maps/original_crossgate/elsa/catalog.json',True),('assets/maps/original_crossgate/east/catalog.json',True)]:
        for token,g in json.loads((ROOT/source).read_text())['graphics'].items():
            if replace or token not in graphics:graphics[token]=g
    result={};rows={}
    for token,kit in sorted(profiles['source_specific_reuse'].items(),key=lambda item:int(item[0])):
        g=graphics[token]
        with lib.connection() as db:
            native=dict(db.execute('SELECT x,y,east,south FROM graphics WHERE pack=? AND row=?',(g['pack'],g['row'])).fetchone())
        assert g['origin']==[native['x'],native['y']] and g['footprint']==[native['east'],native['south']]
        original=lib.image_from_record(g['pack'],g['row']).convert('RGBA')
        digest=hashlib.sha256(original.tobytes()).hexdigest();assert digest==g['rgba_sha256'],token
        clean,shadow=native_without_ground_shadow(original)
        stream=io.BytesIO();original.save(stream,format='PNG',optimize=True);result[token+'.png']=stream.getvalue()
        if kit in ('kili_wall','venoa_wall','timber_fence','iron_fence','measured_pier'):
            # These native black planes are unobserved-face masks, not black masonry.
            front=clean.copy();pixels=front.load()
            for y in range(front.height):
                for x in range(front.width):
                    r,green,b,a=pixels[x,y]
                    if kit in ('kili_wall','venoa_wall','measured_pier') and a and (max(r,green,b)<=4 or (r,green,b)==(20,20,20)):pixels[x,y]=(r,green,b,0)
            stream=io.BytesIO();front.save(stream,format='PNG',optimize=True);result[token+'-front.png']=stream.getvalue()
        rows[token]={'kit':kit,'pack':g['pack'],'row':g['row'],'origin':g['origin'],'footprint':g['footprint'],
                     'size':list(original.size),'visible':list(clean.getbbox()),'source_rgba_sha256':digest,
                     'removed_review_shadow_pixels':len(shadow)}
        if token in profiles.get('fence_frames',{}):
            rows[token]['fence']=profiles['fence_frames'][token]
            pixels=[p for p in clean.getdata() if p[3]>128]
            rows[token]['iron_rgb']=[sum(p[channel] for p in pixels)/len(pixels)/255 for channel in range(3)]
        if kit=='measured_pier':
            floor=min(clean.height-1,max(1,-int(g['origin'][1])))
            first=clean.getbbox()[1]
            levels=[]
            for y in sorted(set([first,min(first+2,floor),floor]+list(range(first,floor+1,4))),reverse=True):
                xs=[x for line in range(max(first,y-2),min(clean.height,y+3))
                    for x in range(clean.width) if clean.getpixel((x,line))[3]>128]
                if not xs:continue
                width=max(xs)-min(xs)+1
                radius=max(.10,width/(2*2**.5*(32/3)) if int(token) in profiles['round_piers'] else width/(4*(32/3)))
                levels.append([round(radius,5),round((floor-y)*.045,5),round(radius,5)])
            if int(token) in profiles['round_piers']:
                # The broad native black ellipse is a flat unseen top, not a dome.
                top_rows=[]
                for y in range(min(48,original.height)):
                    count=sum(original.getpixel((x,y))[3]>128 and original.getpixel((x,y))[:3]==(20,20,20) for x in range(original.width))
                    top_rows.append((count,y))
                top_y=max(top_rows)[1];top_height=(floor-top_y)*.045
                radius=max(top_rows)[0]/(2*2**.5*(32/3))
                levels=[level for level in levels if level[1]<top_height-.00001]+[[round(radius,5),round(top_height,5),round(radius,5)]]
                rows[token]['flat_top_native_center_y']=top_y
            rows[token]['profile']=levels
            rows[token]['round']=int(token) in profiles['round_piers']
            rows[token]['blue_foundation']=int(token) in [10620,10622,10623,10631,10632]
            # Independent native material patches; no whole front/column repeats on the back.
            atlas=Image.new('RGBA',(384,128));patches=[]
            for slot,level in enumerate((.60,.16,.88)):
                candidates=[]
                for y in range(1,max(2,clean.height-10),2):
                    if abs(y/clean.height-level)>.23:continue
                    for x in range(1,max(2,clean.width-6),2):
                        crop=clean.crop((x,y,x+6,y+10));colors=list(crop.getdata())
                        if any(p[3]<255 or p[:3]==(20,20,20) or max(p[:3])<5 for p in colors):continue
                        score=abs((y+5)/clean.height-level)+abs((x+3)/clean.width-(.72 if slot==0 else .38))*.2
                        candidates.append((score,(x,y,x+6,y+10),crop))
                if not candidates and patches:
                    rect=patches[0];patch=clean.crop(tuple(rect))
                else:
                    assert candidates,('No observed material patch',token)
                    _,rect,patch=min(candidates,key=lambda item:item[0])
                patches.append(list(rect));atlas.paste(patch.resize((128,128),Image.Resampling.BICUBIC),(slot*128,0))
            stream=io.BytesIO();atlas.save(stream,format='PNG',optimize=True);result[token+'-surfaces.png']=stream.getvalue()
            rows[token]['independent_material_samples']=patches
    #17503 is the masked counterpart of the same red column; its half-painted shaft
    # must not be misread as a narrow neck under a wide native cap.
    if '17503' in rows and '17502' in rows:
        rows['17503']['profile']=rows['17502']['profile']
        rows['17503']['compatible_whole_profile']=17502
        result['17503-surfaces.png']=result['17502-surfaces.png']
        rows['17503']['compatible_material_graphic']=17502
    enrolled={int(token) for token in rows}
    scope={i for family in profiles['groups'] for i in family['ids']}|set(profiles.get('typed_additional_classic_ids',[]))
    pending=sorted(scope-enrolled)
    data={'schema':1,'graphics':rows,'pending_classic_ids':pending,
          'inferred':['Unseen sides continue existing compatible master geometry and independent part paint.','Native bounds/origins/footprints are observed; unseen roof/wall depth and joints remain reconstruction.','Fence arm directions and source silhouettes are observed. Closed bar sections, uniform stations inside those arms, cap thickness and hidden joinery use compatible existing parts fitted to native structural bounds.'],
          'scope':'Only enrolled exact East original-map object graphics; prior map/cell-specific owners preempt. No source layout, collider, navigation, door, return or quest changes.'}
    result['data.json']=(json.dumps(data,indent=2)+'\n').encode()
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();stale=[]
    for name,payload in products().items():
        p=OUT/name
        if args.check:
            if not p.exists() or p.read_bytes()!=payload:stale.append(name)
        elif not p.exists() or p.read_bytes()!=payload:p.write_bytes(payload)
    if stale:raise SystemExit('Stale East native architecture reuse: '+','.join(stale))
    print(('Verified' if args.check else 'Prepared')+' bounded native East architecture; originals unchanged.')


if __name__=='__main__':main()
