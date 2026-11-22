"""Recover native palm paint/crown bounds and individual Sokia cliff contours."""
import argparse,hashlib,json,sys,math
from pathlib import Path
from PIL import Image,ImageStat
from build_village_building_surfaces import surface_atlas
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/maps/falan/sokia'
CLUSTERS={11190:(.86,.55),11191:(.58,-.55),11193:(.78,.45),11194:(.78,-.52),11197:(.40,-.55),11207:(.78,-.60),11208:(.74,.65)}
# Traced crown ribs in original graphic 11204; depth remains a fitted 3D adapter.
NATIVE_FRONDS=[
 ([(84,75),(79,60),(75,46),(75,31),(73,16),(70,3)],-.45),
 ([(84,75),(89,60),(94,45),(101,30),(106,16),(112,9)],.65),
 ([(84,75),(72,58),(59,43),(48,34),(37,30),(31,30)],-.75),
 ([(84,75),(65,60),(46,51),(29,51),(13,62),(2,78)],.2),
 ([(84,75),(73,69),(63,67),(56,71),(50,76),(46,80)],.65),
 ([(84,75),(99,59),(117,46),(134,39),(151,39),(160,39)],-.35),
 ([(84,75),(101,65),(121,62),(140,65),(149,68),(155,71)],.45),
 ([(84,75),(100,77),(107,91),(108,107),(107,122),(105,132)],.7),
 ([(84,75),(74,82),(70,95),(69,111),(69,127),(69,136)],.4)]
