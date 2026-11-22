"""Carry existing native pose head anchors onto the Water Dragon weapon derivatives."""
from collections import defaultdict
import hashlib,json,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/crossgate/cosmetics'
ART=ROOT/'assets/characters/crossgate/shin'
TARGET=ART/'900050'

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def prepare():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_assets as cg;import cg_wardrobe as wardrobe
 tables=json.loads((OUT/'anchors.json').read_text());packed=(OUT/'anchors.bin').read_bytes();dependencies=json.loads((OUT/'model-sources.json').read_text());points={};native={}
 def source_points(folder,manifest,stance):
  cache_key=(str(folder),stance['key'])
  if cache_key in native:return native[cache_key]
  clips={(c['action'],c['direction']):c for c in cg.actor(stance['key'])[2]if c['frames']};result={}
  for pose,clip in stance['clips'].items():
   action,direction=map(int,pose.split(':'));raw=clips.get((action,direction))
   if not raw or len(raw['frames'])!=len(clip['frames']):continue
   for original,frame in zip(raw['frames'],clip['frames']):
    p,x,y,w,h,ox,oy=frame;file=folder/(f'atlas-{p}.png'if p<manifest['pages']else f"cast-{p-manifest['pages']}.png");route='res://'+str(file.relative_to(ROOT))
    if route not in points:
     expected=dependencies.get(str(file.relative_to(ROOT)));assert expected==digest(file),('Native head source changed',file)
     offset,count=tables[route];points[route]={}
     for i in range(count):
      xx,yy,hx,hy=struct.unpack_from('<HHhh',packed,offset+i*8);points[route][(xx,yy)]=(hx,hy)
    if (x,y)in points[route]:
     hx,hy=points[route][(x,y)];result.setdefault(original[0],(hx+ox*4,hy+oy*4))
  native[cache_key]=result;return result
 basic=json.loads((ART/'100050/motions.json').read_text());sword_points=source_points(ART/'100050',basic,basic['weapons'][0]);bare_points=source_points(ART/'100050',basic,basic)
 new=defaultdict(dict)
 for folder in sorted(TARGET.iterdir()):
  if not folder.is_dir()or not(folder/'motions.json').exists():continue
  manifest=json.loads((folder/'motions.json').read_text());kind=manifest['weapon'];thrown=kind in ('kunai','boomerang')
  if not thrown:
   original_folder=ART.parent/'weapons'/manifest['key'].replace(':','-');original=json.loads((original_folder/'motions.json').read_text());native_points=source_points(original_folder,original,original)
  ident=cg.actor(manifest['key'])[0];fallback=wardrobe.head_coordinates(ident)
  for pose,clip in manifest['clips'].items():
   for frame,raw in zip(clip['frames'],clip['source_frames']):
    source_key=clip.get('source_key',manifest['key'])
    fallback=wardrobe.head_coordinates(cg.actor(source_key)[0])
    source=sword_points if source_key==basic['weapons'][0]['key'] else native_points if not thrown else bare_points if clip['source_action']==7 else sword_points
    head=source.get(raw[0])
    if head is None and raw[0]in fallback:head=tuple(v*4 for v in fallback[raw[0]])
    if head is None and pose.startswith('9:'):
     direction=int(pose.split(':')[1]);route='res://assets/characters/crossgate/shin/100050/jump-guard.png';offset,count=tables[route];guard={}
     for i in range(count):
      xx,yy,hx,hy=struct.unpack_from('<HHhh',packed,offset+i*8);guard[(xx,yy)]=(hx-62*4,hy-100*4)
     head=guard[(direction*120,0)]
    assert head is not None,('Missing native head anchor',kind,pose,raw[0],source_key)
    p,x,y,w,h,ox,oy=frame;route='res://'+str((folder/f'atlas-{p}.png').relative_to(ROOT));new[route].setdefault((x,y),(round(head[0]-ox*4),round(head[1]-oy*4)))
  for file in [folder/'motions.json',*(folder/f'atlas-{p}.png'for p in range(manifest['pages'])),folder/'item.png',*folder.glob('projectile.png')]:dependencies[str(file.relative_to(ROOT))]=digest(file)
 data=bytearray();updated={};prefix='res://'+str(TARGET.relative_to(ROOT))+'/'
 for route,(offset,count)in tables.items():
  if route.startswith(prefix)and route[len(prefix):].count('/')>0:continue
  updated[route]=[len(data),count];data.extend(packed[offset:offset+count*8])
 for route,regions in new.items():
  updated[route]=[len(data),len(regions)]
  for(x,y),(hx,hy)in regions.items():data.extend(struct.pack('<HHhh',x,y,hx,hy))
 dependencies={key:value for key,value in dependencies.items()if not key.startswith(str(TARGET.relative_to(ROOT))+'/') or (ROOT/key).exists()}
 for file in [TARGET/'counter-blue.png',ART/'counter.png',Path(__file__),ROOT/'tools/prepare_shin_water_weapons.py',ROOT/'tools/prepare_shin_water_dragon.py']:dependencies[str(file.relative_to(ROOT))]=digest(file)
 dependencies[str((TARGET/'motions.json').relative_to(ROOT))]=digest(TARGET/'motions.json')
 for name,value in [('anchors.bin',bytes(data)),('anchors.json',(json.dumps(updated,separators=(',',':'))+'\n').encode()),('model-sources.json',(json.dumps(dependencies,separators=(',',':'))+'\n').encode())]:
  path=OUT/name;temp=path.with_name(path.name+'.water.tmp');temp.write_bytes(value);temp.replace(path)
 # This is a fresh derived-cache bake, preserving all other models and authored inputs.
 preservation=json.loads((OUT/'preservation.json').read_text());preservation['inputs']=dependencies
 preservation['outputs']={str(p.relative_to(ROOT)):digest(p)for p in OUT.iterdir()if p.suffix in('.png','.json','.bin')and p.name not in('preservation.json','sample-anchors.json','head-fits.json')}
 (OUT/'preservation.json').write_text(json.dumps(preservation,indent=2)+'\n')
 print('Prepared Water Dragon weapon anchors:',sum(map(len,new.values())),'regions; all other packed anchors retained.')

if __name__=='__main__':prepare()
