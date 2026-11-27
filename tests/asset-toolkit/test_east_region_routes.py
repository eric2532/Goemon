import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('east_routes', ROOT / 'tools/prepare_east_region_routes.py')
routes = importlib.util.module_from_spec(spec); spec.loader.exec_module(routes)


class EastRoutesTest(unittest.TestCase):
    def test_gates_battle_victories_and_boundary_housing(self):
        graph = dict(maps=[2000,2801,11033,11032,47017,47018], boundaries=[1541], links=[
            dict(kind='fixed warp',source=11033,cell=[21,18],target=11032,landing=[7,9]),
            dict(kind='fixed warp',source=2000,cell=[11,12],target=1541,landing=[3,4]),
            dict(kind='HouseWarp2',source=2000,cell=[20,21],target=2801,landing=None),
            dict(kind='fixed warp',source=2801,cell=[8,9],target=2000,landing=[20,22]),
            dict(kind='inline StandEnemy',source=47017,cell=[1,2],target=47018,landing=[3,4],actor=80001),
        ])
        result = routes.compile_graphs([graph], {'actors':[]}, {})
        self.assertNotIn([11033,21,18,11032,7,9], result['fixed'])
        self.assertIn([2000,11,12,1541,3,4], result['fixed'])
        self.assertIn([2000,20,21,2801,8,9], result['fixed'])
        self.assertEqual(result['event_links'][0]['kind'], 'inline StandEnemy')
        self.assertNotIn([47017,1,2,47018,3,4], result['fixed'])
        self.assertEqual(len(result['gated_static_rows']),1)

    def test_phase_masks_and_watch_bounds_are_preserved(self):
        graph = dict(maps=[11016,11017], boundaries=[100], links=[
            dict(kind='inline Warp',source=100,cell=[665,184],target=11016,landing=[16,19],actor=0,raw='0|11016|16|19|3||0|0|'),
            dict(kind='inline Warp',source=100,cell=[665,184],target=11017,landing=[16,19],actor=1,raw='0|11017|16|19|12||0|0|')])
        raw=['']*25;raw[18]='60000'
        actor=dict(id='42',source=11016,cell=[40,40],type='WatchEvent',script='watch.txt',raw=raw,source_line=4)
        population=dict(actors=[actor], scripts={'watch.txt':dict(lines=[[3,'block XPos == 38 && YPos >= 39 && YPos < 42']])})
        result=routes.compile_graphs([graph],population,{})
        self.assertEqual([r['time_mask'] for r in result['inline_warps']],[3,12])
        self.assertEqual(result['fixed'],[])
        self.assertEqual(result['automatic'][0]['bounds'],[38,39,40,41])
        self.assertEqual(result['automatic'][0]['cooldown_ms'],60000)

    def test_goral_inline_relocations_remain_battle_metadata(self):
        graph=dict(maps=[dict(id=47017),dict(id=47018)], boundaries=[], edges=[
            dict(kind='inline_encounter_victory',map=47017,cell=[1,2],target=47018,arrival=[3,4],npc_id=12)])
        result=routes.compile_graphs([graph], {'actors':[]}, {})
        self.assertEqual(result['fixed'],[])
        self.assertEqual(result['event_links'][0]['actor'],12)


if __name__ == '__main__':
    unittest.main()
