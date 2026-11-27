"""Preserved original references for the three ceremonial hourglasses."""
import argparse, hashlib, io, json, sys
from pathlib import Path
from recover_venoa_walls import native_without_ground_shadow
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/maps/falan/east_region/hourglasses';IDS=[1235180,1235181,1235182]

def products():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 cat=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text());files={};graphics={}
 for serial in IDS:
  g=cat['graphics'][str(serial)];im=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(im.tobytes()).hexdigest();assert digest==g['rgba_sha256']
  clean,_=native_without_ground_shadow(im);s=io.BytesIO();clean.save(s,format='PNG',optimize=True);files[f'{serial}-front.png']=s.getvalue()
  graphics[str(serial)]={'size':list(im.size),'bounds':list(clean.getbbox()),'origin':g['origin'],'footprint':g['footprint'],'source_rgba_sha256':digest,'metal':'gold' if serial==1235180 else 'copper' if serial==1235181 else 'iron','glass':'amber' if serial==1235181 else 'blue'}
 files['data.json']=(json.dumps({'schema':1,'graphics':graphics,'inferred':['Unseen glass curvature, rear metal support and underside continue the observed round construction. Source fronts and original placement/footprints remain unchanged.'],'scope':'Three source-confirmed ceremonial hourglass scenery forms, without event behavior.'},ensure_ascii=False,indent=2)+'\n').encode()
 return files

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();bad=[]
 for n,b in products().items():
  f=OUT/n
  if a.check:
   if not f.exists() or f.read_bytes()!=b:bad.append(n)
  else:OUT.mkdir(parents=True,exist_ok=True);f.write_bytes(b)
 if bad:raise SystemExit('Stale hourglass references: '+', '.join(bad))
 print(('Verified' if a.check else 'Prepared')+'3 ceremonial hourglass references; original RGBA preserved.')
if __name__=='__main__':main()
