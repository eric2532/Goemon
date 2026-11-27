"""Recover source NPCs and encounter membership for the locked South Gate–Kili corridor."""
import argparse,hashlib,json,re,sys
from pathlib import Path
from PIL import Image
from prepare_snow_region_population import rows,SOURCE,ARCHIVE,ROOT
OUT=ROOT/'assets/maps/falan/south_kili_route'
CAVES=[11000,11001,11002,15005,15003,15004,15592,15593,15594]

def prepare(pack=False):
 OUT.mkdir(exist_ok=True)
 for proof in json.loads((SOURCE/'references.json').read_text()):assert hashlib.sha256((SOURCE/proof['file']).read_bytes()).hexdigest()==proof['sha256']
 sys.path.insert(0,str(ARCHIVE/'tools'));import cg_assets as cg;import cg_library as lib
 from build_freyja_destinations import load_map
 maps={i:load_map(lib,i) for i in CAVES+[100,300,3200]}
 lookup=lib.serial_index();catalog=cg.catalog()['entries'];keys={}
 for r in catalog:
  if r['key'].startswith('original:'):keys.setdefault(r['id'],r['key'])
 for r in catalog:
  if r['key'].startswith('original:') and 2800<=int(r['key'].split(':')[1])<3000:keys[r['id']]=r['key']
 text=(ROOT/'assets/maps/falan/undersea_entrances.gd').read_text();main=text.split('"bear_to_sea":[',1)[1].split(']',1)[0]
 road=[tuple(map(int,m)) for m in re.findall(r'Vector2i\((\d+),(\d+)\)',main)]
 assert road[0]==(442,349) and road[-1]==(343,497)
 def area(f,x,y):
  if f in CAVES:return 'interior'
  if f==3200:return 'kili'
  if f==100:
   if 420<=x<=489 and 253<=y<=335:return 'south_gate'
   if any((x-a)**2+(y-b)**2<=18**2 for a,b in road):return 'south_lakes'
  if f==300 and 229<=x<=287 and 253<=y<=305:return 'sokia_coast'
  return ''
 cells={
  'south_gate':{(x,y) for x in range(420,490) for y in range(253,336)},
  'south_lakes':{(a+dx,b+dy) for a,b in road for dx in range(-18,19) for dy in range(-18,19) if dx*dx+dy*dy<=18*18},
  'sokia_coast':{(x,y) for x in range(229,288) for y in range(253,306)}}
 scope={}
 for place,points in cells.items():
  spans=[]
  for y in sorted({y for x,y in points}):
   xs=sorted(x for x,z in points if z==y);first=last=xs[0]
   for x in xs[1:]:
    if x!=last+1:spans.append([y,first,last]);first=x
    last=x
   spans.append([y,first,last])
  scope[place]=spans
 npcs=[];skipped=[];images={};art={};messages={r[0]:r[1].replace('\\n','\n').replace('@c','') for r in rows('msg.txt') if len(r)>1}
 for raw in rows('npc.txt'):
  if len(raw)<25 or not raw[8].isdigit() or not raw[9].isdigit() or not raw[10].isdigit():continue
  f,x,y=map(int,[raw[8],raw[9],raw[10]]);place=area(f,x,y)
  if not place or raw[0] in ['Warp','HouseWarp2']:continue
  if raw[6]!='1' or not raw[20].isdigit() or raw[20]=='1' or int(raw[3])>=1000000 and raw[3]!='1102712':
   skipped.append(dict(id=raw[3],map=f,cell=[x,y],name=raw[1],reason='Inactive/invisible or later event record without original corroboration.'));continue
  graphic=int(raw[20]);direction=int(raw[19])%8;token=f'{graphic}:{direction}'
  if token not in images:
   if graphic<100000 and graphic in lookup:
    g=lookup[graphic];im=lib.image_from_record(g['pack'],g['row']);ox,oy=g['x'],g['y'];key=f'graphic:{graphic}'
   else:
    key=keys.get(graphic,next((r['key'] for r in catalog if r['id']==graphic),''));assert key,(raw[3],graphic)
    _,_,clips=cg.actor(key);clip=next(c for c in clips if c['action']==0 and c['direction']==direction);im,ox,oy=cg.frame_parts(key,clip['index'],0)
   box=im.getbbox();assert box;im=im.crop(box);images[token]=im;art[token]=dict(key=key,origin=[ox+box[0],oy+box[1]],rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest())
  w,h,_,objects,_=maps[f]
  physical=objects[y*w+x]==graphic
  npcs.append(dict(id=raw[3],name=raw[1],type=raw[0],area=place,floor=f if place=='interior' else 3200 if place=='kili' else 0,source=f,cell=[x,y],direction=direction,graphic=graphic,token=token,scenery=graphic<14000 or raw[0] in ['HouseMaster','Dengon','Billboard','Windowman'],rendered_elsewhere=physical,messages=[messages[v] for v in raw[24].split('|') if v in messages] if raw[0]=='TownPeople' else ['你好。這裡的詳細對話尚待恢復。'],raw=raw))
 atlas=Image.new('RGBA',(1024,4096));x=y=rh=0
 for token,im in images.items():
  if x+im.width+2>1024:x=0;y+=rh;rh=0
  atlas.paste(im,(x+1,y+1));art[token]['rect']=[x+1,y+1,*im.size];x+=im.width+2;rh=max(rh,im.height+2)
 atlas.crop((0,0,1024,y+rh)).save(OUT/'npc-atlas.png')
 species=[dict(id=i,key=keys[i],name=n) for i,n in [(101010,'穴熊'),(101630,'惡魔螃蟹'),(101721,'水龍蜥'),(101700,'蜥蜴戰士'),(100802,'熱砂的歐茲尼克')]]
 for row,skin,family in zip(species,[4,5,1,2,0],['venoa_route','venoa_route','undersea','undersea','undersea']):row.update(skin=skin,family=family)
 for skin,row in enumerate(json.loads((ROOT/'assets/maps/falan/frontier_species.json').read_text())):species.append(dict(row,skin=skin,family='falan_encounters'))
 e={r[2]:r for r in rows('enemy.txt')};b={r[1]:r for r in rows('enemybase.txt')};g={r[2]:r for r in rows('group.txt')};skins={r['id']:i for i,r in enumerate(species)};groups={};zones=[]
 for raw in rows('encount.txt'):
  floor=int(raw[3])
  if floor not in CAVES+[100,300]:continue
  x0,y0,x1,y1=map(int,raw[4:8])
  if floor not in CAVES and not any(x0<=x<=x1 and y0<=y<=y1 for place,points in cells.items() if (floor==300)==(place=='sokia_coast') for x,y in points):continue
  chosen=[]
  for i,gid in enumerate(raw[14:24]):
   weight=int(raw[24+i] or 0)
   if not gid or not weight:continue
   group=g[gid];members=[];source_members=[]
   for j,eid in enumerate(group[5:15]):
    if not eid or eid=='0' or not int(group[15+j] or 0):continue
    enemy=e[eid];members.append([skins[int(b[enemy[3]][30])],int(enemy[4]),int(enemy[5]),int(group[15+j])])
    source_members.append(dict(enemy_id=eid,count=list(map(int,enemy[6:8])),mandatory=group[25+j]=='1'))
   groups[gid]=dict(members=members,raw=group,order=group[1])
   if gid in ['9033','9034']:groups[gid]['source_members']=source_members
   chosen.append([gid,weight])
  zones.append(dict(id=int(raw[0]),map=int(raw[3]),bounds=list(map(int,raw[4:8])),probability=list(map(int,raw[8:10])),maximum=int(raw[10]),priority=int(raw[11]),groups=chosen,raw=raw))
 data=dict(schema=1,npcs=npcs,art=art,skipped=skipped,species=species,zones=zones,groups=groups,road=road,outdoor_scope=scope,source_hashes={n:hashlib.sha256((SOURCE/n).read_bytes()).hexdigest() for n in ['npc.txt','msg.txt','encount.txt','group.txt','enemy.txt','enemybase.txt']},limits=['Source references corroborate identities; original server state is unavailable.','Existing special Great Bear and native undersea boss combat are preserved. Map15003 selects source groups9033/9034 by held item18403 instead of the old fixed-position trigger.','Original probability ramp and group-size distribution are unavailable; preserve bounds/weights and use the existing shuffled encounter adapter. Mandatory Oznik parties retain one boss and both escort types; source9067 escape AI and source reward18404 remain unverified.','Static NPC art preserves the original drawn facing and direction record; other 3D views are unavailable.'])
 (OUT/'population.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 if pack:
  from recover_habaru_encounter import recover
  old=json.loads((ROOT/'assets/characters/crossgate/habaru/motions.json').read_text());height=float(next(l.split('=')[1] for l in (ROOT/'scripts/character_proportions.gd').read_text().splitlines() if l.startswith('const GOEMON_HEIGHT=')))
  records=[dict(id=r['id'],key=keys[r['id']],height=r['standing_height']/height) for r in old['variants']]+[dict(id=101630,key=keys[101630],height=.75)]
  recover(ARCHIVE,shalena=True,species_override=records,output_override=ROOT/'assets/characters/crossgate/venoa_route')
 print('PASS',len(npcs),'source NPCs;',len(zones),'encounter zones; prepared crab appearance; source road',len(road),'cells')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--pack',action='store_true');a=p.parse_args();prepare(a.pack)
