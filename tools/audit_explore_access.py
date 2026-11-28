#!/usr/bin/env python3
"""Inventory prepared Explore geography and explicit source-script transfers.

This is a source inventory, never evidence that a player traversed a route.
"""
import csv
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/Other Files/Asset Toolkit/Explore Access"
ROUTES = ROOT / "assets/maps/falan/explore-access.json"
CATALOGS = [
    "assets/maps/original_crossgate/catalog.json",
    "assets/maps/falan/sokia/fixed/catalog.json",
    "assets/maps/original_crossgate/university/catalog.json",
    "assets/maps/original_crossgate/elsa/catalog.json",
    "assets/maps/original_crossgate/east/catalog.json",
    "assets/maps/original_crossgate/sokia_server/catalog.json",
    "assets/maps/original_crossgate/sokia_server/water/catalog.json",
    "assets/maps/original_crossgate/freyja_trial/catalog.json",
    "assets/maps/original_crossgate/sokia_wind_tower/catalog.json",
    "assets/maps/original_crossgate/sokia_desert_temple/catalog.json",
    "assets/maps/original_crossgate/sokia_dragon_summit/catalog.json",
    "assets/maps/falan/sokia/cape/access/catalog.json",
    "assets/maps/falan/black_prayer/events/return-maps/catalog.json",
    "assets/maps/original_crossgate/explore_recovered/catalog.json",
]
EVENTS = [
    "assets/maps/falan/east_region/population.json",
    "assets/maps/falan/black_prayer/events/data.json",
    "assets/maps/falan/sokia/cape/access/events/data.json",
    *[str(p.relative_to(ROOT)) for p in sorted((ROOT / "assets/maps/original_crossgate").glob("*/events/data.json"))],
    "assets/maps/original_crossgate/sokia_server/water/events/data.json",
]


def housing_routes():
    path = ROOT / 'assets/references/crossgate_tina/events/houseroom.txt'
    payload = path.read_bytes()
    assert hashlib.sha1(b'blob ' + str(len(payload)).encode() + b'\0' + payload).hexdigest() == '5a333361422da4200b5c6c56c6b7d8ef60928096'
    houses = {int(row[0]): list(map(int, row[:11])) for line in payload.decode('gb18030').splitlines()
              if (row := line.split()) and not line.startswith('#')}
    result = []
    for line in (path.parent / 'npc.txt').read_bytes().decode('gb18030').splitlines():
        raw = line.split('\t')
        if len(raw) != 25 or raw[0] != 'HouseWarp2' or raw[6] != '1':
            continue
        fields = raw[24].split('|')
        mode, key = map(int, fields[:2]); house = houses[key]
        assert mode == house[1], (raw[3], house)
        # Source999 has three unowned setup-room aliases, outside the recorded housing frontage.
        if int(raw[8]) != house[4]:
            assert mode == 0 and int(raw[8]) == 999, (raw[3], house)
            continue
        result.append(dict(actor=raw[3], type='HouseWarp2', name=raw[1], source=int(raw[8]),
                           cell=list(map(int, raw[9:11])), target=house[2], landing=house[7:9],
                           evidence=str(path.relative_to(ROOT)), script=raw[24], victory_only=False,
                           qualification='Explore visits the pinned original room template; no property, home or quest state is changed.'))
    return result


# The same no-ticket return is explicit in pinned col14/16/32. Keep original bytes;
# only these authenticated Explore routes repair the decimal/comma typo on line13.
ARENA_RETURN_REPAIRS={
    'f6edacedf000719a8135ad4313e88a5acd583700272e55c436d65a96c6a05527':'EV_miz_col27.txt',
    'b300696c7fa091e31dda1f22275da6a5efd9cd850d3bcbdd52d5644625c594e5':'EV_miz_col40.txt',
    '7d86c142647515134da61efb7b256c8c0cee7fab7c2851905e9f4fbd745ca0bd':'EV_miz_col53.txt',
}


def arena_return_repair(program,number,text):
    if program.get('sha256')in ARENA_RETURN_REPAIRS and number==13 and text.strip()=='Warp 0,1496.15,7':
        return dict(script=ARENA_RETURN_REPAIRS[program['sha256']],sha256=program['sha256'],line=13,
                    original=text,explore_command='Warp 0,1496,15,7',
                    corroboration='EV_miz_col14.txt:13, EV_miz_col16.txt:13, EV_miz_col32.txt:13; same Item18256==0 branch')
    return None


