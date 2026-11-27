"""Private source/closed-component contracts, separate from runtime acceptance."""
import collections
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import unittest
import zlib

from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Volume Candidates'


def mesh(serial):
 blob=(FOLDER/f'{serial}.bin').read_bytes();assert blob[:4]==b'ECR4';count,indices,length=struct.unpack_from('<III',blob,4);raw=zlib.decompress(blob[16:]);assert len(raw)==length
 rows=list(struct.iter_unpack('<12f',raw[:count*48]));ids=struct.unpack_from(f'<{indices}I',raw,count*48);assert count*48+indices*4==length
 return blob,rows,ids


class EastCliffVolumeCandidate(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.data=json.loads((FOLDER/'data.json').read_text())

 def test_native_sources_and_generation_dependencies(self):
  self.assertEqual({12536,12537,12538,12542,12543,12546},set(map(int,self.data['graphics'])))
  for path,digest in self.data['source_inputs'].items():self.assertEqual(digest,hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),path)
  sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'));import cg_library as lib
  lookup=lib.serial_index()
  for token,row in self.data['graphics'].items():
   with self.subTest(graphic=token):
    source=lookup[int(token)];original=lib.image_from_record(source['pack'],source['row']).convert('RGBA');paint=Image.open(FOLDER/f'{token}.png').convert('RGBA')
    self.assertEqual(row['native_rgba_sha256'],hashlib.sha256(original.tobytes()).hexdigest());self.assertEqual(original.convert('RGB').tobytes(),paint.convert('RGB').tobytes())
    self.assertEqual(row['reused_master']['sha256'],hashlib.sha256((ROOT/row['reused_master']['source']).read_bytes()).hexdigest());self.assertFalse(row['reused_master']['owner_y_scale_applied'])
    self.assertEqual(row['native_registration']['fraction'],1.);self.assertFalse(row['source_contour']['shared_native_modified'])

 def test_buffers_and_every_closed_component(self):
  for token,row in self.data['graphics'].items():
   with self.subTest(graphic=token):
    blob,vertices,ids=mesh(token);self.assertEqual(row['cost']['geometry_sha256'],hashlib.sha256(blob).hexdigest());self.assertEqual(len(ids),row['cost']['indices']);self.assertEqual(len(vertices),row['cost']['vertices'])
    for vertex in vertices:
     self.assertTrue(all(math.isfinite(v)for v in vertex));self.assertAlmostEqual(math.sqrt(sum(v*v for v in vertex[3:6])),1.,places=4)
     self.assertTrue(all(0<=v<=1 for v in vertex[6:10]))
    self.assertTrue(all(0<=index<len(vertices)for index in ids))
    self.assertEqual(len(row['closed_components']),row['closed_boulders']+1)
    for component in row['closed_components']:
     edges=collections.Counter();start=component['first_triangle']*3;end=start+component['triangles']*3
     for offset in range(start,end,3):
      triangle=[tuple(round(v,5)for v in vertices[index][:3])for index in ids[offset:offset+3]]
      for a,b in zip(triangle,triangle[1:]+triangle[:1]):edges[tuple(sorted((a,b)))]+=1
     self.assertEqual({2},set(edges.values()),f"Closed component {token}:{component['first_triangle']}")

 def test_global_projection_and_nonwrapping_material(self):
  shader=(ROOT/'scripts/forest/forest_east_cliff_volume.gdshader').read_text();self.assertNotIn('discard',shader);self.assertIn('greaterThanEqual(UV',shader);self.assertIn('lessThan(UV',shader);self.assertIn('native_eye',shader)
  for token,row in self.data['graphics'].items():
   with self.subTest(graphic=token):
    _,vertices,_=mesh(token)
    with Image.open(FOLDER/f'{token}.png')as image:size=image.size
    center=[(row['source_footprint'][0]-1)*1.5,0,-(row['source_footprint'][1]-1)*1.5]
    for vertex in vertices:
     if vertex[10]<0 and vertex[11]<0:continue
     x,y,z=[vertex[i]+center[i]for i in range(3)];u=(x+z)*32/3-row['source_origin'][0];v=(z-x)*8-y/row['pixel_height']-row['source_origin'][1]
     self.assertAlmostEqual(u,vertex[10]*size[0],places=3);self.assertAlmostEqual(v,vertex[11]*size[1],places=3)


if __name__=='__main__':unittest.main()
