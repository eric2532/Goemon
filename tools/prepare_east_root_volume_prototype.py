"""Private source-pixel continuous root volume; original six compounds stay untouched."""
import json,math,hashlib
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
from prepare_east_root_compounds import ROOT,BODY_OUTLINE
OUT=ROOT/'assets/maps/falan/east_region/root_volume_prototype'
ROUTES=[[[364,327,0],[370,270,57],[379,200,127],[387,130,197],[386,70,257],[386,35,292],[385,0,327]],[[354,110,210],[286,224,85],[198,309,18],[128,370,0]],[[357,150,177],[286,249,78],[224,281,25],[92,285,0]],[[375,130,197],[421,245,82],[444,332,25],[462,421,0]],[[390,120,207],[455,230,97],[496,309,32],[519,419,0]],[[398,110,217],[457,219,108],[536,265,24],[638,292,0]],[[358,80,247],[306,161,108],[235,180,22],[149,179,0]],[[401,80,247],[461,155,92],[535,184,19],[616,219,0]]]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def height(x,y):
 distances=[]
 for route in ROUTES:
  best=None
  for a,b in zip(route,route[1:]):
   dx,dy=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy)));d=(x-a[0]-t*dx)**2+(y-a[1]-t*dy)**2;h=a[2]+t*(b[2]-a[2])
   if best is None or d<best[0]:best=(d,h)
  distances.append(best)
 distances.sort();distances=distances[:3];weights=[1/(d+6)**2 for d,h in distances]
 return max(0,min(327,sum(h*w for (d,h),w in zip(distances,weights))/sum(weights)))
def prepare():
 source=ROOT/'assets/maps/falan/east_region/root_compounds/data.json';data=json.loads(source.read_text());w,h=data['body']['native_size'];step=4;grid=[[round(height(x,y),5)for x in range(0,w+step,step)]for y in range(0,h+step,step)]
 # These controls are the previous source-traced trunk/root routes. Front RGB
 # remains the exact existing body split. Hidden continuous depth is inferred.
 OUT.mkdir(parents=True,exist_ok=True);result=dict(source_data_sha256=sha(source.read_bytes()),source_body_rgba_sha256=sha(Image.open(ROOT/'assets/maps/falan/east_region/root_compounds/body-front.png').convert('RGBA').tobytes()),size=[w,h],origin=data['body']['native_origin'],outline=BODY_OUTLINE,hollow=data['prototype']['source_hollow_outline'],height_controls=ROUTES,grid_step=step,height_grid=grid,scope='PRIVATE source-face/root-centerline height prototype. Exact body/hollow silhouette with continuous inferred depth; six maps/navigation remain unchanged.')
 (OUT/'data.json').write_text(json.dumps(result,indent=2)+'\n');print('ROOT_VOLUME_PRIVATE',len(grid),len(grid[0]))
if __name__=='__main__':prepare()
