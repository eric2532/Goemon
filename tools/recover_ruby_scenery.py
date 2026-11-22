"""Rectify native Ruby-palace paint for shared solid scenery."""
import argparse,hashlib,json,sys
from collections import deque
from pathlib import Path
from PIL import Image,ImageStat,ImageChops
from build_village_building_surfaces import surface_atlas
from prepare_arena_carvings import shallow_depth
from recover_falan_landmarks import rect
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/black_prayer'
PATCHES={
 'books_16079':(16079,[(41,124),(142,55),(142,190),(41,259)],True,(112,112)),
 'books_16080':(16080,[(41,124),(142,55),(142,190),(41,259)],True,(112,112)),
 'books_16143':(16143,[(41,124),(153,47),(153,193),(41,269)],True,(112,112)),
 'case_red':(16080,[(149,52),(156,47),(156,155),(149,160)],False,(32,96)),
 'case_gilt':(16080,[(2,103),(37,127),(37,138),(2,114)],False,(96,32)),
 'column_16464':(16464,[(4,44),(31,59),(31,213),(4,198)],True,(112,112)),
 'column_16499':(16499,[(3,34),(30,51),(30,208),(3,191)],True,(112,112)),
 'picture_16130':(16130,[(7,15),(46,42),(46,87),(7,60)],True,(112,112)),
 'picture_16131':(16131,[(6,14),(39,37),(39,71),(6,48)],True,(112,112)),
 'picture_16132':(16132,[(7,15),(46,42),(46,87),(7,60)],True,(112,112)),
 'picture_gilt':(16130,[(18,18),(28,25),(28,26),(18,19)],False,(112,24)),
 'court_linen':(16115,[(5,89),(94,26),(121,44),(31,107)],True,(112,112)),
 'court_red':(16140,[(37,29),(42,26),(47,30),(42,33)],False,(32,32)),
 'cabinet_face':(16140,[(25,50),(71,19),(71,48),(25,78)],True,(112,112)),
 'stool_red':(16204,[(17,16),(30,16),(30,28),(17,28)],False,(32,32)),
 'stool_purple':(16205,[(17,16),(30,16),(30,28),(17,28)],False,(32,32)),
 'vase_blue':(16140,[(18,26),(26,26),(26,34),(18,34)],False,(32,32)),
 'chair_red':(16124,[(10,38),(23,30),(32,36),(20,44)],False,(48,48)),
 'chair_ivory':(16124,[(28,16),(29,16),(29,19),(28,19)],False,(24,48)),
 'plinth_green':(16100,[(9,45),(18,51),(18,88),(9,82)],False,(32,96)),
 'plinth_gilt':(16100,[(6,35),(20,43),(20,46),(6,38)],False,(64,24)),
 'curtain_16465':(16465,[(4,137),(58,106),(58,230),(4,251)],True,(112,112)),
 'curtain_16466':(16466,[(61,174),(96,151),(96,284),(61,309)],True,(112,112)),
 'curtain_side':(16466,[(29,156),(59,176),(59,311),(29,294)],True,(112,112)),
 'curtain_frieze_16465':(16465,[(2,98),(83,53),(83,78),(2,124)],True,(112,112)),
 'curtain_frieze_16466':(16466,[(63,140),(154,77),(154,105),(63,169)],True,(112,112)),
 'curtain_canopy':(16466,[(43,108),(150,35),(150,60),(59,126)],True,(112,112)),
 'armor_16193':(16193,[(52,76),(112,76),(112,193),(52,193)],True,(112,112)),
 'armor_16196':(16196,[(0,135),(52,135),(52,252),(0,252)],True,(112,112)),
 'pedestal_lacquer':(16128,[(16,27),(18,26),(18,29),(16,30)],False,(24,48)),
 'pedestal_blue':(16128,[(10,9),(14,9),(14,18),(10,18)],False,(32,64)),
 'pedestal_lip':(16128,[(12,1),(15,1),(15,4),(12,4)],False,(24,24)),
 'mirror_glass':(16223,[(8,32),(38,12),(38,63),(8,83)],True,(112,112)),
 'mirror_lacquer':(16223,[(46,103),(49,101),(49,112),(46,114)],False,(32,64)),
 'mirror_vase':(16223,[(8,106),(12,104),(12,115),(8,117)],False,(32,64)),
 'flower_pot_16218':(16218,[(19,55),(24,55),(24,60),(19,60)],False,(48,64)),
 'flower_pot_16219':(16219,[(31,51),(37,51),(37,57),(31,57)],False,(64,48)),
 'flower_pot_16232':(16232,[(34,41),(39,41),(39,45),(34,45)],False,(64,32)),
}

