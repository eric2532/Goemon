"""Exact server planes use existing MAP01 resources without pretending client flags."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from prepare_sokia_server_maps import SOURCE,OUT,runtime_map,decoder_regression,ACTIVE_WATER
from prepare_east_region_maps import reference_map,active_raw


class ServerMapSource(unittest.TestCase):
    def test_new_map_planes_are_exact_and_flags_are_explicitly_synthetic(self):
        data=json.loads((OUT/'catalog.json').read_text());self.assertEqual(len(data['maps']),13)
        for row in data['maps'].values():
            source=(SOURCE/row['layout_reference']['file']).read_bytes()
            w,h,values,_=reference_map(source,row['id']);cells=w*h;raw=active_raw(row)
            self.assertEqual(struct.unpack_from('<II',raw,12),(w,h))
            self.assertEqual(struct.unpack_from(f'<{cells*2}H',raw,20),values)
            self.assertEqual(set(struct.unpack_from(f'<{cells}H',raw,20+cells*4)),{0xc000})
            self.assertFalse(row['source_flags_available'])
            self.assertEqual(row['recorded'],0)
            self.assertEqual(row['warp_cells'],[])
            self.assertEqual(row['sokia_visual_only'],row['id']not in ACTIVE_WATER)

    def test_decoder_preserves_known_ground_and_documents_client_exit_markers(self):
        result=decoder_regression()
        self.assertTrue(result['all_ground_cells_equal'])
        self.assertEqual([r['cell']for r in result['object_differences']],[[8,7],[91,7]])
        source=(SOURCE/'15526_usi').read_bytes()
        with self.assertRaises(ValueError):runtime_map(source,15525)
        with self.assertRaises(ValueError):runtime_map(source[:-2],15526)

    def test_existing_east_tree_rooms_are_reused_without_new_map_rows(self):
        data=json.loads((OUT/'catalog.json').read_text())
        east=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
        for ident,name in [(11031,'11031_kodaiju'),(11039,'11039_kodaiju2'),(11040,'11040_kodaiju3')]:
            path=f'BlueCrossgate/map/0/{ident}.dat';self.assertNotIn(path,data['maps'])
            w,h,values,_=reference_map((SOURCE/name).read_bytes(),ident)
            self.assertEqual(struct.unpack_from(f'<{w*h*2}H',active_raw(east['maps'][path]),20),values)

    def test_all_new_atlas_crops_retain_exact_source_rgba(self):
        data=json.loads((OUT/'catalog.json').read_text());self.assertEqual(len(data['graphics']),15)
        pages=[Image.open(ROOT/'assets/maps/original_crossgate'/p).convert('RGBA')for p in data['pages']]
        for g in data['graphics'].values():
            x,y,w,h=g['rect'];pixels=pages[g['page']].crop((x,y,x+w,y+h)).tobytes()
            self.assertEqual(hashlib.sha256(pixels).hexdigest(),g['rgba_sha256'])

    def test_two_ordinary_maps_keep_exact_original_groups_and_existing_bank_slots(self):
        data=json.loads((OUT/'encounters.json').read_text())
        self.assertEqual([(r['id'],r['skin'],r['family'])for r in data['species']],[(101422,11,'east_region'),(101503,106,'east_region')])
        offset=data['species_offset']
        for key in ['server:7029','server:7031','server:7032']:
            self.assertEqual(data['groups'][key]['source_group'],key.split(':')[1])
            for member in data['groups'][key]['members']:
                self.assertIn(member[0],[offset,offset+1]);self.assertEqual(member[1:],[25,27,1])
        self.assertEqual([(z['id'],z['map'],z['bounds'],z['probability'],z['maximum'])for z in data['zones']],
            [(7037,13509,[0,0,99,99],[1,1],3),(7039,13512,[0,0,49,79],[1,2],4)])
        for z in data['zones']:self.assertEqual(z['groups'],[['server:7032',1],['server:7029',1],['server:7031',1]])


if __name__=='__main__':unittest.main()
