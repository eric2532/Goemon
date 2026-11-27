#!/usr/bin/env python3
"""Stage one default-off Tour handoff call; never edit the shared runtime file."""
from pathlib import Path
import difflib
import hashlib
import json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit/Prototype'
PATH='scripts/forest/forest_falan_tour.gd'
OLD=''' if not crossing.is_empty():
  return walk_into(game,venture,crossing.area,crossing.arrival,crossing.rotation)
 if outlying:return false
'''
NEW=''' if not crossing.is_empty():
  return walk_into(game,venture,crossing.area,crossing.arrival,crossing.rotation)
 var source_context=Regions.private_source_context
 if source_context!=null:
  var handoff:Dictionary=source_context.scene_handoff(game,before,at)
  if not handoff.is_empty():return walk_into(game,venture,handoff.area,handoff.arrival,handoff.rotation)
 if outlying:return false
'''

def sha(data):return hashlib.sha256(data).hexdigest()

def main():
    original=(ROOT/PATH).read_bytes();text=original.decode()
    if 'source_context.scene_handoff(game,before,at)' in text:
        raise SystemExit('Refusing to restage against an already applied handoff hook.')
    if text.count(OLD)!=1:
        raise SystemExit('Shared Tour source changed: inspect the unique original crossing branch before staging.')
    candidate=text.replace(OLD,NEW)
    target=OUT/'handoff-shadow'/PATH;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(candidate)
    patch=''.join(difflib.unified_diff(text.splitlines(True),candidate.splitlines(True),fromfile='a/'+PATH,tofile='b/'+PATH))
    patch_path=OUT/'same-source-handoff.patch';patch_path.write_text(patch)
    dependencies={p:sha((ROOT/p).read_bytes()) for p in ['scripts/forest/forest_east_source_context_review.gd','scripts/forest/forest_east_host_source_context.gd']}
    record={'default_off':True,'runtime_files':[PATH],'baseline_sha256':sha(original),'candidate_sha256':sha(candidate.encode()),'patch_sha256':sha(patch.encode()),'private_dependencies':dependencies,'stage_only':True,'scope':'One null-guarded call after original doors and Regions.crossings, before outlying return. Reuses existing walk_into without changing source positions, yaw/velocity conversion, native/source data, collision, other-goal routing or canonical flag. Active Host handoff proof/actual player/pet remain pending; historical52assertions are13directions times4radii across five cells/eight undirected edges, not52distinct edges.'}
    (OUT/'same-source-handoff-source.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record,indent=2))

if __name__=='__main__':main()
