"""Independent checks of preserved client cells and append-only native artwork."""
import base64
import hashlib
import json
from pathlib import Path
import struct
import unittest
import zlib
import sys
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'assets/maps/original_crossgate'


def decode(row,key='raw'):
    return zlib.decompress(base64.b64decode(row.get(key,row['raw'])))


class UniversitySourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=json.loads((ART/'catalog.json').read_text())
        cls.region=json.loads((ART/'university/catalog.json').read_text())

    def test_existing_catalog_is_unchanged(self):
        self.assertEqual(hashlib.sha256((ART/'catalog.json').read_bytes()).hexdigest(),self.region['base_sha256'])
        self.assertFalse(set(self.base['graphics']) & set(self.region['graphics']))

    def test_every_recorded_client_cell_and_flag_is_preserved(self):
        for path,row in self.region['maps'].items():
            original=decode(row);runtime=decode(row,'restored_raw')
            self.assertEqual(hashlib.sha256(original).hexdigest(),row['sha256'],path)
            if path in self.base['maps']:self.assertEqual(original,decode(self.base['maps'][path]),path)
            w,h=struct.unpack_from('<II',original,12);cells=w*h
            self.assertEqual(len(original),20+cells*6,path)
            self.assertEqual(runtime[20+cells*4:],original[20+cells*4:],path)
            values=struct.unpack_from(f'<{cells*3}H',original,20)
            final=struct.unpack_from(f'<{cells*3}H',runtime,20)
            for i in range(cells):
                if values[2*cells+i] & 0xc000:
                    self.assertEqual((values[i],values[cells+i]),(final[i],final[cells+i]),(path,i))

    def test_each_new_graphic_retains_its_native_pixels(self):
        offset=len(self.base['pages']);pages={}
        for serial,g in self.region['graphics'].items():
            page=g['page']-offset
            self.assertTrue(0<=page<len(self.region['pages']),serial)
            if page not in pages:pages[page]=Image.open(ART/self.region['pages'][page]).convert('RGBA')
            x,y,w,h=g['rect'];rgba=pages[page].crop((x,y,x+w,y+h)).tobytes()
            self.assertEqual(hashlib.sha256(rgba).hexdigest(),g['rgba_sha256'],serial)
            if 'surfaces' in g:
                index=g['surfaces'][0]-len(self.base['surface_pages'])
                self.assertTrue(0<=index<len(self.region['surface_pages']),serial)
                self.assertTrue((ART/self.region['surface_pages'][index]).is_file(),serial)

    def test_version_conflict_is_explicit_and_not_filled(self):
        row=self.region['maps']['BlueCrossgate/map/0/4400.dat']
        self.assertEqual(decode(row,'restored_raw'),decode(row))
        report=json.loads((ROOT/'build/Other Files/Asset Toolkit/University Region/map-preservation.json').read_text())
        self.assertIn(4400,[r['source'] for r in report['blockers']])
        self.assertIn('BlueCrossgate/map/0/4409.dat',self.region['maps'])
        self.assertIn('BlueCrossgate/map/0/4424.dat',self.region['maps'])

    def test_sylph_chambers_extend_the_shared_map_without_claiming_other_quests(self):
        manifest=json.loads((ROOT/'assets/maps/falan/university_region/sylph_ownership.json').read_text())['59752']
        shared=json.loads((ART/'elsa/catalog.json').read_text())['maps']['BlueCrossgate/map/0/59752.dat']
        self.assertEqual(manifest['layout_sha256'],shared['restored_sha256'])
        self.assertEqual(manifest['chamber_walk_cells'],[49,49])
        bits=zlib.decompress(base64.b64decode(manifest['open']));native=zlib.decompress(base64.b64decode(shared['walk']))
        self.assertEqual(sum(bin(v).count('1') for v in bits),98)
        self.assertTrue(all((part & source)==part for part,source in zip(bits,native)))
        width=manifest['size'][0]
        for x,y in [(100,112),(98,110),(104,116),(130,143),(136,148)]:
            index=y*width+x;self.assertTrue(bits[index>>3] & (1<<(index&7)))
        # The Elsa room is independently owned and must not be absorbed into the regional mask.
        index=206*width+264;self.assertFalse(bits[index>>3] & (1<<(index&7)))

    def test_native_snow_templates_are_complete_client_snapshots(self):
        sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
        import cg_library as lib
        templates=self.region['mountain_templates'];self.assertEqual(len(templates),12)
        for entry in templates:
            _,payload=lib.source_file(entry['source_file_id'])
            source=payload.read_bytes() if isinstance(payload,Path) else payload
            row=self.region['maps'][entry['path']];raw=decode(row)
            self.assertEqual(raw,source,entry['path'])
            self.assertEqual(hashlib.sha256(raw).hexdigest(),entry['sha256'])
            w,h=entry['size'];self.assertEqual(w,40);self.assertTrue(40<=h<=80)
            values=struct.unpack_from(f'<{w*h*3}H',raw,20)
            self.assertTrue(all(value&0xc000 for value in values[w*h*2:]))
            for name,serial in [('up',17956),('down',17957)]:
                x,y=entry[name];self.assertEqual(values[w*h+y*w+x],serial)

    def test_added_npcs_preserve_source_anchors_pixels_and_existing_residents(self):
        folder=ROOT/'assets/maps/falan/university_region'
        population=json.loads((folder/'population.json').read_text())
        existing=json.loads((ROOT/'assets/maps/falan/snow_region/population.json').read_text())
        previous={r['id'] for r in existing['npcs']}
        self.assertFalse(previous & {r['id'] for r in population['npcs']})
        table=ROOT/'assets/references/crossgate_tina/events/npc.txt'
        rows={r[3]:r for line in table.read_bytes().decode('gb18030').splitlines() if len(r:=line.split('\t'))==25}
        self.assertEqual(hashlib.sha256(table.read_bytes()).hexdigest(),population['source_hashes']['npc.txt'])
        with Image.open(folder/'npc-atlas.png') as image:
            for token,record in population['art'].items():
                x,y,w,h=record['rect']
                self.assertTrue(x>=0 and y>=0 and x+w<=image.width and y+h<=image.height,token)
                self.assertEqual(hashlib.sha256(image.crop((x,y,x+w,y+h)).tobytes()).hexdigest(),record['rgba_sha256'],token)
        for record in population['npcs']:
            source=rows[record['id']]
            self.assertFalse(source[0].startswith('#'),record['id'])
            self.assertEqual(source[6],'1',record['id'])
            self.assertEqual([record['source'],*record['cell']],list(map(int,[source[8],source[9],source[10]])),record['id'])
            self.assertTrue(record['messages'],record['id'])
        actions={r['id']:r.get('quest_action') for r in population['npcs']}
        self.assertEqual(actions['6394'],'decree_blade')
        self.assertEqual(actions['6450'],'decree_return')
        self.assertEqual(actions['6735'],'azure_wall')


if __name__=='__main__':unittest.main()
