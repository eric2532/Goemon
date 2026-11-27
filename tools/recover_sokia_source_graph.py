"""Recover scoped, pinned source evidence; never modify game data or claim execution."""
from concurrent.futures import ThreadPoolExecutor
from collections import Counter
from pathlib import Path
import hashlib
import json
import re
import subprocess
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Source events'
COMMIT = 'dd8690ed3df11e4eb5a038a54079a8f40d8e93b3'
REMOTE = f'https://raw.githubusercontent.com/linv2/Crossgate_Docker/{COMMIT}/gmsv/data/'
SOURCE = ROOT / 'assets/references/crossgate_tina/events'
DURABLE = ROOT / 'assets/references/crossgate_sokia/events'
SCRIPT = re.compile(r'(?<![\w./-])([A-Za-z0-9_-]+\.txt)', re.I)
NUMBER = re.compile(r'^-?\d+$')
TREE_PINS = DURABLE / 'git-tree-pins.json'


def source_blob_matches(name, data):
    if not TREE_PINS.exists():
        return True
    pins = json.loads(TREE_PINS.read_text())
    assert pins['commit']==COMMIT
    path='gmsv/data/'+('' if name=='dungeonconf.txt' else 'npc/')+name
    expected=pins['blobs'].get(path)
    return expected is None or hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==expected['sha']


def digest(data):
    return hashlib.sha256(data).hexdigest()


def rows(data):
    return [r.split('\t') for r in data.decode('gb18030', errors='replace').splitlines()
            if r and not r.startswith('#')]


