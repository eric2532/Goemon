"""Exact references for five native market/crate drawings incorrectly typed as trees."""
import argparse,hashlib,io,json,sys
from pathlib import Path
from PIL import Image
from recover_venoa_walls import native_without_ground_shadow
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/maps/falan/east_region/market_goods'
IDS=[10053,10054,10056,10057,10098]
def products():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 native=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())['graphics']
 for path in ['assets/maps/falan/sokia/fixed/catalog.json','assets/maps/original_crossgate/university/catalog.json','assets/maps/original_crossgate/elsa/catalog.json','assets/maps/original_crossgate/east/catalog.json']:
  g=json.loads((ROOT/path).read_text())['graphics']
  if 'sokia/fixed' in path:
   for k,v in g.items():native.setdefault(k,v)
  else:native.update(g)
 graphics={};files={}
 for serial in IDS:
  g=native[str(serial)];image=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(image.tobytes()).hexdigest();assert digest==g['rgba_sha256']
  clean,_=native_without_ground_shadow(image);stream=io.BytesIO();clean.save(stream,format='PNG',optimize=True);files[str(serial)+'-front.png']=stream.getvalue()
  graphics[str(serial)]={'role':'vented_crate'if serial==10098 else'meat_fish_stand'if serial in[10054,10057]else'produce_stand','origin':g['origin'],'size':list(image.size),'footprint':g['footprint'],'bounds':list(clean.getbbox()),'source_rgba_sha256':digest,'source_pack':g['pack'],'source_row':g['row']}
 data={'schema':1,'graphics':graphics,'scope':'Five exact native drawings, not trees. Reuse existing market display/crate construction; preserve source placements, navigation and NPC services.',
       'inferred':['Board thickness, frame joints, hidden backs, product-bed height and sign/display support reconstruct the single native view. Small food/meat/fish drawings remain bounded native art; no new merchandise interaction or NPC behavior is introduced.']}
 files['data.json']=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode();return files
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();bad=[]
 for n,b in products().items():
  f=OUT/n
  if a.check:
   if not f.exists()or f.read_bytes()!=b:bad.append(n)
  elif not f.exists()or f.read_bytes()!=b:OUT.mkdir(parents=True,exist_ok=True);f.write_bytes(b)
 if bad:raise SystemExit('Stale East market references: '+', '.join(bad))
 print(('Verified'if a.check else'Prepared')+'five native market/crate references; originalRGBA unchanged.')
if __name__=='__main__':main()
