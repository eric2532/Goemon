"""Exact Dragon Hourglass background composition and bounded 3D paint references.

Composites retain every pinned source background anchor and original painter order.
The separate derivative ground continues source-occluded floor and sky behind
the reconstructed glass, crowns and supports. Native sources are never edited.
"""
import argparse, base64, bisect, hashlib, io, json, math, statistics, struct, sys, zlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/maps/falan/east_region/dragon_hourglass'

def measured_depth_mask(image):
 mask=Image.new('L',image.size);pixels=image.load();m=mask.load()
 # The native colored glass, including its actual narrow necks. Bounds exclude
 # the incidental dragons and the source reflections below the main platform.
 for y in range(0,408):
  for x in range(505,991):
   r,g,b,a=pixels[x,y]
   gold=r>g*1.05 and g>b*1.15
   green=g>r*1.03 and g>b*.98
   purple=b>g*1.25 and r>g*1.05
   if a and (gold or green or purple):m[x,y]=255
 mask=mask.filter(ImageFilter.MaxFilter(13));draw=ImageDraw.Draw(mask)
 for box in [(505,0,665,68),(625,0,850,42),(792,0,972,73),(515,330,683,397),(797,329,957,397),(621,378,853,540)]:draw.rounded_rectangle(box,radius=12,fill=255)
 return mask

def ground_removal_mask(image):
 # The three glass bodies include dark blue and nearly white source pixels that
 # a color-key cannot distinguish from the sky. These bounded native silhouettes
 # cover those pixels, their caps and the front scroll supports completely.
 mask=Image.new('L',image.size);draw=ImageDraw.Draw(mask)
 outlines=[[(500,0),(680,0),(681,74),(661,151),(624,191),(622,214),(659,242),(684,293),(685,343),(703,369),(689,409),(511,409),(506,346),(524,270),(559,225),(582,211),(583,198),(550,174),(517,126)],
 [(619,0),(865,0),(865,78),(846,139),(818,181),(763,207),(760,222),(778,244),(821,280),(845,336),(847,382),(864,406),(854,451),(861,494),(874,531),(852,551),(809,540),(780,508),(742,486),(708,508),(679,545),(633,552),(602,537),(604,513),(620,482),(625,444),(613,421),(614,399),(632,379),(638,331),(662,278),(699,242),(718,221),(716,207),(682,183),(650,146),(630,95)],
 [(790,0),(980,0),(980,73),(956,137),(924,176),(876,209),(876,225),(907,247),(940,280),(956,327),(963,353),(991,380),(994,415),(797,416),(785,375),(789,333),(801,289),(825,256),(851,229),(852,211),(828,191),(802,161),(788,123)]]
 for points in outlines:draw.polygon(points,fill=255)
 draw.rounded_rectangle((778,205,966,354),radius=14,fill=255)
 return mask.filter(ImageFilter.MaxFilter(9))


def continue_hidden_ground(image,mask,broken):
 # Infer only source-occluded ground. Radial median colors continue visible
 # circular floor bands without repeating glass, sculpture or perspective art.
 result=image.copy();source=image.load();target=result.load();hidden=mask.load();cx,cy,rx,ry=742.,394.,402.,126.;samples={}
 for y in range(265,536):
  for x in range(335,1146):
   if hidden[x,y] or source[x,y][3]<200:continue
   radius=math.hypot((x-cx)/rx,(y-cy)/ry)
   if radius<=1.12:samples.setdefault(round(radius*100),[]).append((math.atan2((y-cy)/ry,(x-cx)/rx),source[x,y][:3]))
 samples={i:sorted(rows)for i,rows in samples.items()}
 radii=sorted(samples)
 def floor_color(radius,angle):
  key=min(radii,key=lambda i:abs(i-round(radius*100)));rows=samples[key]
  angles=[row[0]for row in rows];at=bisect.bisect_left(angles,angle)
  a,ca=rows[at-1]if at else(rows[-1][0]-math.tau,rows[-1][1])
  b,cb=rows[at]if at<len(rows)else(rows[0][0]+math.tau,rows[0][1])
  weight=max(0.,min(1.,(angle-a)/max(.0001,b-a)))
  return tuple(round(ca[k]*(1-weight)+cb[k]*weight)for k in range(3))
 for y in range(image.height):
  for x in range(image.width):
   if not hidden[x,y]:continue
   radius=math.hypot((x-cx)/rx,(y-cy)/ry)
   if 265<=y<=535 and radius<1.12:
    color=floor_color(radius,math.atan2((y-cy)/ry,(x-cx)/rx))
    grain=source[450+x%29,373+y%17];factor=.96+.08*(sum(grain[:3])/765.)
    target[x,y]=tuple(max(0,min(255,round(c*factor)))for c in color)+(255,)
   else:
    sample=source[x-500 if x>=500 else 150+x%161,y]
    if sample[3]==0:sample=(20,20,20,255)if broken else source[1200+x%101,y]
    target[x,y]=sample
 return result


