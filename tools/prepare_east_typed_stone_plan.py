"""Read-only ownership/source checklist for reached typed cave walls and caps."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit'


def main():
 path=FOLDER/'typed-owner-inventory.json';inventory=json.loads(path.read_text());existing=json.loads((FOLDER/'STONE_SOURCE_PLAN.json').read_text())['graphics']
 architecture=json.loads((FOLDER/'ARCHITECTURE_FAMILY_PLAN.json').read_text());architecture_ids={serial for group in architecture['groups']for serial in group['ids']}
 rows={};excluded={16191:'Root owns the verified stove repair.',16769:'Root owns the verified weapon-counter repair.'}
 for row in inventory['typed_graphics']:
  serial=int(row['graphic'])
  if (row['family']not in ['room_wall','cave_crag']and serial!=17065)or serial in excluded:continue
  assert serial not in architecture_ids,'Coordinate architecture ownership before adding '+str(serial)
  rows[str(serial)]={**row,'graphic':serial,'already_in_652_plan':str(serial)in existing,'status':'source_and_owner_inventory_only_requires_native_and_reachable_angle_review','geometry_rule':'Preserve source anchor, footprint cells, walk/portal masks and source cap/ground planes. Sparse/black occlusion art never measures a whole rock body; any closed hidden support is separate inference. Use source-defined wall/ice/stone form, not automatic generic pillars.'}
 result={'scope':'Additional reached typed cave/wall owner audit, including explicitly assigned wall17065. Typed status and correct RGBA binding are not visual acceptance. This is separate from the652 final-fallback source families and110 lower-bank frames.','source_inventory_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'native_binding_proof':'typed-native-binding-check.json','graphics':rows,'excluded_root_owners':excluded,'counts':{family:sum(row['family']==family for row in rows.values())for family in ['room_wall','cave_crag','wall']},'overlap_652':sorted(int(token)for token,row in rows.items()if row['already_in_652_plan'])}
 (FOLDER/'TYPED_STONE_SOURCE_PLAN.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('EAST_TYPED_STONE_PLAN',len(rows),result['counts'],'overlap652',len(result['overlap_652']))


if __name__=='__main__':main()
