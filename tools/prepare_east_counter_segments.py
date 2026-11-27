"""Native continuous blue shop-counter segments, not individual chests/lecterns."""
import argparse, hashlib, io, json, sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/counter_segments'
IDS=list(range(17196,17205))
def products():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 graphics={}
 for name in ['assets/maps/original_crossgate/catalog.json','assets/maps/original_crossgate/east/catalog.json']:
  graphics.update(json.loads((ROOT/name).read_text())['graphics'])
 files={};rows={}
 for serial in IDS:
  g=graphics[str(serial)];image=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(image.tobytes()).hexdigest();assert digest==g['rgba_sha256']
  stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);files[str(serial)+'.png']=stream.getvalue()
  rows[str(serial)]=dict(origin=g['origin'],size=list(image.size),footprint=g['footprint'],source_pack=g['pack'],source_row=g['row'],source_rgba_sha256=digest)
 data=dict(schema=1,graphics=rows,source_context='33514 native PG0+PG1:17199 repeats along the continuous blue counter,17197 forms its end/junction;17196..17204 form the same modular family.',scope='Private connected-counter study. No runtime routing change yet. The two formerly called blue_chest and the17196/98lectern route need compound-context validation.',inferred=['A3m source cell determines shared counter joints; hidden timber backs, base trim, corner depth and thickness follow the neighboring source counter pieces. Native visible cloth/items stay on the original faces. No service, inventory container or new route is added.'])
 files['data.json']=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode();return files
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args();bad=[]
 for name,value in products().items():
  path=OUT/name
  if args.check:
   if not path.exists()or path.read_bytes()!=value:bad.append(name)
  elif not path.exists()or path.read_bytes()!=value:OUT.mkdir(parents=True,exist_ok=True);path.write_bytes(value)
 if bad:raise SystemExit('Stale counter references: '+', '.join(bad))
 print(('Verified'if args.check else'Prepared')+' nine continuous native counter-segment references.')
if __name__=='__main__':main()
