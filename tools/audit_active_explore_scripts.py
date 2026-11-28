"""Find unprepared transfers/fights in enabled scripts of available Explore owners."""
import hashlib
import json
from pathlib import Path
import re

from audit_explore_access import EVENTS, transfers, script_warps
from prepare_east_region_population import compile_script

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/Explore Access'
SOURCE = ROOT / 'assets/references/crossgate_sokia/events'


def main():
    inventory = json.loads((OUT / 'runtime-inventory.json').read_text())
    available = {int(row['source']) for row in inventory['maps'] if row['available_source']}
    available.update(map(int, inventory['known_sources']))
    available.update([100,300,1000,1500,2000,2100,2300,2400,3000,3200])
    prepared = set(); prepared_fights = set()
    catalog = json.loads((ROOT / 'assets/maps/falan/explore-access.json').read_text())
    route_keys = {(int(row['source']), *map(int, row['cell']), int(row['target']), *map(int,row['landing']))
                  for rows in catalog['routes'].values() for row in rows}
    for path in EVENTS:
        data = json.loads((ROOT / path).read_text()); actors = data.get('actors', [])
        for actor in actors.values() if isinstance(actors, dict) else actors:
            prepared.add((int(actor['source']), str(actor['id'])))
    prepared.update((int(actor['source']),str(actor['id']))for actor in catalog.get('source_events',{}).get('actors',{}).values())
    for rows in catalog['bosses'].values():
        prepared_fights.update((int(row['source']), str(row['actor'])) for row in rows)
    pins = {}
    for name in ['references.json','explore-extra-references.json','frontier-references.json']:
        pins.update({row['file']: row for row in json.loads((SOURCE/name).read_text())})
    scripts = {}; blockers = []; required = []; other_warps = []
    for line in (ROOT / 'assets/references/crossgate_tina/events/npc.txt').read_bytes().decode('gb18030').splitlines():
        raw = line.split('\t')
        if line.startswith('#')or len(raw)!=25 or raw[6]!='1' or not raw[8].isdigit() or int(raw[8])not in available or not(raw[24].endswith('.txt')or raw[0].lower()in ['warp','standenemy']):continue
        actor = dict(id=raw[3], source=int(raw[8]), type=raw[0], name=raw[1], cell=list(map(int,raw[9:11])), script=raw[24], raw=raw)
        name = actor['script']
        if not name.endswith('.txt'):program={'lines':[]}
        elif name not in scripts:
            if name not in pins or not (SOURCE/name).exists():
                scripts[name] = None
            else:
                payload=(SOURCE/name).read_bytes()
                assert hashlib.sha256(payload).hexdigest()==pins[name]['sha256'], name
                try:scripts[name]=compile_script(payload)
                except UnicodeDecodeError as error:scripts[name]=dict(decode_blocker=str(error))
        if name.endswith('.txt'):program=scripts[name]
        if program is None or 'decode_blocker' in program:
            blockers.append(dict(actor=actor['id'],source=actor['source'],script=name,reason='Pinned original script unavailable'if program is None else program['decode_blocker']));continue
        missing = []
        for _, target, x, y in transfers(actor,{name:program}):
            key=(actor['source'],*actor['cell'],target,x,y)
            if key not in route_keys:missing.append(dict(target=target,landing=[x,y]))
        fights=[actor['script']]if actor['type'].lower()=='standenemy'else[text for _,text in program['lines']if re.match(r'\s*Encount\b',text,re.I)]
        if missing or fights and (actor['source'],actor['id'])not in prepared_fights:
            required.append(dict(actor, prepared_actor=(actor['source'],actor['id'])in prepared, missing_transfers=missing, unprepared_fights=fights if (actor['source'],actor['id'])not in prepared_fights else []))
        for number,text in program['lines']:
            if re.match(r'\s*Warp\b',text,re.I)and not script_warps({'sha256':program.get('sha256'),'lines':[[number,text]]}):
                other_warps.append(dict(source=actor['source'],actor=actor['id'],script=name,line=number,command=text))
    report=dict(qualification='Pinned active-source command audit only. Published declarations do not prove reachable entrance placement, battle completion or normal-play traversal.',
                scripts=len(scripts),required_actors=required,script_blockers=blockers,other_warps=other_warps)
    (OUT/'active-script-access-gaps.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('EXPLORE_ACTIVE_SCRIPT_GAPS',len(scripts),'scripts;',len(required),'actors with missing transfers/fights;',len(other_warps),'other Warp commands;',len(blockers),'script blockers')


if __name__=='__main__':main()
