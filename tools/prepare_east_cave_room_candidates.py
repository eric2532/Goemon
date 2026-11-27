"""Private native-wall candidates for the three observed East cave/room contexts."""
import argparse
import hashlib
import io
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageFilter
from east_architecture_sections import closed_wall, rectified_material
from prepare_east_stone_profiles import clean_native_front
from prepare_elsa_scenery import outline
from prepare_abanis_cliffs import measured_profile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/Cave Room Candidate'
IDS = list(range(13612,13648))+list(range(13720,13756))+[17065,17075,17076]


def room_materials(image,g):
    from recover_falan_architecture import opaque_paint
    height=(-g['origin'][1]-24)*.045;windowed=g['origin'][1]==-155
    bands=[('wall',3.4,1.2 if windowed else 2.4,1.2 if windowed else 2.4),
           ('wood',.76 if windowed else 1.005,1.12 if windowed else 1.69,3.),
           ('stone',.08,.16,2.4),('cornice',3.4 if windowed else height-.125,1.2 if windowed else .25,1.2 if windowed else 2.4),
           ('cap',3.4,1.2 if windowed else 2.4,1.2 if windowed else 2.4)]
    atlas=Image.new('RGBA',((len(bands)+1)*128,128));proof={}
    def pixel(x,y,z):return ((x+z)*32/3-g['origin'][0],(z-x)*8-y/.045-g['origin'][1])
    for i,(name,y,span,pitch)in enumerate(bands):
        # The unwindowed native -X face supplies separate wall/wood/stone paint.
        corners=[pixel(-1.5,y+span*.5,-pitch*.5),pixel(-1.5,y-span*.5,-pitch*.5),
                 pixel(-1.5,y-span*.5,pitch*.5),pixel(-1.5,y+span*.5,pitch*.5)]
        patch=image.transform((128,128),Image.Transform.QUAD,tuple(v for p in corners for v in p),Image.Resampling.BICUBIC)
        patch=opaque_paint(patch);atlas.paste(patch,(i*128,0));proof[name]={'native_face_pixels':[list(p)for p in corners],'center_world_y':y,'vertical_span':span,'horizontal_span':pitch,'top_world_y':y+span*.5}
    timber_path=ROOT/'assets/maps/falan/il_laruka/building-surfaces.png'
    with Image.open(timber_path)as image:atlas.paste(image.convert('RGBA').crop((384,0,512,128)),(len(bands)*128,0))
    proof['frame']={'horizontal_span':1.2,'vertical_span':1.2,'top_world_y':0.,'reuse':str(timber_path.relative_to(ROOT)),'source_sha256':hashlib.sha256(timber_path.read_bytes()).hexdigest(),'tile_rect':[384,0,128,128]}
    return atlas,{'world_pitch':2.4,'native_bands':proof,'rule':'Independent native material bands from the unwindowed -X face. Each band retains its own horizontal/vertical world pitch; panel motifs occur once across the recorded wainscot height. Observed front RGB is separate and unchanged. No whole window/facade photograph on backs.'}


def peaks(front, role):
    """Locate actual bright stone/moss patches; no random or regular noise field."""
    score = Image.new('L', front.size)
    for y in range(front.height):
        for x in range(front.width):
            r,g,b,a = front.getpixel((x,y))
            if a < 128: continue
            light = .30*r+.59*g+.11*b
            # The Great Tree art has brown roots between visible green foliage.
            # Its physical clusters follow the latter; the root photograph stays exact.
            value = light if role=='stacked_moss_stone' else light*min(1., max(0., (g-r*.75)/55.))
            score.putpixel((x,y),round(value))
    score = score.filter(ImageFilter.GaussianBlur(1.6))
    maximum = score.filter(ImageFilter.MaxFilter(11))
    candidates = sorted([(score.getpixel((x,y)),x,y) for y in range(front.height) for x in range(front.width)
                         if score.getpixel((x,y))>55 and score.getpixel((x,y))==maximum.getpixel((x,y))],reverse=True)
    selected=[]
    for strength,x,y in candidates:
        if any((x-p['center'][0])**2+(y-p['center'][1])**2<8**2 for p in selected):continue
        radii=[]
        for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
            radius=2
            for step in range(2,13):
                xx,yy=x+dx*step,y+dy*step
                if not(0<=xx<front.width and 0<=yy<front.height)or score.getpixel((xx,yy))<strength*.50:break
                radius=step
            radii.append(radius)
        selected.append({'center':[x,y],'radius':[max(4.,sum(radii[:2])*.65),max(4.,sum(radii[2:])*.65)],
                         'source_patch_score':strength,'depth_m':round(min(.26,max(.10,sum(radii)*.007)),4)})
        if len(selected)>=48:break
    return selected


