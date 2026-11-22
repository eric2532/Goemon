"""Protect solid travel props and reproducible original surface paint."""
from collections import Counter
from pathlib import Path
import math
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from asset_pipeline.glb import GLB
from prepare_travel_stone_surfaces import build


class TravelStone3DTest(unittest.TestCase):
    def test_each_part_has_closed_volume_and_opaque_materials(self):
        glb=GLB.read(ROOT/'assets/models/environments/wind_meadow/travel_stones/travel_stone_kit.glb')
        parts={n['name']:glb.doc['meshes'][n['mesh']] for n in glb.doc['nodes'] if 'mesh' in n}
        self.assertEqual(set(parts),{'Crescent','Post','Lectern','Crystal'})
        for material in glb.doc['materials']:
            self.assertEqual(material.get('alphaMode','OPAQUE'),'OPAQUE')
        for name,mesh in parts.items():
            points=[];edges=Counter();triangles=0
            for primitive in mesh['primitives']:
                vertices=glb.accessor(primitive['attributes']['POSITION'])
                self.assertTrue(all(math.isfinite(c) for point in vertices for c in point))
                points.extend(vertices)
                ids=[i[0] for i in glb.accessor(primitive['indices'])]
                positions=[tuple(round(c,5) for c in v) for v in vertices]
                for i in range(0,len(ids),3):
                    tri=[positions[ids[i+j]] for j in range(3)]
                    for j in range(3):edges[tuple(sorted([tri[j],tri[(j+1)%3]]))]+=1
                    triangles+=1
            self.assertTrue(all(max(p[i] for p in points)-min(p[i] for p in points)>.2 for i in range(3)),name)
            # Closed stacked post rings share coincident edges; they have four incident faces.
            self.assertTrue(all(count%2==0 for count in edges.values()),name)
            if name=='Crystal':self.assertEqual(triangles,8)

    def test_rectified_carving_paint_is_reproducible(self):
        source=ROOT/'assets/textures/wind_meadow/travel_stones'
        with tempfile.TemporaryDirectory() as folder:
            output=Path(folder);build(output)
            for name in ['surface_paint.png','crystal_paint.png','source_patches.json']:
                self.assertEqual((output/name).read_bytes(),(source/name).read_bytes())


if __name__=='__main__':unittest.main()
