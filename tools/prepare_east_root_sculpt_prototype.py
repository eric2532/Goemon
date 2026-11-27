"""Private rounded source-contour root mass; no canonical source or map changes."""
import hashlib,json,math
from pathlib import Path
from PIL import Image
from prepare_east_root_volume_prototype import ROOT,height
OUT=ROOT/'assets/maps/falan/east_region/root_sculpt_prototype'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def prepare():
 source=ROOT/'assets/maps/falan/east_region/root_compounds';data=json.loads((source/'data.json').read_text());im=Image.open(source/'body-front.png').convert('RGBA');w,h=im.size;step=4;gw=math.ceil(w/step)+1;gh=math.ceil(h/step)+1;active=set()
 for y in range(gh-1):
  for x in range(gw-1):
   if im.crop((x*step,y*step,min(w,(x+1)*step),min(h,(y+1)*step))).getchannel('A').getbbox():active.add((x,y))
 # Two-pass chamfer distance from the exact source-alpha edge. Rounded depth is
 # inferred from local root width, rather than a uniform photograph extrusion.
 dist=[0. if im.getpixel((x,y))[3]<128 else 10000. for y in range(h)for x in range(w)]
 for y in range(h):
  for x in range(w):
   i=y*w+x
   if x:dist[i]=min(dist[i],dist[i-1]+1)
   if y:dist[i]=min(dist[i],dist[i-w]+1)
   if x and y:dist[i]=min(dist[i],dist[i-w-1]+math.sqrt(2))
 for y in range(h-1,-1,-1):
  for x in range(w-1,-1,-1):
   i=y*w+x
   if x<w-1:dist[i]=min(dist[i],dist[i+1]+1)
   if y<h-1:dist[i]=min(dist[i],dist[i+w]+1)
   if x<w-1 and y<h-1:dist[i]=min(dist[i],dist[i+w+1]+math.sqrt(2))
 depths=[];heights=[]
 for y in range(gh):
  dr=[];hr=[]
  for x in range(gw):
   px,py=min(w-1,x*step),min(h-1,y*step);edge=any((x+dx,y+dy)not in active for dx,dy in[(-1,-1),(0,-1),(-1,0),(0,0)]);d=0. if edge else min(8.,math.sqrt(dist[py*w+px])*.75)
   dr.append(round(d,5));hr.append(round(height(px,py)*.045,5))
  depths.append(dr);heights.append(hr)
 # Independent hidden bark grain retains only the observed silhouette alpha.
 bark=Image.open(source/'bark-grain.png').convert('RGBA');reverse=im.copy()
 for y in range(h):
  for x in range(w):
   p=bark.getpixel((x%bark.width,y%bark.height));reverse.putpixel((x,y),(*p[:3],im.getpixel((x,y))[3]))
 OUT.mkdir(parents=True,exist_ok=True);reverse.save(OUT/'independent-back.png');result=dict(schema=1,scope='PRIVATE rounded source-contour mass. Original132BGdrawings/crown/maps/navigation unchanged. Hidden depth and bark are inferred.',source_data_sha256=sha((source/'data.json').read_bytes()),source_body_rgba_sha256=sha(im.tobytes()),back_rgba_sha256=sha(reverse.tobytes()),size=[w,h],origin=data['body']['native_origin'],grid_step=step,active_cells=sorted(active,key=lambda p:(p[1],p[0])),depth_grid=depths,height_grid=heights,hollow=data['prototype']['source_hollow_outline'],inferences=['Rounded depth follows the local source silhouette distance; no full native front is wrapped around the back.','Native dark mouth is a bounded recessed surface, not an added room or route.','Existing closed crown/branches/ground are reused without changing their source pixels.'])
 (OUT/'data.json').write_text(json.dumps(result,indent=2)+'\n');print('ROOT_SCULPT_PRIVATE',len(active),'cells',gw,gh)
if __name__=='__main__':prepare()
