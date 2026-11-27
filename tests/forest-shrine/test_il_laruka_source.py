"""Coverage against read-only native maps and warp graph; no legacy roster sweep."""
import hashlib
import json
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT.parent/'Magic Power/tools')]
import cg_library as library
from build_freyja_destinations import load_map,warp_rows,read_housing_map
from prepare_il_laruka import BUILDINGS,FORMS,WATERFRONT,laruka_lookup
from PIL import Image

class VillageSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=json.loads((ROOT/'assets/maps/falan/il_laruka/provenance.json').read_text())

    def test_warp_closure_includes_recovered_lower_room(self):
        ids={2000,2300};warps=list(warp_rows(ROOT.parent/'Magic Power'))
        while True:
            extra={r[3] for r in warps if r[0] in ids and (2000<=r[3]<2100 or 2300<=r[3]<2400)}-ids
            if not extra:break
            ids|=extra
        self.assertEqual(set(map(int,self.data['maps'])),ids)
        self.assertEqual(len(ids),21)
        self.assertEqual(self.data['blockers'],{})
        self.assertFalse(self.data['maps']['2307']['blocked_source'])
        self.assertEqual(self.data['maps']['2307']['size'],[20,20])
        self.assertEqual(self.data['maps']['2307']['objects'],97)

    def test_every_available_map_and_object_is_accounted(self):
        lookup=laruka_lookup(library)
        for ident,record in self.data['maps'].items():
            ident=int(ident)
            source=self.data['sources'][str(ident)]
            if ident==2307:path=ROOT/source['path']
            else:
                with library.connection() as db:
                    fid=db.execute('SELECT id FROM files WHERE path=?',(source['path'],)).fetchone()[0]
                _,path=library.source_file(fid)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),source['sha256'])
            _,_,_,objects,_=load_map(library,ident)
            for s in set(objects)-{0,2,252}:
                if s<1000 or s in {12000,12001,12002}:continue
                if s in lookup:self.assertIn(str(s),self.data['graphics'])
                else:self.assertTrue(any(row[0]==ident and row[3]==s for row in self.data['missing_graphics']))

    def test_all_building_placements(self):
        for ident,expected in [(2000,8),(2300,7)]:
            objects=load_map(library,ident)[3]
            self.assertEqual(sum(s in BUILDINGS for s in objects),expected)
            self.assertEqual(self.data['maps'][str(ident)]['buildings'],expected)
        self.assertTrue({11272,11273,11275,11106,11281,11285}<=FORMS.keys())

    def test_server_reference_matches_cached_partner_and_stair(self):
        reference=ROOT/'assets/references/crossgate_laruka_basement'
        records=json.loads((reference/'provenance.json').read_text())['files']
        for record in records:
            raw=(reference/record['file']).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),record['sha256'])
            read_housing_map(raw,record['map'])
        server=read_housing_map((reference/'02306_syokuryo').read_bytes(),2306)
        cached=load_map(library,2306)
        self.assertEqual(tuple(map(list,server[2:4])),tuple(map(list,cached[2:4])))
        w,h,ground,objects,_=load_map(library,2307)
        self.assertEqual(objects[7*w+6],16595)
        self.assertIn((2306,7,3,2307,6,5),list(warp_rows(ROOT.parent/'Magic Power')))

    def test_expansion_art_is_recovered_without_portrait_aliases(self):
        lookup=laruka_lookup(library)
        self.assertEqual(self.data['missing_graphics'],[])
        self.assertEqual(self.data['maps']['2300']['objects'],824)
        for serial in WATERFRONT:
            entry=lookup[serial]
            self.assertEqual(entry['source_serial'],serial+200000)
            self.assertEqual(entry['pack'],'ex')
            native=library.image_from_record(entry['pack'],entry['row'])
            record=self.data['graphics'][str(serial)]
            self.assertEqual(record['rgba_sha256'],hashlib.sha256(native.tobytes()).hexdigest())
            self.assertTrue(record['shore_bank'])
            self.assertEqual(record['ground'],1)
        self.assertEqual(lookup[25290]['source_serial'],225290)

    def test_recovered_caps_only_change_their_own_land_mask_cells(self):
        before=Image.open(ROOT/'assets/maps/falan/freyja_laruka.png').convert('RGBA')
        after=Image.open(ROOT/'assets/maps/falan/il_laruka/laruka-mask.png').convert('RGBA')
        w,h,_,objects,_=load_map(library,2300)
        self.assertEqual(after.size,(w,h))
        self.assertEqual(sum(s in WATERFRONT for s in objects),15)
        for i,serial in enumerate(objects):
            at=(i%w,i//w)
            if serial in WATERFRONT:self.assertEqual(after.getpixel(at),(0,0,0,255))
            else:self.assertEqual(after.getpixel(at),before.getpixel(at))

if __name__=='__main__':unittest.main()
