"""Measure intended stone exposure against the actual closed candidate core."""
import json
from pathlib import Path
import numpy as np
from audit_east_boulder_contact import ray_intervals
from prepare_east_cliff_volumes import REVIEW


def main():
 rows=[]
 for serial in [12536,12537,12538,12542,12543,12546]:
  path=REVIEW/f'Images/{serial}-study.json'
  if not path.exists():continue
  description=json.loads(path.read_text());triangles=np.load(REVIEW/f'Images/{serial}-geometry.npz')['triangles'];core_count=description['core_triangles'];per=description['reused_master']['triangles'];core=triangles[:core_count];measurements=[]
  for index,placement in enumerate(description['placements']):
   rock=triangles[core_count+index*per:core_count+(index+1)*per];normal=np.asarray(placement['normal']);origin=np.asarray(placement['point'])+normal*3
   ci=ray_intervals(core,origin,-normal);ri=ray_intervals(rock,origin,-normal)
   exposure=ci[0][0]-ri[0][0]if ci and ri else None
   measurements.append({'volume':index,'source_front':placement['source_front'],'source_patch':placement['source_patch'],'exposure_m':exposure})
  front=[r for r in measurements if r['source_front']];hidden=[r for r in measurements if not r['source_front']]
  row={'graphic':serial,'source_front_stones':len(front),'source_front_buried_at_anchor':sum(r['exposure_m']is not None and r['exposure_m']<=.02 for r in front),'hidden_stones':len(hidden),'hidden_buried_at_anchor':sum(r['exposure_m']is not None and r['exposure_m']<=.02 for r in hidden),'measurements':measurements}
  rows.append(row);print('STONE_EXPOSURE',serial,'front buried',row['source_front_buried_at_anchor'],'/',len(front),'hidden buried',row['hidden_buried_at_anchor'],'/',len(hidden),flush=True)
 (REVIEW/'exposure-audit.json').write_text(json.dumps({'scope':'Private geometry diagnostic, not visual acceptance. Rays compare actual whole-stone and core surfaces at the measured placement axis; negative exposure means a stone is buried beneath the retained core at its intended anchor.','graphics':rows},indent=2)+'\n')


if __name__=='__main__':main()
