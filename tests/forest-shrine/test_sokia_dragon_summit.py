"""Complete Dragon/Summit source planes, roster identity and existing-owner preservation."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools')); sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
import cg_assets as cg
import cg_library as lib
import prepare_sokia_dragon_summit as prep
from prepare_east_region_maps import active_raw
from prepare_east_region_population import compile_script
from prepare_snow_region_population import rows


class DragonSummitSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads((prep.OUT / 'catalog.json').read_text())
        cls.proof = json.loads((prep.OUT / 'source-preservation.json').read_text())
        cls.roster = json.loads((prep.OUT / 'encounters.json').read_text())
        cls.events = json.loads((prep.OUT / 'events/data.json').read_text())

    def test_all_fixed_sources_flags_and_generated_entrance_markers(self):
        self.assertEqual({r['id'] for r in self.catalog['maps'].values()}, prep.IDS - {15577})
        self.assertEqual(sum(r['cells'] for r in self.catalog['maps'].values()), 103175)
        self.assertEqual(sum(r['restored_cells'] for r in self.catalog['maps'].values()), 42803)
        differences = []
        for row in self.catalog['maps'].values():
            raw = active_raw(dict(raw=row['raw'])); done = active_raw(row)
            w, h, g, o, f = lib.parse_map(raw); _, _, gg, oo, ff = lib.parse_map(done)
            source = (prep.SOURCE / row['layout_reference']['file']).read_bytes(); ref = row['layout_reference']
            self.assertEqual(hashlib.sha256(source).hexdigest(), ref['sha256'])
            self.assertEqual(hashlib.sha1(b'blob ' + str(len(source)).encode() + b'\0' + source).hexdigest(), ref['git_blob_sha1'])
            _, _, values, _ = prep.reference_map(source, row['id'])
            self.assertEqual(f, ff); self.assertEqual(raw[:20], done[:20])
            for i, flag in enumerate(f):
                if flag & 0xc000:
                    self.assertEqual((g[i], o[i]), (gg[i], oo[i]))
            for i, (a, b) in enumerate(zip(gg + oo, values)):
                if a != b:
                    differences.append((row['id'], i // (w * h), i % (w * h) % w, i % (w * h) // w, a, b))
            self.assertTrue(row['sokia_visual_only'])
        self.assertEqual(differences, [(15578,1,24,26,13996,0), (15579,1,25,15,13996,0),
            (15583,1,25,15,13996,0), (15584,1,24,26,13996,0), (15585,1,25,34,13997,0),
            (15586,1,24,40,13997,0), (15589,1,15,27,13997,0), (15590,1,15,27,13997,0)])

    def test_existing15577_has_one_preserved_server_owner(self):
        self.assertEqual(len(self.proof['reused_maps']), 1)
        reused = self.proof['reused_maps'][0]
        self.assertEqual(reused['id'], 15577)
        catalog = json.loads((ROOT / reused['owner']).read_text())
        row = catalog['maps'][reused['path']]
        self.assertEqual(hashlib.sha256(json.dumps(row, sort_keys=True).encode()).hexdigest(), reused['runtime_row_sha256'])
        self.assertNotIn(reused['path'], self.catalog['maps'])
        w, h, g, o, _ = lib.parse_map(active_raw(row))
        ref = next(r for r in self.proof['maps'] if r['id'] == 15577)['source']
        _, _, values, _ = prep.reference_map((prep.SOURCE / ref['file']).read_bytes(), 15577)
        self.assertEqual(tuple(g + o), values)
        self.assertFalse(next(r for r in self.proof['maps'] if r['id'] == 15577)['completion']['source_flags_available'])

    def test_1887_actual_graphics_preserve_original_pixels_anchors_and_shared_pages(self):
        owners = {}; catalogs = {}; images = {}
        for name, digest in self.proof['protected_catalog_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), digest)
            catalog = json.loads((ROOT / name).read_text()); catalogs[name] = catalog
            for key, g in catalog['graphics'].items():
                owners.setdefault(key, (name, g))
        lookup = lib.serial_index()
        self.assertEqual(len(self.proof['source_graphics']), 1887)
        self.assertEqual(len(self.catalog['graphics']), 20)
        for key, source in self.proof['source_graphics'].items():
            if key in self.catalog['graphics']:
                g = self.catalog['graphics'][key]; path = prep.OUT / Path(self.catalog['pages'][g['page']]).name
            else:
                name, g = owners[key]; c = catalogs[name]; page = g['page']
                root = ROOT / 'assets/maps/falan/sokia/fixed' if '/sokia/fixed/' in name else ROOT / 'assets/maps/original_crossgate'
                if '/university/' in name:
                    page -= len(catalogs[prep.CATALOGS[0]]['pages'])
                elif '/elsa/' in name:
                    page -= c['page_offset']
                path = root / c['pages'][page]
            if path not in images:
                images[path] = Image.open(path).convert('RGBA')
            x, y, w, h = g['rect']; actual = images[path].crop((x, y, x+w, y+h))
            original = lib.image_from_record(source['pack'], source['row'])
            self.assertEqual(actual.size, original.size, key); self.assertEqual(actual.tobytes(), original.tobytes(), key)
            native = lookup[int(key)]
            self.assertEqual(g['origin'], [native['x'], native['y']]); self.assertEqual(g['footprint'], [native['east'], native['south']])

    def test_every_fixed_scripted_and_generated_pool_retains_full_source_identity(self):
        pools = {int(r[0]): r for r in rows('encount.txt')}; groups = {r[2]: r for r in rows('group.txt')}
        enemies = {r[2]: r for r in rows('enemy.txt')}; bases = {r[1]: r for r in rows('enemybase.txt')}
        self.assertEqual(set(self.roster['pools']), {'2006','2007','10029','10030','11011','14014','15007'})
        self.assertEqual(len(self.roster['groups']), 8)
        for key, pool in self.roster['pools'].items():
            raw = pools[int(key)]; self.assertEqual(pool['raw'], raw)
            self.assertEqual(pool['groups'], [['dragon:'+gid, int(raw[24+i])] for i, gid in enumerate(raw[14:24]) if gid and int(raw[24+i] or 0)])
        for key, group in self.roster['groups'].items():
            self.assertEqual(group['raw'], groups[key.removeprefix('dragon:')])
            for detail in group['details']:
                enemy = enemies[detail['enemy']]
                self.assertEqual(detail['raw_enemy'], enemy); self.assertEqual(detail['raw_base'], bases[enemy[3]])
        # Preserve the surprisingly broad source range; do not silently normalize it to the castle levels.
        self.assertEqual([m[1:3] for m in self.roster['groups']['dragon:2013']['members']], [[2,58]] * 4)
        self.assertEqual(self.roster['groups']['dragon:11013']['source_members'][1]['count'], [2,2])
        self.assertTrue(self.roster['groups']['dragon:11013']['source_members'][0]['mandatory'])
        base = json.loads((ROOT / 'assets/maps/original_crossgate/sokia_desert_temple/encounters.json').read_text())['species']
        self.assertEqual(self.roster['species'][:len(base)], base)
        self.assertEqual({s['appearance'] for s in self.roster['art_contracts']}, {100452,101000,101003,101204,101210,101211,101212,101213,101511,101523,101712,101812})

    def test_all72_generated_floors_remain_required_and_unregistered(self):
        branches = {b['config']: b for b in self.roster['generated_branches']}
        self.assertEqual({k: b['floors'] for k, b in branches.items()}, {108:[19,19],109:[19,19],110:[9,9],111:[9,9],309:[16,16]})
        self.assertEqual({k: b['pool']['levels'] for k, b in branches.items()}, {108:[67,69],109:[67,69],110:[69,71],111:[69,71],309:[30,35]})
        raw = {int(r[3]): r for line in (ROOT / 'assets/references/crossgate_sokia/events/dungeonconf.txt').read_bytes().decode('gb18030').splitlines()
            if len(r := line.split('\t')) > 52 and r[3].isdigit()}
        for key, b in branches.items():
            self.assertEqual(b['raw'], raw[key]); self.assertFalse(b['runtime_registered'])
            self.assertEqual(b['end'], list(map(int, raw[key][15:18])))
        self.assertFalse(self.proof['runtime_registration_verified']); self.assertFalse(self.proof['goal_complete'])
        self.assertEqual(self.proof['missing_native_appearances'], [])
        self.assertEqual(self.roster['species'][256]['bank'], 'east_region')
        self.assertEqual(self.roster['species'][256]['skin'], 166)

    def test_all_original_actors_include_invisible_piano_without_invented_art(self):
        originals = {r[3]: r for r in rows('npc.txt') if len(r)==25 and r[8].isdigit() and int(r[8]) in prep.IDS - {15577}
            and r[6]=='1' and int(r[3])<300000 and r[0] not in ['Warp','HouseWarp2']}
        actual = self.events['actors']
        self.assertEqual(set(actual), set(originals)); self.assertEqual(len(actual), 43)
        self.assertEqual(set(self.events['invisible_actor_ids']), {'5648'})
        for key, actor in actual.items():
            self.assertEqual(actor['raw'], originals[key]); self.assertEqual(actor['cell'], list(map(int, originals[key][9:11])))
        self.assertTrue(actual['5648']['invisible']); self.assertEqual(actual['5648']['graphic'], 0)
        self.assertEqual(actual['5648']['quest_action'], 'sokia_server:5648')
        self.assertEqual(actual['5648']['type'], 'Event')
        self.assertNotIn('0:0', self.events['art'])
        for name, script in self.events['scripts'].items():
            self.assertEqual(script, compile_script((ROOT / 'assets/references/crossgate_sokia/events' / name).read_bytes()))
        with Image.open(prep.OUT / 'events/npc-atlas.png') as atlas:
            for art in self.events['art'].values():
                key = art['key']; x,y,w,h = art['rect']; actual = atlas.crop((x,y,x+w,y+h)).convert('RGBA')
                if key.startswith('graphic:'):
                    r = lib.serial_index()[int(key.split(':')[1])]; image = lib.image_from_record(r['pack'],r['row']); ox,oy = r['x'],r['y']
                else:
                    _,_,clips = cg.actor(key); clip = next(c for c in clips if c['action']==0 and c['direction']==art['source_direction'])
                    image,ox,oy = cg.frame_parts(key,clip['index'],0)
                box=image.getbbox(); self.assertEqual(actual.tobytes(),image.crop(box).tobytes())
                self.assertEqual(art['origin'],[ox+box[0],oy+box[1]])


if __name__ == '__main__':
    unittest.main()
