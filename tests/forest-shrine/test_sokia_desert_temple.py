"""Independent original-map, encounter and asset preservation checks."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'));sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_assets as cg
import cg_library as lib
import prepare_sokia_desert_temple as prep
from prepare_east_region_maps import active_raw
from prepare_east_region_population import compile_script
from prepare_snow_region_population import rows


class DesertTempleSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=json.loads((prep.OUT/'catalog.json').read_text());cls.roster=json.loads((prep.OUT/'encounters.json').read_text())
        cls.actors=json.loads((prep.OUT/'events/data.json').read_text());cls.proof=json.loads((prep.OUT/'source-preservation.json').read_text())

    def test_complete_planes_and_flags_preserve_every_recorded_client_cell(self):
        self.assertEqual({r['id'] for r in self.catalog['maps'].values()},prep.IDS)
        self.assertEqual(sum(r['cells'] for r in self.catalog['maps'].values()),13200)
        self.assertEqual(sum(r['restored_cells'] for r in self.catalog['maps'].values()),4094)
        differences=[]
        for r in self.catalog['maps'].values():
            raw=active_raw(dict(raw=r['raw']));done=active_raw(r);w,h,g,o,flags=lib.parse_map(raw);_,_,gg,oo,ff=lib.parse_map(done)
            server=(prep.SOURCE/r['layout_reference']['file']).read_bytes();ref=r['layout_reference']
            self.assertEqual(hashlib.sha256(server).hexdigest(),ref['sha256'])
            self.assertEqual(hashlib.sha1(b'blob '+str(len(server)).encode()+b'\0'+server).hexdigest(),ref['git_blob_sha1'])
            _,_,source,_=prep.reference_map(server,r['id']);self.assertEqual(flags,ff);self.assertEqual(raw[:20],done[:20])
            for i,v in enumerate(flags):
                if v&0xc000:self.assertEqual((g[i],o[i]),(gg[i],oo[i]))
            for i,(a,b) in enumerate(zip(gg+oo,source)):
                if a!=b:differences.append(dict(map=r['id'],layer=i//(w*h),cell=[i%(w*h)%w,i%(w*h)//w],client=a,server=b))
            self.assertTrue(r['sokia_visual_only']);self.assertFalse(r['outdoor'])
        self.assertEqual(differences,[dict(map=13022,layer=1,cell=[7,4],client=13998,server=0)])

    def test_all_181_actual_cached_graphics_match_original_rgba_and_anchors(self):
        owners={};catalogs={};images={};lookup=lib.serial_index()
        for name,digest in self.proof['protected_catalog_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),digest)
            c=json.loads((ROOT/name).read_text());catalogs[name]=c
            for k,g in c['graphics'].items():owners.setdefault(k,(name,g))
        self.assertEqual(len(self.proof['source_graphics']),181);self.assertEqual(len(self.catalog['graphics']),20)
        for key,source in self.proof['source_graphics'].items():
            if key in self.catalog['graphics']:
                g=self.catalog['graphics'][key];path=prep.OUT/Path(self.catalog['pages'][g['page']]).name
            else:
                name,g=owners[key];c=catalogs[name];root=ROOT/'assets/maps/falan/sokia/fixed' if '/sokia/fixed/' in name else ROOT/'assets/maps/original_crossgate';page=g['page']
                if '/university/' in name:page-=len(catalogs[prep.CATALOGS[0]]['pages'])
                elif '/elsa/' in name:page-=c['page_offset']
                path=root/c['pages'][page]
            if path not in images:images[path]=Image.open(path).convert('RGBA')
            x,y,w,h=g['rect'];actual=images[path].crop((x,y,x+w,y+h));original=lib.image_from_record(source['pack'],source['row'])
            self.assertEqual(actual.tobytes(),original.tobytes(),key);self.assertEqual(actual.size,original.size,key)
            native=lookup[int(key)];self.assertEqual(g['origin'],[native['x'],native['y']]);self.assertEqual(g['footprint'],[native['east'],native['south']])

    def test_all_source_zones_groups_and_contextual_enemy_identities(self):
        original={int(r[0]):r for r in rows('encount.txt') if int(r[3]) in prep.IDS};groups={r[2]:r for r in rows('group.txt')};enemies={r[2]:r for r in rows('enemy.txt')};bases={r[1]:r for r in rows('enemybase.txt')}
        self.assertEqual({z['id'] for z in self.roster['zones']},set(original));self.assertEqual(len(original),9);self.assertEqual(len(self.roster['groups']),12)
        for z in self.roster['zones']:
            raw=original[z['id']];self.assertEqual(z['raw'],raw);self.assertEqual(z['groups'],[['desert:'+gid,int(raw[24+i])] for i,gid in enumerate(raw[14:24]) if gid and int(raw[24+i] or 0)])
        used=set()
        for key,g in self.roster['groups'].items():
            self.assertEqual(g['raw'],groups[key.removeprefix('desert:')])
            for d in g['details']:
                used.add(d['enemy']);self.assertEqual(d['raw_enemy'],enemies[d['enemy']]);self.assertEqual(d['raw_base'],bases[enemies[d['enemy']][3]])
        self.assertEqual(used,{'7012','7013','7014','7015','11040','15007','15008','15009'})

    def test_generated_approach_remains_required_with_original_five_floor_roster(self):
        g=self.roster['generated_approach'];self.assertEqual(g['config'],303);self.assertEqual([g['minimum'],g['maximum']],[5,5]);self.assertEqual(g['source_template'],21600)
        self.assertEqual(g['entry_map'],300);self.assertEqual(g['entry_rect'],[570,300,640,400]);self.assertEqual(g['end'],[13022,7,4]);self.assertFalse(g['runtime_registered'])
        self.assertEqual(g['pool']['levels'],[26,28]);self.assertEqual(g['pool']['raw'],next(r for r in rows('encount.txt') if r[0]=='15003'))
        self.assertEqual(g['pool']['groups'],[['desert:15012',3],['desert:15010',2],['desert:15011',2],['desert:15013',2],['desert:15014',1]])
        self.assertEqual(self.roster['groups']['desert:15013']['raw'][3:5],['18462','-1'])
        self.assertTrue(self.roster['groups']['desert:15014']['source_members'][0]['mandatory'])
        self.assertEqual(self.proof['required_missing_runtime_maps'][0]['generated_floors'],5)

    def test_rare_pockets_item_gate_and_mandatory_general_stay_distinct(self):
        zones={z['id']:z for z in self.roster['zones']};groups=self.roster['groups']
        self.assertEqual(zones[7022]['bounds'],[11,16,21,30]);self.assertEqual(zones[7025]['bounds'],[11,4,19,15])
        self.assertEqual([zones[n]['priority'] for n in [7021,7022,7024,7025]],[1,5,1,5])
        for gid,eid in [('7016','7012'),('7018','7014')]:
            g=groups['desert:'+gid];i=next(i for i,d in enumerate(g['source_members']) if d['enemy_id']==eid)
            self.assertEqual(g['members'][i][1:],[1,1,1]);self.assertEqual(g['source_members'][i]['count'],[1,1])
        self.assertEqual(groups['desert:7021']['raw'][3:5],['18462','-1'])
        for gid in ['desert:7021','desert:7022']:
            d=groups[gid]['source_members'][0];self.assertEqual(d['enemy_id'],'11040');self.assertTrue(d['mandatory']);self.assertEqual(d['count'],[1,1])
        wind=json.loads((ROOT/'assets/maps/original_crossgate/sokia_wind_tower/encounters.json').read_text());self.assertEqual(self.roster['species'][:len(wind['species'])],wind['species'])
        self.assertEqual(len(self.roster['art_contracts']),3)
        for r in self.roster['art_contracts']:
            p=ROOT/'assets/characters/crossgate'/r['bank']/'motions.json';self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),r['motions_sha256']);self.assertEqual(json.loads(p.read_text())['variants'][r['skin']]['id'],r['appearance'])

    def test_every_original_actor_and_script_retains_source_data(self):
        self.assertEqual(len(self.actors['actors']),14);self.assertEqual({a['id'] for a in self.actors['excluded']},{'305089','305099'})
        for a in self.actors['actors'].values():self.assertEqual(a['cell'],list(map(int,a['raw'][9:11])))
        for name,s in self.actors['scripts'].items():self.assertEqual(s,compile_script((ROOT/'assets/references/crossgate_sokia/events'/name).read_bytes()))
        with Image.open(prep.OUT/'events/npc-atlas.png') as atlas:
            for art in self.actors['art'].values():
                x,y,w,h=art['rect'];actual=atlas.crop((x,y,x+w,y+h)).convert('RGBA');key=art['key']
                if key.startswith('graphic:'):
                    r=lib.serial_index()[int(key.split(':')[1])];source=lib.image_from_record(r['pack'],r['row']);ox,oy=r['x'],r['y']
                else:
                    _,_,clips=cg.actor(key);clip=next(c for c in clips if c['action']==0 and c['direction']==art['source_direction']);source,ox,oy=cg.frame_parts(key,clip['index'],0)
                box=source.getbbox();self.assertEqual(actual.tobytes(),source.crop(box).tobytes());self.assertEqual(art['origin'],[ox+box[0],oy+box[1]])


if __name__=='__main__':unittest.main()