def products():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 cat=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text());native_graphics=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())['graphics']|cat['graphics'];placements=[];files={};maps={}
 for mid in [58000,58001]:
  row=cat['maps'][f'BlueCrossgate/map/0/{mid}.dat'];payload=row['reference_variant_raw'] if row.get('active_layout_variant')=='pinned-reference' else row.get('restored_raw',row['raw'])
  raw=zlib.decompress(base64.b64decode(payload));width,height=struct.unpack_from('<II',raw,12);cells=width*height;aliases=row.get('graphic_aliases',{})
  for layer in range(2):
   for i,native in enumerate(struct.unpack_from(f'<{cells}H',raw,20+layer*cells*2)):
    serial=int(aliases.get(str(native),native))
    if serial<1000:continue
    assert serial==1001 or serial in range(1238000,1238028), (mid,serial)
    g=native_graphics[str(serial)];x,y=i%width,i//width;u=(x+y)*32+g['origin'][0];v=(y-x)*24+g['origin'][1]
    placements.append({'map':mid,'graphic':serial,'cell':[x,y],'layer':layer,'origin':g['origin'],'native_global_bounds':[u,v,u+g['rect'][2],v+g['rect'][3]],'source_rgba_sha256':g['rgba_sha256'],'ground':g['ground'],'index':layer*cells+i})
 def png(n,image):
  stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);files[n]=stream.getvalue()
 for mid in [58000,58001]:
  rows=[r for r in placements if r['map']==mid]
  assert sum(r['graphic']!=1001 for r in rows)==(15 if mid==58000 else 13)
  assert sum(r['graphic']==1001 for r in rows)==(55 if mid==58000 else 50)
  low=[min(r['native_global_bounds'][i] for r in rows) for i in [0,1]];high=[max(r['native_global_bounds'][i] for r in rows) for i in [2,3]]
  assert [high[i]-low[i] for i in range(2)]==[1503,750]
  image=Image.new('RGBA',(high[0]-low[0],high[1]-low[1]));pins=[]
  def order(r):
   g=native_graphics[str(r['graphic'])];x,y=r['cell'];return 0 if r['layer']==0 or g['ground'] else 1,11*y-9*x-min(g['footprint'])*10,(x+y)*32+g['origin'][0],r['index']
  for r in sorted(rows,key=order):
   g=native_graphics[str(r['graphic'])];native=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(native.tobytes()).hexdigest();assert digest==g['rgba_sha256']==r['source_rgba_sha256']
   point=r['native_global_bounds'];image.alpha_composite(native,(point[0]-low[0],point[1]-low[1]));pins.append({'graphic':r['graphic'],'cell':r['cell'],'layer':r['layer'],'source_rgba_sha256':digest,'bounds':point})
  png(f'{mid}-native.png',image)
  ground=image.copy();mask=ground_removal_mask(image)
  ground=continue_hidden_ground(image,mask,mid==58001);png(f'{mid}-ground.png',ground);png(f'{mid}-depth-mask.png',mask)
  form=image.copy();form.putalpha(Image.composite(image.getchannel('A'),Image.new('L',image.size),mask))
  if mid==58001:
   pixels=form.load()
   for y in range(form.height):
    for x in range(form.width):
     r,g,b,a=pixels[x,y]
     if a and max(r,g,b)<35:pixels[x,y]=(r,g,b,0)
  png(f'{mid}-form.png',form)
  if mid==58000:png('frieze-tile.png',image.crop((542,350,582,380)).resize((128,128),Image.Resampling.NEAREST))
  anchor=[42,44];anchor_pixel=[(sum(anchor))*32,(anchor[1]-anchor[0])*24]
  maps[str(mid)]={'source':mid,'anchor':anchor,'origin':[low[i]-anchor_pixel[i] for i in range(2)],'size':list(image.size),'native_rgba_sha256':hashlib.sha256(image.tobytes()).hexdigest(),'source_components':[p for p in pins if p['graphic']!=1001],'source_floor_components':[p for p in pins if p['graphic']==1001],'broken':mid==58001,'scope':'Lossless native composition; separate derivative depth mask reconstructs observed glass/caps/supports. Source-occluded ground is inferred from visible neighboring/radial native colors.'}
 data={'schema':1,'maps':maps,'inferred':['The original is a single perspective background; glass depth, hidden crown/back surfaces, cap thickness and scroll supports are reconstructed from its visible round design. These are not original 3D measurements.', 'Visible clouds, reflection and incidental motifs retain native artwork. Ground hidden behind the removed hourglass silhouettes is inferred from visible source circular-floor pixels at the same elliptical radius, or from adjacent cloud/void samples on the same row; no new route or physical floor is added.', 'The destroyed-state upper caps remain suspended. Broken glass follows source alpha on the curved glass envelope; its unseen circumference continues the observed edge pattern with independent glass color, rather than invented regular teeth. No door, route or encounter is invented.']}
 files['data.json']=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode();return files

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();bad=[]
 for n,b in products().items():
  f=OUT/n
  if a.check:
   if not f.exists() or f.read_bytes()!=b:bad.append(n)
  else:OUT.mkdir(parents=True,exist_ok=True);f.write_bytes(b)
 if bad:raise SystemExit('Stale Dragon Hourglass: '+', '.join(bad))
 print(('Verified' if a.check else 'Prepared')+' 28 background and105 native floor placements in both Dragon Hourglass states; original RGBA retained.')
if __name__=='__main__':main()