def script_warps(program):
    lines = program.get('lines', []) or [line for block in program.get('blocks', []) for line in block.get('lines', [])]
    result = []
    for number, text in lines:
        repair=arena_return_repair(program,number,text)
        if repair:text=repair['explore_command']
        match = re.match(r'\s*Warp\s+(.+)', text, re.I)
        if not match:continue
        fields = match[1].split('#', 1)[0].strip().split(',')
        if len(fields) % 4 or not all(re.fullmatch(r'-?\d+', value.strip()) for value in fields):continue
        values = list(map(int, fields))
        result.extend(tuple(values[i:i+4]) for i in range(0,len(values),4) if values[i]==0 and values[i+1]>0)
    return result


def transfers(actor, scripts):
    result = []
    if actor.get("type", "").lower() == "warp":
        fields = actor.get("script", "").split("|")
        if len(fields) >= 4 and all(re.fullmatch(r"-?\d+", x) for x in fields[:4]):
            result.append(tuple(map(int, fields[:4])))
    script = scripts.get(actor.get("script", ""), {})
    lines = script.get("lines", [])
    if not lines:
        lines = [line for block in script.get("blocks", []) for line in block.get("lines", [])]
    declarations = [actor.get('script', '')] if actor.get('type', '').lower() == 'standenemy' else []
    declarations += [re.sub(r'^\s*Encount\s+', '', text, flags=re.I) for _, text in lines if re.match(r'\s*Encount\b', text, re.I)]
    for declaration in declarations:
        fields = declaration.split('|')
        win = fields[1].strip().split(',') if len(fields) > 1 else []
        if len(win) == 4 and all(re.fullmatch(r'-?\d+', x.strip()) for x in win):
            result.append(tuple(int(x.strip()) for x in win))
    result.extend(script_warps(script))
    return sorted(set(row for row in result if row[0] == 0 and row[1] > 0))


