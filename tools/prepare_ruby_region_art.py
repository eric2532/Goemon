"""Native palace dimensions for existing solid props; the archive stays read-only."""
import argparse,hashlib,json,sys,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_library as lib
from PIL import Image
from build_falan_room_art import project_wall,FREYJA_WALLS
from recover_venoa_walls import solid_native_paint
from prepare_abanis_cliffs import edge_paint,measured_profile
OUT=ROOT/'assets/maps/falan/black_prayer/palace-proportions.json'

def prepare():
 lookup=lib.serial_index()
 with lib.connection() as db:key=db.execute("SELECT id FROM files WHERE path='BlueCrossgate/map/0/16508.dat'").fetchone()[0]
 raw=lib.source_file(key)[1].read_bytes();w,h,floor,objects,flags=lib.parse_map(raw)
 graphics={}
 for serial in sorted(set(objects)-{0}):
  g=lookup[serial];im=lib.image_from_record(g['pack'],g['row']);b=im.getbbox()
  if not b:continue
  east,south=max(1,g['east']),max(1,g['south'])
  # Compound props are owned at the center of their source blocked footprint.
  dx=(east-south)*16;dy=-(east+south-2)*12
  graphics[str(serial)]=dict(bounds=[g['x']+b[0]-dx,g['y']+b[1]-dy,b[2]-b[0],b[3]-b[1]],
   origin=[g['x'],g['y']],size=list(im.size),span=[east,south],rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest())
 serials=sorted(set(objects)&FREYJA_WALLS)
 atlas=Image.new('RGB',(576,math.ceil((len(serials)+1)*2/16)*100))
 for i,s in enumerate(serials,1):
  im=lib.image_from_record(lookup[s]['pack'],lookup[s]['row'])
  for side in range(2):
   tile=(i-1)*2+side;atlas.paste(project_wall(im,lookup[s],bool(side),background=(0,0,0)),(tile%16*36,tile//16*100))
 result=dict(map_sha256=hashlib.sha256(raw).hexdigest(),graphics=graphics,
  wall_tiles=b''.join((serials.index(s)+1 if s in serials else 0).to_bytes(2,'little') for s in objects).hex(),
  wall_heights=[-lookup[s]['y']+22 for s in serials],wall_serials=serials,
  note='Visible alpha bounds and compound source anchors. Rear surfaces and 3D depth are not recovered.')
 return result,atlas

def trees(scopes=None):
 lookup=lib.serial_index();areas={};graphics={}
 if scopes is None:scopes={'venoa':(2100,None),'kili':(3200,None),'south_lakes':(100,[320,340,460,510]),'sokia_coast':(300,[227,251,306,335])}
 for area,(number,bounds) in scopes.items():
  with lib.connection() as db:key=db.execute('SELECT id FROM files WHERE path=?',(f'BlueCrossgate/map/0/{number}.dat',)).fetchone()[0]
  raw=lib.source_file(key)[1].read_bytes();w,h,f,o,flags=lib.parse_map(raw);placements=[];fences=[]
  if number==300:
   from build_freyja_destinations import load_map
   w,h,f,o,flags=load_map(lib,number)
   from prepare_sokia_outdoor_source import source_folder
   if (source_folder()/'300.dat').exists():raw=(source_folder()/'300.dat').read_bytes()
  for i,s in enumerate(o):
   cx,cy=i%w,i//w
   if not(10058<=s<=10074 or 10085<=s<=10094 or 11188<=s<=11208 or 11363<=s<=11372) or bounds and not(bounds[0]<=cx<=bounds[2] and bounds[1]<=cy<=bounds[3]):continue
   (fences if 11363<=s<=11372 else placements).append([cx,cy,s])
   if str(s) in graphics:continue
   g=lookup[s];im=lib.image_from_record(g['pack'],g['row']);b=im.getbbox()
   leaves=[p for p in im.getdata() if p[3]>=128 and p[1]>p[0]*1.1 and p[1]>p[2]*1.1]
   rgb=[sum(p[c] for p in leaves)/len(leaves)/255. for c in range(3)] if leaves else [1.,1.,1.]
   east,south=max(1,g['east']),max(1,g['south'])
   graphics[str(s)]=dict(origin=[g['x']-(east-south)*16,g['y']+(east+south-2)*12],span=[east,south],bounds=list(b),rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest(),leaf_rgb=rgb)
  areas[area]=dict(source=number,bounds=bounds,trees=placements,fences=fences,map_sha256=hashlib.sha256(raw).hexdigest())
 palettes={}
 for serial in [10058,10085,10088]:
  g=lookup[serial];im=lib.image_from_record(g['pack'],g['row'])
  leaves=[p for p in im.getdata() if p[3]>=128 and p[1]>p[0]*1.1 and p[1]>p[2]*1.1]
  palettes[str(serial)]=[sum(p[c] for p in leaves)/len(leaves)/255. for c in range(3)]
 return dict(areas=areas,graphics=graphics,palettes=palettes)

def walls():
 lookup=lib.serial_index();graphics={};images={};x=y=height=0
 for serial in range(11230,11251):
  g=lookup[serial];original=lib.image_from_record(g['pack'],g['row']);im,shadow=solid_native_paint(original)
  if x+im.width+4>1024:x=0;y+=height;height=0
  graphics[str(serial)]=dict(origin=[g['x'],g['y']],rect=[x+2,y+2,im.width,im.height],rgba_sha256=hashlib.sha256(original.tobytes()).hexdigest(),removed_ground_shadow=shadow)
  images[serial]=im;x+=im.width+4;height=max(height,im.height+4)
 atlas=Image.new('RGBA',(1024,y+height))
 for s,im in images.items():atlas.paste(im,tuple(graphics[str(s)]['rect'][:2]))
 return graphics,atlas

def cave_walls(scopes=None,extra_cliffs=()):
 lookup=lib.serial_index();maps={};graphics={};images={};masks={};x=y=height=0
 if scopes is None:scopes={n:{100:[320,340,460,510],300:[227,251,306,335]}.get(n) for n in [15003,15004,15005,16507,2100,100,300]}
 for number,bounds in scopes.items():
  with lib.connection() as db:key=db.execute('SELECT id FROM files WHERE path=?',(f'BlueCrossgate/map/0/{number}.dat',)).fetchone()[0]
  raw=lib.source_file(key)[1].read_bytes();w,h,f,o,flags=lib.parse_map(raw);rows=[]
  if number==300:
   from build_freyja_destinations import load_map
   w,h,f,o,flags=load_map(lib,number)
  for i,s in [*enumerate(o),*((-1,s) for s in extra_cliffs if number==300)]:
   if i>=0 and bounds and not(bounds[0]<=i%w<=bounds[2] and bounds[1]<=i//w<=bounds[3]):continue
   if number in [2100,100,300]:
    if not 12536<=s<=12565:continue
   elif number in [13002,13004,13006,13008,13009,13010,13014]:
    if not (12675<=s<=12684 or 12926<=s<=12937):continue
   elif 13001<=number<=13014 or number in [15524,15525,15526]:
    if not 13080<=s<=13115:continue
   elif number==15564:
    if not 17840<=s<=17875:continue
   elif not(13000<=s<=13035 or 13324<=s<=13359) or s in [13004,13016,13028]:continue
   serial=s;s=s+100000 if number==16507 else s
   if i>=0:rows.append([i%w,i//w,s])
   if str(s) in graphics:continue
   g=lookup[serial];original=lib.image_from_record(g['pack'],g['row'],2 if number in [15003,15004,15005] else 0)
   visible=original.copy()
   visible.putdata([(r,g,b,a if max(r,g,b)>45 else 0) for r,g,b,a in original.getdata()])
   # The navy/black void is a flat map occluder, not a solid rock column.
   colored=sum(a>=128 for r,g,b,a in visible.getdata())
   if colored<original.width*original.height*.05:
    graphics[str(s)]=dict(source_serial=serial,void_only=True,rgba_sha256=hashlib.sha256(original.tobytes()).hexdigest())
    continue
   im=edge_paint(visible)
   if x+im.width+4>1024:x=0;y+=height;height=0
   source_hash=hashlib.sha256(original.tobytes()).hexdigest()
   profile,_=measured_profile(visible,dict(origin=[g['x'],g['y']],rect=[0,0,im.width,im.height],footprint=[max(1,g['east']),max(1,g['south'])],rgba_sha256=source_hash))
   color=[round(sum(p[c] for p in visible.getdata() if p[3]>=128)/colored/255.,6) for c in range(3)]
   graphics[str(s)]=dict(source_serial=serial,origin=[g['x'],g['y']],bounds=list(visible.getbbox()),rect=[x+2,y+2,im.width,im.height],rgba_sha256=source_hash,profile=profile,fallback_rgb=color)
   images[s]=im;masks[s]=visible.getchannel('A');x+=im.width+4;height=max(height,im.height+4)
  maps[str(number)]=rows
 atlas=Image.new('RGBA',(1024,y+height));mask=Image.new('L',atlas.size)
 for s,im in images.items():
  at=tuple(graphics[str(s)]['rect'][:2]);atlas.paste(im,at);mask.paste(masks[s],at)
 return dict(maps=maps,graphics=graphics),atlas,mask

def annex():
 lookup=lib.serial_index();catalog=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
 with lib.connection() as db:key=db.execute("SELECT id FROM files WHERE path='BlueCrossgate/map/0/15004.dat'").fetchone()[0]
 raw=lib.source_file(key)[1].read_bytes();w,h,f,o,flags=lib.parse_map(raw)
 rows=[[i%w,i//w,s] for i,s in enumerate(o) if s>1000 and not 13000<=s<=13071 and s not in [13268,13269]]
 graphics={};images={};x=y=height=0
 families={10432:'chest',10451:'fence',10455:'fence',11078:'prop',11141:'room_wall',11149:'room_wall',11143:'room_wall',11146:'room_wall',11325:'pillar',17656:'coast_cushion'}
 for serial in sorted({r[2] for r in rows}):
  g=lookup[serial];original=lib.image_from_record(g['pack'],g['row'],2);im,_=solid_native_paint(original)
  if x+im.width+4>1024:x=0;y+=height;height=0
  pixels=[p for p in original.getdata() if p[3]>=128]
  graphics[str(serial)]=dict(origin=[g['x'],g['y']],rect=[x+2,y+2,im.width,im.height],bounds=list(original.getbbox()),footprint=[max(1,g['east']),max(1,g['south'])],ground=bool(g['ground']),family=families.get(serial,catalog['graphics'].get(str(serial),{}).get('family','prop')) or 'prop',rgba_sha256=hashlib.sha256(original.tobytes()).hexdigest(),fallback_rgb=[sum(p[c] for p in pixels)/len(pixels)/255. for c in range(3)])
  images[serial]=(im,original.getchannel('A'));x+=im.width+4;height=max(height,im.height+4)
 atlas=Image.new('RGBA',(1024,y+height));mask=Image.new('L',atlas.size)
 for serial,(im,alpha) in images.items():
  at=tuple(graphics[str(serial)]['rect'][:2]);atlas.paste(im,at);mask.paste(alpha,at)
 return dict(map_sha256=hashlib.sha256(raw).hexdigest(),placements=rows,graphics=graphics),atlas,mask

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();result,atlas=prepare()
 wall=OUT.parent/'palace-walls.png'
 if a.check:
  assert json.loads(OUT.read_text())==result
  with Image.open(wall) as existing:assert existing.mode==atlas.mode and existing.size==atlas.size and existing.tobytes()==atlas.tobytes()
 else:
  OUT.write_text(json.dumps(result,indent=2)+'\n');atlas.save(wall)
 tree_data=trees();tree_file=OUT.parent/'region-trees.json'
 if a.check:assert json.loads(tree_file.read_text())==tree_data
 else:tree_file.write_text(json.dumps(tree_data,indent=2)+'\n')
 wall_data,wall_atlas=walls();wall_file=OUT.parent/'kili-walls.json';wall_png=OUT.parent/'kili-walls.png'
 if a.check:
  assert json.loads(wall_file.read_text())==wall_data
  with Image.open(wall_png) as existing:assert existing.mode==wall_atlas.mode and existing.size==wall_atlas.size and existing.tobytes()==wall_atlas.tobytes()
 else:wall_file.write_text(json.dumps(wall_data,indent=2)+'\n');wall_atlas.save(wall_png)
 cave_data,cave_atlas,cave_mask=cave_walls();cave_file=OUT.parent/'region-cave-walls.json';cave_png=OUT.parent/'region-cave-walls.png';mask_png=OUT.parent/'region-cave-mask.png'
 if a.check:
  assert json.loads(cave_file.read_text())==cave_data
  with Image.open(cave_png) as existing:assert existing.mode==cave_atlas.mode and existing.size==cave_atlas.size and existing.tobytes()==cave_atlas.tobytes()
  with Image.open(mask_png) as existing:assert existing.mode==cave_mask.mode and existing.size==cave_mask.size and existing.tobytes()==cave_mask.tobytes()
 else:cave_file.write_text(json.dumps(cave_data,indent=2)+'\n');cave_atlas.save(cave_png);cave_mask.save(mask_png)
 annex_data,annex_paint,annex_mask=annex()
 stair_record=lib.serial_index()[13268]
 entry_stair=lib.image_from_record(stair_record['pack'],stair_record['row'],0)
 stair_file=OUT.parent/'entry-stair.png'
 if a.check:
  with Image.open(stair_file) as existing:assert existing.mode==entry_stair.mode and existing.size==entry_stair.size and existing.tobytes()==entry_stair.tobytes()
 else:entry_stair.save(stair_file)
 for name,value in [('undersea-annex.json',annex_data),('undersea-annex.png',annex_paint),('undersea-annex-mask.png',annex_mask)]:
  target=OUT.parent/name
  if isinstance(value,dict):
   if a.check:assert json.loads(target.read_text())==value
   else:target.write_text(json.dumps(value,indent=2)+'\n')
  elif a.check:
   with Image.open(target) as existing:assert existing.mode==value.mode and existing.size==value.size and existing.tobytes()==value.tobytes()
  else:value.save(target)
 print(('Verified' if a.check else 'Prepared'),len(result['graphics']),'native palace graphic bounds')
 print('Source vegetation placements:',{area:len(data['trees']) for area,data in tree_data['areas'].items()})
