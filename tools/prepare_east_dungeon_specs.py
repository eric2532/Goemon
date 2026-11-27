"""Prepare original East Gate, Akelufa and Goral random-dungeon contracts."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region'
OUT=ROOT/'assets/maps/falan/east_region/dungeon_specs.gd'
GRAPHS=[REPORT/'Source Audit/graph.json',REPORT/'Akelufa Source Audit/graph.json',REPORT/'Harbor Quest Source Audit/graph.json',REPORT/'Version Expansion Source Audit/graph.json',REPORT/'Verification/Goral Source Audit/inventory.json']
SOURCE=REPORT/'Source Audit/dungeonconf.txt'
OUTDOORS={704,605,803,804,805,806,4096,4101,4102,4103,4104}
INFERRED_OUTDOORS={4096,4103,4104}


def number(row,index,default=0):
    return int(row[index]) if index<len(row) and row[index].strip() else default


def prepare():
    original={}
    for line in SOURCE.read_bytes().decode('gb18030').splitlines():
        row=line.split('\t')
        if not line.startswith('#') and len(row)>100 and row[3].isdigit():original[int(row[3])]=row
    selected={};proof=[]
    for path in GRAPHS:
        graph=json.loads(path.read_text())
        for record in graph['dungeons']:
            row=record['raw'];ident=int(row[3])
            assert row==original[ident],f'Config {ident} differs from the pinned full table'
            if ident in selected:assert selected[ident]==row
            selected[ident]=row
        proof.append(dict(file=str(path.relative_to(ROOT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    specs={}
    for ident,row in sorted(selected.items()):
        ending=list(map(int,row[15:18])) if all(row[15:18]) else []
        template_ids=[number(row,i) for i in range(101,min(len(row),117),2) if number(row,i)>0]
        return_only=not ending and number(row,97)<=0 and number(row,99)<=0 and not template_ids
        blocked='' if ending or return_only else 'The pinned configuration supplies no fixed terminal map; source terminal events must resolve the ending.'
        specs[f'east_{ident}']=dict(first=2_000_000+ident*1000,minimum=int(row[39]),maximum=int(row[40]),size=list(map(int,row[41:45])),
            ground=int(row[22]),stairs=list(map(int,row[34:36])),title=row[0],entry=list(map(int,row[9:12])),end=ending,
            frozen=False,outdoor=ident in OUTDOORS,encounter=int(row[49]),levels=list(map(int,row[50:52])),config=ident,
            entry_rect=list(map(int,row[10:14])),end_rect=list(map(int,row[16:20])) if ending else [],
            return_only=return_only,outdoor_inferred=ident in INFERRED_OUTDOORS,terminal_enemy=number(row,97),terminal_enemy_count=number(row,98),terminal_npc=number(row,99),terminal_placement=number(row,100,-1),
            actor_ids=template_ids,east=True,blocked_end=blocked,
            source_wall_graphics=[number(row,i) for i in range(25,30)],source_fixed_markers=[number(row,30),number(row,31)],source_entrance_graphics=[number(row,32),number(row,33)],
            source_stair_counts=[number(row,36),number(row,37)],source_room_parameters=list(map(int,row[45:49])),
            source_decorations=[[number(row,i+j) for j in range(4)] for i in range(57,97,4)])
    assert specs and len({r['first'] for r in specs.values()})==len(specs)
    for spec in specs.values():
        assert 1<=spec['minimum']<=spec['maximum']<1000
        assert 12<=spec['size'][0]<=spec['size'][1] and 12<=spec['size'][2]<=spec['size'][3]
        assert 0<spec['ground']<65536 and len(spec['stairs'])==2
        assert spec['end'] or spec['blocked_end'] or spec['return_only']
    text='extends RefCounted\n## Pinned source contracts; geometry uses the existing seeded room-graph adaptation.\nconst SPECS='+json.dumps(specs,ensure_ascii=False,indent=1)+'\n'
    evidence=dict(source=str(SOURCE.relative_to(ROOT)),source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),audits=proof,specs=specs,
        configs=len(specs),minimum_floors=sum(s['minimum'] for s in specs.values()),maximum_floors=sum(s['maximum'] for s in specs.values()),
        blocked_endpoints=[dict(config=s['config'],reason=s['blocked_end']) for s in specs.values() if s['blocked_end']],
        limits=['Floor counts, dimension ranges, native ground/stair identities, entry rectangles and endpoint maps are copied exactly.',
                'The pinned repository supplies dungeon data but no original random-map generator implementation. The shared Goemon room graph and physical depths are inferred adaptations.',
                'One ascent and one descent per floor are provided by the existing generator. Source generation flags and stair-count fields are preserved, but extra procedural exits are not invented.',
                'Animated stair code 103012 is preserved in specs; it must use an animated world marker, never a truncated 16-bit static graphic.',
                'Config4096 has neither a fixed end nor terminal/template actors; its return-only last-floor realization is not missing source. Roofless4096/4103/4104 depth is inferred from forest/mountain source context and matching terrain.',
                'Config 102 has no fixed end map. Its terminal enemy/event contract is retained, and the last floor has a return path until source ending behavior is implemented.'])
    return text,evidence


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    text,evidence=prepare();report=REPORT/'dungeon-specs.json';serialized=json.dumps(evidence,ensure_ascii=False,indent=2)+'\n'
    if args.check:
        assert OUT.read_text()==text,'East dungeon specs are stale'
        assert report.read_text()==serialized,'East dungeon source evidence is stale'
    else:
        OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(text);report.write_text(serialized)
    print('EAST_DUNGEON_SPECS',evidence['configs'],'configs',evidence['minimum_floors'],evidence['maximum_floors'],'floors; blocked ends',len(evidence['blocked_endpoints']))


if __name__=='__main__':main()
