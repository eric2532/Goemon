"""Fit the original island temple facade; retain archive pixels and mark hidden depth."""
import argparse
import json
import math
from PIL import Image,ImageDraw,ImageChops,ImageFilter
import recover_elsa_island as source
from prepare_elsa_gate import native_layers
from prepare_elsa_scenery import solid_pages

OUT=source.ROOT/'assets/maps/falan/elsa/scenery/temple'
RECT=(7104,-3312,12032,-1872)
VERTICAL=math.sqrt(2*((32/3)**2-8**2))
BAYS=dict(spans=[[9085,9440],[9470,9930]],depth=6.,full_before=-3090.,fade_until=-2790.,across_pixels=24.,vertical_segments=16,
          inference='The paired rounded white facade lobes guide these source spans. Six metres of hidden depth and its lower transition are inferred along the original view direction; source projection and original ground contacts are unchanged.')
UPPER=dict(extension=8.,roof_rise=18.,roof_segments=8,wall_scale=.96,cap_scale=.10,
           inference='No mapped roof art is recovered above the temple crop in the available client cache or corroborating LS2 layers; most of the client upper search region is uncached. This short continuation keeps the source-fitted cross-section, with a gold cornice and rounded blue cap using existing temple materials. Height, hidden enclosure and roof form are inferred, not verified original roof geometry.')
# Feet follow visible facade/blue-plinth contacts. Covered portions behind the
# original entrance terraces continue their neighboring contact, rather than the old block.
PARTS=[
 dict(name='west-entrance',kind='pylon',clip_scale=.78,front=[[7250,-2750],[7390,-2715],[7580,-2710],[7770,-2680],[7925,-2690]],upper=UPPER,clip=-3312),
 dict(name='west-wing',kind='wing',front=[[7885,-2580],[9085,-2450]],height=0.,roof=[[7885,-3140],[9085,-3015]],crest=9.),
 dict(name='central-entrance',kind='pylon',clip_scale=.96,front=[[9070,-2610],[9200,-2600],[9270,-2510],[9470,-2510],[9710,-2500],[9840,-2550],[9910,-2560]],upper=UPPER,clip=-3312,bays=BAYS),
 dict(name='east-wing',kind='wing',front=[[9850,-2330],[11100,-2220]],height=0.,roof=[[9850,-2990],[11100,-2870]],crest=9.),
 dict(name='east-entrance',kind='pylon',clip_scale=.72,front=[[11020,-2420],[11210,-2380],[11390,-2380],[11575,-2350],[11780,-2390]],upper=UPPER,clip=-3312)]


def ground(u,v):return [u*3/64-v/16,u*3/64+v/16]


