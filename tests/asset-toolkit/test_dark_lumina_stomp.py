import hashlib
import json
import math
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from asset_pipeline.glb import GLB


class DarkLuminaStompTests(unittest.TestCase):
    def test_original_sectors_uvs_and_pixels(self):
        folder=ROOT/'assets/characters/recovered_monsters/dark_lumina_2_effects'
        sector=GLB.read(folder/'stomp_sector.glb')
        wave=GLB.read(folder/'stomp_wave.glb')
        original=sector.doc['meshes'][0]['primitives'][0]['attributes']
        assembled=wave.doc['meshes'][0]['primitives'][0]['attributes']
        report=json.loads((folder/'stomp_sources.json').read_text())
        self.assertEqual((report['actor'],report['sectors'],report['sector_angle']),('0x352',19,227))
        for attribute,index in original.items():
            rows=sector.accessor(index);actual=wave.accessor(assembled[attribute])
            self.assertEqual(len(actual),len(rows)*19)
            for i in range(19):
                angle=i*227*math.tau/4096;s,c=math.sin(angle),math.cos(angle)
                expected=[(c*p[0]+s*p[2],p[1],-s*p[0]+c*p[2]) if attribute in ['POSITION','NORMAL'] else p for p in rows]
                for a,b in zip(actual[i*len(rows):(i+1)*len(rows)],expected):
                    for x,y in zip(a,b):self.assertAlmostEqual(x,y,delta=.0001)
        self.assertEqual(wave.image_bytes(wave.doc['images'][0]),(folder/'stomp_wave.png').read_bytes())
        source=ROOT/'build/Other Files/Musashi Asset Recovery'/report['source']
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),report['source_sha256'])
        self.assertEqual(report['rise_scales'],[8192,14336,18432,17408,16384,12288,8192,4096])


if __name__=='__main__':unittest.main()
