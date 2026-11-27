"""Read-only PG0 census/overviews. Blocked bits nominate crops, never prove buildings."""
from array import array
from collections import Counter,OrderedDict,deque
import base64
import hashlib
import json
from pathlib import Path
import re
import zlib
from PIL import Image,ImageDraw
from prepare_east_nature import sources

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Background Layers'
CATALOG=ROOT/'assets/maps/original_crossgate/east/catalog.json'
KNOWN={31954:'Existing exact71-piece BeastCastle owner; compare source compound, not a missing-body claim.',43500:'Confirmed16 split leaf-cottage BG/FG compounds; Village owns source extraction, pending runtime implementation.',58000:'Source DragonHourglass compound; Root private candidate, current hook status separate.',58001:'Destroyed DragonHourglass compound; Root private candidate, current hook status separate.'}

class Native:
    def __init__(self):self.table,_,self.pins=sources();self.pages=OrderedDict();self.tiles=OrderedDict();self.native_tiles={}
    def crop(self,serial):
        if serial in self.native_tiles:return self.native_tiles[serial]
        g,path=self.table[serial]
        if path not in self.pages:
            if len(self.pages)>=5:self.pages.popitem(last=False)
            self.pages[path]=Image.open(path).convert('RGBA')
        self.pages.move_to_end(path);x,y,w,h=map(int,g['rect'])
        result=self.pages[path].crop((x,y,x+w,y+h))
        if w*h<=5000:self.native_tiles[serial]=result
        return result
    def small(self,serial,scale):
        key=(serial,round(scale,7))
        if key not in self.tiles:
            if len(self.tiles)>=6000:self.tiles.popitem(last=False)
            im=self.crop(serial);self.tiles[key]=im.resize((max(1,round(im.width*scale)),max(1,round(im.height*scale))),Image.Resampling.BOX)
        self.tiles.move_to_end(key);return self.tiles[key]

def decode(row):
    w,h=map(int,row['size']);n=w*h
    token=row.get('reference_variant_raw') if row.get('active_layout_variant')=='pinned-reference' else row.get('restored_raw',row['raw'])
    raw=zlib.decompress(base64.b64decode(token));v=array('H');v.frombytes(raw[20:20+n*4])
    bits=zlib.decompress(base64.b64decode(row['walk']))
    assert len(raw)==20+n*6 and len(bits)==(n+7)//8
    return w,h,raw,v,bits,{int(k):int(s) for k,s in row.get('graphic_aliases',{}).items()}