def rear_contact(u,planes,width,height):
    across=u/32;row=round(across)
    # The blocked-band edge bounds hidden depth; zero-valued padding beyond it
    # is not an island-owned walking route.
    for depth in range(127,151):
        x=round((row+depth)*.5);y=row-x
        if 0<=x<width and 0<=y<height and not planes[2][y*width+x]:
            return -24*(depth-1)
    raise AssertionError(('No blocked-band edge',u))


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    _,background=native_layers([],RECT,59520)
    width,height,planes=source.reference_map(59520)
    mask=Image.new('L',background.size);draw=ImageDraw.Draw(mask);parts=[]
    for original in PARTS:
        part=dict(original);front=part['front'];left,right=front[0][0],front[-1][0]
        rear=[]
        for u in [right,*range(math.floor(right/64)*64,math.ceil(left/64)*64-1,-64),left]:
            if left<=u<=right:rear.append([u,rear_contact(u,planes,width,height)])
        # Collapse repeated source rows; each rear vertex still derives from the walking data.
        rear=[p for i,p in enumerate(rear) if not i or p!=rear[i-1]]
        part['rear']=rear;part['footprint']=[ground(u,v) for u,v in front+rear]
        part['center']=[sum(p[0] for p in front)/len(front),sum(p[1] for p in front)/len(front)]
        if part['kind']=='pylon':
            polygon=[(left,RECT[1]),(right,RECT[1])]+list(reversed(front))
            part['source_height']=(part['center'][1]-RECT[1])/VERTICAL
        else:
            polygon=[(left,RECT[1]),(right,RECT[1])]+list(reversed(front))
        draw.polygon([(u-RECT[0],v-RECT[1]) for u,v in polygon],fill=255)
        part['inference']='Visible paint and facade contacts guide the fit; covered contacts, rear walls and upper architecture are inferred. Rear extent stops before the source blocked-band edge. The unowned padding beyond it is not a walking route.'
        parts.append(part)
    # Continue actual native grass only beneath the lifted architecture; visible
    # paving, stairs and ornament outside this source silhouette remain unchanged.
    patch_rect=(8232-RECT[0],-2412-RECT[1],64,48)
    px,py,pw,ph=patch_rect;grass=background.crop((px,py,px+pw,py+ph));colors=list(grass.getdata())
    assert all(a and g>r*1.05 and g>b*1.05 for r,g,b,a in colors),'Grass sample must be native uncovered garden'
    floor=background.copy();pixels=floor.load();covered=mask.load();sample=grass.load()
    for y in range(floor.height):
        for x in range(floor.width):
            if covered[x,y]:pixels[x,y]=sample[(x-px)%pw,(y-py)%ph]
    # Palette-key pinholes along dark masonry become grass-colored streaks when
    # projected onto a floor. Fill only closed 1–2px gaps with nearest native RGB.
    solid=solid_pages(dict(graphics={'front':dict(rect=[0,0,*background.size],page=0)}),[background])[0]
    alpha=background.getchannel('A')
    gaps=ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3)),alpha)
    # The native BG also keys out parts hidden by the original stair railings.
    # Those gaps become visible from the 3D side. Continue only their stair floor.
    stair_regions=[(7200,-2715,8030,-2320),(9120,-2530,9870,-1990),(11000,-2410,11900,-1900)]
    stair_mask=Image.new('L',background.size);stair_draw=ImageDraw.Draw(stair_mask)
    for u,v,right,bottom in stair_regions:stair_draw.rectangle((u-RECT[0],v-RECT[1],right-RECT[0],bottom-RECT[1]),fill=255)
    gaps=ImageChops.lighter(gaps,ImageChops.multiply(ImageChops.invert(alpha),stair_mask))
    gaps=ImageChops.multiply(gaps,ImageChops.invert(mask))
    floor.paste(solid,(0,0),gaps)
    # Private material tiles for surfaces hidden by the original camera. Never
    # project doorway or window photographs over the reverse wall or inferred roof.
    tiles={'white':(9204,-3268,16,16),'stone':(8000,-3110,64,48),
           'blue':(8310,-3220,64,48),'gold':(9402,-3011,24,8)}
    materials={}
    for name,(u,v,w,h) in tiles.items():
        art=background.crop((u-RECT[0],v-RECT[1],u-RECT[0]+w,v-RECT[1]+h))
        assert all(p[3] for p in art.getdata()),name
        art.save(OUT/(name+'.png'));materials[name]=dict(rect=[u,v,w,h],rgba_sha256=source.sha(art.tobytes()))
    for name,image in [('original-background',background),('floor',floor),('building-mask',mask),('occluded-floor-mask',gaps)]:image.save(OUT/(name+'.png'))
    front=background.convert('RGB');front.paste(solid,(0,0),ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3)),alpha));front.save(OUT/'front-solid.png')
    links=json.loads((source.ROOT/'assets/maps/falan/elsa/links.json').read_text())
    data=dict(map=59520,rect=list(RECT),parts=parts,materials=materials,grass_rect=list(patch_rect),
              infilled_floor_pixels=sum(bool(p) for p in gaps.getdata()),stair_infill_regions=stair_regions,
              doors=[r for r in links if r['source']==59520 and r['target']==59530],
              hashes={n:source.sha(i.tobytes()) for n,i in [('background',background),('floor',floor),('mask',mask)]},
              limits=['Original archive layers, walkability and door records are unchanged. Static source art has no original meshes. Hidden depth, rear materials and upper roof continuation are inferred. Entrance terraces are retained for the following stair-height fit. Palette-key pinholes and original stair-rail occlusion use inferred nearest native RGB; opaque source pixels stay exact. Larger keyed doorway openings retain a black matte, never nearest-gold streaks.'])
    (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_TEMPLE',len(parts),'source-fitted volumes;',len(data['doors']),'original door records')


def update_bays():
    path=OUT/'data.json';data=json.loads(path.read_text())
    part=next(p for p in data['parts'] if p['name']=='central-entrance')
    original=next(p for p in PARTS if p['name']==part['name'])
    assert part['front']==original['front'],'Review changed facade contacts before fitting the bays'
    part['bays']=BAYS
    temporary=path.with_suffix('.tmp');temporary.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');temporary.replace(path)
    print('ELSA_TEMPLE_BAYS 2 source-guided lobes; inferred6m depth; source paint/footprints unchanged')

def update_upper():
    path=OUT/'data.json';data=json.loads(path.read_text())
    for part in data['parts']:
        if part['kind']!='pylon':continue
        original=next(p for p in PARTS if p['name']==part['name'])
        assert part['front']==original['front'],'Review changed facade contacts before fitting the upper enclosure'
        part['upper']=UPPER;part.pop('height',None);part.pop('taper',None)
    temporary=path.with_suffix('.tmp');temporary.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');temporary.replace(path)
    print('ELSA_TEMPLE_UPPER 3 short inferred continuations;8-unit white bands and18-unit rounded blue caps')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);group=parser.add_mutually_exclusive_group();group.add_argument('--bays-only',action='store_true');group.add_argument('--upper-only',action='store_true');args=parser.parse_args()
    if args.bays_only:update_bays()
    elif args.upper_only:update_upper()
    else:build()
