"""The coverage audit must detect missing rare groups and never equate crop overlap with full coverage."""
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('coverage', ROOT / 'tools/audit_sokia_venoa_coverage.py')
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)
GRAPH_SPEC = importlib.util.spec_from_file_location('source_graph', ROOT / 'tools/recover_sokia_source_graph.py')
graph_tool = importlib.util.module_from_spec(GRAPH_SPEC)
GRAPH_SPEC.loader.exec_module(graph_tool)


class CoverageTest(unittest.TestCase):
    def test_dragon_fixed_zones_do_not_certify_the72_generated_floors(self):
        report=audit.audit()
        zones=[z for z in report['zones'] if z['id'] in [2006,2007]]
        self.assertEqual(len(zones),2)
        for zone in zones:
            match=[c for c in zone['other_adapter_comparisons'] if c['path'].endswith('sokia_dragon_summit/encounters.json')]
            self.assertEqual(len(match),1); self.assertEqual(match[0]['status'],'prepared_table_match')
            self.assertEqual([m[1:3] for m in zone['source_members']['2013']],[[2,58]]*4)
        self.assertFalse(any(f.get('source_config') in [108,109,110,111,309] for f in report['runtime_generated_floors']))
        self.assertFalse(report['completion'])

    def test_desert_temple_coverage_counts_the_union_without_certifying_generated_maps(self):
        report=audit.audit()
        zones=[z for z in report['zones'] if 13016<=z['map']<=13022]
        self.assertEqual(len(zones),9)
        for zone in zones:
            matches=[c for c in zone['other_adapter_comparisons'] if c['path'].endswith('sokia_desert_temple/encounters.json')]
            self.assertEqual(len(matches),1)
            self.assertEqual(matches[0]['status'],'prepared_table_match')
            self.assertFalse(matches[0]['runtime_dispatch_verified'])
        unmatched=sum(z['status']!='prepared_table_match' and not any(c['status']=='prepared_table_match'
            for c in z['other_adapter_comparisons']) for z in report['zones'])
        self.assertEqual(report['summary']['zones_without_matching_inspected_adapter'],unmatched)
        self.assertFalse(any(f.get('source_config')==303 for f in report['runtime_generated_floors']))
        self.assertFalse(report['completion'])

    def test_raw_source_validation_rejects_the_old_utf8_transcode(self):
        name='EV_ijk_6117.txt';raw=(graph_tool.DURABLE/name).read_bytes()
        self.assertTrue(graph_tool.source_blob_matches(name,raw))
        self.assertFalse(graph_tool.source_blob_matches(name,raw.decode('gb18030').encode('utf-8')))

    def test_generated_templates_retain_quest_actors_and_repeated_fight_slots(self):
        configs=graph_tool.rows((graph_tool.DURABLE/'dungeonconf.txt').read_bytes())
        prayer=graph_tool.generated_templates(configs,{16507})
        self.assertEqual(prayer,[dict(config=301,slot=0,npc='6303',refresh=100,field=101),
                                 dict(config=301,slot=1,npc='6304',refresh=100,field=103)])
        doctor=next(r for r in configs if r[3]=='5')
        repeated=graph_tool.generated_templates([doctor],{int(doctor[9])})
        self.assertEqual([r['npc'] for r in repeated].count('80051'),5)
        self.assertEqual(len({r['slot'] for r in repeated}),8)

    def test_source_ai_slots_keep_zero_conditions_and_skip_blank_slots(self):
        raw=['9067']+['']*40
        raw[1]='0';raw[11]='0';raw[21]='15001';raw[31]='20'
        raw[22]='404';raw[32]='50' # A blank condition does not activate this slot.
        actions=audit.source_ai_actions(raw,{'15001':['逃跑','','','15001']})
        self.assertEqual(len(actions),1)
        self.assertEqual({key:actions[0][key] for key in ('slot','condition','target_type','technique','rate','technique_name')},
                         dict(slot=0,condition=0,target_type=0,technique=15001,rate=20,technique_name='逃跑'))

    def test_encount_operands_resolve_encounters_before_groups(self):
        encounters = {r[0]: r for r in audit.rows('encount.txt')}
        parameters = '|'.join(['2', '0,15526,47,7'] + [''] * 7 + ['12020'])
        fight = graph_tool.fight_parameters(parameters, encounters)
        self.assertEqual(fight['declared_encounter_ids'], [12020])
        self.assertEqual(fight['resolved_group_ids'], ['12098'])
        self.assertEqual(fight['post_battle_warp'], '0,15526,47,7')
        commands = list(graph_tool.commands(b'block\n Encount ' + parameters.encode() + b'\n'))
        self.assertEqual(len(commands), 1)
        self.assertEqual(commands[0]['line'], 2)

    def test_linked_encounters_resolve_once_even_with_a_cycle(self):
        def row(number, follow, group):
            return [str(number)] + [''] * 11 + [str(follow), '100', group] + [''] * 9 + ['1'] + [''] * 9
        fight = graph_tool.fight_parameters('|||||||||1', {'1': row(1, 2, '11'), '2': row(2, 1, '12')})
        self.assertEqual(fight['resolved_group_ids'], ['11', '12'])
        self.assertEqual(len(fight['resolved_encounters']), 2)

    def test_mandatory_member_flags_are_distinct_from_item_gates(self):
        groups = {r[2]: r for r in audit.rows('group.txt')}
        enemies = {r[2]: r for r in audit.rows('enemy.txt')}
        bases = {r[1]: r for r in audit.rows('enemybase.txt')}
        group = groups['12098']
        self.assertEqual(group[3:5], ['-1', '-1'])
        members = audit.source_identities(group, enemies, bases)
        self.assertTrue(all(m['mandatory'] for m in members))
        self.assertEqual([m['count'] for m in members], [[1, 1], [2, 2], [2, 2]])

    def test_boss_related_forms_keep_distinct_source_identities(self):
        enemies = {r[2]: r for r in audit.rows('enemy.txt')}
        bases = {r[1]: r for r in audit.rows('enemybase.txt')}
        result = graph_tool.related_enemies({'9096'}, enemies, bases)
        self.assertEqual(set(result['enemies']), {'9097', '9098'})
        self.assertEqual({r['appearance'] for r in result['enemies'].values()}, {100527})
        self.assertEqual({r['enemy_raw'][3] for r in result['enemies'].values()}, {'1027', '1028'})

    def test_overlapping_crops_count_once_and_retain_uncovered_cells(self):
        self.assertEqual(audit.covered_cells([0, 0, 4, 1], [[0, 0, 3, 2], [2, 0, 2, 2]]), 8)

    def test_source_members_preserve_duplicate_slots_and_ignore_zero_weight(self):
        group = ['', '', '', '', '', 'a', 'a', 'b'] + ['0'] * 7 + ['2', '3', '0'] + ['0'] * 7
        self.assertEqual(audit.source_members(group, {'a': ['', '', '', 'base', '2', '4']},
                                             {'base': [''] * 30 + ['101020']}),
                         [[101020, 2, 4, 2], [101020, 2, 4, 3]])

    def test_missing_rare_group_and_changed_levels_are_reported(self):
        raw = ['1', '', '', '300', '0', '0', '9', '9', '1', '3', '6', '2', '', '',
               'common', 'rare'] + [''] * 8 + ['99', '1'] + [''] * 8
        source = ['name', 'order', 'common', '-1', '-1', 'a'] + ['0'] * 9 + ['1'] + ['0'] * 9
        zone = dict(map=300, bounds=[0, 0, 9, 9], probability=[1, 3], maximum=6,
                    priority=2, groups=[['common', 99]])
        groups = {'common': dict(members=[[0, 3, 4, 1]], order='order', raw=source)}
        differences = audit.zone_comparison(raw, zone, groups, [{'id': 101020}],
                                            {'common': source}, {'a': ['', '', '', 'base', '2', '4']},
                                            {'base': [''] * 30 + ['101020']})
        self.assertEqual({r['kind'] for r in differences}, {'zone_group_weights', 'members_levels_or_weights'})

    def test_enemy_identity_is_retained_when_appearances_match(self):
        group = ['', '', '', '', '', 'ordinary', 'rare'] + ['0'] * 8 + ['1', '1'] + ['0'] * 8
        enemies = {key: [key + ' name', '', key, 'base', '2', '4'] for key in ('ordinary', 'rare')}
        identities = audit.source_identities(group, enemies, {'base': ['mouse', 'base'] + [''] * 28 + ['101020']})
        self.assertEqual([m['enemy_id'] for m in identities], ['ordinary', 'rare'])
        self.assertEqual([m['appearance'] for m in identities], [101020, 101020])

    def test_live_inventory_cannot_certify_unverified_goal(self):
        report = audit.audit()
        zones = {row['id']: row for row in report['zones']}
        for ident in (7035, 7036, 7038, 7040, 7041, 7042, 7043):
            self.assertEqual(zones[ident]['status'], 'prepared_table_match')
            self.assertFalse(zones[ident]['runtime_dispatch_verified'])
        self.assertEqual(zones[7040]['source_members']['7028'],
                         [[101422, 25, 27, 10], [101422, 1, 1, 1]])
        self.assertEqual(zones[7043]['source_members']['7030'],
                         [[101503, 25, 27, 10], [101503, 1, 1, 1]])
        self.assertFalse(report['completion'])
        self.assertEqual(sum(r['map'] == 300 for r in report['zones']), 58)
        self.assertEqual(sum(r['map'] == 100 for r in report['zones']), 56)
        self.assertTrue(all(not r['floor_roster_verified'] for r in report['maps']))
        self.assertTrue({16507, 16508}.issubset({r['map'] for r in report['maps']}))
        self.assertEqual([r['runtime_floor'] for r in report['runtime_generated_floors'][:6]], list(range(30101, 30107)))
        cape = report['runtime_generated_floors'][6:]
        self.assertEqual(len(cape), 20)
        self.assertEqual({r['source_config'] for r in cape}, {305, 306})
        self.assertTrue(all(r['original_map_id'] is None for r in report['runtime_generated_floors']))
        self.assertTrue(all(row['status'] != 'gate_contract_unresolved' for row in report['missing_maps']))
        self.assertTrue({13503, 13504, 15517, 15520, 15524, 15525, 23603, 23604}.issubset(
            {row['map'] for row in report['unverified_map_gate_contracts']}))
        graph = json.loads((audit.OUTPUT / 'Source events/source-graph.json').read_text())
        self.assertTrue(set(graph['groups']).issubset(report['source_group_records']))
        self.assertEqual(report['declared_scripted_fights'], graph['fight_triggers'])
        self.assertEqual(report['unresolved_scripted_group_references'], [])
        self.assertIn('9097', report['enemy_ai_source']['records']['9097']['source_enemy_ids'])
        self.assertIn('9098', report['enemy_ai_source']['records']['9098']['source_enemy_ids'])
        self.assertTrue(all(report['source_group_records'][gid]['source_graph_candidate']
                            for gid in graph['groups']))
        maps = {row['map']: row for row in report['maps']}
        for fight in graph['fight_triggers']:
            row = maps[fight['source_map']]
            self.assertIn(fight, row['declared_scripted_fights'])
            for gid in fight.get('resolved_group_ids', []):
                self.assertIn(str(gid), row['source_group_ids'])
                for member in report['source_group_records'][str(gid)]['members']:
                    self.assertIn(member['enemy_id'], row['source_enemy_ids'])
        southwest = report['venoa_outdoor_evidence']
        self.assertEqual(southwest['source_envelopes']['after']['venoa_component_outside'], 0)
        full = southwest['full_source_comparison']
        self.assertFalse(full['activated'])
        self.assertFalse(full['complete'])
        self.assertGreater(full['union']['envelope']['venoa_component_outside'], 0)
        self.assertGreater(full['source_art']['no_matching_inspected_input_declaration'], 0)
        self.assertFalse(report['completion'])


if __name__ == '__main__':
    unittest.main()
