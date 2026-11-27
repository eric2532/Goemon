"""Exact33608BG composition and a separately labeled private sculpture partition."""
import argparse, hashlib, io, json, math
from collections import Counter
from PIL import Image, ImageDraw
from review_east_backgrounds import Native, decode, ROOT, CATALOG

OUT=ROOT/'assets/maps/falan/east_region/mouse_statue'
# Visible silhouette partitions, in the unscaled640x767native composition.
# These editable reconstruction bounds are not original collision/height data.
BODY=[(144,26),(166,24),(189,37),(213,68),(227,117),(266,131),
 (285,103),(303,98),(331,109),(355,139),(411,121),(433,67),
 (421,125),(397,150),(369,159),(420,173),(451,156),(478,91),
 (510,51),(544,23),(555,22),(529,61),(516,123),(514,166),
 (527,179),(571,180),(597,150),(588,183),(575,211),(535,239),
 (487,250),(485,271),(510,295),(484,331),(434,356),(397,380),
 (386,408),(395,458),(376,503),(351,526),(327,539),(334,516),
 (342,476),(343,448),(330,471),(311,492),(290,501),(288,470),
 (302,437),(302,410),(278,415),(261,435),(233,436),(213,443),
 (191,451),(206,426),(240,405),(253,382),(240,374),(214,362),
 (181,355),(137,350),(119,338),(111,316),(116,289),(120,265),
 (83,288),(76,288),(76,268),(111,263),(118,240),(119,216),
 (132,188),(147,163),(157,150),(142,126),(134,94),(136,56)]
STAFF=[(45,110),(64,106),(83,115),(98,129),(115,128),(121,146),
 (105,174),(105,210),(97,238),(89,228),(89,202),(77,193),
 (76,348),(84,365),(78,386),(72,402),(64,393),(59,376),
 (50,369),(51,197),(43,185),(39,205),(32,211),(29,200),
 (35,178),(28,164),(23,140),(27,120)]

