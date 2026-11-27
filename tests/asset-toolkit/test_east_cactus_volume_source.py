import importlib.util,json,sys,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
class CactusSourceTest(unittest.TestCase):
 def test_ground_partition_preserves_native_pixels(self):
  root=ROOT/'assets/maps/falan/east_region/cactus_volume_prototype';spec=json.loads((root/'data.json').read_text())['graphics']['11178'];old=Image.open(ROOT/'assets/maps/falan/east_region/nature/11178-front.png').convert('RGBA');front=Image.open(root/'11178-front.png').convert('RGBA');ground=Image.open(root/'11178-residual-ground.png').convert('RGBA')
  self.assertEqual(old.size,front.size)
  for source,body,floor in zip(old.getdata(),front.getdata(),ground.getdata()):
   self.assertEqual(source[:3],body[:3]);self.assertEqual(source[:3],floor[:3]);self.assertEqual(source[3],body[3]+floor[3]);self.assertFalse(body[3]and floor[3])
  self.assertEqual(spec['body_bottom'],133);self.assertEqual(spec['ground_offset'],10)
  self.assertEqual(spec['ground_offset']-(spec['graphic']['origin'][1]+132),0)
 def test_round_parts_keep_exact_source_foot_and_measured_limbs(self):
  spec=json.loads((ROOT/'assets/maps/falan/east_region/cactus_volume_prototype/data.json').read_text())['graphics']['11178'];self.assertEqual(spec['solid_parts'][0]['start'],[27,132]);self.assertEqual(len(spec['solid_parts']),4);self.assertEqual(spec['graphic']['origin'],[-27,-122]);self.assertEqual(spec['graphic']['footprint'],[1,1])
if __name__=='__main__':unittest.main()
