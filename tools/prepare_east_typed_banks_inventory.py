"""Read-only source frames for reached typed East banks/cliffs, preserving raw planes."""
import hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit'
def main():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
 lookup=lib.serial_index();catalog=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text());rows=json.loads((REPORT/'typed-native-candidates.json').read_text())['graphics'];records={}
 for row in rows:
  serial=int(row['graphic'])
  if not (12500<=serial<=12535 or 12926<=serial<=12937 or 1238125<=serial<=1238216):continue
  if serial>=1000000:g=catalog['graphics'][str(serial)]
  else:
   raw=lookup[serial];g={'pack':raw['pack'],'row':raw['row'],'origin':[raw['x'],raw['y']],'footprint':[max(1,raw['east']),max(1,raw['south'])]}
  image=lib.image_from_record(g['pack'],g['row']).convert('RGBA');digest=hashlib.sha256(image.tobytes()).hexdigest();assert digest==row['source_rgba_sha256']
  records[str(serial)]={'graphic':serial,'native_rgba_sha256':digest,'origin':g['origin'],'pixels':list(image.size),'visible_box':image.getbbox(),'footprint':g['footprint'],'raw_ground_flag':row['ground'],'source_contexts':row['contexts'],
   'image_frame_y_range':[(-g['origin'][1]-image.height)*.045,-g['origin'][1]*.045],
   'frame_rule':'Resolve source cap at ground0 using the existing bank owner. Image-frame vertical range includes floor shear and is not an above-ground pillar height. Preserve raw ground/object planes, native water, anchors, walk bits and portals.',
   'status':'source_frame_inventory_only_not_implemented_or_visually_accepted'}
 payload={'scope':'Reached typed bank/cliff source-frame inventory, separate from652above-ground stone/cave families. Source38000..38027cinematic cloud/hourglass backgrounds explicitly excluded.','source_catalog_sha256':hashlib.sha256((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_bytes()).hexdigest(),'graphics':records}
 (REPORT/'TYPED_BANK_SOURCE_PLAN.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n');print('EAST_TYPED_BANK_SOURCE_PLAN',len(records),'source frames; no runtime enrollment')
if __name__=='__main__':main()
