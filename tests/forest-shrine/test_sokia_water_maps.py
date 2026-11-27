"""Exact source completion and rare-identity checks for the staged Water Cave branch."""
from pathlib import Path
import base64
import hashlib
import sys
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import prepare_sokia_water_maps as prep
from prepare_east_region_maps import active_raw, reference_map


class WaterMaps(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog, cls.encounters, cls.npcs, cls.images, cls.proof = prep.prepare()

    def test_all_recorded_cells_and_every_client_marker_are_preserved(self):
        sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
        import cg_library as lib
        for row in list(self.catalog['maps'].values())+list(self.catalog['layout_overrides'].values()):
            raw = zlib.decompress(base64.b64decode(row['raw']))
            final = active_raw(row); w, h, floor, objects, flags = lib.parse_map(raw)
            fw, fh, merged_floor, merged_objects, merged_flags = lib.parse_map(final)
            reference = (prep.SOURCE / row['layout_reference']['file']).read_bytes()
            _, _, expected, _ = reference_map(reference, row['id'])
            self.assertEqual((fw, fh), (w, h)); self.assertEqual(merged_flags, flags)
            if row['id']==13502:
                expected=list(expected);expected[w*h+24*w+45]=17953
                self.assertEqual(row['client_event_variations'],[dict(cell=[45,24],client=[7903,17953],server=[7903,0])])
            self.assertEqual(tuple(merged_floor + merged_objects), tuple(expected))
            for i, flag in enumerate(flags):
                if flag & 0xc000:
                    self.assertEqual((merged_floor[i], merged_objects[i]), (floor[i], objects[i]))
            self.assertFalse(row['sokia_visual_only'])
        self.assertEqual(sum(r['completion']['completed'] for r in self.proof['maps']), 5896)

    def test_new_atlas_rectangles_retain_every_original_rgba_pixel(self):
        sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
        import cg_library as lib
        lookup = lib.serial_index()
        self.assertEqual(len(self.catalog['graphics']), 43)
        for serial, graphic in self.catalog['graphics'].items():
            native = lookup[int(serial)]; image = lib.image_from_record(native['pack'], native['row'])
            x, y, w, h = graphic['rect']; page = self.images[f'atlas-{graphic["page"]}.png']
            self.assertEqual(page.crop((x, y, x+w, y+h)).tobytes(), image.tobytes())
            self.assertEqual(graphic['origin'], [native['x'], native['y']])
            self.assertEqual(graphic['rgba_sha256'], hashlib.sha256(image.tobytes()).hexdigest())

    def test_rare_overlay_levels_weights_and_distinct_enemy_ids_survive(self):
        zones = {row['id']: row for row in self.encounters['zones']}
        for ident, gid, eid in [(7040, 'server:7028', 7020), (7043, 'server:7030', 7022)]:
            zone = zones[ident]; group = self.encounters['groups'][gid]
            self.assertEqual(zone['map'], 13507); self.assertEqual(zone['priority'], 10)
            self.assertEqual(zone['groups'][-1], [gid, 1]); self.assertEqual([row[1] for row in zone['groups'][:3]], [10, 10, 10])
            self.assertEqual(group['members'][1][1:4], [1, 1, 1])
            self.assertEqual([row[3] for row in group['members']], [10, 1])
            self.assertEqual(group['details'][1]['enemy_id'], eid)
            self.assertEqual(group['details'][0]['appearance'], group['details'][1]['appearance'])
        self.assertEqual({int(row['source']) for row in self.npcs['actors'].values()}, prep.IDS)

    def test_continuous_cliff_context_keeps_voids_and_opaque_source_paint_separate(self):
        data = self.catalog['source_cliffs']; profiles = set(map(int, data['profiles'])); voids = set(data['void_source_fragments'])
        self.assertFalse(profiles & voids); self.assertEqual(profiles | voids, {n for first in prep.CLIFF_FAMILIES for n in range(first,first+36)})
        self.assertFalse(voids);self.assertEqual(len(data['sparse_visible_fragments']),58)
        self.assertTrue(set(data['sparse_visible_fragments'])<=profiles)
        self.assertGreater(data['profiles']['13965']['height'],3)
        page = self.images['atlas-0.png']
        for key, profile in data['profiles'].items():
            self.assertEqual(profile['rgba_sha256'], data['graphics'][key]['rgba_sha256'])
        for family in [first+offset for first in prep.CLIFF_FAMILIES for offset in [0,12,24]]:
            x,y,w,h = data['wall_tiles'][str(family)]
            self.assertEqual(page.crop((x,y,x+w,y+h)).getchannel('A').getextrema(), (255,255))
            self.assertIn(data['wall_paint_sources'][str(family)]['source_serial'], range(family,family+12))

    def test_client_trigger_variation_keeps_all_unverified_warp_operands(self):
        row=next(r for r in self.proof['guarded_warp_actors'] if r['id']=='13' and r['source_map']==13502)
        self.assertEqual(row['cell'],[45,24]);self.assertEqual(row['graphic'],17953)
        self.assertEqual(row['parameters'],'0|13503|11|64|15|18182|-1|0|0|13503|11|64|')
        self.assertEqual(set(self.proof['branch_maps']),set(range(13500,13516)))


if __name__ == '__main__':
    unittest.main()
