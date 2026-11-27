"""Source map/rare-roster preservation, separate from future gameplay review."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
SPEC=importlib.util.spec_from_file_location('trial',ROOT/'tools/prepare_freyja_trial_caves.py')
prep=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(prep)


class TrialSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog,cls.roster,cls.npcs,cls.images,cls.proof=prep.prepare()

    def test_recorded_cells_flags_and_completed_planes_match_sources(self):
        import cg_library as lib
        from prepare_east_region_maps import active_raw
        self.assertEqual({m['id'] for m in self.catalog['maps'].values()},prep.IDS)
        self.assertEqual(sum(m['restored_cells'] for m in self.catalog['maps'].values()),545)
        for row in self.catalog['maps'].values():
            raw=active_raw(dict(raw=row['raw']));done=active_raw(row)
            w,h,f,o,flags=lib.parse_map(raw);_,_,df,do,dflags=lib.parse_map(done)
            self.assertEqual(flags,dflags)
            server=(prep.SOURCE/row['layout_reference']['file']).read_bytes()
            _,_,values,_=prep.reference_map(server,row['id'])
            self.assertEqual(tuple(df)+tuple(do),tuple(values))
            for i,flag in enumerate(flags):
                if flag&0xc000:self.assertEqual((df[i],do[i]),(f[i],o[i]))
            self.assertTrue(row['sokia_visual_only'])

    def test_existing_graphics_are_reused_and_catalogs_untouched(self):
        self.assertFalse(self.catalog['graphics'])
        self.assertEqual(len(self.proof['reused_graphics']),191)
        self.assertEqual(self.proof['original_graphics_repacked'],0)
        self.assertEqual(len(self.catalog['solid_pages']),len(self.catalog['pages']))
        for path,expected in self.proof['protected_catalog_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),expected)

    def test_small_cliff_tiers_keep_original_profiles_and_opaque_paint(self):
        cliffs=self.catalog['source_cliffs'];all_ids={n for first in [13432,13468]for n in range(first,first+36)}
        profiles=set(map(int,cliffs['profiles']));voids=set(cliffs['void_source_fragments'])
        self.assertFalse(profiles&voids);self.assertEqual(profiles|voids,all_ids)
        self.assertTrue(set(cliffs['sparse_visible_fragments'])<=profiles)
        for key,p in cliffs['profiles'].items():self.assertEqual(p['rgba_sha256'],cliffs['graphics'][key]['rgba_sha256'])
        for family in [13432,13444,13456,13468,13480,13492]:
            x,y,w,h=cliffs['wall_tiles'][str(family)]
            self.assertEqual(self.images['cliff-paint.png'].crop((x,y,x+w,y+h)).getchannel('A').getextrema(),(255,255))
            source=cliffs['wall_paint_sources'][str(family)]
            self.assertLessEqual(source['body_patch'][3]-source['body_patch'][1],64)

    def test_rare_ids_mixed_groups_caps_levels_and_names_stay_distinct(self):
        zones={z['id']:z for z in self.roster['zones']};groups=self.roster['groups']
        self.assertEqual(len(zones),8);self.assertEqual(len(groups),4)
        self.assertEqual(zones[5000]['maximum'],2);self.assertEqual(zones[5002]['maximum'],4)
        rare_bat=groups['trial:5000'];rare_spider=groups['trial:5002']
        self.assertEqual([m['enemy_id']for m in rare_bat['source_members']],['5001','5000'])
        self.assertEqual(rare_bat['members'][1][1:],[1,1,1])
        self.assertEqual(rare_bat['source_members'][1]['count'],[1,1])
        self.assertEqual([m['enemy_id']for m in rare_spider['source_members']],['5001','5003','5002'])
        self.assertEqual(rare_spider['members'][2][1:3],[1,1])
        self.assertEqual([d['name']for d in rare_spider['details']],['大蝙蝠','火蜘蛛','火蜘蛛'])
        self.assertEqual({self.roster['species'][m[0]]['bank'] for m in rare_spider['members']},{'companion','east_region'})
        self.assertEqual({r['id']:r['source_key'] for r in self.roster['art_contracts']},
                         {101250:'original:2853',101332:'original:2874'})

    def test_original_entrance_and_npc_release_boundaries_are_explicit(self):
        ports=self.proof['branch_boundary_ports']
        self.assertIn(dict(source_map=100,cell=[351,145],target_map=11013,arrival=[12,29],authority='existing pinned fixed-port reference; direction preserved'),ports)
        self.assertEqual(len(self.npcs['actors']),6)
        self.assertEqual({a['id']for a in self.npcs['excluded']},{'991029','1102723','1102724'})
        for actor in self.npcs['actors'].values():
            self.assertEqual(actor['cell'],list(map(int,actor['raw'][9:11])))
            if actor['script'].endswith('.txt'):
                proof=self.npcs['source_provenance'][actor['script']]
                self.assertEqual(self.npcs['scripts'][actor['script']]['sha256'],proof['sha256'])
        self.assertFalse(self.proof['scripted_fights'])
        self.assertEqual(self.proof['geographically_unverified_layouts'][0]['id'],11012)
        self.assertNotIn(11012,prep.IDS)


if __name__=='__main__':unittest.main()
