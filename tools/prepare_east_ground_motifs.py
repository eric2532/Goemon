"""Pin the40 individually reviewed flat East object graphics at full native bounds."""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/maps/falan/east_region/ground_motifs/data.json'
GROUPS={'magic_circle':[11799,11803,*range(16638,16643)],'loose_floor_tool':[11063,11064,11067],'loose_floor_plank':[11166,11168],'loose_floor_bone':[11212,11213,11214,*range(11219,11229),11709,11723,*range(11734,11743)],'loose_rope':[16347],'tiny_floor_vessel':[16535],'loose_coins':[16546,16547]}
IDS=sorted(i for group in GROUPS.values()for i in group);assert len(IDS)==len(set(IDS))==40

def products():
 graphics={}
 for path in ['assets/maps/original_crossgate/catalog.json', 'assets/maps/falan/sokia/fixed/catalog.json', 'assets/maps/original_crossgate/university/catalog.json', 'assets/maps/original_crossgate/elsa/catalog.json', 'assets/maps/original_crossgate/east/catalog.json']:
  for token,g in json.loads((ROOT/path).read_text())['graphics'].items():
   if 'sokia/fixed' not in path or token not in graphics:graphics[token]=g
 rows={}
 for role,ids in GROUPS.items():
  for serial in ids:
   g=graphics[str(serial)];assert g['ground']==1,(serial,g)
   rows[str(serial)]={'role':role,'source_rgba_sha256':g['rgba_sha256'],'size':g['rect'][2:],'origin':g['origin'],'source_footprint':g['footprint']}
 return {'schema':1,'graphics':rows,'scope':'Only the40 individually inspected flat OBJECT drawings. Full original pixel bounds replace the truncated1tilequad; original positions/alpha/floors/walk/events stay unchanged. Does not include banks, geology, stairs, raised mixed art or cinematic backgrounds. Existing exact context owners take priority.'}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();raw=(json.dumps(products(),ensure_ascii=False,indent=2)+'\n').encode()
 if a.check:
  if not OUT.exists()or OUT.read_bytes()!=raw:raise SystemExit('Stale East flat motif source pins')
 else:OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_bytes(raw)
 print(('Verified'if a.check else 'Prepared')+'40 full-extent native ground motifs; original atlas/map data unchanged.')
if __name__=='__main__':main()