def products():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    catalog={}
    for path in ['assets/maps/original_crossgate/catalog.json','assets/maps/falan/sokia/fixed/catalog.json',
                 'assets/maps/original_crossgate/university/catalog.json','assets/maps/original_crossgate/elsa/catalog.json',
                 'assets/maps/original_crossgate/east/catalog.json']:
        catalog.update(json.loads((ROOT/path).read_text())['graphics'])
    from prepare_east_cliff_boulder_study import master
    positions,normals,colors,indices,master_proof=master()
    stone_master={'positions':positions.tolist(),'normals':normals.tolist(),'colors':colors.tolist(),'indices':indices.reshape(-1).tolist(),'proof':master_proof}
    result={};rows={};native={}
    def png(name,image):
        stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);result[name]=stream.getvalue()
    for serial in IDS:
        g=catalog[str(serial)]
        image=lib.image_from_record(g['pack'],g['row']).convert('RGBA')
        digest=hashlib.sha256(image.tobytes()).hexdigest();assert digest==g['rgba_sha256'],serial
        native[serial]=(g,image,digest)
    for serial,(g,image,digest) in native.items():
        architecture=serial>=17000
        role='native_room_section' if architecture else 'root_and_foliage_wall' if serial<13720 else 'stacked_moss_stone'
        row,front=closed_wall(image,g,wood_trim=architecture)
        if not architecture:
            front=clean_native_front(image)
            moss=[p[:3]for p in front.getdata()if p[3]>=128 and p[1]>p[0]*1.02 and p[1]>p[2]*1.08]
            if not moss:moss=[p[:3]for p in front.getdata()if p[3]>=128]
            row['inferred_moss_rgb']=[sorted(p[c]for p in moss)[len(moss)//2]/255. for c in range(3)]if moss else [.2,.25,.16]
            visible=sum(p[3]>=128 for p in front.getdata())
            row['cap_only']=visible<image.width*image.height*.05
            row['source_patches']=peaks(front,role) if not row['cap_only'] else []
            for patch in row['source_patches']:
                patch['native_palette_rgb']=[v/255. for v in front.filter(ImageFilter.GaussianBlur(1.2)).getpixel(tuple(patch['center']))[:3]]
                rx,ry=patch['radius'];factor=1.
                for attempt in range(12):
                    samples=[(round(patch['center'][0]+float(p[0])*rx*factor),round(patch['center'][1]+float(p[2])*ry*factor))for p in positions]
                    if all(0<=x<front.width and 0<=y<front.height and front.getpixel((x,y))[3]>=128 for x,y in samples):break
                    factor*=.80
                patch['closed_master_alpha_fit']=factor
                patch['hidden_stone_radii_m']=[rx*factor/(32/3*math.sqrt(2)),min(.35,max(.12,rx*factor/(32/3*math.sqrt(2))*.80)),ry*factor/math.sqrt(128+1/.045**2)]
            sw,sh=math.ceil(front.width/4),math.ceil(front.height/4);mask=front.getchannel('A').resize((sw,sh),Image.Resampling.BOX)
            row['source_alpha_cells']=[[x*front.width/sw,y*front.height/sh,(x+1)*front.width/sw,(y+1)*front.height/sh]
                                       for y in range(sh)for x in range(sw)if mask.getpixel((x,y))>0]
            row['source_alpha_edges']=outline(front)
            row['closed_source_depth']=.55
            profile,coverage=measured_profile(image,g)
            # These are modular wall/cap tiles, not natural sloping piles. A
            # cropped/sparse occlusion mask cannot lower its family's wall plane.
            peer_height=6.21
            profile.update(height=peer_height,pixel_height=.045,paint_source=serial,paint_rect=[0,0,*image.size])
            profile['contour_top']=[(3-abs((x+g['origin'][0])*3/32))*8-peer_height/.045-g['origin'][1]for x in range(image.width)]
            row['context_wall_profile']=profile
            row['context_mass_inference']='A closed contiguous mass uses only these original blocked wall cells. The full native same-family wall establishes6.21m cap height; cropped black/sparse masks do not measure missing room height. Existing Native boundary/corner/chunk geometry is reused unchanged. No source walk or portal is filled.'
            row['relief_rule']='Only original visible-alpha cells form the closed source wall. Native two-face/cap projection locates those cells inside the original3m footprint; the unpainted black mask does not become a full cuboid. Measured source bright patches supply bounded physical relief. Original source projection is preserved along its viewing ray. Hidden .55m depth and independently tiled rear material are inference; no random peaks.'
        peer=17065 if serial==17065 else 17075 if architecture else 13612 if serial<13720 else 13721
        peer_g,peer_image,_=native[peer]
        peer_clean=clean_native_front(peer_image) if not architecture else peer_image
        atlas,material=room_materials(peer_image,peer_g) if architecture else rectified_material(peer_clean,peer_g)
        row.update({'serial':serial,'role':role,'size':list(image.size),'origin':g['origin'],'footprint':g['footprint'],
                    'pack':g['pack'],'row':g['row'],'source_rgba_sha256':digest,'visible':list(front.getbbox() or [0,0,0,0]),
                    'rectified_material':material,'material_sample_graphic':peer,'native_source_height':(-g['origin'][1]-24)*.045,
                    'status':'private_candidate_not_enrolled_or_visually_accepted'})
        rows[str(serial)]=row
        png(f'{serial}-native.png',image);png(f'{serial}-front.png',front);png(f'{serial}-surfaces.png',atlas)
    result['data.json']=(json.dumps({'schema':1,'graphics':rows,'rounded_stone_master':stone_master,'maps':[11037,34018,33506],
        'preserved':['Original source RGBA, anchors, footprint cells, source height datum, all collision/navigation and quest/portal owners.'],
        'reused':['Existing measured native cap/closed architecture section and window-frame geometry.',
                  'Existing coastal source material and fixed-scale independent rectified native back contract.'],
        'inferred':['Closed hidden wall thickness, independently tiled unseen material and bounded depth of source-correlated stone/foliage patches.',
                    'Black cap/void masks record occlusion; they do not supply a black visible roof or new traversable surface.',
                    'A roof-camera cutaway may be reviewed separately; original 2D art does not verify new roof material.'],
        'scope':'Private75-source-graphic study only. No runtime enrollment, source placement, collider, route, save or source map edits.'},indent=2)+'\n').encode()
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();bad=[]
    for name,payload in products().items():
        path=OUT/name
        if args.check:
            if not path.exists()or path.read_bytes()!=payload:bad.append(name)
        else:
            OUT.mkdir(parents=True,exist_ok=True)
            if not path.exists()or path.read_bytes()!=payload:path.write_bytes(payload)
    assert not bad,'Stale cave/room candidates: '+','.join(bad)
    print('EAST_CAVE_ROOM_CANDIDATES',len(IDS),'CHECK PASS' if args.check else 'PRIVATE PREPARED')


if __name__=='__main__':main()
