"""Compare pinned regional encounters with prepared data; never certify gameplay from table presence."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/references/crossgate_tina/events'
REGIONAL_SOURCE = ROOT / 'assets/references/crossgate_sokia/events'
OUTPUT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage'
TABLES = ('encount.txt', 'group.txt', 'enemy.txt', 'enemybase.txt', 'npc.txt')
# These are confirmed follow-on branches, not a claim that the full event graph is inventoried.
BRANCH_MAPS = {13503, 13504, 15517, 15520, 15524, 15525, 15526, 15527,
               15530, 15592, 15593, 15594, 23603, 23604, 23605, 23606, 23607}


def read_json(path):
    return json.loads(path.read_text())


def rows(name):
    return [line.split('\t') for line in (SOURCE / name).read_bytes().decode('gb18030').splitlines()
            if line and not line.startswith('#')]


def source_members(group, enemies, bases):
    result = []
    for index, enemy_id in enumerate(group[5:15]):
        weight = int(group[15 + index] or 0)
        if enemy_id not in ('', '0') and weight:
            enemy = enemies[enemy_id]
            result.append([int(bases[enemy[3]][30]), int(enemy[4]), int(enemy[5]), weight])
    return result


def source_identities(group, enemies, bases):
    result = []
    for slot, enemy_id in enumerate(group[5:15]):
        weight = int(group[15 + slot] or 0)
        if enemy_id not in ('', '0') and weight:
            enemy = enemies[enemy_id]
            base = bases[enemy[3]]
            result.append(dict(slot=slot, enemy_id=enemy_id, enemy_name=enemy[0],
                               base_id=enemy[3], base_name=base[0], appearance=int(base[30]),
                               levels=list(map(int, enemy[4:6])), weight=weight,
                               mandatory=len(group)>25+slot and group[25+slot]=='1',
                               count=list(map(int,enemy[6:8])) if len(enemy)>7 else None,
                               enemy_raw=enemy, base_raw=base))
    return result


def source_ai_actions(raw, techniques):
    """Keep ordered AI slots; rate fields do not establish native decision timing."""
    if len(raw) < 41:
        raise ValueError(f'Incomplete source AI row: {raw[0]}')
    result = []
    for slot in range(10):
        if not raw[1 + slot]:
            continue
        code = int(raw[21 + slot] or 0)
        technique = techniques.get(str(code), [])
        result.append(dict(slot=slot, condition=int(raw[1 + slot]),
                           target_type=int(raw[11 + slot] or 0), technique=code,
                           rate=int(raw[31 + slot] or 0),
                           technique_name=technique[0] if technique else None,
                           technique_function=technique[1] if technique else None,
                           technique_args=technique[2] if technique else None,
                           technique_raw=technique))
    return result


def zone_comparison(raw, zone, groups, species, source_groups, enemies, bases):
    """Compare each weighted group independently, including duplicate member slots."""
    differences = []
    expected_fields = dict(map=int(raw[3]), bounds=list(map(int, raw[4:8])),
                           probability=list(map(int, raw[8:10])), maximum=int(raw[10]),
                           priority=int(raw[11]))
    for field, expected in expected_fields.items():
        if zone.get(field) != expected:
            differences.append(dict(kind='zone_field', field=field,
                                    expected=expected, actual=zone.get(field)))
    expected = [[gid, int(raw[24 + i] or 0)] for i, gid in enumerate(raw[14:24])
                if gid and int(raw[24 + i] or 0)]
    actual = []
    for key, weight in zone['groups']:
        group = groups.get(key)
        gid = str(group.get('source_group', key)) if group else key
        actual.append([gid, weight])
        if group is None:
            differences.append(dict(kind='missing_prepared_group', group=gid))
            continue
        if gid not in source_groups:
            differences.append(dict(kind='unverified_group', group=gid))
            continue
        try:
            members = [[int(species[m[0]]['id']), *m[1:]] for m in group['members']]
        except (IndexError, KeyError, TypeError):
            differences.append(dict(kind='invalid_appearance_mapping', group=gid))
            continue
        wanted = source_members(source_groups[gid], enemies, bases)
        if members != wanted:
            differences.append(dict(kind='members_levels_or_weights', group=gid,
                                    expected=wanted, actual=members))
        if group.get('order') != source_groups[gid][1]:
            differences.append(dict(kind='formation_record', group=gid))
        if group.get('raw') != source_groups[gid]:
            differences.append(dict(kind='source_identity_record', group=gid))
    if actual != expected:
        differences.append(dict(kind='zone_group_weights', expected=expected, actual=actual))
    return differences


def covered_cells(bounds, rectangles):
    """Count union coverage without counting overlapping crops twice; bounds are inclusive."""
    x0, y0, x1, y1 = bounds
    count = 0
    for y in range(y0, y1 + 1):
        spans = sorted((max(x0, x), min(x1, x + w - 1)) for x, yy, w, h in rectangles
                       if yy <= y < yy + h and max(x0, x) <= min(x1, x + w - 1))
        end = x0 - 1
        for lo, hi in spans:
            count += max(0, hi - max(end + 1, lo) + 1)
            end = max(end, hi)
    return count


def audit():
    proofs = {p['file']: p for p in read_json(SOURCE / 'references.json')}
    source_hashes = {}
    for name in TABLES:
        digest = hashlib.sha256((SOURCE / name).read_bytes()).hexdigest()
        if digest != proofs[name]['sha256']:
            raise ValueError(f'Pinned source hash mismatch: {name}')
        source_hashes[name] = digest
    regional_proofs = read_json(REGIONAL_SOURCE / 'references.json') if (REGIONAL_SOURCE / 'references.json').exists() else []
    tree_path = REGIONAL_SOURCE / 'git-tree-pins.json'
    tree = read_json(tree_path) if tree_path.exists() else {'blobs':{}}
    unpinned_blob_paths = []
    for proof in regional_proofs:
        raw = (REGIONAL_SOURCE / proof['file']).read_bytes()
        if hashlib.sha256(raw).hexdigest() != proof['sha256']:
            raise ValueError(f"Pinned regional source hash mismatch: {proof['file']}")
        expected = tree['blobs'].get(proof.get('path'))
        if expected:
            blob = hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
            if blob != expected['sha']:
                raise ValueError(f"Regional reference bytes differ from pinned Git tree: {proof['file']}")
        else:unpinned_blob_paths.append(proof['file'])
    graph_path = OUTPUT / 'Source events/source-graph.json'
    source_graph = read_json(graph_path) if graph_path.exists() else {}
    inventory_path = OUTPUT / 'runtime-map-inventory.json'
    inventory = read_json(inventory_path) if inventory_path.exists() else {}
    server_dir = ROOT / 'assets/references/crossgate_sokia/maps/server'
    server_by_file = {}
    for path in sorted(server_dir.glob('*references.json')) + sorted(server_dir.parent.glob('*references.json')):
        for proof in read_json(path):
            proof = {**proof, 'file': Path(proof['file']).name}
            if proof['file'] in server_by_file and server_by_file[proof['file']]['sha256'] != proof['sha256']:
                raise ValueError(f"Conflicting pinned server source: {proof['file']}")
            server_by_file[proof['file']]=proof
    server_proofs = list(server_by_file.values())
    for proof in server_proofs:
        if hashlib.sha256((server_dir / proof['file']).read_bytes()).hexdigest() != proof['sha256']:
            raise ValueError(f"Pinned server map hash mismatch: {proof['file']}")
    server_ids = {int(r['file'].split('_')[0]) for r in server_proofs}
    completion_path = OUTPUT / 'Server completion/source-completion.json'
    completion = read_json(completion_path) if completion_path.exists() else {}
    active_path = ROOT / 'assets/maps/falan/sokia/source/provenance.json'
    active_source = read_json(active_path) if active_path.exists() else {}
    active_300_full = False
    if active_source:
        active_hash = hashlib.sha256(active_path.with_name('300.dat').read_bytes()).hexdigest()
        if active_hash != active_source['active_sha256']:
            raise ValueError('Active outdoor300 source hash mismatch')
        active_300_full = bool(active_source.get('active') and active_hash==active_source.get('candidate_sha256'))
    freyja_active_path=ROOT/'assets/maps/falan/freyja_source/provenance.json'
    freyja_active_source=read_json(freyja_active_path) if freyja_active_path.exists() else {}
    if freyja_active_source and hashlib.sha256(freyja_active_path.with_name('100.dat').read_bytes()).hexdigest()!=freyja_active_source['active_sha256']:
        raise ValueError('Active Freyja100 source hash mismatch')
    owner_records = {int(row['map']): row for row in inventory.get('maps', [])}
    southwest_path = OUTPUT / 'Freyja union audit/southwest-verification-summary.json'
    southwest = read_json(southwest_path) if southwest_path.exists() else {}
    union_path = OUTPUT / 'Freyja union audit/union-coverage.json'
    union = read_json(union_path) if union_path.exists() else {}
    venoa_evidence = dict(
        status='scoped_evidence_snapshot_not_full_region_signoff',
        path=str(southwest_path.relative_to(ROOT)),
        source_map_sha256=southwest.get('source_map_sha256'),
        source_envelopes=southwest.get('source_envelopes', {}),
        source_component=union.get('venoa_component'),
        current_union=union.get('union', {}),
        decoder_open_outside_all_envelopes=union.get('decoder_open_outside_all_envelopes', []),
        focused_checks=southwest.get('checks', {}),
        renderer_stations=southwest.get('scenery', {}).get('runtime_station_evidence', {}).get('actual_renderer_stations'),
        restored_station_counts=southwest.get('scenery', {}).get('runtime_station_evidence', {}).get('counts', {}),
        native_navigation=southwest.get('native_navigation', {}),
        source_art=union.get('source_art', {}),
        unresolved=southwest.get('unverified', []),
        unseen_ocean_status=southwest.get('scenery', {}).get('ocean_index_status'),
        qualification='Rectangle coverage, visible source art, native clearance and original encounters require separate verification.')
    full_union_path = OUTPUT / 'Freyja full-source union/union-coverage.json'
    if full_union_path.exists():
        full_union = read_json(full_union_path)
        source_path = ROOT / full_union['source_path']
        if hashlib.sha256(source_path.read_bytes()).hexdigest() != full_union['source_sha256']:
            raise ValueError('Full Freyja union references a changed prepared source map')
        art = full_union['source_art']
        venoa_evidence['full_source_comparison'] = dict(
            path=str(full_union_path.relative_to(ROOT)),
            source_path=full_union['source_path'], source_sha256=full_union['source_sha256'],
            source_variant=full_union['source_variant'],
            activated=False, complete=full_union['complete'],
            decoder_open_cells=full_union['native_open_cells'],
            decoder_dry_open_cells=full_union['decoder_dry_open_cells'],
            venoa_component=full_union['venoa_component'], union=full_union['union'],
            source_art={key:art[key] for key in ('original_anchor_count', 'matching_input_declarations',
                'no_matching_inspected_input_declaration')},
            source_fixed_ports=len(full_union['source_fixed_ports']),
            source_fixed_ports_outside_envelopes=sum(not p['in_terrain_envelope'] for p in full_union['source_fixed_ports']),
            qualification='Prepared client-known plus pinned server-unrecorded source; decoder openness is not original walk authorization. Current terrain/input snapshots and other regional owners remain separate. This audit activates no terrain or routes.')
        visibility_path = OUTPUT / 'Freyja full-source union/art-visibility.json'
        if visibility_path.exists():
            visibility = read_json(visibility_path)
            if visibility['source_sha256'] != full_union['source_sha256']:
                raise ValueError('Freyja alpha classification references another source variant')
            venoa_evidence['full_source_comparison']['art_visibility'] = dict(
                path=str(visibility_path.relative_to(ROOT)),
                source_anchor_counts=visibility['source_anchor_counts'], input_gap_counts=visibility['input_gap_counts'])
    base = read_json(ROOT / 'assets/maps/falan/south_kili_route/population.json')
    sokia = read_json(ROOT / 'assets/maps/falan/sokia/population.json')
    server = read_json(ROOT / 'assets/maps/original_crossgate/sokia_server/encounters.json')
    water_path = 'assets/maps/original_crossgate/sokia_server/water/encounters.json'
    water = read_json(ROOT / water_path)
    prayer = read_json(ROOT / 'assets/maps/falan/black_prayer/encounters.json')
    freyja = read_json(ROOT / 'assets/maps/falan/freyja_residual/encounters.json')
    provenance = read_json(ROOT / 'assets/maps/falan/map_encounter_provenance.json')
    for package in (base, sokia, server, prayer, freyja, provenance):
        for name, digest in package['source_hashes'].items():
            if name in source_hashes and source_hashes[name] != digest:
                raise ValueError(f'Prepared data references different source: {name}')
    if sokia['base_species_count'] != len(base['species']):
        raise ValueError('Sokia combined roster has incompatible base indices')
    species = base['species'] + sokia['extra_species']
    for package in (server,prayer):
        if len(species)!=package['species_offset']:
            raise ValueError('Regional source encounter additions have incompatible member indices')
        species += package['species']
    offset = int(water['species_offset'])
    if species[offset:offset+len(water['reuses_species'])] != water['reuses_species']:
        raise ValueError('Water Cave reused species indices changed')
    # Mirror the existing owner: the base zone/group wins an existing ID.
    zones = {int(z['id']): z for z in base['zones']}
    zones.update({int(z['id']): z for z in sokia['zones'] if int(z['id']) not in zones})
    for zone in server['zones'] + water['zones']:
        if int(zone['id']) in zones:raise ValueError('Server source zone has two prepared owners')
        zones[int(zone['id'])]=zone
    if species[:freyja['base_species_count']]!=freyja['species']:
        raise ValueError('Freyja source member prefix changed')
    zones={ident:zone for ident,zone in zones.items() if int(zone['map'])!=100}
    zones.update({int(zone['id']):zone for zone in freyja['zones']})
    prepared_groups = {**server['groups'], **prayer['groups'], **sokia['groups'], **base['groups']}
    if prepared_groups.keys() & water['groups'].keys():
        raise ValueError('Water Cave rare group has two prepared owners')
    prepared_groups.update(water['groups'])
    prepared_groups.update(freyja['groups'])
    fixed = read_json(ROOT / 'assets/maps/falan/sokia/fixed/catalog.json')
    fixed_maps = {int(m['id']) for m in fixed['maps'].values()}
    maps = fixed_maps | BRANCH_MAPS | {100, 300, 2100, 3000, 3200, 13001, 16507, 16508,
                                     11000, 11001, 11002, 15003, 15004, 15005}
    maps.update(source_graph.get('expanded_regional_maps', []))
    enemies = {r[2]: r for r in rows('enemy.txt')}
    bases = {r[1]: r for r in rows('enemybase.txt')}
    groups = {r[2]: r for r in rows('group.txt')}
    other_adapters = []
    for path in ('assets/maps/falan/east_region/population.json',
                 'assets/maps/original_crossgate/freyja_trial/encounters.json',
                 'assets/maps/original_crossgate/sokia_wind_tower/encounters.json',
                 'assets/maps/original_crossgate/sokia_desert_temple/encounters.json',
                 'assets/maps/original_crossgate/sokia_dragon_summit/encounters.json',
                 'assets/maps/falan/university_region/encounters.json',
                 'assets/maps/falan/snow_region/population.json'):
        payload = read_json(ROOT / path)
        if path=='assets/maps/falan/east_region/population.json':
            payload={**payload,'zones':[z for z in payload['zones'] if int(z['map'])!=100]+freyja['zones'],
                     'groups':{**payload['groups'],**freyja['east_groups']}}
        other_adapters.append((path, payload))
    source_zones = [r for r in rows('encount.txt') if int(r[3]) in maps]
    provenance_zones = {int(z['id']): z for z in provenance['zones']}
    banks = {}
    for path in sorted((ROOT / 'assets/characters/crossgate').glob('*/motions.json')):
        for index, variant in enumerate(read_json(path).get('variants', [])):
            if 'id' in variant:
                banks.setdefault(int(variant['id']), []).append(dict(path=str(path.relative_to(ROOT)), skin=index))
    records = []
    source_group_records = {}
    appearance_ids = set()
    conditional = {}
    for raw in source_zones:
        ident, number = int(raw[0]), int(raw[3])
        source_choices = [[gid, int(raw[24 + i] or 0)] for i, gid in enumerate(raw[14:24])
                          if gid and int(raw[24 + i] or 0)]
        memberships = {}
        for gid, _ in source_choices:
            members = source_members(groups[gid], enemies, bases)
            memberships[gid] = members
            source_group_records[gid] = dict(raw=groups[gid],
                                             members=source_identities(groups[gid], enemies, bases))
            appearance_ids.update(m[0] for m in members)
            if any(v not in ('', '0', '-1') for v in groups[gid][3:5]):
                conditional[gid] = dict(group=gid, raw=groups[gid],
                                       status='required_or_forbidden_item_fields; runtime_gate_unverified')
        z = zones.get(ident)
        record = dict(id=ident, map=number, bounds=list(map(int, raw[4:8])),
                      source_groups=source_choices, source_members=memberships)
        if z is not None:
            record['differences'] = zone_comparison(raw, z, prepared_groups, species, groups, enemies, bases)
            record['status'] = 'table_divergence' if record['differences'] else 'prepared_table_match'
            if any(int(candidate['id'])==ident for candidate in server['zones']):
                record['prepared_evidence']='assets/maps/original_crossgate/sokia_server/encounters.json'
                record['runtime_dispatch_verified']=False
                record['activation_qualification']='Server map remains review-only until its renderer/route checks pass.'
            if any(int(candidate['id'])==ident for candidate in water['zones']):
                record['prepared_evidence']=water_path
                record['runtime_dispatch_verified']=False
                record['activation_qualification']='Water Cave data is prepared; focused native/rendered evidence and guarded source gates remain separate from regional completion.'
        elif ident in provenance_zones:
            record['status'] = 'provenance_only_fixed_post_adaptation'
        elif number == 15593:
            record['status'] = 'existing_fixed_patrol_adaptation_not_source_group_adapter'
        else:
            record['status'] = 'missing_from_prepared_adapter'
        record['other_adapter_comparisons'] = []
        for path, adapter in other_adapters:
            for candidate in adapter.get('zones', []):
                if int(candidate['id']) != ident:
                    continue
                differences = zone_comparison(raw, candidate, adapter['groups'], adapter['species'],
                                              groups, enemies, bases)
                mismatches = [name for name, digest in adapter.get('source_hashes', {}).items()
                              if name in source_hashes and source_hashes[name] != digest]
                if mismatches:
                    differences.append(dict(kind='source_version', tables=mismatches))
                record['other_adapter_comparisons'].append(dict(path=path, differences=differences,
                    status='table_divergence' if differences else 'prepared_table_match',
                    runtime_dispatch_verified=False))
        if number == 300:
            bounds = record['bounds']
            total = (bounds[2] - bounds[0] + 1) * (bounds[3] - bounds[1] + 1)
            record['source_bounds_cells_outside_adapter'] = total - covered_cells(bounds, list(sokia['outdoor_bounds'].values()))
        if number == 100:
            record['regional_assignment'] = 'provisional_whole_map_100_inventory_boundary_not_proven'
        records.append(record)
    generated_encounters = []
    for entry in source_graph.get('generated_encounter_rows', []):
        raw = entry['raw']
        choices = [[gid, int(raw[24 + i] or 0)] for i, gid in enumerate(raw[14:24]) if gid and int(raw[24 + i] or 0)]
        for gid, _ in choices:
            source_group_records[gid] = dict(raw=groups[gid], members=source_identities(groups[gid], enemies, bases))
            appearance_ids.update(m['appearance'] for m in source_group_records[gid]['members'])
        generated_encounters.append(dict(config=entry['config'], encounter_id=entry['encounter_id'],
                                         source_groups=choices, raw=raw,
                                         source_template_npc_ids=sorted({actor['npc'] for actor in source_graph.get('generated_npc_templates', [])
                                             if any(ref['config']==entry['config'] for ref in actor['references'])}, key=int),
                                         source_template_fights=[fight for fight in source_graph.get('generated_fight_triggers', [])
                                             if any(ref['config']==entry['config'] for ref in fight['references'])],
                                         status='generated_floor_mapping_and_rules_unverified',
                                         geographic_map_id=None))
    unresolved_fight_groups = []
    for gid in source_graph.get('groups', {}):
        if gid not in groups:
            unresolved_fight_groups.append(gid)
            continue
        record = source_group_records.setdefault(gid, dict(raw=groups[gid], members=source_identities(groups[gid], enemies, bases)))
        record['source_graph_candidate'] = True
        appearance_ids.update(m['appearance'] for m in record['members'])
        if any(v not in ('', '0', '-1') for v in groups[gid][3:5]):
            conditional[gid] = dict(group=gid, raw=groups[gid], status='required_or_forbidden_item_fields; runtime_gate_unverified')
    ai_dir = ROOT / 'assets/references/crossgate_sokia/ai'
    ai_records = {}
    related = source_graph.get('related_enemy_rules', {'edges': [], 'enemies': {}})
    ai_references = read_json(ai_dir / 'references.json') if (ai_dir / 'references.json').exists() else []
    for proof in ai_references:
        if hashlib.sha256((ai_dir / proof['file']).read_bytes()).hexdigest() != proof['sha256']:
            raise ValueError(f"Pinned enemy AI source hash mismatch: {proof['file']}")
    if ai_references:
        technique_hash = hashlib.sha256((SOURCE / 'tech.txt').read_bytes()).hexdigest()
        if technique_hash != proofs['tech.txt']['sha256']:
            raise ValueError('Pinned technique source hash mismatch')
        techniques = {r[3]:r for r in rows('tech.txt') if len(r)>3}
        ai_rows = {r[0]:r for line in (ai_dir / 'enemyai.txt').read_bytes().decode('gb18030').splitlines()
                   if line and not line.startswith('#') and (r:=line.split('\t'))[0].isdigit()}
        ai_enemies = {member['enemy_id']:member['enemy_raw'] for record in source_group_records.values()
                      for member in record['members']}
        ai_enemies.update({ident:row['enemy_raw'] for ident,row in related['enemies'].items() if row.get('enemy_raw')})
        referenced = {row[8] for row in ai_enemies.values() if int(row[8] or 0)>0}
        for ident in sorted(referenced, key=int):
            raw = ai_rows.get(ident)
            ai_records[ident] = dict(raw=raw, actions=source_ai_actions(raw, techniques) if raw else [],
                                    status='source_slots_retained; condition_execution_and_native_mapping_unverified' if raw else 'referenced_ai_row_missing',
                                    source_enemy_ids=sorted((enemy for enemy,row in ai_enemies.items() if row[8]==ident), key=int))
    oznik_dir = OUTPUT / 'Oznik encounters'
    selection_path = oznik_dir / 'selection.json'
    if selection_path.exists():
        selection = read_json(selection_path)
        native_path = oznik_dir / 'native.json'
        native = read_json(native_path) if native_path.exists() else {}
        for gid in ('9033', '9034'):
            if gid in conditional:
                conditional[gid].update(
                    status='source_group_restored; bounded_selection_and_native_evidence; original_variant_rules_require_separate_review',
                    selection_evidence=str(selection_path.relative_to(ROOT)),
                    selection_checks=selection.get('checks'), selection_failures=selection.get('failures'),
                    native_evidence=str(native_path.relative_to(ROOT)) if native else None,
                    native_checks=native.get('checks'), native_failures=native.get('failures'),
                    unverified=selection.get('unverified', []))
    source_event_dirs = [REGIONAL_SOURCE, SOURCE, ROOT / 'build/Other Files/Asset Toolkit/Sokia Region Reconstruction/Source events']
    events = []
    for raw in rows('npc.txt'):
        if len(raw) < 25 or not raw[8].isdigit() or int(raw[8]) not in maps or raw[0] != 'Event':
            continue
        script = raw[24]
        path = next((d / script for d in source_event_dirs if (d / script).is_file()), None)
        event = dict(npc=raw[3], name=raw[1], map=int(raw[8]), cell=raw[9:11],
                     active=raw[6] == '1', script=script, rule_status='unverified_against_gameplay')
        if path:
            text = path.read_text(errors='replace')
            event.update(path=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                         battle_lines=[line.strip() for line in text.splitlines()
                                       if re.match(r'\s*(Encount|Battle|BattleNext|StartBattle)\b', line, re.I)])
        elif not re.fullmatch(r'[A-Za-z0-9_-]+\.txt', script, re.I):
            event['unresolved_script_field'] = True
        else:
            event['missing_script'] = True
        events.append(event)
    per_map = []
    for dependency in related['enemies'].values():
        if dependency.get('appearance') is not None:
            appearance_ids.add(dependency['appearance'])
    for number in sorted(maps):
        selected = [r for r in records if r['map'] == number]
        fights = [fight for fight in source_graph.get('fight_triggers', [])
                  if fight['source_map'] == number]
        group_ids = {gid for zone in selected for gid, _ in zone['source_groups']}
        group_ids.update(gid for fight in fights for gid in fight.get('resolved_group_ids', []))
        enemy_ids = {member['enemy_id'] for gid in group_ids
                     for member in source_group_records.get(gid, {}).get('members', [])}
        pending = list(enemy_ids)
        for enemy_id in pending:
            for edge in related['edges']:
                if edge['enemy'] == enemy_id and edge['target'] not in enemy_ids:
                    enemy_ids.add(edge['target'])
                    pending.append(edge['target'])
        map_appearances = {int(bases[enemies[eid][3]][30]) for eid in enemy_ids}
        reusable_banks = (set.intersection(*({entry['path'] for entry in banks.get(appearance, [])}
                                           for appearance in map_appearances))
                          if map_appearances else set())
        per_map.append(dict(map=number, zone_count=len(selected),
                            statuses=dict(Counter(r['status'] for r in selected)),
                            other_adapter_table_matches=sum(any(c['status']=='prepared_table_match'
                                for c in r['other_adapter_comparisons']) for r in selected),
                            source_group_ids=sorted(group_ids, key=int),
                            source_enemy_ids=sorted(enemy_ids, key=int),
                            source_appearance_ids=sorted(map_appearances),
                            complete_roster_art_bank_candidates=sorted(reusable_banks),
                            bank_candidate_qualification='Prepared appearance presence only; verify native contracts, selected pages, source fits and visual motion before reuse.',
                            declared_scripted_fights=fights,
                            runtime_owner_snapshot=owner_records.get(number),
                            no_random_rows='not_proof_of_safe_zone' if not selected else None,
                            floor_roster_verified=False))
    missing_assets = [ident for ident in sorted(appearance_ids) if ident not in banks]
    missing_asset_records = [dict(
        appearance=ident,
        source_members=[dict(group=gid, **{key: member[key] for key in
                                         ('enemy_id', 'enemy_name', 'base_id', 'base_name', 'levels', 'weight')})
                        for gid, group in source_group_records.items()
                        for member in group['members'] if member['appearance'] == ident],
        source_dependencies=[r for r in related['enemies'].values() if r.get('appearance') == ident],
        status='not_in_scanned_prepared_banks; source release/placement/trigger still requires reconciliation')
        for ident in missing_assets]
    mapping_errors = []
    for s in species:
        path = ROOT / f"assets/characters/crossgate/{s['family']}/motions.json"
        variants = read_json(path)['variants'] if path.is_file() else []
        index = int(s['skin'])
        if index >= len(variants) or int(variants[index]['id']) != int(s['id']):
            mapping_errors.append(dict(appearance=s['id'], family=s['family'], skin=index))
    ledger = 'build/Other Files/Asset Toolkit/Sokia Region Reconstruction/REGIONAL_ROUTE.md'
    missing_maps = [dict(map=number, status='absent_from_verified_runtime_scope',
                         evidence=ledger, reason='Source-confirmed northeast fixed port; previously labeled outside the Cape boundary. Requires regional restoration/reconciliation.')
                    for number in (15527, 15530) if number not in fixed_maps]
    unverified_gates = [dict(map=number, status='gate_contract_unresolved', evidence=ledger,
                            reason='Source-confirmed gated destination/return remains unverified; gate and original floor contract require restoration. This does not assert a missing fixed-map file.')
                       for number in (13503, 13504, 15517, 15520, 15524, 15525, 23603, 23604)]
    unverified_gates.append(dict(map=15526, status='gate_contract_unresolved',
                                evidence='build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Gorge corridor/',
                                reason='Configurations305/306 have twenty source-linked runtime floors and317 passing contract checks. Direct native boss checks pass. Production zero/nonzero ItemSpace derives from the existing unbounded quest-item dictionary; original slot-limit parity is unmodeled. Natural quest/item18599 access and its prerequisites still need integration; no shortcut is authorized.'))
    unverified_gates.append(dict(map=16508, status='source_scheduling_semantics_unverified',
                                evidence='build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer source route/checkpoint.json',
                                reason='Bounded source-route evidence verifies NPC6305 solo/item18421 guards, NPC81000 F interaction, the source Ruby party and victory transfer, including surviving-party reentry. The western253 source cells are now restored; focused native/rendered checks cover68new open cells, the west boundary, normal controls and the fight. Original StandEnemy scheduling and repeat/cooldown/escape semantics remain unverified; the native real-time adaptation is not original server execution.'))
    unverified_gates.append(dict(map=16509, status='source_return_services_and_room_review_incomplete',
                                evidence='build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer source route/checkpoint.json',
                                reason='Bounded native/rendered evidence verifies Ruby victory travel to16509(24,12), its source-completed map owner and original Shanti return/reward branches. Original inventory capacity, profession gates and book20580 skill service remain unmodeled, and source-room3354/5011 furniture fitting remains required. The full natural outdoor route and original procedural layouts/NPC refresh remain separate required work.'))
    prayer_path = ROOT / 'assets/maps/falan/black_prayer/encounters.json'
    runtime_floors = [dict(runtime_floor=floor['runtime_id'], original_map_id=None,
                          source_identity_status='source_config301_six_floor_count_matches; original_generator_unrecovered',
                          source_config=floor['config'], source_floor=floor['number'], source_encounter=floor['source_encounter'],
                          levels=floor['source_level_range'], reference_generator_level=floor['reference_generator_level'],
                          source_group_ids=sorted(gid.removeprefix('prayer:') for gid in prayer['groups']),
                          source_template_npc_ids=sorted({actor['npc'] for actor in source_graph.get('generated_npc_templates', [])
                              if any(ref['config']==floor['config'] for ref in actor['references'])}, key=int),
                          source_enemy_ids=sorted({m['enemy_id'] for gid in prayer['groups']
                              for m in source_group_records[gid.removeprefix('prayer:')]['members']}, key=int),
                          name=f"Black Prayer B{floor['number']}F",
                          roster_status='source_contract_prepared; native_fight_and_camera_evidence_separate',
                          evidence=str(prayer_path.relative_to(ROOT)), floor_roster_verified=False)
                      for floor in prayer['floors']]
    cape_path = OUTPUT / 'Cape caves/source-contracts.json'
    if cape_path.exists():
        for floor in read_json(cape_path)['floors']:
            runtime_floors.append(dict(runtime_floor=floor['runtime_id'], original_map_id=None,
                source_identity_status='source_config_and_floor_index_mapped; original_procedural_layout_unrecovered',
                source_config=floor['config'], source_floor=floor['number'],
                source_encounter=floor['encounter'], levels=floor['level_range'],
                reference_generator_level=floor['reference_generator_level'],
                source_group_ids=[gid.removeprefix('cape:') for gid, _ in floor['groups']],
                source_enemy_ids=sorted({m['enemy_id'] for gid, _ in floor['groups']
                    for m in source_group_records[gid.removeprefix('cape:')]['members']}, key=int),
                name=f"{floor['branch']} floor {floor['number']}",
                roster_status='source_contract_prepared; rendered_fight_and_trigger_review_separate',
                evidence=str(cape_path.relative_to(ROOT))))
    prayer_path = ROOT / 'assets/characters/crossgate/black_prayer/motions.json'
    prayer_variants = read_json(prayer_path)['variants']
    prayer_ghost = next((r for r in prayer_variants if r['id'] == 101121), {})
    prayer_blade = next((r for r in prayer_variants if r['id'] == 101600), {})
    presentation_followups = []
    if prayer_ghost.get('key') != 'original:2833':
        presentation_followups.append(dict(appearance=101121, bank='assets/characters/crossgate/black_prayer/',
            status='existing_source_actor_choice_requires_reconciliation',
            reason='The Black Prayer bank does not yet use coherent original:2833. Review its source frames before certifying appearance.',
            evidence='build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Scripted Enemy Assets/101121-original-1248-vs-2833.json'))
    if prayer_blade.get('key') == 'original:1328':
        presentation_followups.append(dict(appearance=101600, bank='assets/characters/crossgate/black_prayer/',
            status='source_record_direction_coherence_requires_review',
            reason='Prepared Blade pixels match1328, but direction0 and part of the defeat sequence contain a different creature. Source-record reconciliation and isolated rendered-body review remain required.',
            evidence='build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer Ghost/blade-1328-readonly.json'))
    elif prayer_blade.get('key') == 'original:2913':
        checkpoint_path=OUTPUT/'checkpoint-verification.json'
        review=read_json(checkpoint_path).get('black_prayer_blade',{}) if checkpoint_path.exists() else {}
        if not review.get('visual_accepted') or review.get('reviewed_bank_sha256')!=hashlib.sha256(prayer_path.read_bytes()).hexdigest():
            presentation_followups.append(dict(appearance=101600,bank='assets/characters/crossgate/black_prayer/',
                status='coherent_source_actor_published; current_native_and_rendered_review_pending',
                reason='Original2913 restores the coherent Blade with preserved timing/cues and Ruby/Ghost pixels. Current-source live-body review remains required.',
                evidence='build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer Blade/'))
    return dict(schema=1, completion=False, scope='Mandatory full 索奇亞 + 維諾亞 regional restoration; source inventory with bounded implementation evidence, not regional signoff',
                source_hashes=source_hashes, source_references={n: proofs[n]['url'] for n in TABLES},
                source_authority='Pinned CGMSV corroboration; original BlueCG server execution is not available',
                regional_git_blob_verification=dict(pins=str(tree_path.relative_to(ROOT)),
                    verified=len(regional_proofs)-len(unpinned_blob_paths),not_in_current_tree_snapshot=unpinned_blob_paths,
                    repaired_transcoded_reference_copies='build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Source events/raw-source-repair.json'),
                source_map_completion=dict(path=str(completion_path.relative_to(ROOT)), active=False,
                    source_variant=completion.get('source_variant'),
                    maps=[{**{k:r[k] for k in ('map','client_open_cells','candidate_open_cells',
                          'recorded_walk_changes_from_completed_footprints')},
                          'active':active_300_full if r['map']==300 else r['active']} for r in completion.get('maps',[])],
                    active_outdoor300_source={key:active_source.get(key) for key in (
                        'map','active','stage','preview_bounds','active_sha256','active_additions','active_decoder_open_cells')},
                    outdoor300_full_candidate_active=active_300_full,
                    active_freyja100_source={key:freyja_active_source.get(key) for key in ('active','stage','preview_bounds','active_sha256')},
                    active_freyja100_source_path=str(freyja_active_path.relative_to(ROOT)) if freyja_active_source else None,
                    active_outdoor300_source_path=str(active_path.relative_to(ROOT)) if active_source else None,
                    limitation='Map300 whole-source activation is recorded separately from physical/scenery review. Whole-map100 completion remains staged; existing East windows may already reuse pinned server cells. Neither establishes whole-region visual or encounter signoff.'),
                regional_source_files=len(regional_proofs),
                runtime_inventory_snapshot=dict(path=str(inventory_path.relative_to(ROOT)),
                                                summary=inventory.get('summary', {}),
                                                method=inventory.get('method'),
                                                candidate_ids_match=set(owner_records) == maps,
                                                playable_maps_certified=False),
                maps_without_identified_data_owner=[number for number in sorted(maps) if owner_records.get(number, {}).get('owner_status') == 'no_identified_current_data_owner'],
                missing_source_client_files=[number for number in sorted(maps) if owner_records.get(number, {}).get('original_client_file_present') is False],
                pinned_server_map_ids=sorted(server_ids),
                missing_client_maps_with_pinned_server_source=[number for number in sorted(maps)
                    if owner_records.get(number, {}).get('original_client_file_present') is False and number in server_ids],
                source_graph=dict(path=str(graph_path.relative_to(ROOT)),
                                  sha256=hashlib.sha256(graph_path.read_bytes()).hexdigest() if graph_path.exists() else None,
                                  complete=source_graph.get('complete', False),
                                  scope_policy=source_graph.get('scope_policy', 'Source graph not yet recovered'),
                                  named_fight_identity_conflicts=source_graph.get('named_fight_identity_conflicts', []),
                                  generated_npc_templates=len(source_graph.get('generated_npc_templates', [])),
                                  generated_fight_triggers=len(source_graph.get('generated_fight_triggers', [])),
                                  regional_boundaries=source_graph.get('regional_boundaries', {})),
                summary=dict(maps=len(maps), runtime_generated_floors=len(runtime_floors), zones=len(records), appearances=len(appearance_ids),
                             zone_statuses=dict(Counter(r['status'] for r in records)),
                             zones_matched_by_other_adapters=sum(any(c['status']=='prepared_table_match'
                                 for c in r['other_adapter_comparisons']) for r in records),
                             zones_without_matching_inspected_adapter=sum(r['status']!='prepared_table_match' and not any(
                                 c['status']=='prepared_table_match' for c in r['other_adapter_comparisons']) for r in records),
                             missing_prepared_assets=len(missing_assets), appearance_mapping_errors=len(mapping_errors)),
                maps=per_map, zones=records, source_group_records=source_group_records,
                conditional_groups=list(conditional.values()),
                mandatory_member_groups=[gid for gid, g in source_group_records.items()
                                         if any(m['mandatory'] for m in g['members'])], event_scripts=events,
                missing_maps=missing_maps, unverified_map_gate_contracts=unverified_gates,
                candidate_map_list_complete=False,
                runtime_generated_floors=runtime_floors,
                generated_encounter_candidates=generated_encounters,
                declared_scripted_fights=source_graph.get('fight_triggers', []),
                generated_npc_templates=source_graph.get('generated_npc_templates', []),
                declared_generated_fights=source_graph.get('generated_fight_triggers', []),
                related_enemy_rules=related,
                enemy_ai_source=dict(references=ai_references, reader='assets/references/crossgate_sokia/schema/readers/CEnemyAiReader.java',
                                     techniques='assets/references/crossgate_tina/events/tech.txt', records=ai_records,
                                     qualification='Ordered source condition/target/technique/rate slots are evidence, not a claim of native AI parity or original turn timing.'),
                unresolved_scripted_group_references=unresolved_fight_groups,
                prepared_northeast_maps=[number for number in (15527, 15530) if number in fixed_maps],
                sokia_whole_source_coverage=read_json(ROOT / 'assets/maps/falan/sokia/provenance.json').get('whole_source_coverage'),
                venoa_outdoor_evidence=venoa_evidence,
                open_graph_targets=[dict(target=target, status='source_candidate_prepared_gated; natural entry/invisible events and full scenery pending' if target in (301,302) else 'source_confirmed_event_target_pending_graph_reconciliation')
                                    for target in (302, 301, 3355, 3100)],
                missing_enemy_assets=missing_assets, missing_enemy_asset_records=missing_asset_records,
                appearance_mapping_errors=mapping_errors,
                enemy_presentation_followups=presentation_followups,
                scenery_followups=[dict(map=15526,
                                         status='reviewed_local_scenery_checkpoint; not_full_regional_signoff',
                                         issues=['Prior paint/loot defects are corrected. Source rock depth/caps are fitted 3D interpretation; original dithered ground is retained.'],
                                         evidence='build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Gorge corridor/checkpoint-summary.json')],
                outdoor_encounter_rule_gaps=[dict(map=100, source_bounds=[408,36,439,134],
                    source_encounter_ids=[r['id'] for r in records if r['map']==100
                        and r['bounds'][0]<=439 and r['bounds'][2]>=408
                        and r['bounds'][1]<=134 and r['bounds'][3]>=36],
                    current_rule='Exact existing city/village rectangles replace the220half-plane. Source encounter tables now cover all56zones through the existing native owners.',
                    required='Direct source-group contact/rendered fights and actual player targetability remain required after the156-check native navigation/field preservation proof. Original count/probability/AI execution stays qualified.',
                    terrain_scope='Friendly/terrain/bridge/ray data remains exact. Whole-map100terrain/art and the two inherited finite-radius source-shore gaps remain incomplete.',
                    native_evidence='build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja enemy safety/verification.json')],
                prepared_appearance_banks={str(i): banks.get(i, []) for i in sorted(appearance_ids)},
                required_unverified_work=[
                    'Close the complete regional map/warp/event graph, including quest-gated branches and disconnected outdoor components.',
                    'Assign every source-map-100 zone to a verified regional boundary; the whole-map candidate list includes other Freyja regions.',
                    'Compare every terrain/art tile, off-route area and entrance; adapter rectangle coverage is not terrain or scenery certification.',
                    'Verify source safe-zone/event rules; absence of encount rows alone does not prove a safe zone.',
                    'Verify documented conditional groups, scripted bosses, mixed-party composition, formation, group-size and probability rules; explicitly label undocumented algorithms and adaptation choices.',
                    'Preserve distinct source enemy/base identities and document their native mapping; shared appearance/level mappings alone do not identify every rare variant. Retain existing native combat unless a documented variant requires a specific behavior.',
                    'Review fixed gameplay-camera scenery and directly triggered representative fights; this audit runs no gameplay.',
                ],
                measured_note=dict(source='Historical initial root source-array inspection, 2026-11-26; current Sokia proof is sokia_whole_source_coverage, not this snapshot',
                                   sokia_300=dict(size=[800, 532], nonzero_ground=129484, object_anchors=22940,
                                                  outside_current_crop_union=dict(nonzero_ground=979,
                                                      water_serials=list(range(5000, 5009)), decoder_open_cells=0,
                                                      object_anchors=0),
                                                  remaining='Full original water extent is verified through the existing full-map water owner; camera appearance remains separate.'),
                                   venoa_2100=dict(size=[100, 100], nonzero_ground=5763, object_anchors=2144,
                                                   envelope_omissions=0, rendered_signoff=False),
                                   southern_lakes_100=dict(mask_bounds=[227, 303, 321, 321],
                                                          outside_mask_nonzero_ground=125144,
                                                          outside_mask_object_anchors=29433,
                                                          note='Complement partly belongs to other Freyja regions; not a count of missing Venoa terrain. Regional boundary remains unverified.')),
                documented_adaptations=list(dict.fromkeys(base['limits'] + sokia['limits'] + freyja['limits'] + [provenance['note']])))


def markdown(report):
    s = report['summary']
    lines = ['# 索奇亞 + 維諾亞 required coverage', '',
             '**Goal remains incomplete.** This is a source-data inventory, not gameplay or scenery sign-off.', '',
             f"Inventoried {s['maps']} candidate original maps, {s['runtime_generated_floors']} separately identified generated runtime floors, {s['zones']} source encounter zones and {s['appearances']} enemy appearances.", '',
             '| Encounter data status | Zones |', '| --- | ---: |']
    lines += [f'| {status} | {count} |' for status, count in s['zone_statuses'].items()]
    lines += ['', 'A prepared-table match retains memberships/levels/weights; it does not certify source frequency, geometry, safe zones or scripted fights.', '',
              '`missing_from_prepared_adapter` means absent from this inspected adapter, not proof of absence game-wide; other native/quest owners still require reconciliation.', '',
              '## Missing maps and incomplete coverage', '']
    lines += [f'- {item}' for item in report['required_unverified_work'][:3]]
    lines += [''] + [f"- Map {m['map']}: {m['status']} — {m['reason']}" for m in report['missing_maps']]
    lines += [f"- Unverified gate/floor contract for map {m['map']}: {m['reason']}" for m in report['unverified_map_gate_contracts']]
    lines += [f"- Northeast source maps now prepared: {report['prepared_northeast_maps']}. Map/port presence does not verify their original event fights or camera appearance."]
    for row in report['scenery_followups']:
        lines.append(f"- Required scenery follow-up in map {row['map']}: {' '.join(row['issues'])}")
    lines += [f"- Godot metadata inventory identifies no current data owner for {len(report['maps_without_identified_data_owner'])} source candidates. This is an open map/owner queue, not proof that every candidate belongs to the same original release.",
              f"- {report['runtime_inventory_snapshot']['summary'].get('owner_kind_occurrences',{}).get('prepared_source_catalog_gated',0)} prepared source catalogs are explicitly gated for review. They count as data owners, with no playable or visual approval.",
              f"- Missing original client files in that inventory: {report['missing_source_client_files']}.",
              f"- Pinned server layouts are available for these missing-client IDs: {report['missing_client_maps_with_pinned_server_source']}. Existing East ownership, staged recovery and live route activation remain separate.",
              '- `runtime-map-inventory.json` records each owner and its limits. Existing ownership does not establish route, art or encounter completion.',
              f"- {s['zones_matched_by_other_adapters']} source zones also match other prepared tables. JSON records each comparison; adapter presence does not verify runtime dispatch or gameplay. The primary South/Sokia counts remain separate.",
              f"- {s['zones_without_matching_inspected_adapter']} source zones have no matching inspected adapter; this union count avoids double-counting overlapping owners."]
    lines += ['- This confirmed pending-map list is incomplete until the source warp/event graph is closed. Generated floors are not classified as missing fixed-map files.',
              '- Source-confirmed event targets 302 → 301 and 3355/3100 remain open graph items; their rules and rosters must be reconciled.',
              '- The whole-source Sokia proof includes every disconnected decoder-open component, source object and flagged entrance. The 979 out-of-crop water cells use the existing full-map water surface; camera appearance and event access are separate checks.',
              '- Whole source-map-100 mask complements include other Freyja regions and cannot all be labeled missing Venoa scenery.']
    venoa = report['venoa_outdoor_evidence']
    if venoa['source_envelopes']:
        before, after = (venoa['source_envelopes'][key] for key in ('before', 'after'))
        lines += ['', '## Venoa outdoor evidence', '',
                  f"- Southern Lakes now includes the 672-cell southwest source component omitted by the old mask. Venoa-component cells outside all current native rectangles: {before['venoa_component_outside']} → {after['venoa_component_outside']}.",
                  f"- Other source decoder-open cells outside every rectangle remain: {venoa['decoder_open_outside_all_envelopes']}. Their disconnected ownership remains open.",
                  f"- Venoa-component cells outside every nonzero-alpha mask: {venoa['current_union'].get('alpha_nonzero', {}).get('venoa_component_outside')}; outside alpha≥128: {venoa['current_union'].get('alpha_opaque', {}).get('venoa_component_outside')}. Rectangle containment does not certify visible scenery.",
                  f"- Focused terrain checks are recorded as a snapshot: {venoa['focused_checks']}. Native self-query diagnostic: {venoa['native_navigation'].get('self_reachable')}/{venoa['native_navigation'].get('source_decoder_open')}; remaining failures are unclassified clearance evidence, not proof of original walkability.",
                  '- Original source art and encounter rules remain required. Detailed current evidence and limitations: `Freyja union audit/REPORT.md` and `southwest-verification-summary.json`.',
                  f"- Southwest source stations verified in the renderer: {venoa['renderer_stations']} ({venoa['restored_station_counts']}). Whole-map unmatched input declarations remain {venoa['source_art'].get('no_matching_inspected_input_declaration', 'unmeasured')}; source stations do not certify individual 3D tree silhouettes or shore depth.",
                  '- The latest scenery fixture passes 35 assertions with Metal fence diagnostics; canopy-occluded close views remain qualified. Use the clear `southwest-flowers-normal.png` and the source-aligned comparison for their separate scopes.',
                  f"- Unseen visual ocean uses original graphic 5000 art; {venoa['unseen_ocean_status']}"]
    full = venoa.get('full_source_comparison')
    if full:
        envelope, dry = full['union']['envelope'], full['union']['dry_opaque']
        lines += ['', '## Complete Freyja source comparison', '',
                  f"- Separate prepared client-known plus pinned server-unrecorded source: `{full['path']}`. This does not replace or activate the client-only evidence above.",
                  f"- {envelope['decoder_dry_open_outside']} dry decoder-open cells lie outside all current terrain envelopes. The Venoa-connected gap is {envelope['venoa_component_outside']} decoder-open cells at {envelope['venoa_component_outside_bounds']}.",
                  f"- {dry['decoder_dry_open_outside']} dry decoder-open cells lack opaque dry paint. Openness from the decoder is not original walk authorization.",
                  f"- Source object anchors (including invisible markers): {full['source_art']['original_anchor_count']}; matched input declarations: {full['source_art']['matching_input_declarations']}; ownership gaps: {full['source_art']['no_matching_inspected_input_declaration']}. Other regional owners remain separate.",
                  f"- {full['source_fixed_ports']} source fixed ports, {full['source_fixed_ports_outside_envelopes']} outside current envelopes. Containment alone does not verify original event triggers."]
        if full.get('art_visibility'):
            lines += [f"- Original-alpha classification of input gaps: {full['art_visibility']['input_gap_counts']}. Invisible source markers do not require invented visible geometry."]
    graph = report['source_graph']
    lines += ['', '## Source graph and generated floors', '',
              f"- Full static LS2MAP comparisons expose client-cache omissions. Prepared data preserves all recorded client cells and flags. Whole300 candidate active: {report['source_map_completion']['outdoor300_full_candidate_active']}. Physical/scenery review and whole100 recovery remain separate required work; JSON records the exact active source variant.",
              f"- {report['regional_source_files']} regional source files are SHA-pinned. Forward fixed/script/configuration closure supplies additional candidate map IDs; regional boundaries and target-release compatibility still require review.",
              f"- {len(report['generated_encounter_candidates'])} generated-dungeon encounter records need per-floor mapping and native fight verification; their source map-777 field is not a geographic map ID.",
              f"- {len(report['declared_scripted_fights'])} source fight declarations and every graph-referenced group are retained, including scripted-only enemies absent from the random tables. Unresolved group references: {report['unresolved_scripted_group_references']}.",
              f"- {len(report['generated_npc_templates'])} additional generated-dungeon NPC templates retain all configuration slots and raw refresh operands, including duplicate references. Their {len(report['declared_generated_fights'])} fight declarations are recorded per configuration, without treating source marker777 as a geographic map. Original placement/count/refresh execution remains unverified.",
              f"- {len(graph['named_fight_identity_conflicts'])} unresolved named-fight identity conflicts. Encounter operands resolve through encount.txt before group.txt; the earlier seven reported conflicts were extractor errors.",
              '- Detailed graph, conditions, source versions and conflicts: `Source events/source-graph.json` and `Source events/REPORT.md`.']
    lines += ['', '## Enemy assets', '', f"- {s['missing_prepared_assets']} source appearances absent from scanned prepared native banks: {report['missing_enemy_assets']}.",
              f"- {s['appearance_mapping_errors']} prepared family/skin mappings differ from the declared appearance.",
              '- Asset presence in another bank does not establish that a floor or fight uses it. Scripted-only group candidates are included; release compatibility and source triggers remain separate.']
    for row in report['missing_enemy_asset_records']:
        names = ', '.join(sorted({member['base_name'] for member in row['source_members']}))
        groups = ', '.join(sorted({member['group'] for member in row['source_members']}, key=int))
        lines.append(f"- Missing appearance {row['appearance']} ({names}), source groups {groups}. Enemy/base IDs, levels and weights are retained in JSON.")
    for row in report['enemy_presentation_followups']:
        lines.append(f"- Required presentation follow-up for {row['appearance']} in `{row['bank']}`: {row['reason']}")
    lines += ['', '## Unverified encounter rules', '']
    lines += [f'- {item}' for item in report['required_unverified_work'][3:]]
    ai = report['enemy_ai_source']['records']
    lines += [f"- {len(ai)} referenced source AI records retain ordered condition/target/technique/rate slots; {sum(not row['raw'] for row in ai.values())} referenced rows are missing. Native mapping and original condition/rate execution remain unverified. Shared appearance does not erase variant rules."]
    for gap in report['outdoor_encounter_rule_gaps']:
        lines.append(f"- Map {gap['map']} bounds {gap['source_bounds']}: source encounters {gap['source_encounter_ids']}. {gap['current_rule']} {gap['required']}")
    missing_scripts = sum(bool(e.get('missing_script')) for e in report['event_scripts'])
    unresolved_fields = sum(bool(e.get('unresolved_script_field')) for e in report['event_scripts'])
    lines += [f"- {len(report['conditional_groups'])} groups have required/forbidden item fields requiring runtime reconciliation. {len(report['mandatory_member_groups'])} groups have mandatory-member flags; those are separate from item conditions.",
              f"- {len(report['event_scripts'])} Event NPC records require gameplay reconciliation ({missing_scripts} missing script files; {unresolved_fields} unresolved source script fields).", '',
              '## Related enemy forms', '',
              'Enemy fields45/46 reference additional enemy records in the source reader. Identities remain separate even when the appearance matches. Trigger timing, summon/phase behavior and native use remain unverified.', '',
              '| Parent enemy | Field | Referenced enemy | Source name | Appearance |',
              '| --- | ---: | --- | --- | ---: |']
    dependencies = report['related_enemy_rules']
    for edge in dependencies.get('edges', []):
        row = dependencies['enemies'][edge['target']]
        lines.append(f"| {edge['enemy']} | {edge['field']} | {edge['target']} | {(row.get('enemy_raw') or ['Missing'])[0]} | {row['appearance']} |")
    lines += ['', '## Per-map roster audit', '', '| Original map | Source zones | Enemy IDs | Fight declarations | Prepared data | Roster verified |', '| --- | ---: | ---: | ---: | --- | --- |']
    for row in report['maps']:
        status = ', '.join(f'{key}: {value}' for key, value in row['statuses'].items()) or 'No rows; safe-zone status unverified'
        lines.append(f"| {row['map']} | {row['zone_count']} | {len(row['source_enemy_ids'])} | {len(row['declared_scripted_fights'])} | {status} | Pending |")
    lines += ['', '## Generated dungeon floors', '',
              'These runtime IDs are not authenticated original map IDs. The source config/floor mapping and remaining roster, script and frequency work are recorded separately.', '',
              '| Runtime floor | Original map ID | Source identity / roster |', '| --- | --- | --- |']
    lines += [f"| {row['runtime_floor']} ({row['name']}) | Unknown | {row['source_identity_status']}; {row['roster_status']} |"
              for row in report['runtime_generated_floors']]
    lines += ['', 'Detailed source groups, enemy/base IDs and names, raw enemy/base rows, level ranges, weights, differences, conditional rows, bank paths and event scripts are in `coverage.json`.', '',
              'Pinned source tables are CGMSV corroboration, not authenticated original BlueCG server state. The map/event graph is still open. No fixed-camera review or fights were run by this audit.', '']
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-complete', action='store_true')
    args = parser.parse_args()
    report = audit()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'coverage.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    (OUTPUT / 'coverage.md').write_text(markdown(report))
    print(json.dumps(dict(completion=report['completion'], **report['summary']), ensure_ascii=False))
    return 1 if args.require_complete and not report['completion'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
