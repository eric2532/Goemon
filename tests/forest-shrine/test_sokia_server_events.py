"""Source preservation for the new server-map NPC package; no gameplay approximation claims."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import prepare_sokia_server_events as prep


class ServerNPCs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data, cls.atlas = prep.prepare()

    def test_source_membership_and_unknown_release_ids(self):
        maps = {int(row['id']) for row in json.loads((prep.OUT / 'catalog.json').read_text())['maps'].values()}
        raw = {row[3]: row for row in prep.rows('npc.txt')
               if len(row) == 25 and row[8].isdigit() and int(row[8]) in maps
               and row[0] not in ['Warp', 'HouseWarp2'] and row[6] == '1'}
        expected = set(raw) - {'807215', '807216'}
        self.assertEqual(set(self.data['actors']), expected)
        self.assertEqual({r['id'] for r in self.data['excluded']}, {'807215', '807216'})
        for ident, actor in self.data['actors'].items():
            self.assertEqual(actor['raw'], raw[ident])
            self.assertEqual(actor['cell'], list(map(int, raw[ident][9:11])))
            self.assertNotIn('unbounded_source_quest_items', actor)
        self.assertEqual(self.data['actors']['62017']['messages'],
                         [r[1].replace('\\n', '\n') for key in ['3040', '3041', '3042']
                          for r in prep.rows('msg.txt') if r[0] == key])

    def test_every_prepared_crop_matches_its_original_pixels_and_origin(self):
        sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
        import cg_assets as cg
        import cg_library as lib
        lookup = lib.serial_index()
        for art in self.data['art'].values():
            if art['key'].startswith('graphic:'):
                g = lookup[int(art['key'].split(':')[1])]
                image = lib.image_from_record(g['pack'], g['row']); ox, oy = g['x'], g['y']
            else:
                _, _, clips = cg.actor(art['key'])
                clip = next(c for c in clips if c['action'] == 0 and c['direction'] == art['source_direction'])
                image, ox, oy = cg.frame_parts(art['key'], clip['index'], 0)
            box = image.getbbox(); crop = image.crop(box)
            x, y, w, h = art['rect']
            self.assertEqual(self.atlas.crop((x, y, x+w, y+h)).tobytes(), crop.tobytes())
            self.assertEqual(art['origin'], [ox+box[0], oy+box[1]])
            self.assertEqual(art['rgba_sha256'], hashlib.sha256(crop.tobytes()).hexdigest())

    def test_pinned_scripts_keep_their_original_predicates(self):
        for name, script in self.data['scripts'].items():
            raw = (prep.SOURCE / name).read_bytes()
            self.assertEqual(script['sha256'], hashlib.sha256(raw).hexdigest())
            self.assertEqual(script['sha256'], self.data['source_provenance'][name]['sha256'])
        conditions = [block['condition'] for script in self.data['scripts'].values() for block in script['blocks']]
        self.assertTrue(any('SkillLevel 225' in row for row in conditions))
        self.assertTrue(any('ItemCreateTime 18435 >= 41' in row for row in conditions))
        self.assertTrue(any('Group >= 2' in row for row in conditions))


if __name__ == '__main__':
    unittest.main()
