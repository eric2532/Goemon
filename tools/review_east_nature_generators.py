"""Read-only native graphic dependencies of all68pinned East generator specs."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def run():
    source=ROOT/'assets/maps/falan/east_region/dungeon_specs.gd';specs=json.loads(source.read_text().split('const SPECS=',1)[1]);nature_path=ROOT/'assets/maps/falan/east_region/nature/data.json';nature=json.loads(nature_path.read_text());ids={int(s)for s in nature['graphics']}-{11699}
    rows=[];used=set();matches=set()
    for key,spec in specs.items():
        assert spec.get('east') is True
        static={int(spec['ground'])}|{int(s)for s in spec['stairs']if int(s)<65536}
        fields=('source_wall_graphics','source_fixed_markers','source_entrance_graphics')
        animated=sorted({int(s)for field in fields for s in spec.get(field,[])if int(s)>=65536}|{int(s)for s in spec['stairs']if int(s)>=65536})
        for field in fields:static.update(int(s)for s in spec.get(field,[])if 0<int(s)<65536)
        active=[list(map(int,row)) for row in spec.get('source_decorations',[])if row and 0<int(row[0])<65536 and int(row[1])>0 and int(row[2])>0]
        static.update(row[0]for row in active);hit=sorted(static&ids);used|=static;matches.update(hit)
        runtime=[row for row in active if spec.get('outdoor',False) and (10050<=row[0]<10100 or 11600<=row[0]<11631 or 15067<=row[0]<15082 or 15012<=row[0]<15021)]
        eligible=sorted({row[0]for row in runtime}&ids)
        rows.append(dict(branch=key,config=spec['config'],title=spec['title'],minimum_floors=spec['minimum'],maximum_floors=spec['maximum'],native_static_graphics=sorted(static),animated_markers=animated,active_source_decorations=active,nature_candidates=hit,current_runtime_eligible_nature_ids=eligible,runtime_whitelisted_source_decorations=runtime,scope='Source template dependencies, not a sampled random-map placement count. Runtime decoration whitelist applies only to outdoor blocked edges; source-only15183 is not currently instantiated. Actor/boss graphics are excluded from scenery ownership.'))
    out=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Owned240'
    runtime=ROOT/'scripts/forest/forest_original_dungeons.gd'
    report=dict(generator_count=len(rows),source_specs_sha256=sha(source.read_bytes()),nature_data_sha256=sha(nature_path.read_bytes()),source_generator_sha256=sha(runtime.read_bytes()),native_static_dependency_count=len(used),nature_candidate_ids=sorted(matches),current_runtime_eligible_nature_ids=sorted({s for row in rows for s in row['current_runtime_eligible_nature_ids']}),rows=rows,
        conclusion='No Nature240 static dependency occurs in these68templates; retain the fixed-only group22scope.'if not matches else'Keep generator scope disabled until these exact source dependencies receive a focused generated-layout owner check.',animated_stairs='Native103012 is not a static u16graphic and remains an animated marker, never truncated into a scenery serial.')
    assert len(rows)==68
    (out/'generator-census.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('NATURE_GENERATOR_CENSUS',len(rows),'configs;',len(used),'staticdependencies;',len(matches),'candidate IDs',sorted(matches))
if __name__=='__main__':run()
