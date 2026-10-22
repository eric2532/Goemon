"""Bake a battle-sized Kai Highway height field from the recovered ROM mesh."""
import argparse,json,math,shutil
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];DEST=ROOT/'assets/maps/kai_highway';DEST.mkdir(parents=True,exist_ok=True)
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=DEST);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
source=args.source/'kai-highway.json'
if not source.exists():source=args.source/'source.json'
data=json.loads(source.read_text());(DEST/'source.json').write_text(json.dumps(data,separators=(',',':')))
for image in args.source.glob('texture_*.png'):
 if image.resolve()!=(DEST/image.name).resolve():shutil.copy2(image,DEST/image.name)
base=Image.open(args.source/'texture_09004000_32x64.png')
Image.open(args.source/'texture_09003000_32x64.png').crop((0,0,32,32)).save(DEST/'grass.png')
base.crop((0,30,32,64)).save(DEST/'earth.png')
Image.open(args.source/'texture_0a003000_32x64.png').crop((0,0,32,32)).save(DEST/'planks.png')
WIDTH=161;SPACING=3.;AXIS=np.arange(WIDTH)*SPACING-240
X,Z=np.meshgrid(AXIS,AXIS);SX=X/.14-173;SZ=Z/.14+3
height=np.full(X.shape,-np.inf);owner=np.full(X.shape,-1,dtype=int);triangles=[]
for surface in data['surfaces']:
 for face in surface['faces']:
  v=[data['vertices'][i] for i in face];a,b,c=[q['p'] for q in v]
  det=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
  if abs(det)<1e-6:continue
  u=((b[2]-c[2])*(SX-c[0])+(c[0]-b[0])*(SZ-c[2]))/det
  w=((c[2]-a[2])*(SX-c[0])+(a[0]-c[0])*(SZ-c[2]))/det
  y=(u*a[1]+w*b[1]+(1-u-w)*c[1])*.04
  mask=(u>=-1e-6)&(w>=-1e-6)&(u+w<=1.000001)&(y>height)
  owner[mask]=len(triangles);height[mask]=y[mask]
  triangles.append((surface,v,det))
covered=np.isfinite(height);height[~covered]=0
def smooth(t):t=np.clip(t,0,1);return t*t*(3-2*t)
castle=1-smooth((np.maximum(abs(X),abs(Z))-66)/24)
height*=1-castle;covered|=castle>.999
paths=[];portals=[]
for side in [-1,1]:
 paths.extend([[(side*12,-25),(side*12,-18),(0,-18),(0,-9)],[(side*12,31),(side*12,20),(0,20),(0,9)],[(-25,side*12),(-18,side*12),(-18,0),(-9,0)],[(29,side*12),(20,side*12),(20,0),(9,0)]])
 portals.extend([{'x':side*12,'z':-25,'rotation':2},{'x':side*12,'z':31,'rotation':0},{'x':-25,'z':side*12,'rotation':1},{'x':29,'z':side*12,'rotation':3}])
distance=np.full(X.shape,np.inf);road_cells=set()
for path in paths:
 for (ax,az),(bx,bz) in zip(path,path[1:]):
  a=np.array([ax,az])*6;b=np.array([bx,bz])*6;delta=b-a
  t=np.clip(((X-a[0])*delta[0]+(Z-a[1])*delta[1])/float(delta@delta),0,1)
  distance=np.minimum(distance,np.hypot(X-a[0]-delta[0]*t,Z-a[1]-delta[1]*t))
  for step in range(abs(bx-ax)+abs(bz-az)+1):
   cx=ax+(0 if ax==bx else (1 if bx>ax else -1))*step;cz=az+(0 if az==bz else (1 if bz>az else -1))*step
   for dx in range(-2,3):
    for dz in range(-2,3):road_cells.add((cx+dx,cz+dz))
for axis in range(-9,10):
 for offset in range(-2,3):road_cells.add((axis,offset));road_cells.add((offset,axis))
