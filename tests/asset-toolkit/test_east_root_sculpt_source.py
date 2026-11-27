import hashlib,json,math,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
class SculptSource(unittest.TestCase):
 def test_source_pixels_and_closed_boundary_depth(self):
  folder=ROOT/'assets/maps/falan/east_region/root_sculpt_prototype';d=json.loads((folder/'data.json').read_text());source=ROOT/'assets/maps/falan/east_region/root_compounds';front=Image.open(source/'body-front.png').convert('RGBA');back=Image.open(folder/'independent-back.png').convert('RGBA')
  self.assertEqual(hashlib.sha256(front.tobytes()).hexdigest(),d['source_body_rgba_sha256']);self.assertEqual(hashlib.sha256(back.tobytes()).hexdigest(),d['back_rgba_sha256']);self.assertEqual(front.getchannel('A').tobytes(),back.getchannel('A').tobytes());self.assertEqual(d['origin'],[-448,-216]);self.assertEqual(d['size'],[736,551]);active={tuple(c)for c in d['active_cells']}
  for y,row in enumerate(d['depth_grid']):
   for x,value in enumerate(row):
    self.assertTrue(math.isfinite(value)and 0<=value<=8)
    if any((x+dx,y+dy)not in active for dx,dy in[(-1,-1),(0,-1),(-1,0),(0,0)]):self.assertEqual(value,0)
if __name__=='__main__':unittest.main()
