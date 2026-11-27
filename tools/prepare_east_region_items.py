"""Publish source item-use programs as inert data for the existing guarded event owner."""
import hashlib
import json
from pathlib import Path

from prepare_east_region_population import compile_script

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit'
OUT=ROOT/'assets/maps/falan/east_region/items.json'


def prepare():
    graph=json.loads((SOURCE/'item-use-graph.json').read_text())
    references={r['path']:r for r in json.loads((SOURCE/'references.json').read_text())}
    items={}
    for original in graph['items']:
        row=dict(original)
        raw=row['raw']; ident=str(row['id']); source_program=row.pop('program',None)
        row.update(id=ident,icon=int(raw[12]),source_itemset_line=row['line'],
                   source_itemset_sha256=graph['source_hashes']['itemset.txt'],program=None)
        if source_program:
            proof=references[source_program['path']]
            source=(SOURCE/proof['file']).read_bytes()
            assert hashlib.sha256(source).hexdigest()==source_program['sha256']==proof['sha256']
            row['program']=compile_script(source)
            row['program']['source_path']=source_program['path']
            row['program']['git_blob']=proof['git_blob']
            row['program']['source_url']=proof['url']
        items[ident]=row
    return dict(schema=1,revision=json.loads((SOURCE/'graph.json').read_text())['revision'],
        source_hashes=graph['source_hashes'],items=items,warp_links=graph['links'],
        missing_programs=graph['missing'],unknown_builtin_handlers=graph['unknown_builtin_handlers'],
        handler=dict(code='IuMs',function='ITEM_useMystery',itemfunc_id=17,
            consumption='Only explicit source KillItem commands are staged; native C handler auto-consumption is unprovided and is not inferred.'),
        limits=['Use requires the held original item and all original script conditions, including source Floor identity.',
                'Item programs reuse the existing event interpreter. Unknown commands/capacity/career/handler state remain explicit blockers.',
                'Item use is not a free portal or a replacement NPC. Source consumption and rewards remain staged until destination preflight.'])


if __name__=='__main__':
    data=prepare();OUT.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('EAST_ITEMS',len(data['items']),'source items;',sum(bool(r['program']) for r in data['items'].values()),'original use programs')