def write_json(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def publish_sources(proofs):
    DURABLE.mkdir(parents=True,exist_ok=True)
    repair_path=DURABLE/'raw-byte-repair.json'
    repaired={row['file'] for row in json.loads(repair_path.read_text())['records']} if repair_path.exists() else set()
    for proof in proofs:
        raw=(OUT/proof['file']).read_bytes()
        assert digest(raw)==proof['sha256']
        assert source_blob_matches(proof['file'],raw),'Source differs from pinned Git tree: '+proof['file']
        blob=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
        if proof.get('git_blob'):assert proof['git_blob']==blob
        target=DURABLE/proof['file']
        if target.exists():assert target.read_bytes()==raw,'Preserved source differs: '+str(target)
        else:target.write_bytes(raw)
        proof.update(git_blob=blob,path='gmsv/data/'+(''if proof['file']=='dungeonconf.txt'else'npc/')+proof['file'],
                     durable_path=str(target.relative_to(ROOT)))
        if proof['file'] in repaired:proof['raw_byte_repair_evidence']=str(repair_path.relative_to(ROOT))
    (DURABLE/'references.json').write_text(json.dumps(sorted(proofs,key=lambda p:p['file']),ensure_ascii=False,indent=2)+'\n')


def local_pinned():
    paths = subprocess.check_output(['rg', '--files', 'assets/references',
                                    'build/Other Files/Asset Toolkit'], cwd=ROOT).decode().splitlines()
    found = {}
    for name in paths:
        if not name.endswith('references.json') or 'Sokia Venoa Coverage/Source events/' in name:
            continue
        path = ROOT / name
        try:
            records = json.loads(path.read_text())
        except (ValueError, OSError):
            continue
        if not isinstance(records, list):
            continue
        for record in records:
            if not isinstance(record, dict) or COMMIT not in record.get('url', ''):
                continue
            candidate = path.parent / record.get('file', '')
            if candidate.is_file() and digest(candidate.read_bytes()) == record.get('sha256') and source_blob_matches(candidate.name,candidate.read_bytes()):
                found[candidate.name] = (candidate, record)
    return found


def source_text(data):
    # ASCII commands are authoritative here. Original comments can already be mojibake.
    return data.decode('gb18030', errors='replace')


def commands(data):
    block = None
    branch = []
    for line_number, line in enumerate(source_text(data).splitlines(), 1):
        clean = line.strip()
        if not clean or clean.startswith('#'):
            continue
        word = clean.split()[0].lower()
        if word == 'block':
            block = clean
            branch = []
        elif word.startswith('window_'):
            branch.append(clean)
        if word in ['warp', 'encount', 'battle', 'battlein', 'battleout', 'endbattle', 'startbattle'] or 'battle' in word:
            yield dict(line=line_number, text=clean, block=block, branch_context=branch[-8:],
                       interpretation='lexical command evidence; condition execution unverified')


def warp_candidates(command):
    values=list(map(int,re.findall(r'-?\d+',command)))
    if not values or len(values)%4:return []
    return [dict(dimension=values[i],target_map=values[i+1],arrival=values[i+2:i+4])
            for i in range(0,len(values),4)]


def fight_parameters(parameters, encounters):
    fields = parameters.split('|')
    declared = [int(v) for v in fields[9].split(',') if v.isdigit()] if len(fields) > 9 else []
    resolved = []
    pending = list(declared)
    seen = set()
    while pending:
        number = pending.pop(0)
        if number in seen:
            continue
        seen.add(number)
        raw = encounters.get(str(number))
        choices = [[gid, int(raw[24+i] or 0)] for i, gid in enumerate(raw[14:24])
                   if gid and int(raw[24+i] or 0)] if raw else []
        resolved.append(dict(encounter_id=number, raw=raw, groups=choices,
                             origin='declared' if number in declared else 'linked_encounter_fields_12_13',
                             status='source_row_resolved' if raw else 'missing_source_encounter_row'))
        if raw and raw[12].isdigit() and int(raw[12]) > 0 and int(raw[13] or 0) > 0:
            pending.append(int(raw[12]))
    return dict(encounter_id=declared[0] if len(declared) == 1 else None,
                declared_encounter_ids=declared, resolved_encounters=resolved,
                resolved_group_ids=sorted({gid for row in resolved for gid, _ in row['groups']}, key=int),
                post_battle_warp=fields[1] if len(fields) > 1 else None,
                namespace='encount operand -> encount.txt ID -> weighted group.txt IDs')


def related_enemies(initial_ids, enemies, bases):
    pending = sorted(initial_ids, key=int)
    seen = set()
    edges = []
    records = {}
    while pending:
        ident = pending.pop()
        if ident in seen:
            continue
        seen.add(ident)
        raw = enemies.get(ident, [])
        for column in (45, 46):
            target = raw[column] if len(raw) > column else ''
            if target in ('', '0', '-1'):
                continue
            edges.append(dict(enemy=ident, field=column, target=target,
                              status='reference_reader_summon_field; trigger_semantics_unverified'))
            enemy = enemies.get(target)
            base = bases.get(enemy[3]) if enemy else None
            records[target] = dict(enemy_id=target, enemy_raw=enemy, base_raw=base,
                                   appearance=int(base[30]) if base else None,
                                   levels=list(map(int,enemy[4:6])) if enemy else None,
                                   count=list(map(int,enemy[6:8])) if enemy else None,
                                   status='source_identity_retained; native_summon_or_phase_rule_unverified')
            pending.append(target)
    return dict(edges=edges, enemies=records)


def generated_templates(configs, maps):
    """CDungeonReader slots101–116; preserve duplicate template references and refresh operands."""
    result = []
    for raw in configs:
        if not any(len(raw)>i and raw[i].isdigit() and int(raw[i]) in maps for i in (9,15)):
            continue
        for slot in range(8):
            offset = 101 + slot * 2
            if len(raw)>offset+1 and raw[offset].isdigit() and int(raw[offset])>0:
                result.append(dict(config=int(raw[3]), slot=slot, npc=raw[offset],
                                   refresh=int(raw[offset+1] or 0), field=offset))
    return result


def main():
    coverage = json.loads((OUT.parent / 'coverage.json').read_text())
    previous = json.loads((OUT / 'source-graph.json').read_text()) if (OUT / 'source-graph.json').exists() else {}
    initial_maps = set(previous.get('initial_maps', [r['map'] for r in coverage['maps']]))
    npc_bytes = (SOURCE / 'npc.txt').read_bytes()
    npc_rows = rows(npc_bytes)
    regional = [r for r in npc_rows if len(r) > 24 and r[8].isdigit() and int(r[8]) in initial_maps]
    pinned = local_pinned()
    proofs = []
    failed = []
    scripts = {}
    queued = {name for r in regional for name in SCRIPT.findall(r[24])}
    queued.update(r['script'] for r in coverage['event_scripts'] if SCRIPT.fullmatch(r['script']))

    def fetch(name):
        target = OUT / name
        url = REMOTE + 'npc/' + name
        if name in pinned:
            path, proof = pinned[name]
            data = path.read_bytes()
            acquired = 'existing_sha_pinned_copy'
            origin = str(path.relative_to(ROOT))
            url = proof['url']
        elif target.exists() and (OUT / 'references.json').exists():
            previous = {p['file']: p for p in json.loads((OUT / 'references.json').read_text())}
            proof = previous.get(name)
            data = target.read_bytes()
            if proof and proof.get('commit') == COMMIT and proof['sha256'] == digest(data) and source_blob_matches(name,data):
                return name, data, proof
            raise AssertionError('Unverified pre-existing file: ' + name)
        else:
            try:
                data = urllib.request.urlopen(url, timeout=25).read()
            except (urllib.error.URLError, TimeoutError) as error:
                return name, None, dict(file=name, url=url, error=str(error))
            acquired = 'pinned_primary_raw_download'
            origin = None
        assert source_blob_matches(name,data),'Source bytes differ from pinned Git blob: '+name
        target.write_bytes(data)
        return name, data, dict(file=name, commit=COMMIT, url=url, sha256=digest(data),
                               bytes=len(data), acquired=acquired, local_origin=origin,
                               authority='CGMSV pinned reference; target BlueCG execution unverified')

    while queued:
        batch = sorted(queued - scripts.keys() - {r['file'] for r in failed})
        if not batch:
            break
        print('Recovering', len(batch), 'scoped scripts', flush=True)
        with ThreadPoolExecutor(max_workers=8) as pool:
            for name, data, proof in pool.map(fetch, batch):
                if data is None:
                    failed.append(proof)
                    continue
                scripts[name] = data
                proofs.append(proof)
        queued = {name for data in scripts.values() for name in SCRIPT.findall(source_text(data))}

    # The exact pinned dungeon configuration is needed for generated-floor identities.
    conf_name = 'dungeonconf.txt'
    conf_url = REMOTE + conf_name
    try:
        conf = pinned[conf_name][0].read_bytes() if conf_name in pinned else urllib.request.urlopen(conf_url, timeout=30).read()
        (OUT / conf_name).write_bytes(conf)
        proofs.append(dict(file=conf_name, commit=COMMIT, url=conf_url, sha256=digest(conf),
                           bytes=len(conf), acquired='pinned_primary_raw_download'))
    except (urllib.error.URLError, TimeoutError) as error:
        raise RuntimeError('Required pinned dungeon configuration is unavailable') from error

    import sys
    sys.path.insert(0, str(ROOT / 'tools'))
    from build_freyja_destinations import warp_rows
    all_fixed = list(warp_rows(ROOT.parent / 'Magic Power'))
    conf_rows = rows(conf)
    scope_maps = set(initial_maps)
    # These are documented different regional owners, not evidence that a link is absent.
    boundaries = {777:'Generated NPC/encounter template marker, not a geographic map',
                  1000:'Falan city', 200:'different outdoor region', 400:'Shalena outdoor',
                  401:'Shalena outdoor', 402:'Shalena outdoor', 2000:'Il village / separate regional goal',
                  2300:'Laruka / separate regional goal', 2400:'Alyut / separate regional goal',
                  4000:'Jenova / separate regional goal',4100:'Astia boundary',4200:'Tina',
                  4201:'Tina night',4300:'Abanis',4400:'University',15000:'Shalena sea cave boundary'}
    def regional_target(target):
        return target not in boundaries and not 1000 <= target < 2000 and 0 < target < 30000
    while True:
        regional = [r for r in npc_rows if len(r)>24 and r[8].isdigit() and int(r[8]) in scope_maps]
        template_refs = generated_templates(conf_rows, scope_maps)
        template_ids = {row['npc'] for row in template_refs}
        effective = regional + [r for r in npc_rows if len(r)>24 and r[3] in template_ids and r not in regional]
        queued={name for r in effective for name in SCRIPT.findall(r[24])}-scripts.keys()-{r['file'] for r in failed}
        while queued:
            with ThreadPoolExecutor(max_workers=8) as pool:
                for name,data,proof in pool.map(fetch,sorted(queued)):
                    if data is None:failed.append(proof)
                    else:scripts[name]=data;proofs.append(proof)
            queued={name for data in scripts.values() for name in SCRIPT.findall(source_text(data))}-scripts.keys()-{r['file'] for r in failed}
        candidates = {b for a,x,y,b,tx,ty in all_fixed if a in scope_maps}
        for r in effective:
            if not r[3].isdigit() or int(r[3])>=300000 or (r[6]!='1' and r[3] not in template_ids):
                continue
            if r[0]=='Warp':
                fields=r[24].split('|')
                for offset in [0,8]:
                    if len(fields)>offset+3 and all(NUMBER.fullmatch(v) for v in fields[offset:offset+4]):
                        candidates.add(int(fields[offset+1]))
            if r[0]=='StandEnemy':
                fields=r[24].split('|')
                post=fields[1].split(',') if len(fields)>1 else []
                if len(post)==4 and all(NUMBER.fullmatch(v) for v in post):candidates.add(int(post[1]))
            for name in SCRIPT.findall(r[24]):
                for command in commands(scripts.get(name,b'')):
                    if command['text'].split()[0].lower()=='warp':
                        candidates.update(v['target_map'] for v in warp_candidates(command['text']))
                    elif command['text'].split()[0].lower()=='encount':
                        fields=command['text'].split(None,1)[1].split('|')
                        if len(fields)>1:candidates.update(v['target_map'] for v in warp_candidates(fields[1]))
        for raw in conf_rows:
            if len(raw)>15 and raw[9].isdigit() and int(raw[9]) in scope_maps and raw[15].isdigit():
                candidates.add(int(raw[15]))
        additions={n for n in candidates if regional_target(n)}-scope_maps
        if not additions:
            break
        scope_maps.update(additions)
        print('Expanding source-only graph to',len(scope_maps),'regional maps',flush=True)

    encounter_rows = rows((SOURCE / 'encount.txt').read_bytes())
    encounters = {r[0]: r for r in encounter_rows}
    encounter_counts = Counter(r[0] for r in encounter_rows)
    duplicate_encounters = {key: [r for r in encounter_rows if r[0] == key]
                            for key, count in encounter_counts.items() if count > 1}
    actors = []
    event_edges = []
    fights = []
    npc_warps = []
    script_commands = {name: list(commands(data)) for name, data in scripts.items()}
    for r in regional:
        actor = dict(type=r[0], id=r[3], name=r[1], map=int(r[8]),
                     cell=[int(r[9]), int(r[10])], active=r[6] == '1',
                     target_release='later_id_requires_corroboration' if int(r[3]) >= 300000
                     else 'pinned_reference_original_candidate_not_authenticated_BlueCG', raw=r)
        actors.append(actor)
        for name in SCRIPT.findall(r[24]):
            for command in script_commands.get(name, []):
                edge = dict(source_map=actor['map'], npc=actor['id'], name=actor['name'],
                            script=name, active=actor['active'], target_release=actor['target_release'], **command)
                if command['text'].split()[0].lower() == 'warp':
                    choices=warp_candidates(command['text'])
                    edge['candidate_destinations']=choices
                    if len(choices)==1:edge.update(choices[0])
                    elif choices:edge['choice_rule']='multiple source destinations; selection semantics unverified'
                    event_edges.append(edge)
                else:
                    if command['text'].split()[0].lower()=='encount':
                        edge.update(fight_parameters(command['text'].split(None,1)[1],encounters))
                    fights.append(edge)
        if r[0] == 'Warp':
            fields = r[24].split('|')
            alternatives=[]
            for offset in [0,8]:
                if len(fields)>offset+3 and all(NUMBER.fullmatch(v) for v in fields[offset:offset+4]):
                    alternatives.append(dict(field_offset=offset,dimension=int(fields[offset]),target_map=int(fields[offset+1]),arrival=list(map(int,fields[offset+2:offset+4]))))
            npc_warps.append(dict(source_map=actor['map'], npc=actor['id'], cell=actor['cell'],
                                  raw_parameters=r[24], primary_target=int(fields[1]) if len(fields) > 1 and fields[1].isdigit() else None,
                                  candidate_alternatives=alternatives,
                                  target_release=actor['target_release'],
                                  rule_status='raw owner parameters retained; time/item alternatives unexecuted'))
        if r[0] == 'StandEnemy':
            fields = r[24].split('|')
            fights.append(dict(source_map=actor['map'], npc=actor['id'], name=actor['name'], cell=actor['cell'],
                               active=actor['active'], target_release=actor['target_release'],
                               kind='StandEnemy', raw_parameters=r[24],
                               **fight_parameters(r[24],encounters),
                               interpretation='declared NPC owner parameters; win/loss/flags semantics require owner verification'))

    generated_actors, generated_fights, generated_warps = [], [], []
    for ident in sorted(template_ids, key=int):
        r = next((r for r in npc_rows if len(r)>24 and r[3]==ident), None)
        refs = [row for row in template_refs if row['npc']==ident]
        actor = dict(npc=ident, references=refs, geographic_map_id=None,
                     status='source_template_retained; original_placement_count_refresh_unverified')
        if r is None:
            actor['missing_template'] = True
            generated_actors.append(actor)
            continue
        actor.update(type=r[0], name=r[1], template_map=int(r[8]), template_cell=list(map(int,r[9:11])), raw=r)
        generated_actors.append(actor)
        common = dict(npc=ident, name=r[1], references=refs, geographic_map_id=None)
        if r[0]=='StandEnemy':
            generated_fights.append(dict(**common, kind='StandEnemy', raw_parameters=r[24],
                                         **fight_parameters(r[24],encounters)))
        for name in SCRIPT.findall(r[24]):
            for command in script_commands.get(name, []):
                word=command['text'].split()[0].lower()
                if word=='warp':
                    generated_warps.append(dict(**common, script=name, **command,
                                                candidate_destinations=warp_candidates(command['text'])))
                elif word=='encount':
                    generated_fights.append(dict(**common, script=name, **command,
                        **fight_parameters(command['text'].split(None,1)[1],encounters)))

    # Fixed ports are a distinct reference from client map bytes and scripts.
    fixed = [dict(source_map=a, cell=[x,y], target_map=b, arrival=[tx,ty],
                  authority='existing pinned fixed-port reference; direction preserved')
             for a,x,y,b,tx,ty in all_fixed if a in scope_maps]
    groups = {r[2]:r for r in rows((SOURCE / 'group.txt').read_bytes())}
    enemies = {r[2]:r for r in rows((SOURCE / 'enemy.txt').read_bytes())}
    bases = {r[1]:r for r in rows((SOURCE / 'enemybase.txt').read_bytes())}
    group_ids = {str(r['group']) for r in fights if r.get('group') is not None}
    group_ids.update(gid for r in fights for gid in r.get('resolved_group_ids',[]))
    group_ids.update(gid for r in generated_fights for gid in r.get('resolved_group_ids',[]))
    for row in encounter_rows:
        if int(row[3]) in scope_maps:
            group_ids.update(gid for i, gid in enumerate(row[14:24]) if gid and int(row[24+i] or 0))
    group_ids.update(str(r['group']) for r in coverage['conditional_groups'])
    numeric_targets = {r['target_map'] for r in fixed + event_edges if 'target_map' in r}
    numeric_targets.update(v['target_map'] for r in event_edges for v in r.get('candidate_destinations',[]))
    numeric_targets.update(a['target_map'] for r in npc_warps for a in r['candidate_alternatives'])
    numeric_targets.update(a['target_map'] for r in generated_warps for a in r['candidate_destinations'])
    for r in fights:
        post=(r.get('post_battle_warp') or '').split(',')
        if len(post)==4 and all(NUMBER.fullmatch(v) for v in post):numeric_targets.add(int(post[1]))
    generated = []
    generated_encounters = []
    encounters = rows((SOURCE/'encount.txt').read_bytes())
    for raw in conf_rows:
        map_fields = [int(raw[i]) for i in [9,15] if len(raw)>i and raw[i].isdigit()]
        if not any(n in scope_maps for n in map_fields):continue
        config=dict(name=raw[0],config=int(raw[3]),raw=raw,map_fields_9_15=map_fields,
                    floor_range=list(map(int,raw[39:41])),encounter=int(raw[49]),levels=list(map(int,raw[50:52])),
                    entry=list(map(int,raw[9:12])),end=list(map(int,raw[15:18])) if all(raw[15:18]) else [],
                    schema_basis='Existing prepare_university_dungeon_specs.py and prepare_east_dungeon_specs.py',
                    field_semantics='Data schema reused; original random generator execution unavailable')
        generated.append(config)
        for z in encounters:
            if z[0]!=raw[49]:continue
            generated_encounters.append(dict(config=config['config'],encounter_id=int(z[0]),raw=z))
            for i,gid in enumerate(z[14:24]):
                if gid and int(z[24+i]or 0):group_ids.add(gid)
    encounter_groups = {}
    for gid in sorted(group_ids, key=int):
        if gid not in groups:
            encounter_groups[gid] = dict(missing=True)
            continue
        raw = groups[gid]
        members = []
        for offset,eid in enumerate(raw[5:15]):
            if eid in ['', '0'] or not int(raw[15+offset] or 0):
                continue
            enemy = enemies.get(eid)
            base = bases.get(enemy[3]) if enemy else None
            members.append(dict(enemy_id=eid, weight=int(raw[15+offset]), mandatory=raw[25+offset]=='1',
                                count=list(map(int,enemy[6:8])) if enemy else None, enemy_raw=enemy,
                                appearance=int(base[30]) if base else None, base_raw=base))
        encounter_groups[gid] = dict(name=raw[0], raw=raw, members=members,
                                     condition_fields=raw[3:5], position_order=raw[1])
    dependencies = related_enemies({m['enemy_id'] for g in encounter_groups.values()
                                   for m in g.get('members', [])}, enemies, bases)
    conflicts=[]
    actor_by_id={r['id']:r for r in actors}
    for fight in fights:
        actor=actor_by_id.get(fight.get('npc'))
        if not actor or fight.get('kind')!='StandEnemy':continue
        appearance=int(actor['raw'][20])
        if appearance<=1:continue
        appearances={m['appearance'] for gid in fight['resolved_group_ids']
                     for m in encounter_groups.get(str(gid),{}).get('members',[])}
        if appearance not in appearances:
            conflicts.append(dict(npc=fight['npc'],name=fight['name'],map=fight['source_map'],
                                  npc_appearance=appearance,declared_encounters=fight['declared_encounter_ids'],
                                  resolved_groups=fight['resolved_group_ids'],
                                  declared_group_appearances=sorted(appearances),
                                  status='named_actor_not_present_in_declared_group; source/release or owner semantics need corroboration',
                                  activate_as_restored_rule=False))
    missing_commands = [dict(script=name,line=i,text=line.strip()) for name,data in scripts.items()
                        for i,line in enumerate(source_text(data).splitlines(),1)
                        if not line.lstrip().startswith('#') and re.search(r'\b(?:Warp|Battle|Encount)\b',line,re.I)
                        and not any(c['line']==i for c in script_commands[name])]
    graph = dict(schema=2, complete=False, commit=COMMIT, initial_maps=sorted(initial_maps),
                 expanded_regional_maps=sorted(scope_maps),regional_boundaries=boundaries,
                 scope_policy='Forward fixed/event/config closure of original-candidate records; Falan/other named regional owners and IDs>=30000 remain explicit boundary evidence, not restored claims.',
                 authority='Source-contract graph; original BlueCG server execution/release compatibility unverified',
                 actors=actors, fixed_warps=fixed, event_warps=event_edges, npc_warps=npc_warps,
                 fight_triggers=fights, groups=encounter_groups, generated_dungeon_configs=generated,
                 generated_npc_templates=generated_actors, generated_fight_triggers=generated_fights,
                 generated_event_warps=generated_warps,
                 related_enemy_rules=dependencies,
                 generated_encounter_rows=generated_encounters,
                 named_fight_identity_conflicts=conflicts,
                 duplicate_encounter_rows=duplicate_encounters,
                 duplicate_encounter_uses=sorted({r['encounter_id'] for f in fights
                                                 for r in f.get('resolved_encounters', [])
                                                 if str(r['encounter_id']) in duplicate_encounters}),
                 namespace_schema_reference='assets/references/crossgate_sokia/schema/README.md',
                 unresolved_event_script_fields=[e for e in coverage['event_scripts'] if not SCRIPT.fullmatch(e['script'])],
                 referenced_scripts={name:sorted(set(SCRIPT.findall(source_text(data)))) for name,data in scripts.items()},
                 script_commands=script_commands, missing_sources=failed,
                 outgoing_targets_outside_seed=sorted(numeric_targets-initial_maps),
                 outgoing_targets_outside_expanded_scope=sorted(numeric_targets-scope_maps),
                 lexical_actions_requiring_manual_review=missing_commands,
                 limitations=['Conditions, branch priority, NPC time windows and item consumption are not executed by this extractor.',
                              'Outgoing targets outside initial scope are recorded, not silently declared restored or safe.',
                              'No random encounter row is not proof of a safe map or absence of scripted/generated encounters.',
                              'Later numeric NPC IDs and records require target-release corroboration before activation.',
                              'Config NPC fields101–116 retain all eight slots, including repeated IDs. The reference reader parses refresh operands but comments out createNpc; original placement/count/refresh execution remains unverified.',
                              'Raw scripts preserve original bytes; comments may contain source mojibake.'])
    assert all((OUT/p['file']).is_file() and digest((OUT/p['file']).read_bytes())==p['sha256'] for p in proofs)
    assert set(script_commands)==set(scripts)
    publish_sources(proofs)
    graph.update(durable_source_directory=str(DURABLE.relative_to(ROOT)),
                 durable_source_references=str((DURABLE/'references.json').relative_to(ROOT)))
    write_json('references.json', sorted(proofs,key=lambda p:p['file']))
    write_json('source-graph.json', graph)
    write_json('recovery-summary.json', dict(scripts=len(scripts),actors=len(actors),fixed_warps=len(fixed),
                                           event_warps=len(event_edges),fights=len(fights),groups=len(encounter_groups),
                                           generated_npc_templates=len(generated_actors),generated_fights=len(generated_fights),
                                           dungeon_configs=len(generated),missing=failed,
                                           expanded_regional_maps=len(scope_maps),durable_sources=str(DURABLE.relative_to(ROOT)),
                                           durable_source_count=len(proofs),named_fight_conflicts=len(conflicts),
                                           outside_expanded_scope=graph['outgoing_targets_outside_expanded_scope'],
                                           static_warp_parse_gaps=[r for r in event_edges if not r.get('candidate_destinations')],
                                           outside_targets=graph['outgoing_targets_outside_seed']))
    lines = ['# Sokia and Venoa source contract graph', '',
             '**Regional restoration remains incomplete.** This extractor preserves source contracts; it does not execute gameplay or certify scenery.', '',
             f'Primary tables/scripts: linv2/Crossgate_Docker `{COMMIT}`. Exact bytes, source URLs and SHA256 records are retained under `assets/references/crossgate_sokia/events/`.', '',
             f'- {len(scripts)} scripts plus dungeonconf; {len(failed)} missing source files.',
             f'- {len(initial_maps)} seed maps; {len(scope_maps)} source candidates under the recorded forward-closure/boundary policy.',
             f'- {len(actors)} NPC records, including separately labeled inactive and later-ID records.',
             f'- {len(fixed)} directed fixed warps and {len(event_edges)} actor-associated script Warp records.',
             f'- {len(fights)} actor-associated fight declarations; {len(encounter_groups)} resolved group records; {len(generated)} dungeon configurations.',
             f'- {len(generated_actors)} generated-dungeon NPC templates and {len(generated_fights)} additional fight declarations retain every config slot/refresh operand. Source777 is a template marker, not a geographic map; original dynamic placement/count/refresh is unverified.',
             f'- {len(conflicts)} named-fight identity conflicts and {len(missing_commands)} unparsed lexical commands.', '',
             f"- {len(dependencies['edges'])} source enemy-reference links are retained separately from initial group membership; their summon/phase triggers remain unverified.", '',
             '## Encounter namespace correction', '',
             'Script Encount and StandEnemy operands name encount.txt IDs. Those rows choose weighted group.txt IDs. The earlier extractor skipped that resolution and omitted script Encount commands. Its seven named boss conflicts were false. Historical outputs are retained under `Before namespace correction/`.', '',
             '| NPC | Encounter ID | Resolved groups |', '| --- | --- | --- |']
    lines += [f"| {f['name']} {f['npc']} | {f['declared_encounter_ids']} | {f['resolved_group_ids']} |"
              for f in fights if f.get('kind') == 'StandEnemy' and f['npc'] in ['81000','81001','5301','5302','5303','5304','5305']]
    lines += ['', 'Positive next-encounter links are followed with cycle protection. Global duplicate encounter IDs and their scoped uses are separate JSON fields; none may be silently certified.', '',
              '## Remaining verification', '',
              'Group fields 3/4 are required/forbidden items. Fields 25–34 are mandatory-member flags. See the pinned primary-reader evidence in `assets/references/crossgate_sokia/schema/`. Raw counts, levels, weights, order and enemy/base identities remain in the graph.', '',
              'The graph retains lexical conditions/window context, source release qualifications, NPC Warp alternatives, generated configuration endpoints and missing client map IDs separately. It does not prove branch priority, item consumption, win/loss behavior, original random generation, regional membership, runtime ownership, safe zones or rendered gameplay. Those require the coverage ledger and focused verification.', '',
              'Canonical extractor: `tools/recover_sokia_source_graph.py`.']
    (OUT/'REPORT.md').write_text('\n'.join(lines) + '\n')
    print(json.dumps(dict(scripts=len(scripts), maps=len(scope_maps), fights=len(fights),
                          groups=len(encounter_groups), missing=failed, identity_conflicts=len(conflicts))))


if __name__ == '__main__':
    main()
