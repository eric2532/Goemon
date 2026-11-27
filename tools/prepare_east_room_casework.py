"""Source references for the East branch's reused case, counter and table forms."""
import argparse, hashlib, io, json, sys
from pathlib import Path
from PIL import Image
from east_region_furniture_roles import ROLES
from recover_venoa_walls import native_without_ground_shadow
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/room_casework'
ROLES_USED={'low_cabinet','open_hutch','empty_shelf','covered_side_cabinet','wall_clock','narrow_drawers','closed_wardrobe','low_open_display','marble_low_table','covered_low_seat','tea_table','glass_hutch','kitchen_counter','wall_kitchen_unit','writing_table','arched_drawers','dresser_mirror','plain_wood_counter','covered_counter','curved_counter','goods_counter','drawer_over_firewood','firewood_counter','writing_hutch'}
IDS=sorted(s for s,r in ROLES.items() if r in ROLES_USED)

def products():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
 import cg_library as lib
 cats=[json.loads((ROOT/p).read_text()) for p in ['assets/maps/original_crossgate/catalog.json','assets/maps/original_crossgate/east/catalog.json']]
 native={};[native.update(c['graphics']) for c in cats]
 results={};graphics={}
 def png(name,image):
  stream=io.BytesIO();image.save(stream,format='PNG',optimize=True);results[name]=stream.getvalue()
 for serial in IDS:
  g=native[str(serial)];image=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(image.tobytes()).hexdigest();assert digest==g['rgba_sha256'],serial
  clean,_=native_without_ground_shadow(image);png(f'{serial}-front.png',clean)
  graphics[str(serial)]={'role':ROLES[serial],'origin':g['origin'],'footprint':g['footprint'],'bounds':list(clean.getbbox()),'size':list(image.size),'source_rgba_sha256':digest,'source_pack':g['pack'],'source_row':g['row']}
 data={'schema':1,'graphics':graphics,'scope':'Exact source furniture references. Candidate geometry must be reviewed before any OriginalMaps enrollment. Original maps, walks and NPC/event ownership stay unchanged.',
  'inferred':['Unseen cabinet interiors, backs, undersides, board thickness and joints follow compatible existing furniture construction. Native facade ornament remains flat inside physical frames.', 'No furniture scenery recipe adds services, doors, containers or interactions.']}
 results['data.json']=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()
 return results

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();bad=[]
 for name,raw in products().items():
  path=OUT/name
  if args.check:
   if not path.exists() or path.read_bytes()!=raw:bad.append(name)
  else:OUT.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
 if bad:raise SystemExit('Stale East casework: '+', '.join(bad))
 print(('Verified' if args.check else 'Prepared')+f' {len(IDS)} native casework references; original RGBA preserved.')
if __name__=='__main__':main()
