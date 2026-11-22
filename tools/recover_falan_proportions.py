"""Measure native city silhouettes in the original 32/24-pixel isometric frame."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from collections import deque
from PIL import Image
from build_freyja_destinations import load_map
from recover_falan_architecture import opaque_paint

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan'
REVIEW=ROOT/'build/Other Files/Asset Toolkit/Falan Proportions'
CIVIC={1201:(10001,(-339,-3),(1422,1525)),1400:(10002,(66,93),(1526,1621)),1301:(10600,(36,-93),(6707,6776)),1111:(10602,(-168,214.5),None),1112:(10602,(-168,-202.5),None),1121:(10010,(-67.5,-265.5),None),1101:(10004,(7.5,-207),None),1092:(10604,(-231,241.5),None),1091:(10607,(-252,-135),None)}

def mansion_components(image):
 # Flat green ground is not architecture; the three disconnected painted buildings are.
 mask=image.getchannel('A');mask.putdata([0 if g>r*1.25 and g>b*1.15 else a for r,g,b,a in image.getdata()]);image.putalpha(mask)
 w,h=image.size;pending=bytearray(a>=200 for a in mask.getdata());groups=[]
 for index in range(len(pending)):
  if not pending[index]:continue
  pending[index]=0;queue=deque([index]);left=right=index%w;top=bottom=index//w;count=0
  while queue:
   p=queue.popleft();x=p%w;y=p//w;count+=1;left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y)
   for k in [p-1 if x else -1,p+1 if x<w-1 else -1,p-w if y else -1,p+w if y<h-1 else -1]:
    if k>=0 and pending[k]:pending[k]=0;queue.append(k)
  if count>1000:groups.append((count,[left,top,right+1,bottom+1]))
 assert len(groups)==3,'The mansion must retain its main rotunda and two pavilions'
 return [box for _,box in sorted(groups,reverse=True)]

def recover(source):
 sys.path.insert(0,str(source/'tools'))
 import cg_library as library
 lookup=library.serial_index();width,_,ground,objects,_=load_map(library,1000)
 arch=json.loads((OUT/'city_architecture.json').read_text());old=json.loads((OUT/'city_building_surfaces.json').read_text())
 def placed(serial,center):
  hits=[]
  for i,s in enumerate(objects):
   if s!=serial:continue
   e=lookup[s];x=3*(i//width-134)-1.5*(e['south']-1);z=3*(153-i%width)-1.5*(e['east']-1)
   hits.append(((x-center[0])**2+(z-center[1])**2,i))
  assert hits,(serial,center)
  return min(hits)[1]
 records={};REVIEW.mkdir(parents=True,exist_ok=True)
 def reference(key,serial,center,base=None):
  i=placed(serial,center);parts=[(1,i,serial)]
  if base:
   parts += [(0,j,s)for j,s in enumerate(ground)if base[0]<=s<=base[1]]
   if serial==10600:parts += [(1,j,s)for j,s in enumerate(objects)if s==10601]
  layers=[];used={}
  for layer,j,s in parts:
   e=lookup[s];im=library.image_from_record(e['pack'],e['row'])
   x=(j%width+j//width)*32+e['x']-287*32
   y=(j//width-j%width)*24+e['y']+19*24
   layers.append((layer,11*(j//width)-9*(j%width),x,y,im))
   used[str(s)]=hashlib.sha256(im.tobytes()).hexdigest()
  left=min(x for _,_,x,y,im in layers);top=min(y for _,_,x,y,im in layers)
  right=max(x+im.width for _,_,x,y,im in layers);bottom=max(y+im.height for _,_,x,y,im in layers)
  image=Image.new('RGBA',(right-left,bottom-top))
  for _,_,x,y,im in sorted(layers,key=lambda r:r[:2]):image.alpha_composite(im,(x-left,y-top))
  components=[]
  if key=='civic_1301':
   image.save(REVIEW/'native-civic_1301-with-ground.png');components=mansion_components(image)
  bounds=image.getchannel('A').point(lambda a:255 if a>=200 else 0).getbbox();assert bounds
  if components:bounds=(min(b[0]for b in components),min(b[1]for b in components),max(b[2]for b in components),max(b[3]for b in components))
  sx=(center[0]-center[1])*32/3;sy=(center[0]+center[1])*8
  rect=[left+bounds[0]-sx,top+bounds[1]-sy,bounds[2]-bounds[0],bounds[3]-bounds[1]]
  image.crop(bounds).save(REVIEW/f'original-{key}.png')
  records[key]={'graphic':serial,'center':center,'source_rect':rect,'parts':len(parts),'rgba_hashes':used}
  if components:records[key]['components']=[[left+a-sx,top+b-sy,c-a,d-b]for a,b,c,d in components]
 for serial,r in arch['graphics'].items():
  row=next(r for r in arch['bindings']if r['reference_graphic']==int(serial));reference('house_'+serial,int(serial),row['source_center'])
 done=set()
 for r in old['composites']:
  s=r['reference_graphic']
  if s in done:continue
  reference('special_'+str(s),s,r['source_center']);done.add(s)
 for floor,(serial,center,base)in CIVIC.items():reference('civic_'+str(floor),serial,center,base)
 rows=['extends RefCounted','## Generated from native map 1000; rectangles are in source pixels relative to each building owner.','const RECTS={']
 for key,r in records.items():rows.append(' "%s":Rect2(%s),'%(key,','.join(f'{v:.9f}'for v in r['source_rect'])))
 rows+=['}','const COMPONENTS={']
 for key,r in records.items():
  if 'components'in r:rows.append(' "%s":[%s],'%(key,','.join('Rect2(%s)'%','.join(f'{v:.9f}'for v in rect)for rect in r['components'])))
 rows.append('}')
 paints={};images=[];masks=[];x=y=row_height=0
 for key in records:
  if key.startswith('house_'):continue
  with Image.open(REVIEW/f'original-{key}.png')as original:
   original=original.convert('RGBA');im=opaque_paint(original);mask=original.getchannel('A')
   if key=='civic_1301':mask.putdata([0 if g>r*1.25 and g>b*1.15 else a for r,g,b,a in original.getdata()])
  if x+im.width+4>2048:x=0;y+=row_height;row_height=0
  paints[key]=[x+2,y+2,im.width,im.height];images.append((im,(x+2,y+2)));masks.append((mask,(x+2,y+2)))
  x+=im.width+4;row_height=max(row_height,im.height+4)
 atlas=Image.new('RGBA',(2048,y+row_height));alpha=Image.new('L',atlas.size)
 for im,at in images:atlas.paste(im,at)
 for mask,at in masks:alpha.paste(mask,at)
 rows += ['const ATLAS=preload("res://assets/maps/falan/city_civic_source_paint.png")','const PAINT={']
 for key,rect in paints.items():rows.append(' "%s":Rect2(%s),'%(key,','.join(map(str,rect))))
 rows.append('}');rows.append('const MASK=preload("res://assets/maps/falan/city_civic_source_mask.png")')
 return records,'\n'.join(rows)+'\n',atlas,alpha

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power');p.add_argument('--check',action='store_true');a=p.parse_args()
 records,data,atlas,alpha=recover(a.source)
 meta={'records':records,'projection':{'horizontal_pixels_per_unit':32/3,'floor_pixels_per_unit':8,'vertical_pixels_per_unit':(2*((32/3)**2-8**2))**.5},'method':'Original opaque silhouette bounds, including native ground-layer facade pieces for the three compound civic buildings.'}
 path=OUT/'city_proportion_references'
 if a.check:
  with Image.open(OUT/'city_civic_source_paint.png')as actual:assert actual.tobytes()==atlas.tobytes()
  with Image.open(OUT/'city_civic_source_mask.png')as actual:assert actual.tobytes()==alpha.tobytes()
  with Image.open(OUT/'city_house_projection_mask.png')as mask,Image.open(OUT/'city_architecture.png')as houses:assert mask.tobytes()==houses.getchannel('A').tobytes()
  assert path.with_suffix('.gd').read_text()==data
  assert json.loads(path.with_suffix('.json').read_text())==json.loads(json.dumps(meta))
 else:
  atlas.save(OUT/'city_civic_source_paint.png',optimize=True);alpha.save(OUT/'city_civic_source_mask.png',optimize=True)
  with Image.open(OUT/'city_architecture.png')as houses:houses.getchannel('A').save(OUT/'city_house_projection_mask.png',optimize=True)
  path.with_suffix('.gd').write_text(data);path.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n')
 print('PASS: measured',len(records),'source archetypes covering 89 city buildings')
