"""Native references and bedding paint for bounded reused East furniture."""
import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

from PIL import Image
from east_region_furniture_roles import GROUPS,ROLES
from recover_venoa_walls import native_without_ground_shadow

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/room_furniture'
REUSED_ROLES={'hospital_bed','wood_bed','wood_chair','bookcase','plain_bench','backed_wood_bench','hand_cart','hammock'}
IDS=sorted(s for s,r in ROLES.items() if r in REUSED_ROLES)+[11031]


def products():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
 import cg_library as lib
 catalog=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
 base=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text());graphics={};results={}
 def png(name,image):
  stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);results[name]=stream.getvalue()
 for serial in IDS:
  g=catalog['graphics'].get(str(serial),base['graphics'].get(str(serial)))
  assert g,serial
  image=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(image.tobytes()).hexdigest();assert digest==g['rgba_sha256'],serial
  clean,_=native_without_ground_shadow(image);png(f'{serial}-front.png',clean)
  role=ROLES[serial]
  row={'role':role,'origin':g['origin'],'footprint':g['footprint'],'bounds':list(clean.getbbox()),'size':list(image.size),'source_rgba_sha256':digest,'source_pack':g['pack'],'source_row':g['row']}
  if role in {'hospital_bed','wood_bed'}:
   cx,cy=round(image.width*.48),round(image.height*.55)
   crop=image.crop((cx-8,cy-8,cx+8,cy+8)).convert('RGB').resize((64,64),Image.Resampling.NEAREST).convert('RGBA')
   png(f'{serial}-bedding.png',crop);row['bedding_sample']=[cx-8,cy-8,cx+8,cy+8]
   row['frame_rgb']=[.43,.48,.50] if role=='hospital_bed' else ([.62,.26,.14] if serial in [16039,16040,16051,16052,16053,16059,16062] else [.48,.29,.15])
  graphics[str(serial)]=row
 data={'schema':1,'graphics':graphics,'scope':'Exact bounded furniture IDs only; reuse complete furniture/cart/hammock masters. No original map/event/navigation changes.',
  'inferred':['Unseen backs retain the reused model construction and native palette. Fit, hidden joints, board thickness and cloth folds reconstruct the single native view.',
   'Source bedding motifs are sampled separately at fixed world scale; original front paint is projected only onto observed facing surfaces.']}
 results['data.json']=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()
 return results


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args();bad=[]
 for name,raw in products().items():
  path=OUT/name
  if args.check:
   if not path.exists() or path.read_bytes()!=raw:bad.append(name)
  else:OUT.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
 if bad:raise SystemExit('Stale East furniture derivatives: '+', '.join(bad))
 print(('Verified' if args.check else 'Prepared')+f'{len(IDS)} reused native furniture forms; original RGBA preserved.')


if __name__=='__main__':main()
