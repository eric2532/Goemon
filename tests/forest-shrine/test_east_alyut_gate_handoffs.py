import base64
import hashlib
import json
from pathlib import Path
import struct
import unittest
import zlib

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Alyut Complete Candidate'


class AlyutGateHandoffs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=json.loads((FOLDER/'map-data.json').read_text());cls.handoff=json.loads((FOLDER/'gate-handoffs.json').read_text())
        cls.bits=zlib.decompress(base64.b64decode(cls.source['walk_bits']))
        cls.pg=struct.unpack('<10000H',zlib.decompress(base64.b64decode(cls.source['objects_u16le_deflate'])))

    def test_only_four_original_two_cell_gate_transfers(self):
        self.assertEqual({row['source_warp']['id']for row in self.handoff['source_warps']},{488,490,493,495})
        expected={(x,y)for xs,ys in [([58,59],range(28,31)),([66,67],range(61,64))]for x in xs for y in ys}
        self.assertEqual({tuple(row['village_cell'])for row in self.handoff['handoff_cells']},expected)
        for row in self.handoff['source_warps']:
            warp=row['source_warp'];self.assertEqual((warp['source'],warp['target']),(2400,100))
            self.assertIn(warp,self.source['connections']);self.assertEqual(row['direction'],[0,-1])
            x,y=warp['cell'];self.assertEqual(warp['landing'],[x+529,y+19])
            sx,sy=row['first_village_open_after_buffer'];i=sy*100+sx;self.assertTrue(self.bits[i>>3]&(1<<(i&7)))

    def test_handoff_excludes_only_post_warp_invisible_buffer(self):
        def cells(rows):return {(x,y)for a,b,w,h in rows for x in range(a,a+w)for y in range(b,b+h)}
        before=cells(self.source['blocked_land_rectangles']);after=cells(self.handoff['blocked_land_rectangles'])
        exceptions={tuple(row['village_cell'])for row in self.handoff['handoff_cells']}
        self.assertEqual(before-after,exceptions);self.assertFalse(after-before);self.assertEqual(len(after),4424)
        for row in self.handoff['handoff_cells']:
            x,y=row['village_cell'];i=y*100+x
            self.assertEqual(self.pg[i],17644);self.assertFalse(self.bits[i>>3]&(1<<(i&7)))
            self.assertEqual(row['field_cell'],[x+529,y+20]);self.assertTrue(row['field_native_open']);self.assertTrue(row['field_recorded'])
            self.assertLess(row['field_pg1'],1000);self.assertNotIn(row['field_bg'],[0,100,*range(5000,5009)])

    def test_no_source_layer_or_known_flower_changes(self):
        self.assertEqual(hashlib.sha256((FOLDER/'map-data.json').read_bytes()).hexdigest(),self.handoff['map_data_sha256'])
        self.assertEqual(hashlib.sha256((FOLDER/'hybrid-map.bin').read_bytes()).hexdigest(),self.handoff['source_hybrid_sha256'])
        self.assertEqual(self.source['source']['sha256'],self.handoff['source_hybrid_sha256']);self.assertEqual(self.pg[73*100+36],11497)


if __name__=='__main__':unittest.main()
