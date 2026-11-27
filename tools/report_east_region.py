"""Join source inventories and observed checks into the East Gate delivery ledger."""
import collections
import datetime
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
ASSETS = ROOT / 'assets/maps/falan/east_region'


def read(path, default=None):
    return json.loads(path.read_text()) if path.exists() else ({} if default is None else default)


def passed(report):
    return bool(report) and not report.get('failures', True)


def source_freshness(report):
    hashes = report.get('source_hashes', report.get('runtime_source_hashes', {}))
    changed = []
    for name, expected in hashes.items():
        path = ROOT / name.removeprefix('res://')
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            changed.append(name)
    return dict(fingerprinted_files=len(hashes), current=not changed if hashes else None,
                changed=changed, scope='Only recorded files are compared; an absent fingerprint does not establish currentness.')


def main():
    routes = read(ASSETS / 'routes.json')
    population = read(ASSETS / 'population.json')
    catalog = read(ROOT / 'assets/maps/original_crossgate/east/catalog.json')
    specs = json.loads((ASSETS / 'dungeon_specs.gd').read_text().split('const SPECS=', 1)[1])
    matrix = read(OUT / 'route-matrix.json')
    contracts = {name: read(OUT / 'Verification' / f'{name}.json') for name in
                 ['dungeon-contracts', 'event-contracts', 'item-contracts', 'harbor-contracts', 'native-bank-contracts', 'battle-result-contracts']}
    event_audit = read(OUT / 'Verification/event-source-audit.json')
    harbor = read(ASSETS / 'harbor.json')
    map_checks = {int(row['source']): row for row in matrix.get('maps', [])}
    incoming = collections.Counter(int(row[3]) for row in routes['fixed'])
    outgoing = collections.Counter(int(row[0]) for row in routes['fixed'])
    actors = collections.defaultdict(list)
    for actor in population['actors']:
        actors[int(actor['source'])].append(actor)
    maps = []
    for ident in routes['fixed_maps']:
        ident = int(ident)
        row = catalog['maps'].get(f'BlueCrossgate/map/0/{ident}.dat', {})
        maps.append(dict(id=ident, title=row.get('title', ''), prepared=bool(row),
                         source_layout_complete=bool(row.get('layout_complete',False)),
                         existing_owner=bool(row.get('east_existing_owner')),
                         active_layout='pinned-reference-only' if row.get('reference_only',False) else row.get('active_layout_variant', 'native-client'),
                         native_sha256=row.get('sha256'), reference_sha256=row.get('reference_variant_sha256'),
                         incoming=incoming[ident], outgoing=outgoing[ident], actors=len(actors[ident]),
                         observed=map_checks.get(ident, {}), visual_inferences=row.get('visual_inferences', []),
                         inferred_graphic_bindings=row.get('inferred_graphic_bindings', []),
                         outdoor_reference=row.get('outdoor_reference'), walk_override=row.get('walk_override')))
    fixed = []
    observations = {(int(r['source']), *map(int, r['cell']), int(r['target']), *map(int, r['landing'])): r
                    for r in matrix.get('fixed', [])}
    for row in routes['fixed']:
        key = tuple(map(int, row))
        fixed.append(dict(source=key[0], cell=list(key[1:3]), target=key[3], landing=list(key[4:6]),
                          observed=observations.get(key, {})))
    gates = []
    condition_blockers = collections.defaultdict(list)
    command_blockers = collections.defaultdict(list)
    for blocked in event_audit.get('unknown_external_conditions', []):
        condition_blockers[(blocked['script'], int(blocked['line']))].append(blocked)
    for blocked in event_audit.get('source_blockers', []) + event_audit.get('technical_blockers', []):
        command_blockers[blocked['script']].append(dict(line=blocked['line'], reason=blocked['reason'], command=blocked.get('command', '')))
    for actor in population['actors']:
        program = population['scripts'].get(actor['script'], {})
        for block in program.get('blocks', []):
            if block['condition'].strip():
                blocked = condition_blockers.get((actor['script'], int(block['line'])), [])
                gates.append(dict(actor=actor['id'], source=int(actor['source']), cell=actor['cell'],
                                  script=actor['script'], line=block['line'], condition=block['condition'],
                                  implementation='guarded original predicate',
                                  status='external-state contract blocked' if blocked else 'predicate supported; original condition retained',
                                  condition_blockers=blocked, potential_command_blockers=command_blockers[actor['script']]))
        for line, text in program.get('lines', []):
            word = text.strip().split(None, 1)
            if len(word) == 2 and word[0].lower().startswith('window_') and word[1].strip():
                gates.append(dict(actor=actor['id'], source=int(actor['source']), cell=actor['cell'],
                                  script=actor['script'], line=line, condition=text.strip()))
    generators = []
    verified_generators = {int(row['config']): row for row in contracts['dungeon-contracts'].get('branches', [])}
    for key, spec in specs.items():
        verified = passed(contracts['dungeon-contracts']) and verified_generators.get(int(spec['config']), {}).get('possible_floors', 0) >= spec['maximum']
        floors = [dict(number=n, runtime=spec['first']+n-1,
                       contract_verified=verified)
                  for n in range(1, spec['maximum']+1)]
        generators.append(dict(key=key, config=spec['config'], title=spec['title'],
                               minimum=spec['minimum'], maximum=spec['maximum'], entry=spec['entry'],
                               entry_rectangle=spec['entry_rect'], end=spec['end'], floors=floors,
                               terminal_enemy=spec['terminal_enemy'], terminal_npc=spec['terminal_npc'],
                               template_actor_ids=spec['actor_ids'], blocked_end=spec['blocked_end'], contract_verified=verified,
                               verification_scope='Source dimensions, stairs and seeded walking/link progression; not a live original quest-ending replay.',
                               live_terminal_return_replay='not recorded for this configuration',
                               placement_limits=[row for row in matrix.get('blockers', []) if row.get('config') == spec['config']]))
    battle_results = []
    for battle in population['scripted_battles']:
        text = battle['command'].strip()
        if text.lower().startswith('encount'):
            text = text[7:].strip()
        args = text.split('|')
        if len(args) < 10:
            continue
        unknown = ([dict(field=2, value=args[2], paired_field_3=args[3])] if args[2] not in ['', '0'] else [])
        unknown += [dict(field=n, value=value) for n, value in enumerate(args[10:], 10) if value not in ['', '0']]
        if unknown:
            battle_results.append(dict(actor=battle['actor'], source=battle['source'], script=battle['script'],
                                       line=battle.get('line'), encounter=battle['encounter'], operands=unknown,
                                       reason='Pinned encounter-handler item/result contract unavailable; native fight remains with its owner, ambiguous victory continuation stays gated.'))
    field_hosts = [dict(source=100, area=area, comparison=read(OUT / 'field-version-comparison.json').get(area+'_window', {}),
                        approach_report='field-approaches.json', scenery='assets/maps/falan/east_region/field-scenery.json')
                   for area in ['east_gate', 'north_coast']]
    technical = []
    for original in event_audit.get('technical_blockers', []):
        row = dict(original)
        row['overridden_actor_ids'] = [str(actor['id']) for actor in row.get('actors', []) if str(actor['id']) in harbor['actions']]
        technical.append(row)
    items = read(ASSETS / 'items.json')
    item_programs = []
    for row in items.get('items', {}).values():
        if not isinstance(row.get('program'), dict):
            continue
        item_programs.append(dict(id=row['id'], name=row['name'], source_line=row['source_itemset_line'],
                                  program=row['program'], acquisition_providers=row.get('providers', [])))
    source_files = ['routes.json', 'population.json', 'items.json', 'dungeon_specs.gd', 'map_index.gd', 'harbor.json']
    snapshot = {str((ASSETS / name).relative_to(ROOT)): hashlib.sha256((ASSETS / name).read_bytes()).hexdigest() for name in source_files}
    runtime_reports = {name: read(OUT / path) for name, path in {
        'normal_east_gate': 'Verification/Recovered/verification.json',
        'shipping': 'Verification/shipping-world.json', 'shipping_boundary_historical': 'Verification/shipping-boundary-world.json',
        'native_formations': 'Verification/battle-runtime.json',
        'held_item_ui': 'Quest Items/quest-bag-review.json', 'held_item_native_battles': 'Quest Items/native-item-battle.json',
        'full_fields': 'Verification/OverseasFields/review.json',
        'village_buildings': 'Village Buildings/review.json', 'village_building_visuals': 'Village Buildings/visual-review.json',
        'village_props': 'Village Props/review.json', 'continental_ground': 'Continental Ground/preservation.json',
        'lektal_annexes': 'Lektal Annexes/review.json', 'komatei_ruin_sections': 'Komatei Ruins/review.json',
        'room_columns_asset_preview': 'Room Columns/preview.json',
        'room_furniture_asset_preview': 'Room Furniture/preview.json',
        'room_furniture_actual': 'Room Furniture/Actual Rooms/review.json',
        'casework_actual': 'Room Casework/Actual Rooms/review.json',
        'native_trees_actual': 'Visual Landmarks/Tree Families/Typed27/Actual Maps Final/review.json',
        'mounted_details_asset_preview': 'Mounted Details/preview.json',
        'mounted_details_actual': 'Mounted Details/Actual Maps/review.json',
        'misc_furniture_asset_preview': 'Misc Furniture/preview.json',
        'market_goods_asset_preview': 'Market Goods/preview.json',
        'misc_market_actual': 'Misc Furniture/Actual Maps/review.json',
        'hourglass_roof_actual': 'Hourglass Studies/Actual Maps/review.json',
        'gold_hourglass_focused_actual': 'Hourglass Studies/Gold Actual/review.json',
        'display_furniture_asset_candidates': 'Display Furniture/preview.json',
        'display_furniture_actual': 'Display Furniture/Actual Maps/review.json',
        'display_furniture_near_actual': 'Display Furniture/Near Actual/review.json',
        'counter_segments_actual': 'Counter Segments/Actual Maps/review.json',
        'mouse_statue_exact_owner': 'Mouse Statue/Publication Candidate/contract.json',
        'mouse_statue_actual': 'Mouse Statue/Actual Maps/review.json',
        'low_prop_camera_contract': 'Display Furniture/Low Prop Camera/contract.json',
        'low_prop_camera_actual': 'Display Furniture/Low Prop Camera/Actual Maps/review.json',
        'mouse_room_pier_contract': 'Mouse Room Piers/Publication/contract.json',
        'mouse_room_pier_actual': 'Mouse Room Piers/Actual Maps/review.json',
        'remaining_generic_boxes': 'Visual Landmarks/Remaining Fallback Audit/final-boxes.json',
        'nature240_actual': 'Visual Landmarks/Nature/Actual Maps/review.json',
        'full_alyut_staged_actual': 'Village Props/Cliff Audit/Alyut Canonical Stage/Stage Review02/actual-review.json',
        'full_alyut_published_actual': 'Village Props/Cliff Audit/Alyut Canonical Stage/Canonical Review/actual-review.json',
        'il_water_walk_private_actual': 'Il Source Completion/Water Walk Candidate/actual-review-clean-03.json',
        'east_export_data_static': 'Verification/export-data-contract.json',
        'landmark_main': 'Visual Landmarks/Final Main/review.json',
        'landmark_continental': 'Visual Landmarks/Final Continental/review.json'}.items()}
    ledger = dict(generated_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  scope='East Gate, eastern Freyja, both inland continents, source-connected quest and shipping branches; separate owned-region boundaries retained.',
                  maps=maps, outdoor_hosts=field_hosts, fixed_connections=fixed, inline_warps=routes['inline_warps'],
                  scripted_connections=routes['event_links'], quest_gates=gates, generators=generators,
                  boundaries=routes['boundaries'], observed_route_report=matrix,
                  contracts=contracts, source_blockers=population.get('blockers', []),
                  event_source_blockers=event_audit.get('source_blockers', []),
                  event_technical_blockers=technical, battle_result_blockers=battle_results,
                  held_item_programs=item_programs, item_use_source_audit=read(OUT / 'Verification/item-source-audit.json'),
                  conditional_item_boundary=read(OUT / 'Version Expansion Source Audit/conditional-item-reference-graph.json'),
                  harbor_boundary_connections=harbor.get('boundary_connections', []),
                  item_battle_technical_limits=['Original item encounters20010–20013 share the existing prepared East native bank. A different regional/legacy skin bank is held before consuming the item; it requires a compatible combined bank contract.'],
                  enemy_item_drop_blockers=read(OUT / 'Source Audit/enemy-item-drop-contracts.json'),
                  npc_service_coverage=read(OUT / 'Source Audit/npc-service-coverage.json'),
                  source_handoff=read(OUT / 'Source Audit/final-source-handoff.json'),
                  runtime_verification=runtime_reports,
                  evidence_freshness={name: source_freshness(report) for name, report in
                                      {'route_matrix': matrix, **contracts, **runtime_reports}.items()},
                  shipping_boundary_supersession='The current main shipping report includes the held West boundary; the separate boundary report is historical.',
                  prepared_source_snapshot=snapshot,
                  source_layout_publication=read(OUT / 'Verification/il-source-publication.json'),
                  source100_context_implementation_gaps=read(OUT / 'Source Audit/source100-context-gaps.json'),
                  source100_field_audit='Runtime Audit/Source100 Completeness/REPORT.md',
                  bank_support_publication=read(OUT / 'Bank Caps/Native Support Proof/published-source.json'),
                  fort_cpu_publication=read(OUT / 'Bank Caps/Fort CPU Candidate/published-source.json'),
                  fort_cpu_published_replay=read(OUT / 'Bank Caps/Fort CPU Candidate/live-array-proof.json'),
                  bank_material_publication=read(OUT / 'Bank Caps/Body Material Candidate/published-source.json'),
                  declared_roofless_contract=read(OUT / 'Verification/roofless-contract.json'),
                  nature_fixed_publication=read(OUT / 'Visual Landmarks/Nature/Owned240/published-source.json'),
                  nature_asset_review=read(OUT / 'Visual Landmarks/Nature/Owned240/VISUAL_DECISIONS.json'),
                  mouse_statue_publication=read(OUT / 'Mouse Statue/Publication Candidate/publication.json'),
                  low_prop_camera_publication=read(OUT / 'Display Furniture/Low Prop Camera/publication.json'),
                  mouse_room_pier_publication=read(OUT / 'Mouse Room Piers/Publication/publication.json'),
                  full_alyut_publication=read(OUT / 'Alyut Publication/published-source.json'),
                  fixed_map_components=read(OUT / 'fixed-map-connections.json'),
                  manual_actor_checks=read(OUT / 'manual-anchor-matrix.json'),
                  map_art_audit=dict(
                      final_generic_branch_audit='Visual Landmarks/Remaining Fallback Audit/final-boxes.json',
                      classic_classification='Visual Landmarks/Remaining Fallback Audit/classic-classification.json',
                      aliased_classification='Visual Landmarks/Remaining Fallback Audit/aliased-01-09-classification.json',
                      aliased_tail_classification='Visual Landmarks/Remaining Fallback Audit/root-aliased-10-14-classification.json',
                      furniture_roles='Visual Landmarks/Remaining Fallback Audit/furniture-roles.json',
                      execution_queue='NEXT_UNFINISHED.md',
                      scope='Native role classification is distinct from implementation and visual acceptance. The execution queue records unfinished families.'),
                  external_quest_state=event_audit.get('unknown_external_conditions', []),
                  limits=['Prepared source data and source-grid checks are distinct from rendered crossings and visual acceptance.',
                          'Seeded random floor topology, hidden/reverse geometry and any interaction-only cutscene stage are explicit adaptations.',
                          'Historical or failed reports remain evidence; only the current successful observations establish verification.'])
    (OUT / 'region-checklist.json').write_text(json.dumps(ledger, ensure_ascii=False, indent=2)+'\n')
    lines = ['# East Gate region ledger', '',
             'This ledger joins pinned map/warp/NPC/event sources with observed checks. It is a work checklist, not a visual-completion certificate.', '',
             f"Source-layout data is complete for {sum(row['source_layout_complete'] for row in maps)} of {len(maps)} fixed maps. Existing owner availability below does not establish completed scenery, original quest behavior or a current route replay.", '',
             'The exhaustive remaining native-art audit and its implementation/review queue are linked from [NEXT_UNFINISHED.md](NEXT_UNFINISHED.md). Asset previews and source checks do not establish actual map placement or visual acceptance.', '',
             'Source100 still requires native floor/object binding recovery and separate original100/2400contexts. The Alyut join currently suppresses original day/night entrances at549,43to16501/16502and overlays two original event actors; see [exact context gaps](Source%20Audit/source100-context-gaps.json). These are unfinished implementation, with source available.', '',
             f"{len(maps)} fixed maps plus both eastern windows of source map100; {len(fixed)} directed static connections; {len(routes['event_links'])} scripted/battle transfers; {len(gates)} condition records; {len(generators)} generators with {sum(s['maximum'] for s in specs.values())} possible floors.", '',
             '## Observed checks', '', '| Check | Assertions | Result |', '|---|---:|---|']
    for name, report in {'route-matrix': matrix, **contracts, **runtime_reports}.items():
        freshness = source_freshness(report)
        result = 'pending or failed'
        if passed(report) and name.endswith('_historical'):
            result = 'historical; superseded by current shipping report'
        elif passed(report):
            result = 'passed; recorded files current' if freshness['current'] else 'passed on older source; refresh pending' if freshness['current'] is False else 'passed; no source fingerprint recorded'
        lines.append(f"| {name} | {int(report.get('checks', 0))} | {result} |")
    lines += ['', 'Detailed entrances, returns, gates, source lines, all possible floors and actual blockers are retained in [region-checklist.json](region-checklist.json).', '',
              f"The held-item audit includes {len(items.get('items', {}))} source item definitions with recorded or candidate providers and {len(item_programs)} original use programs. Candidate enemy-drop operands do not establish runtime acquisition. The conditional Mirror/Floor101 closure is recorded separately; its entry has no proven East-region route.", '',
              '## Every fixed map', '', '| Source map | Name | Entrances / exits | Actors | Source preparation | Owner availability |', '|---:|---|---:|---:|---|---|']
    for row in maps:
        owner = 'available in recorded route check' if row['observed'].get('available') else 'pending or unavailable'
        lines.append(f"| {row['id']} | {row['title'].replace('|', '/')} | {row['incoming']} / {row['outgoing']} | {row['actors']} | {row['active_layout']} | {owner} |")
    lines += ['', '## Every generated branch', '', '| Config | Name | Floors | Entry source | End source | Contract |', '|---:|---|---|---|---|---|']
    for row in generators:
        lines.append(f"| {row['config']} | {row['title']} | {row['minimum']}–{row['maximum']} | {row['entry']} | {row['end'] or 'source terminal'} | {'verified' if row['contract_verified'] else 'pending'} |")
    lines += ['', '## Verification limits and blockers', '',
              'Source blockers, unsupported gameplay/state contracts and other-goal boundary handoffs are recorded separately in the JSON ledger. A failed or unavailable source route remains gated; no quest payment or item exchange authorizes a fallback room.', '',
              'Rendered routes, normal/second-angle landmark review, inferred visuals and the exact next unfinished item belong in the delivery report after the current camera checks finish.']
    (OUT / 'REGION_CHECKLIST.md').write_text('\n'.join(lines)+'\n')
    print(f'EAST_REGION_LEDGER maps={len(maps)} fixed={len(fixed)} gates={len(gates)} generators={len(generators)}')


if __name__ == '__main__':
    main()