CORDS={16465:[(64,3),(65,30),(67,48),(74,54),(82,56),(92,55),(104,53),(111,50)],
 16466:[(14,8),(15,30),(17,43),(27,49),(43,51),(60,52),(80,52),(96,50),(110,47)]}
BOUQUET_CROPS={16218:[(0,0,44,47)],16219:[(0,0,68,47)],16232:[(0,0,64,44)],
 16223:[(0,70,22,104),(31,68,56,94)]}

def bouquet_palette(images):
 result={}
 for serial,boxes in BOUQUET_CROPS.items():
  pixels=[(r,g,b) for box in boxes for r,g,b,a in images[serial].crop(box).getdata() if a>=128]
  groups={'green':[p for p in pixels if p[1]>p[0]*1.1 and p[1]>p[2]*1.1 and p[1]>60],
   'ivory':[p for p in pixels if p[0]>180 and p[1]>160 and p[2]>120]}
  if serial==16218:groups['warm']=[p for p in pixels if p[0]>p[1]*1.4 and p[0]>p[2]*1.4 and p[0]>100]
  if serial==16219:groups['violet']=[p for p in pixels if p[2]>p[0]*1.1 and p[2]>p[1]*1.2 and p[2]>100]
  if serial==16232:groups['pink']=[p for p in pixels if p[0]>p[1]*1.22 and p[0]>p[2]*1.1 and p[2]>p[1]*.65 and p[0]>140]
  if serial in [16218,16219]:groups['gold']=[p for p in pixels if p[0]>p[1]*.9 and p[1]>p[2]*1.5 and p[1]>90]
  assert all(len(group)>=3 for group in groups.values()),(serial,{k:len(v) for k,v in groups.items()})
  result[serial]={name:[round(sum(p[c] for p in group)/len(group)/255,6) for c in range(3)] for name,group in groups.items()}
 return result

