"""Append-only source package for missing Sokia rooms; reuse the original map renderer."""
import argparse,base64,hashlib,json,sys,zlib
from pathlib import Path
from PIL import Image
import recover_original_crossgate_maps as recovery
from build_falan_room_art import KIND,PALACE_KIND,CELLAR_KIND,CIVIC_KIND,ARENA_KIND,FREYJA_KIND
from build_coastal_villages import KINDS,WALLS
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/sokia/fixed'
VISUAL_ROOMS={3350:'馮奴的家',3352:'馮奴的研究室',3001:'加納村 · 武器防具店',3002:'加納村 · 雜貨店',3008:'加納村 · 酒吧',3010:'加納村 · 醫院',3012:'加納村 · 村長的家',3013:'加納村 · 村長的家地下',3014:'加納村 · 村長的家上樓',3020:'加納村 · 考古學家之家',3021:'加納村 · 魔術師之家',3099:'加納村 · 傳送室'}
MAPS={**VISUAL_ROOMS,5001:'愛鼠的老婆婆之家',5002:'愛鼠的老婆婆之家 · 地下',5003:'飼養師之家',
      **{n:f'流星山丘 · 原始地圖 {n}' for n in range(13002,13015)},23600:'獅子之穴 · 大廳',15564:'風之洞窟 · 入口',13015:'波塔的家',13500:'水之洞窟 · 地下1樓',13501:'水之洞窟 · 地下2樓',13502:'水之洞窟 · 地下3樓',
      15527:'索奇亞東北入口 · 15527',15530:'索奇亞東北洞窟 · 15530',15526:'峽之洞窟 · 中繼走廊',15525:'峽之洞窟 · 牛鬼公主入口'}

def hull(points):
    points=sorted(set(points))
    def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lower=[];upper=[]
    for p in points:
        while len(lower)>1 and cross(lower[-2],lower[-1],p)<=0:lower.pop()
        lower.append(p)
    for p in reversed(points):
        while len(upper)>1 and cross(upper[-2],upper[-1],p)<=0:upper.pop()
        upper.append(p)
    return [list(p) for p in lower[:-1]+upper[:-1]]

def prepare():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    base=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text());lookup=lib.serial_index()
    maps={};used=set()
    for number,title in MAPS.items():
        path=f'BlueCrossgate/map/0/{number}.dat'
        with lib.connection() as db:ident=db.execute('SELECT id FROM files WHERE path=?',(path,)).fetchone()[0]
        raw=lib.source_file(ident)[1].read_bytes();w,h,floor,objects,flags=lib.parse_map(raw)
        serials={s for s in floor if s}|{s for s in objects if s>=1000}
        assert not(serials-lookup.keys()),('Missing original source art',serials-lookup.keys())
        walk=navigation_grid(w,h,floor,objects,lookup);mask=bytearray((w*h+7)//8)
        for i,opened in enumerate(walk):
            if opened:mask[i>>3]|=1<<(i&7)
        visible={};solid_bounds={};void_cliffs=[];cap_pixels={};wall_caps={}
        for serial in serials:
            g=lookup[serial];im=lib.image_from_record(g['pack'],g['row']);box=im.getbbox()
            if box:visible[str(serial)]=[g['x']+box[0],g['y']+box[1],box[2]-box[0],box[3]-box[1]]
            if 12500<=serial<13400 or 17840<=serial<=17875:
                body=im.copy();body.putdata([(r,g,b,a if max(r,g,b)>45 else 0) for r,g,b,a in im.getdata()]);bounds=body.getbbox()
                if bounds:solid_bounds[str(serial)]=[g['x']+bounds[0],g['y']+bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]]
                else:void_cliffs.append(serial)
            if 13152<=serial<=13215 or 16894<=serial<=16927 or serial in WALLS:
                dark=[(i//im.width,abs(i%im.width-im.width*.5),i%im.width) for i,p in enumerate(im.getdata()) if p[3]>=128 and max(p[:3])<=45 and max(p[:3])-min(p[:3])<3]
                if dark:
                    cy,_,cx=min(dark);cap_pixels[str(serial)]=[cx,cy]
                    if 13152<=serial<=13215 or 16894<=serial<=16927 or serial==16998:
                        polygon=hull([(xx,yy) for yy,_,xx in dark if yy<=cy+23])
                        if len(polygon)>=3:
                            wall_base=hull([(i%im.width,i//im.width) for i,p in enumerate(im.getdata()) if p[3]>=128 and -25<=g['y']+i//im.width<=26])
                            wall_caps[str(serial)]=dict(polygon=polygon,base=wall_base,height_pixels=138)
        maps[path]=dict(group='sokia_fixed',sokia_visual_only=number in VISUAL_ROOMS,title=title,size=[w,h],id=number,outdoor=13002<=number<=13014 and any(10050<=s<=10099 or 11188<=s<=11208 for s in objects),raw=recovery.encode(raw),sha256=recovery.digest(raw),bytes=len(raw),walk=recovery.encode(mask),recorded=sum(bool(v&0xC000) for v in flags),cells=w*h,warp_cells=[[i%w,i//w] for i,v in enumerate(flags) if v&2],visible_bounds=visible,solid_bounds=solid_bounds,void_cliffs=void_cliffs,cap_pixels=cap_pixels,wall_caps=wall_caps)
        used.update(serials)
    furniture={**KIND,**PALACE_KIND,**CELLAR_KIND,**CIVIC_KIND,**ARENA_KIND,**FREYJA_KIND,**KINDS}
    furniture.update({s:'room_wall' for s in WALLS if s>=16000})
    furniture.update({s:'room_wall' for s in range(16894,16928)})
    furniture.update({s:'room_wall' for s in range(13152,13216)})
    missing={s for s in used if str(s) not in base['graphics']}
    pages,graphics,_=recovery.pack_graphics(missing,lookup,furniture,lib)
    catalog=dict(schema=1,maps=maps,graphics=graphics,pages=[f'atlas-{i}.png' for i in range(len(pages))])
    surfaces=recovery.rock_surfaces(catalog,pages);solids=recovery.solid_pages(catalog,pages)
    catalog['solid_pages']=[f'solid-{i}.png' for i in range(len(solids))]
    images={**{f'atlas-{i}.png':im for i,im in enumerate(pages)},**{f'solid-{i}.png':im for i,im in enumerate(solids)},**{f'surfaces-{i}.png':im for i,im in enumerate(surfaces)}}
    return catalog,images

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();catalog,images=prepare()
    if a.check:
        assert json.loads((OUT/'catalog.json').read_text())==catalog
        for name,im in images.items():
            actual=Image.open(OUT/name);assert actual.size==im.size and actual.tobytes()==im.tobytes(),name
    else:
        OUT.mkdir(parents=True,exist_ok=True)
        for name,im in images.items():im.save(OUT/name)
        (OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'\n')
    print('SOKIA_FIXED_SOURCE_CHECK maps=',len(catalog['maps']),'new_graphics=',len(catalog['graphics']),'existing graphics/pages preserved')
if __name__=='__main__':main()
