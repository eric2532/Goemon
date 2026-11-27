"""Private source-key plan, not a production scenery/filter enrollment."""
import hashlib,json,sys
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT.parent/'Magic Power/tools'),str(ROOT/'tools')]
import cg_library as lib
from prepare_field_assets import navigation_grid
from prepare_east_nature import sources
B=ROOT/'build/Other Files/Asset Toolkit/East Gate Region'
OUT=B/'Runtime Audit/Source100 Restoration Plan'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def prepare():
    missing_path=B/'Runtime Audit/Source100 Missing13/source.json';missing=json.loads(missing_path.read_text());older_path=B/'Runtime Audit/Source100 Completeness/older73-owner-ledger.json';older=json.loads(older_path.read_text());graph_path=B/'Version Expansion Source Audit/graph.json';graph=json.loads(graph_path.read_text())
    raw_path=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat';w,h,g,o,f=lib.parse_map(raw_path.read_bytes());walk=navigation_grid(w,h,g,o,lib.serial_index());graphics,_,catalog_pins=sources();rows=[];hold=[]
    def add(cell,serial,origin,candidate,footprint,rgba=None):
        x,y=map(int,cell);i=y*w+x;assert o[i]==serial
        graphic,_=graphics[serial]
        if rgba is not None:assert rgba==graphic['rgba_sha256']
        rgba=graphic['rgba_sha256']
        near=[]
        for link in graph['links']:
            point=link.get('cell')if link['source']==100 else link.get('landing')if link['target']==100 else None
            if point and(x-point[0])**2+(y-point[1])**2<=4.:near.append(link)
        family='native_tree'if serial in[10074,10087,10089]else'measured_mushrooms'if serial in[11098,11099]else'blue_mushroom_fit'if serial==11100 else'dry_grass'if serial in[12182,12184]else'native_lamp'if serial in[10424,10428]else'flower_urn'if serial in[10403,10404]else'whole_prepared_boulder'if serial in[12226,12244]else'existing_source_nature'
        dependencies=[]
        if serial in[10074,10089,12226]:dependencies.append('Exact source-closed dryBGcell datum reconstruction; neighboring void/native support must remain authoritative.')
        if family=='native_tree':dependencies.append('Private one-observed-face/rounded-rear crown prototype and actual normal/reachable second view; canonical27unchanged.')
        if family in['blue_mushroom_fit','dry_grass']:dependencies.append('Measured source fit/source-alpha study of compatible existing owner; not yet prepared.')
        if family=='flower_urn':dependencies.append('Reuse existing urn/flower kit with original native proportions; review actual bridge context.')
        rows.append(dict(key=f'100:{x}:{y}:{serial}',source=100,cell=[x,y],graphic=serial,bg=g[i],source_original_open=bool(walk[i]),footprint=footprint,source_rgba_sha256=rgba,source_origin=graphic['origin'],source_size=graphic['rect'][2:],source_inventory_origin=origin,reuse_candidate=candidate,role=family,near_original_gates=near,protected_gate_policy='Retain current runtime entrance guard and original source-trigger bounds; no generic filter is relaxed.',source_closed_policy='A closed original foreground anchor is not a reason to erase its visual. Do not change its original closed/open authority or add another collider owner.',dependencies=dependencies,status='PRIVATE plan only; no live filter/asset enrollment and no visual clearance.'))
    for row in missing['records']:
        if int(row['native_graphic'])==10069:hold.append(dict(graphic=10069,cell=row['cell'],reason='No source-confirmed East entry in available records; other existing owner envelopes.2016verified programs/4772uncached unrelated programs/hidden builtin limits remain explicit.'));continue
        add(row['cell'],int(row['native_graphic']),'13actual-filter omissions',row['source_row'],row['source_footprint'])
    for row in older['rows']:
        if row['whole_bridge_compound']is not None:hold.append(dict(graphic=row['native_graphic'],cell=row['cell'],reason='Retained whole FreyjaStoneBridge compound geometry. Source post/coping fidelity pending; do not duplicate.'));continue
        add(row['cell'],row['native_graphic'],'73older-owner followup',row['reuse_candidate'],row['source_footprint'],row['source_rgba_sha256'])
    assert len(rows)==80 and len({r['key']for r in rows})==80 and len(hold)==6
    OUT.mkdir(parents=True,exist_ok=True);result=dict(schema=1,scope='PRIVATE source-key restoration plan:12eligible diagnosed rows+62field followups+6near-city props.5wholebridgeparapets retained;10069held. No canonical assets/filters/source bits changed.',source_size=[w,h],source_raw_sha256=sha(raw_path),source_evidence_commit=graph['revision'],rows=rows,holds=hold,counts=dict(planned=len(rows),roles=dict(Counter(r['role']for r in rows)),near_gate_holds=sum(bool(r['near_original_gates'])for r in rows)),production_owner_proposal=['Use the existing field-source compiler and Frontier render owners. Store generated source keys/provenance in canonical assets only after visual/ground approval; never load a build-directory test helper in gameplay.','Keep complete_field_plan/scenery_plan collision ownership unchanged. Draw a confirmed closed-anchor visual separately from its rejected walk-radius test; do not manufacture another obstacle.','For details, retain source-area/village/context/protected-link checks; an approved exact source key may replace the generic terrain-disk/tree-proxy filter only for that row. Never relax street_fits globally.','Record emitted source keys during existing tree/detail batching. A new source row must not duplicate an already-emitted native or whole-compound owner.','Use one original source basis/origin and physical.045height frame. Native27/Nature/Tina meshes are reused setup-time, with immutable shared resources; no per-frame loads or new simulation.'],unaccepted=['Each reuse candidate needs native/source view and actual normal/reachable second-view judgment as appropriate.','Three dryBGdatum repairs are private Host-terrain work; native walk/closed, source void, protected routes and physical support must be proved separately.','No new random encounters/NPCbehavior is created for source object art.'],inputs={str(p.relative_to(ROOT)):sha(p)for p in[missing_path,older_path,graph_path,raw_path,Path(__file__)]})
    result['graphic_catalog_source_sha256']=catalog_pins
    (OUT/'source-key-plan.json').write_text(json.dumps(result,indent=2)+'\n');print(result['counts']);return result
if __name__=='__main__':prepare()