def prepare(source):
 sys.path.insert(0,str(source/'tools'))
 import cg_library as lib
 lookup=lib.serial_index();images={};hashes={}
 for serial in {p[0] for p in PATCHES.values()}|{16193,16196}|set(BOUQUET_CROPS):
  entry=lookup[serial];im=lib.image_from_record(entry['pack'],entry['row']);images[serial]=im
  hashes[str(serial)]={'pack':entry['pack'],'row':entry['row'],'rgba_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
 for name,(serial,quad,feature,size) in PATCHES.items():
  if name.startswith(('column_','picture_')):
   ul,ur,lr,ll=quad
   patch=images[serial].transform(size,Image.Transform.QUAD,(*ul,*ll,*lr,*ur),Image.Resampling.BICUBIC)
   assert patch.getchannel('A').getextrema()==(255,255),name
   assert not feature or size==(112,112),name
 paint_images=images.copy()
 for serial in [16193,16196]:
  body=images[serial].copy()
  for py in range(body.height):
   for px in range(body.width):
    r,g,b,a=body.getpixel((px,py))
    if r>g*1.4 and r>b*1.4:body.putpixel((px,py),(r,g,b,0))
  paint_images[serial]=body
 atlas,rows=surface_atlas(paint_images,PATCHES)
 for name in ['armor_16193','armor_16196']:
  index=list(PATCHES).index(name);x,y,w,h=rect(index,(112,112));tile=atlas.crop((x,y,x+w,y+h))
  original=tile.copy()
  queue=deque((px,py) for py in range(h) for px in range(w) if tile.getpixel((px,py))[3]>=128)
  seen=set(queue);assert queue,name
  # Extend only transparent derivative pixels so fitted rear/edge surfaces have native paint, never holes.
  while queue:
   px,py=queue.popleft();r,g,b,a=tile.getpixel((px,py))
   for nx,ny in [(px-1,py),(px+1,py),(px,py-1),(px,py+1)]:
    if not (0<=nx<w and 0<=ny<h) or (nx,ny) in seen:continue
    tile.putpixel((nx,ny),(r,g,b,255));seen.add((nx,ny));queue.append((nx,ny))
  assert all(tile.getpixel((px,py))==original.getpixel((px,py)) for py in range(h) for px in range(w) if original.getpixel((px,py))[3]>=128),name
  assert tile.getchannel('A').getextrema()[0]>=128,name
  atlas.paste(tile,(x,y))
 colors={}
 for name in ['chair_ivory','picture_gilt','chair_red']:
  serial,quad,feature,size=PATCHES[name];ul,ur,lr,ll=quad
  patch=images[serial].transform(size,Image.Transform.QUAD,(*ul,*ll,*lr,*ur),Image.Resampling.BICUBIC)
  colors[name]=[round(v/255.0,6) for v in ImageStat.Stat(patch).mean[:3]]
 # Source armor palette, excluding the spear/background and separating plate highlights from joints.
 pixels=[p for p in images[16193].crop((58,93,108,182)).getdata() if p[3]>=128]
 tones=sorted(pixels,key=lambda p:sum(p[:3]))
 for name,low,high in [('armor_joint',.08,.22),('armor_plate',.50,.75),('armor_edge',.85,.98)]:
  band=tones[int(len(tones)*low):int(len(tones)*high)]
  colors[name]=[round(sum(p[c] for p in band)/len(band)/255,6) for c in range(3)]
 for name,serial,bounds in [('armor_shaft',16193,(22,58,26,65)),('curtain_gold',16466,(122,34,135,47))]:
  sample=images[serial].crop(bounds)
  colors[name]=[round(v/255,6) for v in ImageStat.Stat(sample,mask=sample.getchannel('A')).mean[:3]]
 rows.append('}');rows.append('const COLORS='+json.dumps(colors))
 assert all(0<=v<=112 for path in CORDS.values() for p in path for v in p)
 rows.append('const CORDS={'+','.join(str(k)+':'+json.dumps([[round(x/112,6),round(y/112,6)] for x,y in path]) for k,path in CORDS.items())+'}')
 palettes=bouquet_palette(images)
 rows.append('const BOUQUETS={'+','.join(str(k)+':'+json.dumps(v) for k,v in palettes.items())+'}')
 rows[1]='## Generated by tools/recover_ruby_scenery.py; original Ruby palace paint.'
 topper=images[16100].crop((3,0,38,34))
 assert topper.getbbox() is not None
 return atlas,topper,'\n'.join(rows)+'\n',{'sources':hashes,'patches':PATCHES,'colors':colors,'cords_rectified_pixels':CORDS,'topper_crop':[3,0,38,34],'bouquet_crops':BOUQUET_CROPS,'bouquet_palettes':palettes,'armor_paint':'Native body crops light the fitted solid plates; native palette materials separate ridges, fingers and articulated seams. Brown shaft pixels (R>1.4G and R>1.4B) are separated from the armor derivative before nearest native-color extension of transparent pixels. Retained opaque plate paint and archive masters stay intact. Unseen backs reuse the recovered view.','mirror_glass':'Native static reflection crop excludes the original attached flowers; the solid mirror keeps the painted reflection planar.','flowers':'Original sprite petal/leaf palettes and pot paint; 3D clusters reuse immutable Wind Meadow flower GLBs with owned vertex-color copies. Branch depth and unseen shapes are fitted.','method':'Native curtain cloth/canopy paint follows shared folded geometry; traced native cords wrap those same folds. Native friezes and small pedestal faces also supply separate bounded relief. Native column faces and framed picture art rectified without black tops; shared box/face geometry retains source placements. Native bookcase fronts rectified without black isometric tops; existing modular boxes and ledges supply depth. Blue pedestal ornaments retain original cropped pixels.'}

CARVINGS={
 'chair_back':(16124,[(20,-3),(44,13),(44,39),(20,23)],True,(36,56)),
 'cabinet_carving':(16140,[(25,50),(71,19),(71,48),(25,78)],True,(96,48)),
 'arched_mirror':(16137,[(-1,21),(35,-4),(35,61),(-1,86)],True,(36,80)),
 'tripod_plate':(17680,[(0,0),(31,0),(31,27),(0,27)],True,(32,32)),
 'curtain_frieze_16465':(16465,[(2,98),(83,53),(83,78),(2,124)],True,(112,40)),
 'curtain_frieze_16466':(16466,[(63,140),(154,77),(154,105),(63,169)],True,(112,40)),
 'pedestal_16128':(16128,[(2,27),(13,34),(13,60),(2,53)],True,(32,64)),
 'pedestal_16129':(16129,[(15,33),(27,26),(27,54),(15,62)],True,(32,64)),
 'mirror_cabinet':(16223,[(13,125),(40,107),(40,127),(13,145)],True,(96,48)),
}
RISE={'chair_back':.07,'cabinet_carving':.055,'arched_mirror':.025,'tripod_plate':.025,
 'curtain_frieze_16465':.085,'curtain_frieze_16466':.085,
 'pedestal_16128':.045,'pedestal_16129':.045,'mirror_cabinet':.045}

def prepare_carvings(source):
 sys.path.insert(0,str(source/'tools'))
 import cg_library as lib
 images={};hashes={}
 for serial in {p[0] for p in CARVINGS.values()}:
  entry=lib.serial_index()[serial];im=lib.image_from_record(entry['pack'],entry['row']);images[serial]=im
  hashes[str(serial)]={'pack':entry['pack'],'row':entry['row'],'rgba_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
 atlas,_=surface_atlas(images,CARVINGS);depths=Image.new('L',atlas.size);outlines={}
 rows=['extends RefCounted','## Generated native Ruby furniture paint; relief interprets source shading.',
  'const ATLAS=preload("res://assets/maps/falan/black_prayer/carvings.png")',
  'const DEPTH=preload("res://assets/maps/falan/black_prayer/carvings_depth.png")','const FEATURES={']
 for i,(name,patch) in enumerate(CARVINGS.items()):
  x,y,w,h=rect(i,patch[3]);tile=atlas.crop((x,y,x+w,y+h))
  if name=='chair_back':
   for py in range(round(h*.72),h):
    for px in range(w):
     r,g,b,a=tile.getpixel((px,py))
     if r>g*1.7 and g<110 and b<90:tile.putpixel((px,py),(r,g,b,0))
   atlas.paste(tile,(x,y))
  stone=ImageChops.multiply(tile.convert('L'),tile.getchannel('A'))
  if name=='arched_mirror':
   stone.putdata([value if r>b*1.2 and g>b*1.1 else 0 for value,(r,g,b,a) in zip(stone.getdata(),tile.getdata())])
  depth=shallow_depth(stone);low,high=depth.getextrema();assert low==0 and 0<high<=255,name;depths.paste(depth,(x,y))
  rows.append(f' "{name}":[Rect2i({x},{y},{w},{h}),{RISE[name]}],')
  if name in ['chair_back','arched_mirror','tripod_plate']:
   left=[];right=[]
   for py in range(0,h,2):
    visible=[px for px in range(w) if tile.getpixel((px,py))[3]>=128]
    if not visible:continue
    left.append([round(min(visible)/w-.5,6),round(.5-py/h,6)])
    right.append([round((max(visible)+1)/w-.5,6),round(.5-py/h,6)])
   outline=left+right[::-1];assert len(outline)>=6,name
   assert all(-.5<=v<=.5 for p in outline for v in p),name
   area=abs(sum(outline[j][0]*outline[(j+1)%len(outline)][1]-outline[(j+1)%len(outline)][0]*outline[j][1] for j in range(len(outline))))*.5
   assert .05<area<=1.0,name
   outlines[name]=outline
 rows.append('}');rows.append('const OUTLINES='+json.dumps(outlines))
 crop=images[17680].crop((9,25,21,46));rgb=ImageStat.Stat(crop,mask=crop.getchannel('A')).mean[:3]
 colors={'tripod_metal':[round(v/255,6) for v in rgb]};rows.append('const COLORS='+json.dumps(colors))
 meta={'sources':hashes,'patches':CARVINGS,'maximum_relief_metres':RISE,'outlines':outlines,'colors':colors,
  'mirror_depth':'Only warm native frame strokes supply relief; painted reflection stays planar.',
  'method':'Rectified native paint, alpha-derived furniture silhouettes and shared pale-stroke shallow depth, including native curtain friezes and small pedestal faces. Lower red seat pixels are separated from the chair-back layer. Depth, unseen rear faces and 3D placement are fitted interpretations; original archive images stay intact.'}
 return atlas,depths,'\n'.join(rows)+'\n',meta

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power');p.add_argument('--check',action='store_true');a=p.parse_args()
 atlas,topper,data,meta=prepare(a.source.resolve())
 carving,depth,carving_data,carving_meta=prepare_carvings(a.source.resolve())
 if a.check:
  for name,expected in [('scenery.png',atlas),('pedestal_top.png',topper),('carvings.png',carving),('carvings_depth.png',depth)]:
   with Image.open(OUT/name) as actual:assert actual.size==expected.size and actual.tobytes()==expected.tobytes(),name
  assert (OUT/'scenery.gd').read_text()==data
  assert json.loads((OUT/'scenery.json').read_text())==json.loads(json.dumps(meta))
  assert (OUT/'carvings.gd').read_text()==carving_data
  assert json.loads((OUT/'carvings.json').read_text())==json.loads(json.dumps(carving_meta))
  print('RUBY_SCENERY_CHECK native furniture paint, alpha silhouettes and bounded carving depth preserved')
 else:
  OUT.mkdir(parents=True,exist_ok=True);atlas.save(OUT/'scenery.png',optimize=True);topper.save(OUT/'pedestal_top.png',optimize=True)
  carving.save(OUT/'carvings.png',optimize=True);depth.save(OUT/'carvings_depth.png',optimize=True)
  (OUT/'carvings.gd').write_text(carving_data);(OUT/'carvings.json').write_text(json.dumps(carving_meta,indent=2)+'\n')
  (OUT/'scenery.gd').write_text(data);(OUT/'scenery.json').write_text(json.dumps(meta,indent=2)+'\n');print('Recovered native furniture paint, silhouettes and source-derived carvings')
if __name__=='__main__':main()
