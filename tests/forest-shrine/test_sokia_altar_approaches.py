"""Independent source parity and omission checks for the complete inquiry branch."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
import cg_assets as cg
import cg_library as lib
import prepare_sokia_altar_approaches as prep
from prepare_east_region_maps import active_raw
from prepare_east_region_population import compile_script
from prepare_snow_region_population import rows


class AltarApproachSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads((prep.OUT / 'catalog.json').read_text())
        cls.proof = json.loads((prep.OUT / 'source-preservation.json').read_text())
        cls.roster = json.loads((prep.OUT / 'encounters.json').read_text())
        cls.events = json.loads((prep.OUT / 'events/data.json').read_text())

    def test_all16_sources_and_original_client_cells_and_flags(self):
        self.assertEqual({r['id'] for r in self.proof['maps']}, set(range(15548,15564)))
        self.assertEqual({r['id'] for r in self.catalog['maps'].values()}, prep.IDS - prep.REUSED)
        self.assertEqual(sum(r['cells'] for r in self.catalog['maps'].values()), 34000)
        self.assertEqual(sum(r['restored_cells'] for r in self.catalog['maps'].values()), 14674)
        changes = []
        for row in self.catalog['maps'].values():
            raw = active_raw(dict(raw=row['raw'])); done = active_raw(row)
            w,h,g,o,f = lib.parse_map(raw); _,_,gg,oo,ff = lib.parse_map(done)
            ref = row['layout_reference']; server = (prep.SOURCE / ref['file']).read_bytes()
            self.assertEqual(hashlib.sha256(server).hexdigest(), ref['sha256'])
            self.assertEqual(hashlib.sha1(b'blob '+str(len(server)).encode()+b'\0'+server).hexdigest(), ref['git_blob_sha1'])
            self.assertEqual(f,ff); self.assertEqual(raw[:20],done[:20])
            for i,flag in enumerate(f):
                if flag & 0xc000: self.assertEqual((g[i],o[i]),(gg[i],oo[i]))
            _,_,expected,_ = prep.reference_map(server,row['id'])
            for i,(a,b) in enumerate(zip(gg+oo,expected)):
                if a!=b: changes.append((row['id'],i//(w*h),i%(w*h)%w,i%(w*h)//w,a,b))
            self.assertTrue(row['sokia_visual_only'])
        recorded = [(r['map'],r['layer'],*r['cell'],r['client'],r['server']) for r in self.proof['recorded_client_variations']]
        self.assertEqual(changes,recorded); self.assertEqual(len(changes),26)
        raw_configs = prep.configs()
        for record in self.proof['recorded_client_variations']:
            for c in record['source_configs']:
                raw = raw_configs[c['config']]; start = 9 if c['role']=='entry' else 15
                self.assertEqual(int(raw[start]),record['map'])
                self.assertEqual(list(map(int,raw[start+1:start+3])),record['cell'])
                self.assertEqual(int(raw[c['graphic_field']]),record['client'])

    def test_marker_exception_never_allows_an_unrelated_layout_change(self):
        markers = prep.marker_sources(prep.configs())
        for ident in [15553,15557,15559]:
            row = next(r for r in self.catalog['maps'].values() if r['id']==ident)
            raw = active_raw(dict(raw=row['raw'])); server=(prep.SOURCE/row['layout_reference']['file']).read_bytes()
            done,proof = prep.restore(raw,server,ident,markers)
            self.assertEqual(done,raw); self.assertFalse(proof['compatible']); self.assertTrue(proof['layout_complete'])
            self.assertTrue(proof['full_planes_exact_except_config_markers'])
            # A single new ground discrepancy invalidates the room-specific proof.
            changed=bytearray(raw); struct.pack_into('<H',changed,20,struct.unpack_from('<H',raw,20)[0]^1)
            with self.assertRaises(AssertionError): prep.restore(bytes(changed),server,ident,markers)
            with self.assertRaises(AssertionError): prep.restore(raw,server,ident,{})

    def test_four_existing_map_and_actor_owners_are_preserved(self):
        self.assertEqual({r['id'] for r in self.proof['reused_maps']},{15549,15556,15560,15562})
        self.assertEqual({r['id'] for r in self.proof['reused_actors']},{'5288','5291','5294','5297'})
        for record in self.proof['reused_maps']:
            row=json.loads((ROOT/record['owner']).read_text())['maps'][record['path']]
            self.assertEqual(hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest(),record['runtime_row_sha256'])
            ref=next(r['source'] for r in self.proof['maps'] if r['id']==record['id'])
            server=(prep.SOURCE/ref['file']).read_bytes()
            self.assertEqual(hashlib.sha256(server).hexdigest(),ref['sha256'])
            _,_,g,o,_=lib.parse_map(active_raw(row)); _,_,values,_=prep.reference_map(server,record['id'])
            self.assertEqual(tuple(g+o),values)
        for record in self.proof['reused_actors']:
            row=json.loads((ROOT/record['owner']).read_text())['actors'][record['id']]
            self.assertEqual(hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest(),record['row_sha256'])
            self.assertNotIn(record['id'],self.events['actors'])

    def test_all171_floors_keep_distinct_pool_levels_and_continuation(self):
        config_rows=prep.configs(); branches={b['config']:b for b in self.roster['generated_branches']}
        self.assertEqual(set(branches),set(range(408,427))); self.assertEqual(len(self.roster['generated_floors']),171)
        for config,b in branches.items():
            expected_pool=16007 if config<=413 else 16008 if config<=419 else 16009
            expected_levels=[61,62] if config<=409 else [62,63] if config<=413 else [63,64] if config<=419 else [64,65]
            self.assertEqual(b['raw'],config_rows[config]); self.assertEqual(b['floors'],[9,9]); self.assertFalse(b['runtime_registered'])
            self.assertEqual(b['pool']['id'],expected_pool); self.assertEqual(b['pool']['levels'],expected_levels)
            self.assertEqual(b['pool']['next_encounter'],expected_pool)
            self.assertEqual(b['pool']['next_probability'],{16007:1,16008:30,16009:65}[expected_pool])
            floors=[f for f in self.roster['generated_floors'] if f['config']==config]
            self.assertEqual([f['number'] for f in floors],list(range(1,10)))
            for floor in floors:
                self.assertEqual(floor['encounter'],expected_pool); self.assertEqual(floor['source_level_interval'],expected_levels)
                self.assertEqual(floor['groups'],[['altar:16023',1]])
                self.assertFalse(floor['original_layout_verified']); self.assertFalse(floor['original_floor_level_curve_verified'])
        self.assertEqual(self.roster['zones'],[])
        self.assertEqual([r for r in rows('encount.txt') if int(r[3]) in prep.IDS],[])

    def test_all_eight_enemies_keep_raw_counts_weights_levels_and_art_identity(self):
        pools={int(r[0]):r for r in rows('encount.txt')}; groups={r[2]:r for r in rows('group.txt')}
        enemies={r[2]:r for r in rows('enemy.txt')}; bases={r[1]:r for r in rows('enemybase.txt')}
        self.assertEqual(set(self.roster['pools']),{'16007','16008','16009'})
        for ident,pool in self.roster['pools'].items(): self.assertEqual(pool['raw'],pools[int(ident)])
        group=self.roster['groups']['altar:16023']; self.assertEqual(group['raw'],groups['16023'])
        self.assertEqual([d['enemy'] for d in group['details']],[str(i) for i in range(16011,16019)])
        self.assertEqual([m[1:] for m in group['members']],[[1,1,1]]*8)
        self.assertEqual([d['count'] for d in group['source_members']],[[1,10]]*8)
        self.assertFalse(any(d['mandatory'] for d in group['source_members']))
        for d in group['details']:
            self.assertEqual(d['raw_enemy'],enemies[d['enemy']]); self.assertEqual(d['raw_base'],bases[enemies[d['enemy']][3]])
        base=json.loads((ROOT/'assets/maps/original_crossgate/sokia_dragon_summit/encounters.json').read_text())['species']
        self.assertEqual(self.roster['species'][:258],base)
        manifest=json.loads((ROOT/'assets/characters/crossgate/guard_pets/motions.json').read_text())
        self.assertEqual({c['appearance'] for c in self.roster['art_contracts']},{101720,101721,101722,101723,101700,101701,101702,101703})
        for c in self.roster['art_contracts']:
            self.assertEqual(manifest['variants'][c['skin']]['id'],c['appearance'])
            self.assertEqual(manifest['variants'][c['skin']]['key'],c['key'])

    def test_original_events_and_two_graphic1_statues_without_invented_art(self):
        originals={r[3]:r for r in rows('npc.txt') if len(r)==25 and r[8].isdigit() and int(r[8]) in prep.IDS-prep.REUSED
            and r[6]=='1' and r[0] not in ['Warp','HouseWarp2'] and int(r[3])<300000}
        self.assertEqual(set(self.events['actors']),set(originals)); self.assertEqual(len(originals),12)
        self.assertEqual(self.events['invisible_actor_ids'],['5298','5299'])
        for key,actor in self.events['actors'].items():
            self.assertEqual(actor['raw'],originals[key]); self.assertIsNone(actor['generated_by'])
            payload=(ROOT/'assets/references/crossgate_sokia/events'/actor['script']).read_bytes()
            self.assertEqual(self.events['scripts'][actor['script']],compile_script(payload))
            if key in ['5298','5299']:
                self.assertTrue(actor['invisible']); self.assertEqual(actor['graphic'],1)
                self.assertEqual(actor['quest_action'],'sokia_server:'+key); self.assertNotIn(actor['token'],self.events['art'])
        self.assertEqual(self.events['actors']['5286']['graphic'],16328)
        with Image.open(prep.OUT/'events/npc-atlas.png') as atlas:
            for art in self.events['art'].values():
                key=art['key']; x,y,w,h=art['rect']
                if key.startswith('graphic:'):
                    native=lib.serial_index()[int(key.split(':')[1])]; image=lib.image_from_record(native['pack'],native['row']); ox,oy=native['x'],native['y']
                else:
                    _,_,clips=cg.actor(key); clip=next(c for c in clips if c['action']==0 and c['direction']==art['source_direction'])
                    image,ox,oy=cg.frame_parts(key,clip['index'],0)
                box=image.getbbox(); self.assertEqual(atlas.crop((x,y,x+w,y+h)).convert('RGBA').tobytes(),image.crop(box).tobytes())
                self.assertEqual(art['origin'],[ox+box[0],oy+box[1]])

    def test_all289_source_graphics_keep_pixels_anchors_and_shared_pages(self):
        owners={}; catalogs={}; images={}; lookup=lib.serial_index()
        self.assertEqual(len(self.proof['source_graphics']),289); self.assertEqual(len(self.catalog['graphics']),5)
        for name,digest in self.proof['protected_catalog_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),digest)
            c=json.loads((ROOT/name).read_text()); catalogs[name]=c
            for key,g in c['graphics'].items(): owners.setdefault(key,(name,g))
        for key,source in self.proof['source_graphics'].items():
            if key in self.catalog['graphics']:
                g=self.catalog['graphics'][key]; path=prep.OUT/Path(self.catalog['pages'][g['page']]).name
            else:
                name,g=owners[key]; c=catalogs[name]; page=g['page']
                root=ROOT/'assets/maps/falan/sokia/fixed' if '/sokia/fixed/' in name else ROOT/'assets/maps/original_crossgate'
                if '/university/' in name: page-=len(catalogs[prep.CATALOGS[0]]['pages'])
                elif '/elsa/' in name: page-=c['page_offset']
                path=root/c['pages'][page]
            if path not in images: images[path]=Image.open(path).convert('RGBA')
            x,y,w,h=g['rect']; original=lib.image_from_record(source['pack'],source['row'])
            self.assertEqual(images[path].crop((x,y,x+w,y+h)).tobytes(),original.tobytes(),key)
            native=lookup[int(key)]; self.assertEqual(g['origin'],[native['x'],native['y']]); self.assertEqual(g['footprint'],[native['east'],native['south']])
        self.assertFalse(self.proof['runtime_registration_verified']); self.assertFalse(self.proof['goal_complete'])


if __name__=='__main__':
    unittest.main()
