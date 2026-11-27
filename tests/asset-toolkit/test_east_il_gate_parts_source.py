import hashlib,json,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];F=ROOT/'assets/maps/falan/east_region/il_gate_parts'
class GateSource(unittest.TestCase):
 def test_native_origin_footprint_and_exact_pixel_partition(self):
  data=json.loads((F/'data.json').read_text());self.assertEqual(set(data['graphics']),{'11077','11078'})
  for token,row in data['graphics'].items():
   original=Image.open(F/f'{token}-native.png').convert('RGBA');parts=[Image.open(F/f'{token}-{p}.png').convert('RGBA')for p in['leaf-front','post-front','ground']]
   self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),row['native_rgba_sha256']);self.assertEqual(row['footprint'],[2,1]);self.assertEqual(row['origin'],[-22,-151]if token=='11077'else[-30,-136])
   for source,*pieces in zip(original.getdata(),*[im.getdata()for im in parts]):
    self.assertEqual(source[3],sum(p[3]for p in pieces));self.assertTrue(all(p[:3]==source[:3]for p in pieces));self.assertLessEqual(sum(p[3]>0 for p in pieces),1)
 def test_complete_arch_back_and_fixed_source_material(self):
  data=json.loads((F/'data.json').read_text());grain=ROOT/data['reused_grain']['path'];self.assertEqual(hashlib.sha256(grain.read_bytes()).hexdigest(),data['reused_grain']['file_sha256'])
  for token,row in data['graphics'].items():
   back=Image.open(F/f'{token}-leaf-back.png').convert('RGBA');self.assertGreater(sum(p[3]>0 for p in back.getdata()),1000);self.assertEqual(row['leaf_thickness'],.22);self.assertEqual(row['post_height_pixels'],104)
   for name,digest in row['derived_rgba_sha256'].items():self.assertEqual(hashlib.sha256(Image.open(F/name).convert('RGBA').tobytes()).hexdigest(),digest)
if __name__=='__main__':unittest.main()