def prepare(source):
 sys.path.insert(0,str(source/'tools'));import cg_library as cg
 lookup=cg.serial_index();images={};patches={};records={};palms={};cliffs={};fruits={};fruit_shapes={};crowns={};palm_fronds={};palm_crowns={}
 for serial in [*range(11188,11209),*range(12536,12566)]:
  e=lookup[serial];im=cg.image_from_record(e['pack'],e['row']);images[serial]=im
  records[serial]={'pack':e['pack'],'row':e['row'],'rgba_sha256':hashlib.sha256(im.tobytes()).hexdigest()}
  visible=lambda p:p[3]==255 and max(p[:3])>38
  if serial<12000:
   leaf=lambda p:visible(p) and p[1]>p[0]*.86 and p[1]>p[2]*1.25
   bark=lambda p:visible(p) and p[0]>p[1]*1.15 and p[1]>p[2]*1.15
   points=[(x,y) for y in range(int(im.height*.55)) for x in range(im.width) if leaf(im.getpixel((x,y))) and (y<im.height*.25 or abs(x+e['x'])>im.width*.12)]
   assert points,serial
   left=min(x for x,y in points);right=max(x for x,y in points);top=min(y for x,y in points);bottom=max(y for x,y in points)
   fan=serial in range(11189,11197);root_y=top+(bottom-top)*(.78 if fan else .42)
   y=min(-e['y']-12,im.height-1);xs=[x for x in range(max(0,-e['x']-22),min(im.width,-e['x']+22)) if bark(im.getpixel((x,y)))]
   runs=[]
   for x in xs:
    if not runs or x>runs[-1][-1]+1:runs.append([])
    runs[-1].append(x)
   nearest=min(runs,key=lambda r:abs(sum(r)/len(r)+e['x'])) if runs else []
   trunk_width=max(7,len(nearest))
   palms[serial]=[round((-e['y']-root_y)*.031,5),round((right-left)*.031,5),round((bottom-top)*.031,5),round(trunk_width*.031,5),fan,list(CLUSTERS.get(serial,()))]
   kinds=[('leaf',leaf,(0,0,im.width,max(8,int(root_y)))),('bark',bark,(max(0,-e['x']-22),int(im.height*.50),min(im.width,-e['x']+22),min(im.height,-e['y'])))]
   if serial==11194:
    dry=lambda p:visible(p) and p[1]*.98<p[0]<p[1]*1.25 and p[1]>110 and p[1]>p[2]*1.6
    kinds.append(('dry_leaf',dry,(0,65,60,140)))
   if serial==11204:
    traced=[];ribs=[]
    for path,depth in NATIVE_FRONDS:
     snapped=[path[0]]
     for x,y in path[1:]:
      nearby=[(xx,yy) for yy in range(max(0,y-6),min(im.height,y+7)) for xx in range(max(0,x-6),min(im.width,x+7)) if visible(im.getpixel((xx,yy)))]
      assert nearby,('Missing native frond point',x,y)
      snapped.append(min(nearby,key=lambda p:(p[0]-x)**2+(p[1]-y)**2))
     curve=[]
     for i,(x,y) in enumerate(snapped):
      if i in [0,5]:radius=4 if i==0 else .35
      else:
       dx=snapped[i+1][0]-snapped[i-1][0];dy=snapped[i+1][1]-snapped[i-1][1];length=math.hypot(dx,dy)
       spans=[]
       for side in [-1,1]:
        span=0
        for step in range(1,25):
         xx=round(x-dy/length*step*side);yy=round(y+dx/length*step*side)
         if not (0<=xx<im.width and 0<=yy<im.height) or not visible(im.getpixel((xx,yy))):break
         span=step
        spans.append(span)
       radius=max(1.5,sum(spans)*.5)
      curve.append([round((x-84)*.031,6),round((75-y)*.031,6),round(depth*math.sin(i/5*math.pi*.5),6),round(radius*.031,6)])
     ribs.append(snapped);traced.append(curve)
    palm_fronds[serial]=traced;palm_crowns[serial]=[(84+e['x'])*.031,(-e['y']-75)*.031,0]
    records[serial]['native_frond_ribs']=ribs;records[serial]['native_frond_depths']=[d for p,d in NATIVE_FRONDS]
    gold=lambda p:p[3]==255 and p[0]>=165 and p[1]>=105 and p[0]<p[1]*1.65 and p[1]>p[2]*2.4
    pixels={(x,y) for y in range(78,124) for x in range(74,100) if gold(im.getpixel((x,y)))}
    remaining=set(pixels);lobes=[];shapes=[]
    while remaining:
     component=[min(remaining,key=lambda p:(p[1],p[0]))];remaining.remove(component[0])
     for x,y in component:
      for q in [(x+dx,y+dy) for dx in [-1,0,1] for dy in [-1,0,1]]:
       if q in remaining:remaining.remove(q);component.append(q)
     if len(component)<5:continue
     top=min(y for x,y in component);bottom=max(y for x,y in component)
     groups=[[p for p in component if p[1]<=((top+bottom)//2)],[p for p in component if p[1]>((top+bottom)//2)]] if bottom-top>8 else [component]
     for group in groups:
      x=sum(p[0] for p in group)/len(group);y=sum(p[1] for p in group)/len(group)
      lobes.append([round(x-84,5),round(75-y,5),max(1.5,(max(p[0] for p in group)-min(p[0] for p in group)+1)*.5),max(2,(max(p[1] for p in group)-min(p[1] for p in group)+1)*.5)])
      outline=[]
      for row_y in sorted({p[1] for p in group},reverse=True):
       xs=[p[0] for p in group if p[1]==row_y]
       outline.append([(min(xs)+max(xs))*.5-84,75-row_y,max(.75,(max(xs)-min(xs)+1)*.5)])
      outline.insert(0,[outline[0][0],outline[0][1]-.6,.18]);outline.append([outline[-1][0],outline[-1][1]+.6,.18])
      assert all(a[1]<b[1] for a,b in zip(outline,outline[1:]))
      shapes.append(outline)
    assert len(lobes)==6 and len(pixels)==131
    records[serial]['fruit_row_samples']=shapes
    softened=[]
    for shape in shapes:
     smooth=[p[:] for p in shape]
     for _ in range(2):
      previous=[p[:] for p in smooth]
      for i in range(1,len(smooth)-1):
       for axis in [0,2]:smooth[i][axis]=round(previous[i-1][axis]*.25+previous[i][axis]*.5+previous[i+1][axis]*.25,5)
     softened.append(smooth)
    fruits[serial]=lobes;fruit_shapes[serial]=softened;records[serial]['fruit_pixels']=sorted(pixels);records[serial]['fruit_attachment']=[84,75]
    kinds.append(('fruit',gold,(74,78,100,124)))
  else:
   kinds=[]
   profile=[]
   for i in range(9):
    y=round((1-i/8)*min(-e['y'],im.height-1))
    points=[(x,yy) for yy in range(max(0,y-6),min(im.height,y+7)) for x in range(im.width) if visible(im.getpixel((x,yy)))]
    if points:
     left=min(x for x,yy in points);right=max(x for x,yy in points)
     profile.append([round(((left+right)*.5+e['x'])/im.width,5),round((right-left)/im.width,5),round(i/8,5)])
   cliffs[serial]=profile
   peaks=[];samples=[]
   for z in range(3):
    for x in range(3):
     # Fit the exposed crown while retaining the complete solid crag behind it.
     east=max(1,e['east']);south=max(1,e['south'])
     dx=(x-1)*east*3*.29;dz=(z-1)*south*3*.29
     cx=(east-1)*1.5;cz=-(south-1)*1.5
     column=round(-e['x']+(dx+dz+cx+cz)*32/3)
     base=-e['y']+(dz-dx+cz-cx)*8
     ys=[y for y in range(max(0,min(im.height,round(base)))) if any(visible(im.getpixel((xx,y))) for xx in range(max(0,column-3),min(im.width,column+4)))] if im.height>200 else []
     top=min(ys) if ys else None
     peaks.append(round(max(.55,min(.96,(base-top)/max(1,im.height-46))),5) if top is not None else 0)
     samples.append([column,round(base,3),top])
   assert len(peaks)==9 and all(p==0 or .55<=p<=.96 for p in peaks)
   crowns[serial]=peaks;records[serial]['crown_samples']=samples
  for kind,predicate,box in kinds:
   # Pick a native opaque patch; exclude black archive backplanes and baked shadows.
   size=8
   integral=[[0]*(im.width+1)]
   for yy in range(im.height):
    row=[0];total=0
    for xx in range(im.width):total+=predicate(im.getpixel((xx,yy)));row.append(total+integral[-1][xx+1])
    integral.append(row)
   candidates=[]
   for y in range(box[1],max(box[1]+1,box[3]-size+1),2):
    for x in range(box[0],max(box[0]+1,box[2]-size+1),2):
     score=integral[y+size][x+size]-integral[y][x+size]-integral[y+size][x]+integral[y][x]
     candidates.append((score,x,y))
   score,x,y=max(candidates);assert score>0,(serial,kind)
   assert score==sum(predicate(im.getpixel((xx,yy))) for yy in range(y,y+size) for xx in range(x,x+size))
   # Native nonmatching pixels are filled only in this tiny surface derivative.
   crop=im.crop((x,y,x+size,y+size));good=[(xx,yy) for yy in range(size) for xx in range(size) if predicate(crop.getpixel((xx,yy)))]
   for yy in range(size):
    for xx in range(size):
     if (xx,yy) not in good:crop.putpixel((xx,yy),crop.getpixel(min(good,key=lambda p:(p[0]-xx)**2+(p[1]-yy)**2)))
   key=f'{kind}_{serial}';images[key]=crop
   patches[key]=(key,[(0,0),(size-1,0),(size-1,size-1),(0,size-1)],False,(64,64))
   records[serial][kind+'_crop']=[x,y,size,size]
 atlas,rows=surface_atlas(images,patches);rows[1]='## Generated by tools/recover_sokia_details.py; original Sokia paint and contours.'
 # Tiny native fruit pixels supply the tone without repeating palette dithering on every curved face.
 index=list(patches).index('fruit_11204');box=(index%4*128,index//4*128,index%4*128+128,index//4*128+128)
 patch=atlas.crop(box);tone=tuple(round(v) for v in ImageStat.Stat(patch).mean[:3])+(255,)
 atlas.paste(Image.blend(patch,Image.new('RGBA',patch.size,tone),.75),box[:2])
 rows+=['}','const PALMS={']
 for s,p in palms.items():rows.append(f' {s}:'+str(p).replace('True','true').replace('False','false')+',')
 rows+=['}','const CLIFFS={']
 for s,p in cliffs.items():rows.append(f' {s}:'+str(p)+',')
 rows+=['}','const FRUITS={']
 for s,points in fruits.items():rows.append(f' {s}:['+','.join('Vector4(%s)'%','.join(map(str,p)) for p in points)+'],')
 rows+=['}','const FRUIT_SHAPES={']
 for s,shapes in fruit_shapes.items():rows.append(f' {s}:['+','.join('['+','.join('Vector3(%s)'%','.join(map(str,p)) for p in shape)+']' for shape in shapes)+'],')
 rows+=['}','const CLIFF_CROWNS={']
 for s,peaks in crowns.items():rows.append(f' {s}:'+str(peaks)+',')
 rows+=['}','const PALM_CROWNS={']
 for s,p in palm_crowns.items():rows.append(f' {s}:Vector3('+','.join(map(str,p))+'),')
 rows+=['}','const PALM_FRONDS={']
 for s,curves in palm_fronds.items():rows.append(f' {s}:['+','.join('['+','.join('Vector4(%s)'%','.join(map(str,p)) for p in curve)+']' for curve in curves)+'],')
 rows+=['}','const FRONDS=[']
 fronds=json.loads((OUT/'fronds.json').read_text())
 for path,digest in fronds['protected'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
 for path in fronds['fronds']:rows.append(' ['+','.join('Vector4(%s)'%','.join(map(str,p)) for p in path)+'],')
 rows+=[']']
 meta={'sources':records,'palms':palms,'cliffs':cliffs,'fruits':fruits,'fruit_shapes':fruit_shapes,'cliff_crowns':crowns,'palm_fronds':palm_fronds,'palm_crowns':palm_crowns,'reused':fronds['protected'],'method':'Native crown bounds, paint, contours and projected crown samples. 11204 ribs are traced in source pixels with sampled leaf widths and the recorded crown/fruit attachment. Native fruit rows are preserved and smoothed for curved 3D lobes. Existing trunk and frond geometry are reused; depth, secondary trunk arrangement and unseen backs remain fitted.'}
 return atlas,'\n'.join(rows)+'\n',meta
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power');p.add_argument('--check',action='store_true');a=p.parse_args()
 atlas,data,meta=prepare(a.source.resolve())
 if a.check:
  actual=Image.open(OUT/'details.png');assert actual.size==atlas.size and actual.tobytes()==atlas.tobytes()
  assert (OUT/'details.gd').read_text()==data
  assert json.loads((OUT/'details.json').read_text())==json.loads(json.dumps(meta))
  print('SOKIA_DETAILS_CHECK native palm paint, crown bounds, cliff contours and original palm master preserved')
 else:
  atlas.save(OUT/'details.png',optimize=True);(OUT/'details.gd').write_text(data);(OUT/'details.json').write_text(json.dumps(meta,indent=2)+'\n')
  print('Recovered 21 native palms, six fruit lobes, 30 cliff contours and 44 source paint patches')
if __name__=='__main__':main()
