"""Recover omitted native street fixtures in the two bounded village maps."""
import argparse,hashlib,json,sys
from pathlib import Path
from PIL import Image,ImageDraw
import review_kili_ghana as review
from build_coastal_villages import atlas
ROOT=review.ROOT;OUT=ROOT/'assets/maps/falan/village_street_props'
def covered(s):
 return s<1000 or s==17644 or 10058<=s<=10094 or 11188<=s<=11208 or 11229<=s<=11298 or 11363<=s<=11372 or 11625<=s<=11710 or 12160<=s<=12180 or 12500<=s<=12565
def prepare():
 lookup=review.source.review.lib.serial_index();areas={};used=set()
 for name,n in [('kili',3200),('ghana',3000)]:
  d=review.decode(n);rows=[[i%d['width'],i//d['width'],s] for i,s in enumerate(d['objects']) if not covered(s)];areas[name]=rows;used.update(row[2] for row in rows)
 OUT.mkdir(parents=True,exist_ok=True)
 rects=atlas(review.source.review.lib,lookup,used,OUT/'native.png',2048)
 graphics={}
 for s in sorted(used):
  e=lookup[s];im=review.source.review.lib.image_from_record(e['pack'],e['row'])
  foliage=[p for p in im.getdata() if p[3]>=128 and p[1]>p[0]*.85 and p[1]>p[2]*1.05]
  graphics[str(s)]=dict(rect=list(rects[s]),origin=[e['x'],e['y']],footprint=[max(1,e['east']),max(1,e['south'])],ground=bool(e['ground']),bounds=list(im.getbbox()),family='',pack=e['pack'],row=e['row'],rgba_sha256=hashlib.sha256(im.tobytes()).hexdigest(),leaf_rgb=[sum(p[c] for p in foliage)/len(foliage)/255 for c in range(3)] if foliage else [1,1,1])
 data=dict(areas=areas,graphics=graphics,limits='Native pixels and original placement anchors. Source isometric art does not establish hidden surfaces/depth; reuse shared prepared solid scenery and flat fine details. No new collision or actors.')
 (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 contact=review.OUT/'native-street-props.png';small=[s for s in used if s<11600]
 im=Image.new('RGBA',(1200,180*((len(small)+7)//8)),'#263138');draw=ImageDraw.Draw(im)
 for i,s in enumerate(sorted(small)):
  e=lookup[s];g=review.source.review.lib.image_from_record(e['pack'],e['row']);g.thumbnail((145,150));x=i%8*150;y=i//8*180;im.alpha_composite(g,(x,y+25));draw.text((x+3,y+3),str(s),fill='white')
 im.save(contact)
 print('Recovered source street fixtures', {a:len(v) for a,v in areas.items()},'graphics',len(used))
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 if args.check:
  import tempfile
  target=OUT
  with tempfile.TemporaryDirectory(prefix='cg-village-props-') as folder:
   OUT=Path(folder);prepare()
   assert json.loads((target/'data.json').read_text())==json.loads((OUT/'data.json').read_text())
   with Image.open(target/'native.png') as a,Image.open(OUT/'native.png') as b:assert a.tobytes()==b.tobytes()
  print('PASS native fixture anchors, pixels, bounds and source hashes reproduce')
 else:prepare()
