"""Exact source/caller comparison for73uncompiled Source100PG1follow-ups."""
import json,hashlib,re,sys
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT.parent/'Magic Power/tools'),str(ROOT/'tools')]
import cg_library as lib
from build_freyja_destinations import load_map
B=ROOT/'build/Other Files/Asset Toolkit/East Gate Region'
OUT=B/'Runtime Audit/Source100 Completeness'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def array_body(text,name):
    start=text.index(name)+len(name);level=1;end=start
    while level:
        level+=(text[end]=='[')-(text[end]==']');end+=1
    return text[start:end-1]
def run():
    scene_path=B/'Runtime Audit/Source100 Scene Owners/review.json';scene=json.loads(scene_path.read_text());native=json.loads((OUT/'field-pg1-followup-native.json').read_text());byid={r['native_graphic']:r for r in native};lookup=lib.serial_index()
    w,h,g,o,f=load_map(lib,1000)
    archive_path=ROOT/'assets/maps/falan/freyja_entrance_data.gd';archive=archive_path.read_text();entries=[]
    for area in ['east_gate','east_coast']:
        text=array_body(archive,'"'+area+'":[')
        entries.extend((int(x),int(y),int(serial))for x,y,serial in re.findall(r'\[Vector2i\((-?\d+),(-?\d+)\),(\d+),',text))
    residual_path=ROOT/'assets/maps/falan/freyja_residual/provenance.json';residual=json.loads(residual_path.read_text());shores={tuple(r[:3])for r in residual['areas']['east_gate']['shores']}
    street_path=ROOT/'assets/maps/falan/city_street_data.gd';street=street_path.read_text();nature_path=ROOT/'assets/maps/falan/east_region/nature/data.json';nature=json.loads(nature_path.read_text())['graphics'];rows=[]
    for row in scene['older73']:
        serial=int(row['native_graphic']);x,y=map(int,row['cell']);entry=lookup[serial];sx,sy=max(1,entry['east']),max(1,entry['south']);cx,cy=x-189,y-108;city_inside=0<=cx<w and 0<=cy<h;city_same=city_inside and o[cy*w+cx]==serial
        city_point=[3*(cy-134)-1.5*(sy-1),3*(153-cx)-1.5*(sx-1)]
        vista_point=[-135-city_point[0],-225-city_point[1]]
        group='PARAPETS'if 10620<=serial<=10630 else'LAMPS'if serial in[10424,10428]else'FLOWERS'if serial in[10403,10404]else None
        compiled=[]
        if group:
            body=array_body(street,'const '+group+'=[')
            for a,b,c in re.findall(r'\[Vector2\((-?[\d.]+),(-?[\d.]+)\),(\d+)',body):
                if int(c)==serial and abs(float(a)-city_point[0])<.001 and abs(float(b)-city_point[1])<.001:compiled.append([float(a),float(b),int(c)])
        projection=dict(label='CURRENT runtimevista alignment, not original intermapwarp proof',source1000_cell=[cx,cy],source1000_raw_graphic=o[cy*w+cx]if city_inside else None,same_native_graphic=bool(city_same),compiled_group=group,compiled_rows=compiled,city_center=city_point,east_local_center=vista_point,east_source_anchor=[591-3*y,3*x-1251],parapet_visibility_limit=54,parapet_visible=bool(vista_point[1]<54)if group=='PARAPETS'and compiled else None)
        bridge_role=group=='PARAPETS'and 63<=vista_point[1]<=153 and abs(abs(vista_point[0]-3)-9)<.001
        bridge=dict(whole_owner='forest_freyja_art.gd::bridge / FreyjaStoneBridge',bounds=[-6,63,18,90],continuous_rail_x_centers=[-6.6,12.6],continuous_rail_z_range=[63,153],source_center_on_original_bridge_edge=bridge_role,meaning='Existing whole bridge has continuous rail/arch geometry across this source footprint; do not duplicate the rawsource parapet. Native post/coping silhouette and exact source stations remain a separate comparison.')
        if city_same and compiled and group=='PARAPETS'and vista_point[1]>=54:
            verdict='CityForts source row is visibility-culled, but the same world footprint intersects the retained whole FreyjaStoneBridge rail/arch owner. This is existing compound geometry, not a confirmed missing whole object; source-specific silhouette/station fidelity remains open.'
        elif group:
            verdict='No exact native row at the same current-vista world center in the compiled city group. Keep overlap/compound audit explicit before production enrollment.'
        else:verdict='No exact source row in currentfieldcatalog, entranceArchive or residualshoreowner. Current native-tag census also found0; legacy compound overlap still requires explicit geometry audit.'
        mesh='Nature.mesh canonical source-specific '+nature[str(serial)]['kind']if str(serial)in nature else'TinaStreet.mushrooms_mesh measured native11098/11099'if serial in[11098,11099]else'existing mushroom master needs measured blue11100fit'if serial==11100 else'existing nativegrass helper/sourcealpha study; no new source recipe yet'if serial in[12182,12184]else'Existing cityowner must stay isolated; do not duplicate currentvista.'
        rows.append(dict(source_map=100,cell=[x,y],native_graphic=serial,source_rgba_sha256=byid[serial]['source_rgba_sha256'],source_origin=byid[serial]['source_origin'],source_size=byid[serial]['source_size'],source_footprint=[sx,sy],actual_world_anchor=row['expected_world'],actual_native_tag_instances=row['exact_native_owner_instances'],compiled_field_row=None,compiled_entrance_row=[r for r in entries if r==(x,y,serial)],residual_shore=(x,y,serial)in shores,current_city_projection=projection,whole_bridge_compound=bridge if bridge_role else None,verdict=verdict,reuse_candidate=mesh,production_status='HOLD; read-onlyownership/reuse audit, not art or collision acceptance'))
    assert len(rows)==73 and not any(r['compiled_entrance_row']or r['residual_shore']for r in rows)
    summary=dict(scope='Read-only exact source/world/caller audit. Native tag absence is not itself proof of absent geometry.',counts=dict(rows=len(rows),near_city_roles=sum(r['current_city_projection']['compiled_group']is not None for r in rows),field_roles=sum(r['current_city_projection']['compiled_group']is None for r in rows),matching_city_rows_culled_by_vista=sum(bool(r['current_city_projection']['compiled_rows'])and r['current_city_projection']['parapet_visible']is False for r in rows),existing_whole_bridge_compound_footprints=sum(r['whole_bridge_compound']is not None for r in rows)),rows=rows,inputs={str(p.relative_to(ROOT)):sha(p)for p in[scene_path,archive_path,residual_path,street_path,nature_path]},source_caller_proof=['forest_falan_frontier.gd::complete_field_plan/east_scenery use only field-scenery.json for the enlarged field source rows.','forest_freyja_destination_art.gd::build_archive merges only its compiled Archive/Undersea/Village tables; none of the73exact tuples occur in the two eastern Archive tables.','forest_freyja_residual_art.gd::build draws only167shore rows, all125xx; it cannot own these73flower/mushroom/lamp/parapet tuples.','forest_falan_frontier.gd::city_vista calls CityForts.build with visibility from_city(area,at).y<terrain.bridge_bounds().position.y-9. The current canalbridge starts63, so limit54. Five matching cityparapet rows are at72or farther and are culled.','forest_freyja_art.gd::build separately calls bridge for Rect2(-6,63,18,90); its continuous rails/arches cover all5culled sourceparapet footprints. Keep this compound owner instead of treating missing tags as absence.','The currentSource100toCity1000projectiondelta[-189,-108] differs from the originalwarpdelta[-193,-108]; do not substitute one for originalroute evidence.'],limits=['This staticcaller/compiledrow proof supplements the actual scene census; it does not compare every triangle of arbitrary legacy compound scenery.','No source objects, cityvista, roads, routes, masks, colliders, Native arrays or production assets changed.'])
    (OUT/'older73-owner-ledger.json').write_text(json.dumps(summary,indent=2)+'\n');print(summary['counts'])
if __name__=='__main__':run()