road=1-smooth((distance-24)/6);target=np.maximum(0,np.maximum(abs(X),abs(Z))-78)*.10
height=height*(1-road)+target*road;covered|=road>.99
height[castle>.999]=0
groups={}
def group(key,image):
 if key not in groups:groups[key]={'image':image,'points':[],'uv':[]}
 return groups[key]
for iz in range(WIDTH-1):
 for ix in range(WIDTH-1):
  for offsets in [((0,0),(1,0),(0,1)),((1,0),(1,1),(0,1))]:
   points=[(ix+dx,iz+dz) for dx,dz in offsets];cx=sum(AXIS[x] for x,z in points)/3;cz=sum(AXIS[z] for x,z in points)/3
   ti=owner[min(WIDTH-1,max(0,round((cz+240)/3))),min(WIDTH-1,max(0,round((cx+240)/3)))]
   in_court=max(abs(cx),abs(cz))<66
   # Native bridge/terrace textures retain their source UVs. The castle pad
   # and added approach shoulders use exact cropped source earth/grass tiles.
   if ti<0 or in_court:
    image='earth.png' if in_court else 'grass.png';g=group(image,image)
    for x,z in points:g['points'].append([AXIS[x],height[z,x],AXIS[z]]);g['uv'].append([AXIS[x]/6,AXIS[z]/6])
   else:
    s,v,det=triangles[ti];image=s.get('image','grass.png');g=group(image,image);a,b,c=[q['p'] for q in v]
    for x,z in points:
     sx=SX[z,x];sz=SZ[z,x];u=((b[2]-c[2])*(sx-c[0])+(c[0]-b[0])*(sz-c[2]))/det;w=((c[2]-a[2])*(sx-c[0])+(a[0]-c[0])*(sz-c[2]))/det
     uv=[(u*v[0]['uv'][axis]+w*v[1]['uv'][axis]+(1-u-w)*v[2]['uv'][axis])*s['uv_scale'][axis]/32/s['size'][axis] for axis in range(2)]
     g['points'].append([AXIS[x],height[z,x],AXIS[z]]);g['uv'].append(uv)
# The new roads are intentional battle adaptations, separate from source data.
layout=json.loads((ROOT/'assets/maps/forest_four_gates.json').read_text());layout.update(title='Kai Highway Castle',terrain_source='kai_highway',ramparts=[],trees=[],portals=portals,roads=[{'x':x,'z':z} for x,z in sorted(road_cells)])
(ROOT/'assets/maps/forest_kai_highway.json').write_text(json.dumps(layout,indent=1)+'\n')
report=dict(data['report'],adaptation={'horizontal_scale':.14,'vertical_scale':.04,'origin_source':[-173,3],'castle_clearing_half_width':66,'height_spacing':SPACING,'portals':8,'road_width':30,'road_terrain_half_width':24},derived_tiles={'grass':{'source':'texture_09003000_32x64.png','crop':[0,0,32,32]},'earth':{'source':'texture_09004000_32x64.png','crop':[0,30,32,64]},'planks':{'source':'texture_0a003000_32x64.png','crop':[0,0,32,32]}})
(DEST/'provenance.json').write_text(json.dumps(report,indent=2)+'\n')
bridge_ids=[i for i,(s,v,det) in enumerate(triangles) if s.get('image') in ['texture_0a003000_32x64.png','texture_0a00d000_32x64.png']]
bridges=np.isin(owner,bridge_ids)
args.output.write_text(json.dumps({'width':WIDTH,'spacing':SPACING,'heights':height.flatten().tolist(),'covered':covered.astype(int).flatten().tolist(),'bridges':bridges.astype(int).flatten().tolist(),'groups':list(groups.values())},separators=(',',':')))
print('KAI_BATTLE_BAKE',len(groups),'surfaces',sum(len(g['points']) for g in groups.values())//3,'triangles','height range',float(height.min()),float(height.max()))