def products():
 cat=json.loads(CATALOG.read_text());row=cat['maps']['BlueCrossgate/map/0/33608.dat']
 w,h,raw,values,bits,aliases=decode(row);native=Native();family=[]
 for i,value in enumerate(values[:w*h]):
  serial=aliases.get(int(value),int(value))
  if not 1220589<=serial<=1220780:continue
  g=native.table[serial][0];x,y=i%w,i//w
  family.append(dict(cell=[x,y],graphic=serial,native_graphic=int(value),
    pixel=[(x+y)*32+g['origin'][0],(y-x)*24+g['origin'][1]],size=g['rect'][2:],
    original_open=bool(bits[i>>3]&(1<<(i&7))),source_rgba_sha256=g['rgba_sha256']))
 counts=Counter(r['graphic']for r in family);single=[r for r in family if counts[r['graphic']]==1]
 box=[min(r['pixel'][k]for r in single)for k in range(2)]+[max(r['pixel'][k]+r['size'][k]for r in single)for k in range(2)]
 assert box==[8704,-4320,9344,-3553]and len(single)==186
 rows=[r for r in family if r['pixel'][0]<box[2]and r['pixel'][1]<box[3]and r['pixel'][0]+r['size'][0]>box[0]and r['pixel'][1]+r['size'][1]>box[1]]
 image=Image.new('RGBA',(640,767))
 for r in rows:image.alpha_composite(native.crop(r['graphic']),(r['pixel'][0]-box[0],r['pixel'][1]-box[1]))
 files={}
 def png(name,im):
  stream=io.BytesIO();im.save(stream,format='PNG',optimize=True);files[name]=stream.getvalue()
 png('native.png',image);parts={};union=Image.new('L',image.size)
 png('body-material.png',image.crop((378,215,418,255)).resize((128,128),Image.Resampling.NEAREST))
 png('staff-material.png',image.crop((58,215,74,320)).resize((128,128),Image.Resampling.NEAREST))
 staff_partition=Image.new('L',image.size);ImageDraw.Draw(staff_partition).polygon(STAFF,fill=255)
 backdrop=image.getpixel((639,0))[:3]
 assert all(image.getpixel(p)[:3]==backdrop for p in[(400,50),(450,100),(500,200)])
 for name,polygon in [('body',BODY),('staff',STAFF)]:
  mask=Image.new('L',image.size);ImageDraw.Draw(mask).polygon(polygon,fill=255)
  # Exclude only the exact dark red source backdrop at the silhouette margin;
  # interior eyes, engraving, shadows and cloak pixels keep their native RGB.
  pixels=image.load();mp=mask.load()
  for y in range(image.height):
   for x in range(image.width):
    if mp[x,y]and pixels[x,y][:3]==backdrop:mp[x,y]=0
    if name=='body'and y>=350:
     r,g,b,_=pixels[x,y]
     if r>g*1.13 and r>b*1.3:mp[x,y]=0
    if name=='body'and staff_partition.getpixel((x,y)):mp[x,y]=0
  fore=image.copy();fore.putalpha(Image.composite(image.getchannel('A'),Image.new('L',image.size),mask));png(name+'-front.png',fore)
  cells=[];step=2
  for y in range(0,image.height,step):
   for x in range(0,image.width,step):
    if mask.crop((x,y,min(x+step,image.width),min(y+step,image.height))).getbbox():cells.append([x,y])
  ImageDraw.Draw(union).bitmap((0,0),mask,fill=255)
  parts[name]=dict(outline=polygon,cells=cells,step=step,
    ground_pixel_y=539,
    masses=[[213,250,112,117,7.0],[177,85,48,65,1.6],[312,162,50,68,1.7],[390,260,145,130,2.2],[350,440,46,95,1.3]]if name=='body'else[[69,150,45,50,.45],[65,285,18,110,.25]])
 # Continue only source-occluded floor/backdrop. The unmodified native composite
 # remains above; inferred fill never changes raw BG/PG1/walk/actor bytes.
 floor=image.copy();ip=image.load();fp=floor.load();hidden=union.load()
 for y in range(image.height):
  for x in range(image.width):
   if not hidden[x,y]:continue
   if y<350:fp[x,y]=backdrop+(255,);continue
   sample=ip[48+(x-48)%64,420+(y-420)%64]
   if 170<=x<=350 and 430<=y<=567:
    for xx,yy in[(518-x,y),(x,1004-y)]:
     if 0<=xx<image.width and 0<=yy<image.height and not hidden[xx,yy]and ip[xx,yy][3]>200:sample=ip[xx,yy];break
   fp[x,y]=sample
 png('ground.png',floor);png('partition-mask.png',union)
 data=dict(schema=1,map=33608,anchor=[224,55],origin=[-224,-264],size=list(image.size),
   source_raw_sha256=hashlib.sha256(raw).hexdigest(),catalog_sha256=hashlib.sha256(CATALOG.read_bytes()).hexdigest(),
   native_rgba_sha256=hashlib.sha256(image.tobytes()).hexdigest(),source_placements=rows,
   sculpture_source_placements=single,
   single_use_source_mosaics=186,source_catalogs=native.pins,parts=parts,
   scope='Private closed sculpture study. Native PG0reference is exact; body partition/depth/back/floor continuation are inferred. No map hook, collision, actor, event, route or quest change.',
   inferred=['Editable silhouette partitions separate statue/staff from the original tiled floor/backdrop.',
    'Closed rounded head/ears/hood and thin cape/staff volumes infer hidden depth while retaining source-facing projection.',
    'The reverse uses independent mineral/ivory surfaces, not a stretched copy of the frontal portrait.',
    'Hidden upper backdrop continues its exact native plain color. Occluded lower floor uses the neighboring64pxnative paving patch; small covered circular-floor pieces reflect a visible counterpart where available. These are inferred hidden pixels and establish no new route.'])
 files['data.json']=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode();return files

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();bad=[]
 for name,payload in products().items():
  path=OUT/name
  if args.check:
   if not path.exists()or path.read_bytes()!=payload:bad.append(name)
  elif not path.exists()or path.read_bytes()!=payload:OUT.mkdir(parents=True,exist_ok=True);path.write_bytes(payload)
 if bad:raise SystemExit('Stale source mouse statue study: '+', '.join(bad))
 print(('Verified'if args.check else'Prepared')+' exact290tile native statue reference and separate private reconstruction masks.')
if __name__=='__main__':main()
