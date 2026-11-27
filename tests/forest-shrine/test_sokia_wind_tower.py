"""Check complete connected source coverage separately from native/visual approval."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_assets as cg
import cg_library as lib
import prepare_sokia_wind_tower as prep
from prepare_east_region_maps import active_raw
from prepare_snow_region_population import rows


class WindTowerSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=json.loads((prep.OUT/'catalog.json').read_text())
        cls.roster=json.loads((prep.OUT/'encounters.json').read_text())
        cls.actors=json.loads((prep.OUT/'events/data.json').read_text())
        cls.proof=json.loads((prep.OUT/'source-preservation.json').read_text())

    def test_every_tile_and_all_recorded_flags_survive_in_all_fourteen_maps(self):
        maps={m['id']:m for m in self.catalog['maps'].values()}
        self.assertEqual(set(maps),prep.IDS)
        self.assertEqual(sum(m['restored_cells'] for m in maps.values()),76093)
        self.assertEqual(sum(m['cells'] for m in maps.values()),127925)
        self.assertEqual(set(self.proof['source_tables']),{'npc.txt','msg.txt','encount.txt','group.txt','enemy.txt','enemybase.txt'})
        for name,proof in self.proof['source_tables'].items():
            self.assertEqual(hashlib.sha256((prep.TABLES/name).read_bytes()).hexdigest(),proof['sha256'])
        self.assertEqual(maps[301]['size'],[150,150])
        self.assertEqual(maps[302]['size'],[120,40])
        for row in maps.values():
            raw=active_raw(dict(raw=row['raw'])); restored=active_raw(row)
            w,h,f,o,flags=lib.parse_map(raw); _,_,ff,oo,done_flags=lib.parse_map(restored)
            server=(prep.SOURCE/row['layout_reference']['file']).read_bytes()
            self.assertEqual(hashlib.sha256(server).hexdigest(),row['layout_reference']['sha256'])
            _,_,source,_=prep.reference_map(server,row['id'])
            self.assertEqual(tuple(ff)+tuple(oo),source)
            self.assertEqual(flags,done_flags)
            self.assertEqual(raw[:20],restored[:20])
            for i,flag in enumerate(flags):
                if flag&0xc000:self.assertEqual((f[i],o[i]),(ff[i],oo[i]))
            self.assertTrue(row['sokia_visual_only'])
            self.assertEqual(row['outdoor'],row['id'] in [301,302])

    def test_all_six_hundred_graphics_have_original_pixels_origins_and_footprints(self):
        owners={}; catalogs={}; images={}; lookup=lib.serial_index()
        for name in self.proof['protected_catalog_sha256']:
            path=ROOT/name; catalog=json.loads(path.read_text()); catalogs[name]=catalog
            for key,graphic in catalog['graphics'].items():owners.setdefault(key,(name,graphic))
        self.assertEqual(len(self.proof['source_graphics']),600)
        self.assertEqual(len(self.catalog['graphics']),78)
        self.assertEqual(len(self.catalog['reused_graphics']),522)
        for key,source in self.proof['source_graphics'].items():
            if key in self.catalog['graphics']:
                graphic=self.catalog['graphics'][key]; path=prep.OUT/Path(self.catalog['pages'][graphic['page']]).name
            else:
                name,graphic=owners[key]; catalog=catalogs[name]
                root=ROOT/'assets/maps/falan/sokia/fixed' if '/sokia/fixed/' in name else ROOT/'assets/maps/original_crossgate'
                page=graphic['page']
                if '/university/' in name:page-=len(catalogs[prep.CATALOGS[0]]['pages'])
                elif '/elsa/' in name:page-=catalog['page_offset']
                path=root/catalog['pages'][page]
            if path not in images:images[path]=Image.open(path).convert('RGBA')
            x,y,w,h=graphic['rect']; pixels=images[path].crop((x,y,x+w,y+h))
            original=lib.image_from_record(source['pack'],source['row'])
            self.assertEqual(pixels.size,original.size,key)
            self.assertEqual(pixels.tobytes(),original.tobytes(),key)
            native=lookup[int(key)]
            self.assertEqual(graphic['origin'],[native['x'],native['y']],key)
            self.assertEqual(graphic['footprint'],[native['east'],native['south']],key)
        for name,expected in self.proof['protected_catalog_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),expected,name)

    def test_every_zone_and_script_party_retains_its_source_roster(self):
        originals={int(r[0]):r for r in rows('encount.txt')}
        zones={z['id']:z for z in self.roster['zones']}
        self.assertEqual(set(zones),{i for i,r in originals.items() if int(r[3]) in prep.IDS})
        self.assertEqual(set(self.roster['bosses']),{'10007','10010','10011'})
        self.assertEqual(len(self.roster['groups']),19)
        enemies={r[2]:r for r in rows('enemy.txt')}; bases={r[1]:r for r in rows('enemybase.txt')}
        groups={r[2]:r for r in rows('group.txt')}; used=set()
        for record in [*zones.values(),*self.roster['bosses'].values()]:
            self.assertEqual(record['raw'],originals[record['id']])
            raw=originals[record['id']]
            self.assertEqual(record['groups'],[['wind:'+gid,int(raw[24+j])] for j,gid in enumerate(raw[14:24]) if gid and int(raw[24+j]or 0)])
        for key,group in self.roster['groups'].items():
            self.assertEqual(group['raw'],groups[key.removeprefix('wind:')])
            for detail in group['details']:
                used.add(detail['enemy']); enemy=enemies[detail['enemy']]
                self.assertEqual(detail['raw_enemy'],enemy)
                self.assertEqual(detail['raw_base'],bases[enemy[3]])
        self.assertEqual(len(used),25)
        self.assertEqual(len(self.roster['art_contracts']),14)
        self.assertFalse(self.proof['native_bank_integration_pending'])
        self.assertTrue(all(r['bank'] in ['east_region','companion']for r in self.roster['reused_species']))
        self.assertFalse(self.roster['map_assessment']['20002']['ambient_rows'])
        self.assertFalse(self.roster['map_assessment']['20003']['ambient_rows'])

    def test_rare_subzones_and_two_distinct_guardian_parties_are_not_flattened(self):
        zones={z['id']:z for z in self.roster['zones']}; groups=self.roster['groups']
        self.assertEqual(zones[6043]['bounds'],[8,58,19,66])
        self.assertEqual(zones[6044]['bounds'],[54,58,65,66])
        self.assertEqual([zones[i]['priority'] for i in [6042,6043,6044]],[1,10,10])
        for gid,eid in [('6015','6012'),('6017','6014')]:
            group=groups['wind:'+gid]; j=next(i for i,d in enumerate(group['details']) if d['enemy']==eid)
            self.assertEqual(group['members'][j][1:],[1,1,1])
            self.assertEqual(group['source_members'][j]['count'],[1,1])
        for gid,ids in [('10010',['10041','10046','10047']),('10011',['10050','10048','10049'])]:
            group=groups['wind:'+gid]
            self.assertEqual([d['enemy_id'] for d in group['source_members']],ids)
            self.assertEqual([d['count'] for d in group['source_members']],[[1,1],[3,3],[3,3]])
            self.assertTrue(all(d['mandatory'] for d in group['source_members']))
        boss=groups['wind:10007']
        self.assertEqual([m[1:3] for m in boss['members']],[[80,80],[65,65],[65,65],[65,65],[65,65]])
        self.assertTrue(all(d['mandatory'] for d in boss['source_members']))

    def test_invisible_original_conditions_and_directed_ports_are_preserved(self):
        actors={a['id']:a for a in self.actors['actors']}
        self.assertEqual(len(actors),16)
        self.assertEqual(sum(a['invisible'] for a in actors.values()),11)
        self.assertEqual({i for i,a in actors.items() if a['native_enemy']},{'80081','80082'})
        self.assertEqual(len(self.proof['fixed_ports']),96)
        self.assertEqual(self.proof['branch_boundary_ports'],[dict(source_map=302,cell=[103,24],target_map=300,arrival=[462,404],authority='existing pinned fixed-port reference; direction preserved')])
        entry=self.proof['entry_events']; self.assertEqual(len(entry),1)
        self.assertEqual(entry[0]['block'],'block Item 18575 >= 1 && StrCmpChat == 17034')
        self.assertEqual(entry[0]['branch_context'],['Window_OK Item 18575 >= 1'])
        self.assertEqual(actors['6267']['cell'],[461,404])
        for name,script in self.actors['scripts'].items():
            original=(prep.EVENTS/name).read_bytes()
            self.assertEqual(script,prep.compile_script(original))
            self.assertEqual(script['sha256'],self.actors['source_provenance'][name]['sha256'])
        for actor in actors.values():
            self.assertEqual(actor['cell'],list(map(int,actor['raw'][9:11])))
        self.assertEqual(len(self.proof['scripted_fights']),4)  # Two NPCs share Arcas's single source party.
        self.assertIn('execution_verified',self.roster['zones'][0]['follow_on'])
        self.assertFalse(self.roster['zones'][0]['follow_on']['execution_verified'])

    def test_three_visible_npc_sprites_match_original_facing_and_pixels(self):
        self.assertFalse(self.actors['art_blockers'])
        self.assertEqual(len(self.actors['npcs']),3)
        for art in self.actors['art'].values():
            path=ROOT/self.actors['atlas_paths'][art['atlas']].removeprefix('res://')
            with Image.open(path) as atlas:
                x,y,w,h=art['rect']; actual=atlas.crop((x,y,x+w,y+h)).convert('RGBA')
            key=art['key']
            if key.startswith('graphic:'):
                source=lib.image_from_record(art['pack'],art['row']); native=lib.serial_index()[int(key.split(':')[1])]
                ox,oy=native['x'],native['y']
            else:
                _,_,clips=cg.actor(key)
                clip=next(c for c in clips if c['action']==0 and c['direction']==art['source_direction'])
                source,ox,oy=cg.frame_parts(key,clip['index'],0)
            box=source.getbbox(); source=source.crop(box)
            self.assertEqual(actual.tobytes(),source.tobytes())
            self.assertEqual(actual.size,source.size)
            self.assertEqual(art['origin'],[ox+box[0],oy+box[1]])

    def test_runtime_candidates_match_the_verified_source_stage_and_stay_gated(self):
        runtime=ROOT/'assets/maps/original_crossgate/sokia_wind_tower'
        self.assertEqual(json.loads((runtime/'catalog.json').read_text()),self.catalog)
        self.assertEqual(json.loads((runtime/'encounters.json').read_text()),self.roster)
        actors=json.loads((runtime/'events/data.json').read_text())
        self.assertEqual({k:v for k,v in actors.items()if k!='atlas_paths'},
                         {k:v for k,v in self.actors.items()if k!='atlas_paths'})
        self.assertTrue(all(m['sokia_visual_only'] for m in self.catalog['maps'].values()))
        for name in ['atlas-0.png','solid-0.png','events/npc-atlas.png']:
            self.assertEqual((runtime/name).read_bytes(),(prep.OUT/name).read_bytes(),name)
        preset=(ROOT/'export_presets.cfg').read_text()
        for name in ['catalog.json','encounters.json','events/data.json']:
            self.assertIn('assets/maps/original_crossgate/sokia_wind_tower/'+name,preset)


if __name__=='__main__':unittest.main()
