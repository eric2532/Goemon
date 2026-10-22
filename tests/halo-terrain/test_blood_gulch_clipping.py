"""Geometric regression: preserve upper native walls while clearing walkers."""
import importlib.util,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('builder',Path(__file__).resolve().parents[2]/'tools/build_blood_gulch.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)

class BloodGulchClipping(unittest.TestCase):
 def test_triangle_crossing_clearance_is_split_with_native_upper_silhouette(self):
  self.assertTrue(hasattr(builder,'subtract_volume'),'Terrain adaptation must clip boundaries instead of dropping entire native faces')
  polygon=[([0.,0.,0.],[0.,0.]),([6.,24.,0.],[1.,0.]),([-6.,24.,0.],[0.,1.])]
  # Castle walker clearance: upper half is retained, with interpolated source UV.
  pieces=builder.subtract_volume(polygon,[(1,0,0,72),(-1,0,0,72),(0,0,1,72),(0,0,-1,72),(0,1,0,12)])
  self.assertEqual(len(pieces),1)
  self.assertEqual(len(pieces[0]),4)
  self.assertTrue(all(v[0][1]>=12-1e-6 for v in pieces[0]))
  self.assertTrue(any(v[0][1]==24 for v in pieces[0]))
  self.assertIn(([3.,12.,0.],[.5,0.]),pieces[0])
 def test_repeated_clearance_preserves_cut_plane_vertices(self):
  self.assertTrue(hasattr(builder,'subtract_volume'))
  polygon=[([0.,20.,0.],[0.,0.]),([6.,12.,0.],[1.,0.]),([-6.,12.,0.],[0.,1.])]
  self.assertEqual(builder.subtract_volume(polygon,[(0,1,0,12)]),[polygon])
 def test_native_triangle_boundary_cap_is_exactly_clipped_with_original_uvs(self):
  self.assertTrue(hasattr(builder,'clip_polygon'),'Native boundary cells need exact source triangle caps')
  polygon=[([-1.,0.,0.],[0.,0.]),([2.,0.,0.],[1.,0.]),([-1.,0.,3.],[0.,1.])]
  clipped=builder.clip_polygon(polygon,[(-1,0,0,0),(1,0,0,1),(0,0,-1,0),(0,0,1,1)])
  self.assertEqual(len(clipped),4)
  self.assertTrue(all(0<=v[0][0]<=1 and 0<=v[0][2]<=1 for v in clipped))
  for position,uv in clipped:
   self.assertAlmostEqual(uv[0],(position[0]+1)/3)
   self.assertAlmostEqual(uv[1],position[2]/3)
 def test_triangle_above_walkers_is_unchanged(self):
  self.assertTrue(hasattr(builder,'subtract_volume'),'Clearance clipping must preserve native roofs above walkers')
  polygon=[([0.,20.,0.],[0.,0.]),([6.,24.,0.],[1.,0.]),([-6.,24.,0.],[0.,1.])]
  pieces=builder.subtract_volume(polygon,[(0,1,0,12)])
  self.assertEqual(pieces,[polygon])

if __name__=='__main__':unittest.main()
