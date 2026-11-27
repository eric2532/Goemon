"""Native regional vegetation and cave paint; preserve the solid Sokia crag kit."""
import argparse,json
from collections import deque
from pathlib import Path
from PIL import Image
from prepare_ruby_region_art import trees,cave_walls
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/sokia/scenery'

def mouth_profiles(lib):
    """Reuse the undersea decoder's silhouette method for six visible native holes.

    Meteor's lower crossing and the forger's source crop have no isolated dark
    aperture. They deliberately receive no invented cave arch.
    """
    import hashlib
    with lib.connection() as db:
        ident=db.execute('SELECT id FROM files WHERE path=?',('BlueCrossgate/map/0/300.dat',)).fetchone()[0]
    left,top=lib.map_plan(ident)['bounds'][:2];result=[]
    for x,y,back in [(356,334,[1,0]),(402,304,[0,-1]),(380,324,[0,-1]),(368,351,[0,-1]),(626,209,[1,0]),(755,81,[1,0])]:
        image=lib.render_map(ident,0,0,(x+y)*32-left-250,(y-x)*24-top-260,500,400)
        # Stop above the disconnected cache background at the bottom of Lion's crop.
        dark={(u,v) for v in range(20,280) for u in range(100,360) if image.getpixel((u,v))[:3]==(20,20,20)}
        opening=set()
        while dark:
            seed=dark.pop();component={seed};pending=[seed]
            while pending:
                u,v=pending.pop()
                for p in [(u-1,v),(u+1,v),(u,v-1),(u,v+1)]:
                    if p in dark:dark.remove(p);component.add(p);pending.append(p)
            if len(component)>len(opening):opening=component
        assert len(opening)>2000,(x,y)
        x0,x1=min(p[0] for p in opening),max(p[0] for p in opening)
        y0,y1=min(p[1] for p in opening),max(p[1] for p in opening)
        center=(x0+x1)*.5;sides=[[],[]]
        # Wind has two adjacent recorded trigger tiles,368/369,351. One shared
        # fitted aperture spans both; the native silhouette and height stay common.
        fitted_width=(x1-x0)*3./32. if (x,y)==(755,81) else 6.0 if (x,y)==(368,351) else 3.6
        for step in range(8):
            row=round(y1-5-step*(y1-y0-10)/7)
            pixels=[u for u,v in opening if abs(v-row)<=2];assert pixels
            low,high=(min(pixels)-center)*fitted_width/(x1-x0),(max(pixels)-center)*fitted_width/(x1-x0)
            if step<3:
                clearance=2.1 if (x,y)==(368,351) else 1.2
                low=min(low,-clearance);high=max(high,clearance)
            height=(y1-5-row)*.043
            sides[0].append([round(low,4),round(height,4)]);sides[1].append([round(high,4),round(height,4)])
        result.append(dict(cell=[x,y],back=back,profile=sides[0]+sides[1][::-1],
                           center_offset=[.5,0] if (x,y)==(368,351) else [0,0],fitted_width=fitted_width,
                           native_crop_rgba_sha256=hashlib.sha256(image.tobytes()).hexdigest(),
                           dark_bounds=[x0,y0,x1,y1],dark_pixels=len(opening),
                           source='BlueCrossgate/map/0/300.dat; palette0; original composite'))
    return result

