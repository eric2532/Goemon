"""Bounded two-village map/warp coverage and matched camera evidence."""
import hashlib,json,sys
from pathlib import Path
from collections import deque
from PIL import Image,ImageDraw
import review_ruby_region as source
from build_freyja_destinations import KILI_ROOMS,GHANA_ROOMS,load_map,warp_rows
ROOT=source.ROOT
OUT=ROOT/'build/Other Files/Asset Toolkit/Kili Ghana Villages'

def decode(number,*_):
 w,h,f,o,flags=load_map(source.review.lib,int(number))
 walk=source.review.navigation_grid(w,h,f,o,source.review.lib.serial_index())
 return dict(width=w,height=h,floor=f,objects=o,flags=flags,walk=walk)

def plan():
 OUT.mkdir(parents=True,exist_ok=True)
 stages=[];coverage=[]
 exterior={3200:('kili',[("west-entrance",59,48,58,45),("east-entrance",77,76,80,76),("main-street",62,66,66,66),("chief-terrace",51,66,53,62),("western-houses",38,64,38,59),("southern-houses",62,87,68,87),("hospital",62,58,66,57),("equipment-arcade",67,77,70,77)]),3000:('ghana',[("south-entrance",48,74,48,69),("north-entrance",48,28,48,33),("main-street",50,58,50,53),("central-well",53,57,53,54),("chief-house",41,43,41,39),("eastern-houses",79,74,83,69),("western-house",38,60,38,64),("hospital",52,70,54,72)])}
 warps=list(warp_rows(ROOT.parent/'Magic Power'))
 for number in sorted(KILI_ROOMS|GHANA_ROOMS):
  d=decode(number);w,h=d['width'],d['height'];area=exterior[number][0] if number in exterior else 'interior'
  owner='kili' if number in KILI_ROOMS else 'ghana'
  key=f'{owner}-{number}';cells=[(i%w,i//w) for i,v in enumerate(d['walk']) if v]
  bounds=[[min(x for x,y in cells),min(y for x,y in cells)],[max(x for x,y in cells),max(y for x,y in cells)]]
  if number in exterior:views=exterior[number][1]
  else:
   center=[sum(x for x,y in cells)/len(cells),sum(y for x,y in cells)/len(cells)]
   x,y=min(cells,key=lambda p:(p[0]-center[0])**2+(p[1]-center[1])**2)
   views=[('room',x,y,x,y-1)]
  sections=[dict(key=f'{key}-{label}',at=[x,y],start=[x,y],end=[tx,ty]) for label,x,y,tx,ty in views]
  stages.append(dict(key=key,title=key,source=number,area=area,floor=0 if number in exterior else number,bounds=bounds,sections=sections))
  coverage.append(dict(village=owner,map=number,size=[w,h],walk_cells=len(cells),planes_sha256=hashlib.sha256(json.dumps([list(d['floor']),list(d['objects'])]).encode()).hexdigest(),warps=[r for r in warps if r[0]==number],status='pending matched review',reference='classic server housing; BlueCG parity unverified' if number in [3801,3802,3803,3807] else 'substitute room; original layout unresolved' if number in [3804,3805,3806] else 'original BlueCrossgate client'))
 for area,views,bounds in [('sokia_coast',[('kili-west-approach',274,291,274,294),('kili-east-approach',298,325,294,325)],[[267,285],[303,333]]),('ghana_road',[('ghana-south-approach',704,152,704,147)],[[695,143],[713,160]]),('ghana_north_road',[('ghana-north-approach',704,91,704,96)],[[695,84],[713,101]])]:
  stages.append(dict(key=area,title=area,source=300,area=area,floor=0,bounds=bounds,sections=[dict(key=label,at=[x,y],start=[x,y],end=[tx,ty]) for label,x,y,tx,ty in views]))
 (OUT/'route.json').write_text(json.dumps(dict(seed=41829558,stages=stages),indent=2)+'\n')
 (OUT/'coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+'\n')
 for p in ['scripts/forest/forest_coastal_buildings.gd','scripts/forest/forest_coastal_rooms.gd','scripts/forest/forest_falan_frontier.gd','tools/build_freyja_destinations.py','scripts/forest/forest_falan_room_art.gd','assets/maps/falan/coastal_room_props.gd','assets/maps/falan/coastal_room_floors.png','assets/maps/falan/freyja_destinations_data.gd','assets/maps/falan/room_art_data.gd']:
  target=OUT/'Source baseline'/p;target.parent.mkdir(parents=True,exist_ok=True)
  if not target.exists():target.write_bytes((ROOT/p).read_bytes())
 lookup=source.review.lib.serial_index();sheet=Image.new('RGB',(1600,850),'#263138');draw=ImageDraw.Draw(sheet)
 for i,s in enumerate([11289,11290,11292,11293,11294,11295,11297,11298]):
  e=lookup[s];im=source.review.lib.image_from_record(e['pack'],e['row']);im.thumbnail((390,390))
  x=i%4*400;y=i//4*425;sheet.paste(im,(x,y+25),im);draw.text((x+10,y+5),str(s),fill='white')
 sheet.save(OUT/'original-building-families.jpg')
 print('Planned',len(coverage),'village maps + four bounded approach views')

def compare(phase):
 poses=list({p['name']:p for p in json.loads((OUT/phase/'cameras.json').read_text())}.values());original=OUT/'Original';original.mkdir(exist_ok=True)
 pairs=OUT/('Source vs '+phase);pairs.mkdir(exist_ok=True);changes=OUT/'Before vs After';changes.mkdir(exist_ok=True)
 data={};panels=[]
 for pose in poses:
  name=pose['name'];current=Image.open(OUT/phase/(name+'.png'))
  if pose['kind'] in ['isometric','overhead']:
   number=int(pose['source'])
   if number not in data:data[number]=decode(number)
   native=source.review.reference(pose,data[number],pose['kind']=='overhead');native.save(original/(name+'.png'))
   pair=source.review.panel([native,current],[name+(' | CLASSIC ARCHIVE / BLUECG PARITY UNVERIFIED' if number in [3801,3802,3803,3804,3805,3806,3807] else ' | ORIGINAL CLIENT ART') if pose['kind']=='isometric' else name+' | ORIGINAL GROUND PLAN',phase+' | CURRENT 3D'])
   pair.save(pairs/(name+'.jpg'),quality=92)
  old=OUT/'Before'/(name+'.png')
  if phase=='After' and old.exists():
   pair=source.review.panel([Image.open(old),current],[name+' | BEFORE',name+' | AFTER']);pair.save(changes/(name+'.jpg'),quality=92)
  if pose['kind']=='isometric' and any(k in name for k in ['entrance','main-street','central-well','chief-terrace','approach']):panels.append(name)
 import html
 links=''.join('<section><h2>'+html.escape(n)+'</h2><a href="Before vs After/'+n+'.jpg"><img loading="lazy" src="Before vs After/'+n+'.jpg"></a></section>' for n in panels)
 (OUT/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Kili and Ghana village review</title><style>body{background:#20292e;color:#eee;font:16px system-ui;margin:28px}img{max-width:100%}a{color:#addcf0}h2{font-size:18px}</style><h1>Kili and Ghana</h1><p><a href="KILI_CHECKLIST.md">Kili checklist</a> · <a href="GHANA_CHECKLIST.md">Ghana checklist</a></p>'+links)
 print('Prepared',len(poses),'source/current and matched baseline views')

if __name__=='__main__':
 if '--compare' in sys.argv:compare(sys.argv[-1])
 else:plan()