def active_source_events():
    """Required original events omitted by older regional actor selections."""
    from prepare_east_region_population import compile_script
    prepared = set()
    for path in EVENTS:
        actors = json.loads((ROOT / path).read_text()).get('actors', [])
        prepared.update((int(row['source']), str(row['id'])) for row in (actors.values() if isinstance(actors, dict) else actors))
    sources = {int(row['id']) for path in CATALOGS for row in json.loads((ROOT / path).read_text())['maps'].values()}
    inventory = OUT / 'runtime-inventory.json'
    if inventory.exists():
        runtime = json.loads(inventory.read_text())
        sources.update(int(row['source']) for row in runtime['maps'] if row['available_source'])
        sources.update(map(int, runtime['known_sources']))
    sources.update([100,300,1000,1500,2000,2100,2300,2400,3000,3200])
    folder = ROOT / 'assets/references/crossgate_sokia/events'
    pins = {row['file']: row for name in ['references.json','explore-extra-references.json','frontier-references.json']
            for row in json.loads((folder / name).read_text())}
    table = ROOT / 'assets/references/crossgate_tina/events/npc.txt'
    proof = next(row for row in json.loads((table.parent / 'references.json').read_text()) if row['file']=='npc.txt')
    assert hashlib.sha256(table.read_bytes()).hexdigest() == proof['sha256']
    actors = {}; scripts = {}; programs = {}; messages = {}; automatic = []
    original_messages = {row[0]: row[1].replace('\\n','\n') for line in (table.parent/'msg.txt').read_bytes().decode('gb18030').splitlines()
                         if not line.startswith('#') and len(row := line.split('\t')) > 1}
    for number, line in enumerate(table.read_bytes().decode('gb18030').splitlines(), 1):
        raw = line.split('\t')
        if line.startswith('#') or len(raw)!=25 or raw[6]!='1' or not raw[8].isdigit() or int(raw[8])not in sources:continue
        source = int(raw[8]); ident = raw[3]; name = raw[24]
        file_script=name.endswith('.txt'); inline_warp=raw[0].lower()=='warp'; inline_fight=raw[0].lower()=='standenemy'
        if (source,ident)in prepared or not(file_script or inline_warp or inline_fight)or file_script and name not in pins:continue
        if file_script and name not in programs:
            payload = (folder/name).read_bytes()
            assert hashlib.sha256(payload).hexdigest()==pins[name]['sha256'], name
            programs[name] = compile_script(payload)
        program = programs[name]if file_script else {'lines':[]}
        actor = dict(id=ident, type=raw[0], name=raw[1], source=source, cell=list(map(int,raw[9:11])), script=name,
                     raw=raw, source_line=number, quest_action='east_event:'+ident, dialogue_owner='explore_source',
                     graphic=int(raw[20]or 0), source_provenance=pins[name]if file_script else proof)
        if inline_warp:actor['explore_inline']=True
        fights = [name] if inline_fight else [text for _,text in program['lines'] if re.match(r'\s*Encount\b',text,re.I)]
        if not transfers(actor,{name:program}) and not fights:continue
        actor['explore_fight']=bool(fights)
        key=f'{source}:{ident}'
        if key in actors:
            assert actors[key]['raw']==raw, ('Conflicting original actor identity',key)
            continue
        if source==1000 and ident in {'5000','5001','5002','5003','5004','5005'}:actor['access_owner']='falan_travel_stones'
        actors[key]=actor
        if file_script:scripts[name]=program
        # These source roles already belong to a regional/native encounter.
        owner={(400,'12023'):'regional:zombie',(16520,'12009'):'regional:lizard',(23001,'11009'):'falken_slot',(24068,'12008'):'frostpass_slot'}.get((source,name.split('|')[9])) if inline_fight else None
        if owner:actor['battle_owner']=owner
        if source==4100 and ident=='5255':
            east=json.loads((ROOT/'assets/maps/falan/east_region/population.json').read_text())['art']['14546:0']
            original=json.loads((ROOT/'assets/maps/falan/university_region/population.json').read_text())['art']['14546:6']
            assert east['key']==original['key']=='graphic:14546'and east['rgba_sha256']==original['rgba_sha256']
            actor.update(explore_npc=True,direction=int(raw[19]),token='14546:6',art_reuse='14546:0',
                         art_rgba_sha256=original['rgba_sha256'],generated_by=None,invisible=False,native_enemy=False,scenery=False,
                         messages=[original_messages['21182']])
        if inline_fight and not owner:
            automatic.append(dict(actor=ident,source=source,type=actor['type'],bounds=[*actor['cell'],*actor['cell']],
                                  cooldown_ms=60000,source_line=number))
        if fights and actor['type']in ['WatchEvent','WatchEx']:
            from prepare_east_region_routes import trigger_bounds
            automatic.append(dict(actor=ident,source=source,type=actor['type'],bounds=trigger_bounds(actor,program),
                                  cooldown_ms=max(750,int(raw[18]or 0)),source_line=number))
        for _,text in program['lines']:
            match=re.match(r'\s*(?:End)?Window\s+(\d+)',text,re.I)
            if match and str(int(match[1]))in original_messages:
                mid=str(int(match[1]));messages[mid]=original_messages[mid]
    return dict(actors=actors,scripts=scripts,messages=messages,automatic=automatic,bank_sources=sorted({a['source']for a in actors.values()if a['type'].lower()=='standenemy'and not a.get('battle_owner')}))


def source_layout_complete(row):
    if 'layout_complete' in row:
        return row['layout_complete']
    # Restored-cell counts omit already-empty cells; the authenticated full-map comparison is the completion proof.
    if row.get('restored_raw') and row.get('completion_reference') and row.get('reference_compared_cells') == row.get('recorded'):
        return True
    return row.get('recorded', 0) == row.get('cells', -1)