def castle_reuse(lib):
    from build_freyja_destinations import load_map
    import hashlib
    originals={}
    for number,offset in [(300,(625,-275)),(400,(0,0))]:
        w,h,floor,objects,_=load_map(lib,number)
        pieces=[(0,i%w-offset[0],i//w-offset[1],s) for i,s in enumerate(floor) if 1600<=s<=1692]
        pieces.extend((1,i%w-offset[0],i//w-offset[1],s) for i,s in enumerate(objects) if s==10011)
        originals[number]=sorted(pieces)
    assert originals[300]==originals[400] and len(originals[300])==71,'Northeast castle must match the original reusable Beast Castle'
    return dict(source_map=300,source_graphic_anchor=[756,58],source_anchor=[760,58],source_graphic=10011,
                reused_map=400,reused_source_anchor=[135,333],translation=[625,-275],source_pieces=71,
                placement_sha256=hashlib.sha256(json.dumps(originals[300]).encode()).hexdigest(),
                owner='scripts/forest/forest_beast_castle.gd',
                limits='Same native floor/upper composition; reuse its fitted 3D surfaces without changing terrain, doors or collision.')

def northeast_cliff_footprint(lib):
    from build_freyja_destinations import load_map
    from prepare_field_assets import navigation_grid
    width,height,floor,objects,flags=load_map(lib,300);lookup=lib.serial_index()
    walk=navigation_grid(width,height,floor,objects,lookup)
    bounds=[754,75,14,14];mask=Image.new('L',tuple(bounds[2:]));anchors=[];cells=set()
    for y in range(79,86):
        for x in range(756,763):
            serial=objects[y*width+x]
            if not 12536<=serial<=12565:continue
            g=lookup[serial];anchors.append([x,y,serial])
            for dy in range(max(1,g['south'])):
                for dx in range(max(1,g['east'])):
                    xx,yy=x+dx,y-dy
                    if not walk[yy*width+xx]:cells.add((xx,yy));mask.putpixel((xx-bounds[0],yy-bounds[1]),255)
    assert len(anchors)==8 and (755,81) not in cells and walk[81*width+755]
    return dict(source_map=300,bounds=bounds,anchors=anchors,blocked_cells=len(cells),
                footpoint=[755,81],footpoint_ground=floor[81*width+755],footpoint_flags=flags[81*width+755],
                limits='Visual footprint only; native collision and the raised terrain remain unchanged.'),mask

def source_water(width,height,floor):
    from build_freyja_outlying import is_water
    pixels=[]
    for i,s in enumerate(floor):
        wet=is_water(s);dry=s>=1000 and not wet;x,y=i%width,i//width
        shore=dry and any(is_water(floor[yy*width+xx])for yy in range(max(0,y-1),min(height,y+2))for xx in range(max(0,x-1),min(width,x+2)))
        pixels.append((255 if wet else 0,255 if dry else 0,255 if shore else 0,255))
    image=Image.new('RGBA',(width,height));image.putdata(pixels)
    return image

def prepare():
    regions=json.loads((ROOT/'assets/maps/falan/sokia/provenance.json').read_text())['regions']
    scopes={area:(300,[x,y,x+w-1,y+h-1]) for area,row in regions.items() for x,y,w,h in [row['bounds']]}
    vegetation=trees({**scopes,'ghana':(3000,None),**{str(n):(n,None) for n in [13002,13004,13006,13008,13009,13010,13014]}})
    bounds=scopes['sokia_coast'][1]
    vegetation["areas"]["ghana"]["fences"]=[]  # Existing native Ghana fences keep their authored owner.
    cliffs,atlas,mask=cave_walls({300:bounds,**{n:None for n in [*range(13001,13015),15564,15525,15526,15524]}},range(12536,12566))
    # The native cliff tops are black occluders; do not fill them with meadow grass.
    from prepare_ruby_region_art import lib
    g=lib.serial_index()[12536];original=lib.image_from_record(g['pack'],g['row'])
    black=next(p for p in original.getdata() if p[3]>=128 and max(p[:3])<=45 and max(p[:3])-min(p[:3])<3)
    extended=Image.new('RGBA',(atlas.width,atlas.height+20));extended.paste(atlas,(0,0));extended.paste(black,(2,atlas.height+2,18,atlas.height+18))
    cliffs['cap_pixel']=[10,atlas.height+10];cliffs['cap_source']=dict(serial=12536,rgba=list(black))
    extended_mask=Image.new('L',extended.size);extended_mask.paste(mask,(0,0))
    atlas,mask=extended,extended_mask
    # A separate graphic identity keeps every existing route's meshes and UVs intact.
    cliffs['graphics']={str(int(s)+200000):{**g,'atlas':'res://assets/maps/falan/sokia/scenery/cliffs.png','mask':'res://assets/maps/falan/sokia/scenery/cliff-mask.png'} for s,g in cliffs['graphics'].items()}
    cliffs['maps']={n:[[x,y,s+200000] for x,y,s in rows] for n,rows in cliffs['maps'].items()}
    if (OUT/'cliffs.json').exists():
        previous=json.loads((OUT/'cliffs.json').read_text())
        assert set(previous['graphics'])==set(cliffs['graphics']),'Review new cliff identities before changing the shared paint layout'
        assert all(previous['graphics'][s]['rgba_sha256']==g['rgba_sha256']for s,g in cliffs['graphics'].items())
        # Added source stations must not repack any existing cave/crag paint or profile.
        cliffs['graphics']=previous['graphics'];cliffs['cap_pixel']=previous['cap_pixel'];cliffs['cap_source']=previous['cap_source']
        atlas=Image.open(OUT/'cliffs.png').copy();mask=Image.open(OUT/'cliff-mask.png').copy()
    from build_freyja_destinations import load_map
    from build_freyja_outlying import is_water
    width,height,floor,objects,flags=load_map(lib,300)
    water=source_water(width,height,floor)
    gw,gh,gfloor,gobjects,_=load_map(lib,3000)
    lookup=lib.serial_index()
    ghana_scenery=[[i%gw,i//gw,s,max(1,lookup[s]['east']),max(1,lookup[s]['south']),lookup[s]['h']] for i,s in enumerate(gobjects) if 12500<=s<=12565 or 11188<=s<=11208]

    ghana_water=Image.new('RGBA',(gw,gh));ghana_water.putdata([(255 if is_water(s) else 0,255 if s>=1000 and not is_water(s) else 0,0,255) for s in gfloor])
    import hashlib
    steles={};stone_atlas=Image.new('RGBA',(1024,256));stone_mask=Image.new('L',stone_atlas.size);sx=2
    for serial in [11566,11567,11569,11571,11574]:
        g=lookup[serial];image=lib.image_from_record(g['pack'],g['row']);bounds=image.getbbox()
        assert sx+image.width+2<=1024 and image.height+4<=256
        stone_atlas.paste(image,(sx,2));stone_mask.paste(image.getchannel('A'),(sx,2))
        pixels=[p for p in image.getdata() if p[3]>=128]
        steles[str(serial)]=dict(origin=[g['x'],g['y']],rect=[sx,2,image.width,image.height],bounds=[g['x']+bounds[0],g['y']+bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]],footprint=[max(1,g['east']),max(1,g['south'])],ground=0,family='obelisk',rgb=[sum(p[c] for p in pixels)/len(pixels)/255 for c in range(3)],rgba_sha256=hashlib.sha256(image.tobytes()).hexdigest())
        sx+=image.width+4
    northeast,northeast_mask=northeast_cliff_footprint(lib)
    return {'vegetation.json':vegetation,'cliffs.json':cliffs,'ghana-scenery.json':ghana_scenery,'steles.json':steles,'mouths.json':mouth_profiles(lib),'castle-reuse.json':castle_reuse(lib),'northeast-cliff-footprint.json':northeast},{'cliffs.png':atlas,'cliff-mask.png':mask,'water.png':water,'ghana-water.png':ghana_water,'steles.png':stone_atlas,'steles-mask.png':stone_mask,'northeast-cliff-footprint.png':northeast_mask}

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();data,images=prepare()
    OUT.mkdir(parents=True,exist_ok=True)
    for name,record in data.items():
        if a.check:assert json.loads((OUT/name).read_text())==record,name
        else:(OUT/name).write_text(json.dumps(record,ensure_ascii=False,separators=(',',':'))+'\n')
    for name,im in images.items():
        if a.check:
            actual=Image.open(OUT/name);assert actual.size==im.size and actual.tobytes()==im.tobytes(),name
        else:im.save(OUT/name)
    print('SOKIA_COAST_SCENERY',len(data['cliffs.json']['maps']['300']),'native cliff anchors;',len(data['vegetation.json']['areas']['sokia_coast']['trees']),'native trees')
if __name__=='__main__':main()
