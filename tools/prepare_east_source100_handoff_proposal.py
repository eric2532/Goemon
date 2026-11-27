"""Stage a review-only same100 display interface; never modify production owners."""
from collections import Counter
import difflib
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT.parent / 'Magic Power/tools'), str(ROOT / 'tools')]
import cg_library as lib
from prepare_field_assets import navigation_grid
BASE = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13'
OUT = BASE / 'Display Handoff Proposal'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def resolve(path):return ROOT / path.removeprefix('res://') if path.startswith('res://') else Path(path)

def run():
    cpu_path=BASE/'Remote Views/south-boundary-current.json';source_path=BASE/'Remote Views/crop-open-frontiers.json'
    cpu=json.loads(cpu_path.read_text());source=json.loads(source_path.read_text());contract_path=OUT/'contract.json';contract=json.loads(contract_path.read_text())
    assert not cpu['source_changed'] and not contract['source_changed'] and not contract['failures']
    for report in [cpu,contract]:
        assert all(sha(resolve(p))==digest for p,digest in report['source_hashes'].items()), 'Source changed after CPU proof'
    by_area={r['area']:r['edges']for r in cpu['compiler_frontier_samplers']}
    edges=[];counts=Counter()
    for i,row in enumerate(source['compiler_open_frontiers']):
        actual={area:rows[i]for area,rows in by_area.items()}
        assert all(r['source_from']==row['source_from']and r['source_to']==row['source_to']for r in actual.values())
        radii=[]
        for j,radius in enumerate([.25,.35,.55,.8]):
            owners=sorted(area for area,r in actual.items()if r['all_radii'][j]['edge_clear'])
            radii.append(dict(radius=radius,current_Native_clear_owners=owners))
        owners=radii[1]['current_Native_clear_owners']
        status='same-East-current-Native-edge-clear'if'east_gate'in owners else'other-current-Native-edge-clear-no-display-transfer'if owners else'no-current-Native-edge-clear'
        counts[status]+=1
        transfers={area:r['region_handoff']for area,r in actual.items()if r['region_handoff']!='{}'or r['trail_handoff']}
        assert not transfers
        edges.append(dict(source_from=row['source_from'],source_to=row['source_to'],classification=status,
                          original_open=True,gate_connected=True,actual_radius_results=radii,
                          current_Regions_or_trail_transfers=transfers,
                          closure='Native edge clear is not a scene-transfer/player/render acceptance. The compiler guard supplies no transfer.'))
    samples={r['area']:r['outliers']for r in cpu['outlier_samplers']};outliers=[];outlier_counts=Counter()
    for i,row in enumerate(source['outliers']):
        actual={area:rows[i]for area,rows in samples.items()}
        assert all(r['source_cell']==row['cell']for r in actual.values())
        owners=sorted(area for area,r in actual.items()if r['native_radii'][1]['native_clear'])
        outlier_counts['+'.join(owners)or'no-current-Native-point-support']+=1
        outliers.append(dict(source=row,actual_current_samplers=actual,
                             Native_point_supported_owners_radius035=owners,
                             scene_transfer_status='No transfer inferred from a point, mask or overlapping owner envelope.'))
    raw_path=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat'
    w,h,bg,pg,flags=lib.parse_map(raw_path.read_bytes());walk=navigation_grid(w,h,bg,pg,lib.serial_index())
    strip=[]
    for y in range(359,362):
        for x in range(490,498):
            i=y*w+x;strip.append(dict(cell=[x,y],bg=bg[i],pg1=pg[i],original_open=bool(walk[i]),
                                      kind='closed-native-object'if not walk[i]else'original-open-dry',
                                      action='One Host owner only; preserve original closed authority. No whole rectangle may be marked open.'))
    assert len(strip)==24 and all(r['bg']not in [0,100]and not 5000<=r['bg']<=5008 for r in strip)
    owner='scripts/forest/forest_freyja_regions.gd';original=(ROOT/owner).read_text()
    insertion='''# Technical display seam between two views of original100; not an original warp.
const SOURCE100_DISPLAY_INTERFACES={"east_gate":[-1.0,"south_gate"],"south_gate":[1.0,"east_gate"]}
'''
    anchor='static var private_source_context:Script=null\n';assert original.count(anchor)==1
    proposed=original.replace(anchor,anchor+insertion)
    anchor=' return Sokia.crossing(area,previous,next) if Sokia.owns(area) else {}\n';assert original.count(anchor)==1
    insertion=''' var display:Array=SOURCE100_DISPLAY_INTERFACES.get(area,[]) if private_source_context!=null and private_source_context.host_ready() else []
 if not display.is_empty() and absf(next.y-1080.0)<=.6501:
  var direction:float=display[0]
  if (previous.x-1471.5)*direction<0.0 and (next.x-1471.5)*direction>=0.0:
   var target:Transform2D=frame(display[1])
   return {"area":display[1],"arrival":target.inverse()*next,"rotation":target.get_rotation()-source.get_rotation(),"source":100,"source_float":next/3.0,"display_boundary_only":true}
'''
    proposed=proposed.replace(anchor,insertion+anchor)
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'regions-display-only.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True),proposed.splitlines(True),fromfile='a/'+owner,tofile='b/'+owner)))
    result=dict(status='PRIVATE STAGED PROPOSAL ONLY; not applied or activated',
                frontier_counts=dict(counts),frontier_edges=edges,outlier_counts=dict(outlier_counts),outliers=outliers,
                rock_strip=dict(source=100,bounds_cells=[490,359,8,3],source_cells=strip,source_cell_count=len(strip),
                                original_open_cells=sum(r['original_open']for r in strip),
                                purpose='Bounded source-ground/support candidate from closed rock12226to existing shared Native patch. Exact dry BG and PG1 retained; absolute6m datum remains inferred. Private Host owns terrain/height/physics/native together.'),
                proposed_display_seam=dict(source=100,edge_x=490.5,source_y=360.,
                                           unscaled_y_half_span_m=.65,source_endpoint_cells=[[491,360],[490,360]],
                                           contract_checks=contract['checks'],contract_failures=0,
                                           reuse='Existing Regions.crossings result consumed by Tour.walk_into after existing Data.LINKS priority. Null/unready private_source_context disables seam; existing cached Host readiness gates the two-entry constant lookup. No other-scene resource loads, scans or simulation owner.'),
                existing_endpoint=dict(area='south_gate',continued_source_path=cpu['rock_to_existing_road'][1],
                                       functional_road=cpu['existing_directed_crossing_samplers'][1:3]),
                staged_owner_baseline_sha256=sha(ROOT/owner),staged_patch_sha256=sha(OUT/'regions-display-only.patch'),
                source_raw_sha256=sha(raw_path),inputs={str(p.relative_to(ROOT)):sha(p)for p in [cpu_path,source_path,contract_path]},
                pending=['Do not apply before one Host strip/raw/BG/PG1/physics/native proof and actual player/pet normal/return proof.',
                         'Proposed display seam is technical continuity of one original map, not a source warp or a new route.',
                         'All226interfaces remain individually listed. This one proposal does not close the other interfaces or the1956outliers.',
                         'Current CPU Native support certificate is tied to its recorded source hashes; revalidate against any later private Host installation.',
                         'No South region scenery is rebuilt. Existing SouthGate/SouthLakes road continues under its current owner.'])
    (OUT/'source-interface-ledger.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(dict(frontiers=counts,outliers=outlier_counts,strip_cells=len(strip),strip_open=sum(r['original_open']for r in strip),checks=contract['checks']),indent=2))

if __name__=='__main__':run()
