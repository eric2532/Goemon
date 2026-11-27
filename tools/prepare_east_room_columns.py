"""Recover native column faces and separate back/cap paint for East interiors."""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/room_columns'
GROUPS={
 'pale':list(range(1235141,1235146)),
 'red':list(range(1235151,1235154)),
 'round_red':[1235154], 'round_gold':[1235155], 'round_blue':[1235156],
 'dark':[1235160], 'blue':list(range(1235183,1235186)), 'green':list(range(1235186,1235189)),
}


def products():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
 import cg_library as lib
 catalog=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
 results={};graphics={}
 def png(name,image):
  stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);results[name]=stream.getvalue()
 for style,ids in GROUPS.items():
  sample=None
  for serial in ids:
   g=catalog['graphics'][str(serial)]
   image=lib.image_from_record(g['pack'],g['row']).convert('RGBA')
   digest=hashlib.sha256(image.tobytes()).hexdigest();assert digest==g['rgba_sha256'],serial
   png(f'{serial}.png',image)
   if sample is None:sample=image
   graphics[str(serial)]={'style':style,'round':style.startswith('round_'),'size':list(image.size),
    'origin':g['origin'],'footprint':g['footprint'],'source_rgba_sha256':digest,
    'height':(-g['origin'][1]-24)*.045,'source_pack':g['pack'],'source_row':g['row']}
  # A bounded sample from the original shaft supplies unseen stone/ceramic grain.
  # Source decoration stays on observed faces; a torch or stained window is not copied around the back.
  cx=sample.width//2 if style.startswith('round_') else sample.width*3//8
  cy=round(sample.height*(.78 if style=='red' else .60))
  shaft=sample.crop((cx-6,cy-6,cx+6,cy+6)).convert('RGB')
  shaft=shaft.resize((128,128),Image.Resampling.BICUBIC).convert('RGBA')
  cap=sample.crop((sample.width//2-3,7,sample.width//2+3,13)).resize((128,128),Image.Resampling.BICUBIC)
  cap.putalpha(255)
  atlas=Image.new('RGBA',(256,128));atlas.paste(shaft,(0,0));atlas.paste(cap,(128,0));png(style+'-surfaces.png',atlas)
 data={'schema':1,'graphics':graphics,'scope':'Exact18 native East object-layer room columns; original placements/navigation/events unchanged.',
  'reuse':'forest_east_fallback_families.gd::profile and shared coastal ring/quad primitives.',
  'inferred':['Closed rear faces continue independently sampled native shaft/cap paint at fixed world scale.',
   'Hidden column section, small moulding bevels and full round-column circumference are reconstructed from native front/side silhouettes.']}
 results['data.json']=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()
 return results


def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 bad=[]
 for name,payload in products().items():
  path=OUT/name
  if args.check:
   if not path.exists() or path.read_bytes()!=payload:bad.append(name)
  else:OUT.mkdir(parents=True,exist_ok=True);path.write_bytes(payload)
 if bad:raise SystemExit('Stale East room columns: '+', '.join(bad))
 print(('Verified' if args.check else 'Prepared')+'18 native room column profiles; originals preserved.')


if __name__=='__main__':main()