def clusters(w,h,values,bits):
    blocked={i for i in range(w*h) if values[i]>=1000 and not 5000<=values[i]<=5008 and not bits[i>>3]&(1<<(i&7))}
    output=[]
    while blocked:
        start=blocked.pop();todo=[start];component=[]
        while todo:
            i=todo.pop();component.append(i);x,y=i%w,i//w
            for j in ([i-1] if x else [])+([i+1] if x<w-1 else [])+([i-w] if y else [])+([i+w] if y<h-1 else []):
                if j in blocked:blocked.remove(j);todo.append(j)
        if len(component)<4:continue
        xs=[i%w for i in component];ys=[i//w for i in component]
        output.append(dict(cells=len(component),bounds=[min(xs),min(ys),max(xs)-min(xs)+1,max(ys)-min(ys)+1],floor_native_ids=len({values[i] for i in component}),role='Candidate only: native blocked-land component, not evidence of a structure.'))
    return sorted(output,key=lambda r:-(min(r['cells'],512)+r['floor_native_ids']))

def overview(native,w,h,values,aliases):
    n=w*h;scale=min(600./((w+h)*32+1024),440./((w+h)*24+1024));margin=512*scale
    image=Image.new('RGBA',(620,460),(37,41,35,255));objects=[]
    for i in range(n):
        x,y=i%w,i//w;serial=aliases.get(values[i],values[i])
        if serial>=1000 and serial in native.table:
            g=native.table[serial][0];u=(x+y)*32+g['origin'][0];v=(y-x+w)*24+g['origin'][1]
            image.alpha_composite(native.small(serial,scale),(round(u*scale+margin),round(v*scale+margin)))
        serial=aliases.get(values[n+i],values[n+i])
        if serial>=1000 and serial in native.table:objects.append((y*11-x*9,x+y,i,serial,x,y))
    both=image.copy()
    for depth,u,i,serial,x,y in sorted(objects):
        g=native.table[serial][0];px=(x+y)*32+g['origin'][0];py=(y-x+w)*24+g['origin'][1]
        both.alpha_composite(native.small(serial,scale),(round(px*scale+margin),round(py*scale+margin)))
    return image.convert('RGB'),both.convert('RGB')

def run():
    OUT.mkdir(exist_ok=True);(OUT/'.gdignore').touch();(OUT/'overviews').mkdir(exist_ok=True)
    catalog=json.loads(CATALOG.read_text());native=Native();rows=[];all_bg=Counter();bg_maps={};outliers={}
    def priority(item):
        path,row=item;size=row['size'][0]*row['size'][1]
        urban=bool(re.search('城|村|鎮|镇|港|碼頭|码头|宮|宫|神殿|城堡|教堂|教會|教会',row.get('title','')))
        return (0 if urban and row.get('outdoor') else 1 if row.get('outdoor') else 2 if urban else 3,size,int(path.rsplit('/',1)[1][:-4]))
    ordered=sorted(catalog['maps'].items(),key=priority)
    for at,(path,row) in enumerate(ordered):
        mapid=int(path.rsplit('/',1)[1][:-4]);w,h,raw,values,bits,aliases=decode(row);n=w*h;bg=Counter();fg=Counter();large=[]
        for serial,count in Counter(values[:n]).items():
            if serial<1000:continue
            serial=aliases.get(serial,serial);bg[serial]+=count;all_bg[serial]+=count;bg_maps.setdefault(serial,[]).append(mapid)
            g=native.table[serial][0]
            if g['rect'][2:] not in ([64,47],[64,48]) or g['origin']!=[-32,-24] or g['footprint']!=[1,1]:
                outliers[serial]=dict(graphic=serial,pixels=g['rect'][2:],origin=g['origin'],footprint=g['footprint'],source_rgba_sha256=g['rgba_sha256']);large.append(serial)
        for serial,count in Counter(values[n:]).items():
            if serial>=1000:fg[aliases.get(serial,serial)]+=count
        compounds=clusters(w,h,values,bits)
        if not all((OUT/'overviews'/f'{mapid}-{suffix}.jpg').exists() for suffix in ['bg','both']):
            print('BG_RENDER',mapid,w,h,flush=True)
            bg_image,both=overview(native,w,h,values,aliases)
            bg_image.save(OUT/'overviews'/f'{mapid}-bg.jpg',quality=86);both.save(OUT/'overviews'/f'{mapid}-both.jpg',quality=86)
        rows.append(dict(map=mapid,title=row.get('title'),size=[w,h],outdoor=row.get('outdoor',False),source_raw_sha256=hashlib.sha256(raw).hexdigest(),legacy_owner_retained=row.get('east_existing_owner',False),layer0_graphics=[dict(graphic=s,count=c) for s,c in bg.items()],layer1_graphics=[dict(graphic=s,count=c) for s,c in fg.items()],nonstandard_bg_graphics=large,blocked_land_compound_candidates=compounds,known_compound_owner=KNOWN.get(mapid),coverage='Both active native planes decoded and native-overview-rendered. Visual classification pending; candidates are not confirmed structures.',visual_decision='unreviewed',reference_scale='Downsampled overview only; exact bounded native crops required to confirm structures.'))
        if (at+1)%25==0:print('BG_CENSUS',at+1,'/',len(ordered),flush=True)
        if (at+1)%25==0:(OUT/'census-progress.json').write_text(json.dumps(dict(maps=rows,source_catalog_sha256=hashlib.sha256(CATALOG.read_bytes()).hexdigest())))
    (OUT/'census.json').write_text(json.dumps(dict(maps=rows,map_count=len(rows),unique_bg_graphics=len(all_bg),bg_graphics=[dict(graphic=s,placements=c,maps=bg_maps[s]) for s,c in sorted(all_bg.items())],nonstandard_graphics=list(outliers.values()),source_catalog_sha256=hashlib.sha256(CATALOG.read_bytes()).hexdigest(),limits=['Blocked navigation alone never proves buildings.','All negative visual decisions require source-picture review.','Overviews are candidate indexes; exact source crop proof comes separately.']),indent=2))
    for start in range(0,len(rows),12):
        sheet=Image.new('RGB',(1860,1920),(29,34,38));draw=ImageDraw.Draw(sheet)
        for j,row in enumerate(rows[start:start+12]):
            x=(j%3)*620;y=(j//3)*480
            bg=Image.open(OUT/'overviews'/f"{row['map']}-bg.jpg");both=Image.open(OUT/'overviews'/f"{row['map']}-both.jpg")
            pair=Image.new('RGB',(1240,460));pair.paste(bg,(0,0));pair.paste(both,(620,0));pair.thumbnail((620,440));sheet.paste(pair,(x,y+28))
            draw.text((x+5,y+5),f"{row['map']} {row['title']} | PG0 / PG0+PG1",fill='white')
        sheet.save(OUT/f'overview-contact-{start//12+1:02d}.jpg',quality=91)
    print('BG_CENSUS_COMPLETE maps=',len(rows),'uniquePG0=',len(all_bg),'nonstandard=',len(outliers),flush=True)

if __name__=='__main__':run()
