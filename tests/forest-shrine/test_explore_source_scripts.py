"""Keep pinned source commands exact when original comments have invalid bytes."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from prepare_east_region_population import compile_script
from audit_explore_access import housing_routes, source_layout_complete, script_warps, active_source_events


class SourceScriptsTest(unittest.TestCase):
    def test_required_native_source_routes_keep_existing_city_stones(self):
        events=active_source_events()
        self.assertEqual(events['actors']['1000:6081']['cell'],[107,31])
        self.assertEqual(events['actors']['2100:6094']['source'],2100)
        self.assertTrue(events['actors']['1000:11']['explore_inline'])
        self.assertEqual(events['actors']['1000:11']['script'],'0|21005|18|34|15|18380|-1|0|0|1193|3|14|')
        self.assertEqual(script_warps(events['scripts']['EV_ijk_6094.txt']),[(0,15501,16,9)])
        self.assertTrue(all(events['actors']['1000:'+str(i)]['access_owner']=='falan_travel_stones'for i in range(5000,5006)))
        self.assertTrue(all(not row['type'].startswith('#')for row in events['actors'].values()))
        self.assertTrue(all(row['dialogue_owner']=='explore_source'for row in events['actors'].values()))
        self.assertEqual(len(events['automatic']),sum(row['explore_fight']and (row['type']in ['WatchEvent','WatchEx']or row['type']=='StandEnemy'and not row.get('battle_owner'))for row in events['actors'].values()))
        inline=[row for row in events['actors'].values()if row['type']=='StandEnemy']
        self.assertEqual(len(inline),12)
        self.assertEqual(events['actors']['400:5306']['battle_owner'],'regional:zombie')
        self.assertEqual(events['actors']['16520:81012']['battle_owner'],'regional:lizard')
        self.assertEqual(events['actors']['23001:81001']['battle_owner'],'falken_slot')
        self.assertEqual(events['actors']['24068:81010']['battle_owner'],'frostpass_slot')
        self.assertNotIn(24068,events['bank_sources'])
        self.assertTrue(events['actors']['4100:5255']['explore_npc'])
        self.assertEqual(events['actors']['4100:5255']['art_reuse'],'14546:0')
        self.assertIn(16511,events['bank_sources'])
        self.assertNotIn(16520,events['bank_sources'])
        self.assertNotIn(23001,events['bank_sources'])
        self.assertEqual(events['actors']['16511:81002']['script'],'3|0,16512,26,26||0|6504||||0|12000|0|0|||||||')

    def test_static_warp_choices_and_comments_preserve_every_destination(self):
        lines=[[1,' Warp 0,1405,97,97,0,1412,97,97,0,1413,97,97'],[2,' Warp 0,32047,35,12 ## original comment'],[3,' Warp 0,30313,30,4 1'],[4,'Warp,1521,49,65']]
        self.assertEqual(script_warps({'lines':lines}),[(0,1405,97,97),(0,1412,97,97),(0,1413,97,97),(0,32047,35,12)])
        self.assertEqual(lines[1][1],' Warp 0,32047,35,12 ## original comment')

    def test_arena_return_repair_is_scoped_to_exact_pinned_commands(self):
        from audit_explore_access import ARENA_RETURN_REPAIRS
        folder=ROOT/'assets/references/crossgate_sokia/events'
        for sha,name in ARENA_RETURN_REPAIRS.items():
            original=(folder/name).read_bytes();program=compile_script(original)
            self.assertEqual(program['sha256'],sha)
            self.assertIn((0,1496,15,7),script_warps(program))
            self.assertEqual(next(t for n,t in program['lines']if n==13).strip(),'Warp 0,1496.15,7')
            self.assertEqual((folder/name).read_bytes(),original)
        self.assertEqual(script_warps({'lines':[[13,'Warp 0,1496.15,7']]}),[])
        self.assertEqual(script_warps({'sha256':next(iter(ARENA_RETURN_REPAIRS)),'lines':[[12,'Warp 0,1496.15,7']]}),[])
        for name in ['EV_miz_col14.txt','EV_miz_col16.txt','EV_miz_col32.txt']:
            program=compile_script((folder/name).read_bytes())
            self.assertEqual(next(t for n,t in program['lines']if n==13).strip(),'Warp 0,1496,15,7')

    def test_completed_source_cells_are_distinguished_from_partial_snapshots(self):
        self.assertTrue(source_layout_complete(dict(recorded=2439, restored_cells=40, cells=2500, restored_raw='preserved map', completion_reference={'sha256': 'pinned'}, reference_compared_cells=2439)))
        self.assertFalse(source_layout_complete(dict(recorded=2321, cells=2500)))
        self.assertFalse(source_layout_complete(dict(recorded=2500, cells=2500, layout_complete=False)))

    def test_housing_uses_pinned_room_and_threshold_without_a_property_action(self):
        rows = housing_routes()
        self.assertEqual(len(rows), 40)
        by_actor = {row['actor']: row for row in rows}
        self.assertEqual((by_actor['991160']['target'], by_actor['991160']['landing']), (1806, [1, 9]))
        self.assertEqual((by_actor['770960']['target'], by_actor['770960']['landing']), (1850, [5, 6]))
        self.assertTrue(all(row['type'] == 'HouseWarp2' and not row['victory_only'] for row in rows))

    def test_frontier_commands_and_source_hashes_are_preserved(self):
        source = ROOT / 'assets/references/crossgate_sokia/events'
        pins = json.loads((source / 'frontier-references.json').read_text())
        malformed_comments = 0
        for pin in pins:
            raw = (source / pin['file']).read_bytes()
            with self.subTest(script=pin['file']):
                self.assertEqual(hashlib.sha256(raw).hexdigest(), pin['sha256'])
                compiled = compile_script(raw)
                self.assertEqual(compiled['sha256'], pin['sha256'])
                try:
                    text = raw.decode('gb18030')
                except UnicodeDecodeError:
                    for line in raw.splitlines():
                        try:
                            line.decode('gb18030')
                        except UnicodeDecodeError:
                            self.assertTrue(line.lstrip().startswith(b'#'))
                            malformed_comments += 1
                    continue
                previous = [[i, line] for i, line in enumerate(text.splitlines(), 1)
                            if line.strip() and not line.lstrip().startswith('#')]
                self.assertEqual(compiled['lines'], previous)
        self.assertGreaterEqual(malformed_comments, 3)

    def test_invalid_command_bytes_are_rejected(self):
        with self.assertRaises(UnicodeDecodeError):
            compile_script(b'\tWindow 100\x80\r\n')

    def test_absent_original_script_is_a_blocked_actor_without_a_program(self):
        events = json.loads((ROOT / 'assets/maps/original_crossgate/explore_recovered/events/data.json').read_text())
        actor = events['actors']['1101823']
        script = actor['raw'][24]
        self.assertEqual(script, 'vespa_gm_1101823.txt')
        self.assertNotIn(script, events['scripts'])
        self.assertEqual(actor['raw'][0], 'event')
        self.assertEqual(actor['type'], 'Event')
        self.assertEqual(actor['quest_action'], 'sokia_server:1101823')
        self.assertTrue(actor['messages'][0].startswith('原始事件腳本尚待恢復'))
        self.assertTrue(any(row['script'] == script and row['actor'] == actor['id'] for row in events['script_blockers']))


if __name__ == '__main__':
    unittest.main()
