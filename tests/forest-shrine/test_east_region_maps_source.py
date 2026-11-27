"""Independent preservation and page-index checks for the fixed eastern map supplement."""
import base64
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest
import zlib

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
from prepare_east_region_maps import active_raw, complete_map, extend_solid_pixels, reference_map
import recover_original_crossgate_maps as recovery


def decode(row, key='raw'):
    return zlib.decompress(base64.b64decode(row.get(key,row['raw'])))


class EastFixedMapsSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.art = ROOT/'assets/maps/original_crossgate'
        cls.catalog = json.loads((cls.art/'east/catalog.json').read_text())

    def test_recorded_cells_flags_and_header_are_preserved(self):
        sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
        import cg_library as lib
        for path, row in self.catalog['maps'].items():
            raw = decode(row); final = decode(row,'restored_raw')
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'],path)
            if row.get('source_file_id'):
                _,payload = lib.source_file(row['source_file_id'])
                self.assertEqual(raw,payload.read_bytes() if isinstance(payload,Path) else payload,path)
            self.assertEqual(raw[:20],final[:20],path)
            w,h = struct.unpack_from('<II',raw,12); cells = w*h
            self.assertEqual(len(raw),20+cells*6,path)
            self.assertEqual(raw[20+cells*4:],final[20+cells*4:],path)
            source = struct.unpack_from(f'<{cells*3}H',raw,20)
            prepared = struct.unpack_from(f'<{cells*3}H',final,20)
            for i in range(cells):
                if source[cells*2+i]&0xc000:
                    self.assertEqual((source[i],source[cells+i]),(prepared[i],prepared[cells+i]),(path,i))

    def test_references_and_shared_catalogs_keep_their_pinned_hashes(self):
        for entry in self.catalog['shared_catalogs']+self.catalog['source_manifests']:
            self.assertEqual(hashlib.sha256((ROOT/entry['path']).read_bytes()).hexdigest(),entry['sha256'],entry['path'])
        for row in self.catalog['maps'].values():
            proof = row.get('completion_reference',row.get('layout_reference'))
            if proof:
                raw = (ROOT/proof['local_path']).read_bytes()
                self.assertEqual(hashlib.sha256(raw).hexdigest(),proof['sha256'])
                self.assertEqual(reference_map(raw,row['id'])[:2],tuple(row['size']))

    def test_every_pinned_fixed_map_is_included_or_has_a_specific_blocker(self):
        evidence = json.loads((ROOT/'build/Other Files/Asset Toolkit/East Gate Region/fixed-map-preservation.json').read_text())
        blockers = {entry['source'] for entry in evidence['blockers'] if 'source' in entry}
        boundaries = {entry['source'] for entry in self.catalog.get('excluded_source_maps',[])}
        included = set(self.catalog['fixed_ids'])
        for record in self.catalog['source_manifests']:
            manifest = ROOT/record['path']
            for proof in json.loads(manifest.read_text()):
                if '/map/' not in proof['path']:
                    continue
                source = manifest.parent/proof.get('file',Path(proof['path']).name)
                ident = struct.unpack_from('>H',source.read_bytes(),6)[0]
                self.assertTrue(ident in included or ident in blockers or ident in boundaries,(ident,source))
        self.assertEqual({ident for ident in included if 1000<=ident<2000},{1155})

    def test_novel_pages_keep_native_pixels_and_local_indices(self):
        self.assertEqual(self.catalog['page_indices'],'local')
        self.assertEqual(self.catalog['surface_indices'],'local')
        pages = {}
        for serial,graphic in self.catalog['graphics'].items():
            page = graphic['page']
            self.assertTrue(0<=page<len(self.catalog['pages']),serial)
            if page not in pages:
                pages[page] = Image.open(self.art/self.catalog['pages'][page]).convert('RGBA')
            x,y,w,h = graphic['rect']
            self.assertEqual(hashlib.sha256(pages[page].crop((x,y,x+w,y+h)).tobytes()).hexdigest(),graphic['rgba_sha256'],serial)
            if 'surfaces' in graphic:
                self.assertTrue(0<=graphic['surfaces'][0]<len(self.catalog['surface_pages']),serial)
        self.assertFalse(set(self.catalog['graphics'])&set(self.catalog['reused_graphics']))

    def test_expansion_aliases_leave_map_planes_native(self):
        for path,row in self.catalog['maps'].items():
            for native,alias in row.get('graphic_aliases',{}).items():
                graphic = self.catalog['graphics'][str(alias)]
                self.assertEqual(graphic['source_native_serial'],int(native),path)
                self.assertEqual(graphic['source_serial'],int(native)+200000,path)
                self.assertEqual(alias,graphic['source_serial']+1000000,path)

    def test_version_maps_and_inferred_crystal_binding_are_explicit(self):
        rows={row['id']:row for row in self.catalog['maps'].values()}
        self.assertEqual(rows[31800]['graphic_aliases']['30038'],1230038)
        for ident in (32265,32266):
            self.assertEqual(rows[ident]['graphic_aliases'],{'60057':1260057})
            binding=rows[ident]['inferred_graphic_bindings'][0]
            self.assertEqual((binding['native_serial'],binding['source_serial']),(60057,260057))
            self.assertIn('does not prove client namespace',binding['basis'])
        world=rows[31954]
        self.assertEqual(len(world['inferred_graphic_bindings']),23)
        self.assertEqual(len(world['graphic_aliases']),23)
        for binding in world['inferred_graphic_bindings']:
            self.assertEqual(binding['source_serial'],binding['native_serial']+200000)
            self.assertIn('does not prove client namespace',binding['basis'])

    def test_storm_sea_interaction_anchor_is_explicit_and_bounded(self):
        row=self.catalog['maps']['BlueCrossgate/map/0/41029.dat']
        opened=[[x,y] for y in range(4,7) for x in range(4,7)]
        self.assertEqual(row['walk_override']['opened_cells'],opened)
        self.assertEqual(row['walk_override']['kind'],'technical-cutscene-adaptation')
        bits=zlib.decompress(base64.b64decode(row['walk']))
        for x,y in opened:self.assertTrue(bits[(y*row['size'][0]+x)//8]&(1<<((y*row['size'][0]+x)%8)))

    def test_classic_header_does_not_mislabel_floor_data_as_music(self):
        for row in self.catalog['maps'].values():
            metadata=row['music_metadata'];raw=(ROOT/metadata['source']).read_bytes()
            self.assertEqual(metadata['status'],'not-recorded-in-classic-header',row['id'])
            self.assertEqual(metadata['audio_fidelity'],'unverified',row['id'])
            self.assertEqual(metadata['header_bytes'],44,row['id'])
            self.assertNotEqual(raw[6:8],b'\xff\xff',row['id'])
            self.assertEqual(hashlib.sha256(raw).hexdigest(),metadata['source_sha256'])
            self.assertNotIn('music',row,row['id'])

    def test_new_reference_variants_are_whole_pinned_sources(self):
        for path,row in self.catalog['maps'].items():
            if 'reference_variant_raw' not in row:
                continue
            proof = row['reference_variant_source']
            reference = (ROOT/proof['local_path']).read_bytes()
            w,h,values,_ = reference_map(reference,row['id'])
            raw = decode(row,'reference_variant_raw')
            self.assertEqual(hashlib.sha256(raw).hexdigest(),row['reference_variant_sha256'],path)
            self.assertEqual(struct.unpack_from('<II',raw,12),(w,h),path)
            self.assertEqual(struct.unpack_from(f'<{w*h*2}H',raw,20),values,path)
            if row['active_layout_variant']=='pinned-reference':
                self.assertEqual(active_raw(row),raw,path)
                self.assertTrue(row['layout_complete'],path)
            if row.get('east_existing_owner'):
                self.assertNotEqual(row['active_layout_variant'],'pinned-reference',path)

    def test_custom_owners_and_native_decks_keep_their_correct_classification(self):
        maps = {row['id']:row for row in self.catalog['maps'].values()}
        for ident in (1155,2000,2400,11003,11004,11005,11028):
            self.assertTrue(maps[ident]['east_existing_owner'],ident)
        for ident in (41000,41009,41019,41022):
            self.assertTrue(maps[ident].get('outdoor'),ident)
        for ident in (41001,41023):
            self.assertFalse(maps[ident].get('outdoor',False),ident)
        self.assertNotIn(1530,maps)
        self.assertNotIn(1541,maps)

    def test_incompatible_reference_never_fills_unknown_cells(self):
        ident,w,h = 7,2,2
        reference = b'LS2MAP'+struct.pack('>H',ident)+bytes(32)+struct.pack('>HH',w,h)+struct.pack('>8H',1,2,3,4,0,0,0,0)
        source = b'MAP\x01'+bytes(8)+struct.pack('<II',w,h)+struct.pack('<12H',9,0,0,0,0,0,0,0,0xc000,0,0,0)
        final,evidence = complete_map(source,reference,ident)
        self.assertEqual(final,source)
        self.assertFalse(evidence['compatible'])
        self.assertFalse(evidence['layout_complete'])
        with self.assertRaises(ValueError):
            reference_map(reference,ident+1)

    def test_il_unknown_completion_matches_independent_source_supplement(self):
        row=self.catalog['maps']['BlueCrossgate/map/0/2000.dat']
        proof=row.get('completion_reference',row.get('reference_variant_source'))
        raw=decode(row)
        final,evidence=complete_map(raw,(ROOT/proof['local_path']).read_bytes(),2000)
        supplement=ROOT/'assets/maps/falan/east_region/il_source_completion'
        data=json.loads((supplement/'data.json').read_text())
        self.assertEqual(final,(supplement/'hybrid-map.bin').read_bytes())
        self.assertEqual(hashlib.sha256(final).hexdigest(),data['hybrid_sha256'])
        self.assertEqual((evidence['preserved_client_variations'],
                          evidence['preserved_water_frame_variations'],
                          evidence['meaningful_layout_differences']),(59,56,3))
        self.assertEqual(evidence['completed'],4107)
        self.assertTrue(evidence['layout_complete'])
        self.assertEqual(final[20+10800*4:],raw[20+10800*4:])

    def test_il_water_frame_compatibility_does_not_apply_to_other_maps(self):
        ident,w,h=7,2,2
        reference=b'LS2MAP'+struct.pack('>H',ident)+bytes(32)+struct.pack('>HH',w,h)+struct.pack('>8H',5008,1,1,1,0,0,0,0)
        raw=b'MAP\x01'+bytes(8)+struct.pack('<II',w,h)+struct.pack('<12H',5000,0,0,0,0,0,0,0,0xc000,0,0,0)
        final,evidence=complete_map(raw,reference,ident)
        self.assertEqual(final,raw)
        self.assertFalse(evidence['compatible'])

    def test_byte_gap_fill_matches_existing_solid_paint_exactly(self):
        for seed in range(4):
            image = Image.new('RGBA',(19,13))
            for y in range(image.height):
                for x in range(image.width):
                    value = (x*71+y*29+seed*37)%256
                    image.putpixel((x,y),(value,value//2,255-value,255 if value%5==0 and y%3 else 0))
            graphic = {'page':0,'rect':[0,0,*image.size]}
            expected = recovery.solid_pages({'graphics':{'1':graphic}},[image])[0]
            self.assertEqual(extend_solid_pixels(image).tobytes(),expected.tobytes())


if __name__ == '__main__':
    unittest.main()