def build(supplement=None):
    maps, routes, bosses = {}, {}, []
    for path in CATALOGS:
        data = json.loads((ROOT / path).read_text())
        for row in list(data["maps"].values()) + list(data.get('layout_overrides', {}).values()):
            source = int(row["id"])
            maps[source] = {
                "map": source, "name": row.get("title", ""), "catalog": path,
                "layout_complete": source_layout_complete(row),
                "staged": row.get("sokia_visual_only", False),
                "entrances": [], "npc_fixes": [], "bosses": [],
                "walk_interact_enter_leave": "PENDING", "boss_portal_retry": "PENDING",
            }
    seen = set()
    if supplement is None:supplement=active_source_events()
    payloads=[(path,json.loads((ROOT/path).read_text()))for path in EVENTS]
    payloads.append(("assets/references/crossgate_tina/events/npc.txt",supplement))
    for path,data in payloads:
        actors = data.get("actors", [])
        if isinstance(actors, dict):
            actors = actors.values()
        for actor in actors:
            source = int(actor["source"])
            for _, target, x, y in transfers(actor, data.get("scripts", {})):
                cell = list(map(int, actor["cell"]))
                key = (source, *cell, target, x, y)
                if key in seen:
                    continue
                seen.add(key)
                row = {"actor": str(actor["id"]), "type": actor.get("type", ""), "name": actor.get("name", ""), "source": source, "cell": cell,
                       "target": target, "landing": [x, y], "evidence": path, "script": actor.get("script", "")}
                if actor.get("access_owner"):row["access_owner"]=actor["access_owner"]
                if actor.get("explore_inline"):row["explore_inline"]=True
                program = data.get('scripts', {}).get(actor.get('script', ''), {})
                commands = program.get('lines', []) or [line for block in program.get('blocks', []) for line in block.get('lines', [])]
                direct_warp = (0,target,x,y) in script_warps(program)
                row['victory_only'] = actor.get('type', '').lower() != 'warp' and not direct_warp
                for number,text in commands:
                    repair=arena_return_repair(program,number,text)
                    if repair and (target,x,y)==(1496,15,7):row['source_repair']=repair
                routes.setdefault(str(source), []).append(row)
                if source in maps:
                    maps[source]["entrances"].append(row)
            text = actor.get("script", "")
            script = data.get("scripts", {}).get(text, {})
            lines = script.get("lines", []) or [line for block in script.get("blocks", []) for line in block.get("lines", [])]
            fights = [text] if actor.get("type", "").lower() == "standenemy" else [t for _, t in lines if re.match(r"\s*Encount\b", t, re.I)]
            if fights:
                boss = {"actor": str(actor["id"]), "source": source, "cell": actor["cell"], "name": actor.get("name", ""), "declarations": fights, "evidence": path, "visible_approach_defeat_portal_retry": "PENDING"}
                bosses.append(boss)
                if source in maps:
                    maps[source]["bosses"].append(boss)
    recovered = json.loads((ROOT / 'assets/maps/original_crossgate/explore_recovered/catalog.json').read_text())
    recovered_ids = {int(row['id']) for row in recovered['maps'].values()}
    original_path = 'assets/maps/original_crossgate/catalog.json'
    for source, cx, cy, target, x, y in json.loads((ROOT / original_path).read_text())['warps']:
        if target not in recovered_ids:
            continue
        key = (source, cx, cy, target, x, y)
        if key in seen:
            continue
        seen.add(key)
        row = dict(actor=f'recovered-door:{source}:{cx}:{cy}:{target}', type='Recovered original door',
                   name=next(m['title'] for m in recovered['maps'].values() if int(m['id']) == target),
                   source=source, cell=[cx, cy], target=target, landing=[x, y], evidence=original_path, script='')
        routes.setdefault(str(source), []).append(row)
        if source in maps:
            maps[source]['entrances'].append(row)
    for row in housing_routes():
        key = (row['source'], *row['cell'], row['target'], *row['landing'])
        if key in seen:
            continue
        seen.add(key)
        routes.setdefault(str(row['source']), []).append(row)
        if row['source'] in maps:
            maps[row['source']]['entrances'].append(row)
    return maps, routes, bosses


def main():
    supplement=active_source_events()
    maps, routes, bosses = build(supplement)
    OUT.mkdir(parents=True, exist_ok=True)
    by_source = {}
    for boss in bosses:
        by_source.setdefault(str(boss["source"]), []).append(boss)
    ROUTES.write_text(json.dumps({"schema": 1, "routes": routes, "bosses": by_source, "source_events": supplement}, ensure_ascii=False, indent=1) + "\n")
    inventory = {"qualification": "Source census only. PENDING is not reachable/verified. Includes preserved maps outside the normal Explore graph.", "maps": list(maps.values()), "scripted_fights": bosses}
    (OUT / "map-checklist.json").write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + "\n")
    with (OUT / "map-checklist.csv").open("w") as f:
        writer = csv.writer(f)
        writer.writerow(["source map", "name", "staged", "layout complete", "script entrances", "script fights", "walk/interact/enter/leave", "boss/portal/retry"])
        for source, row in sorted(maps.items()):
            writer.writerow([source, row["name"], row["staged"], row["layout_complete"], len(row["entrances"]), len(row["bosses"]), row["walk_interact_enter_leave"], row["boss_portal_retry"]])
    print(f"{len(maps)} source maps; {sum(map(len, routes.values()))} explicit transfers; {len(bosses)} fight declarations. Traversal verification pending.")


if __name__ == "__main__":
    main()
