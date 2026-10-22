"""Behavioral checks for recovered native source and the playable adaptation."""
import hashlib, json, math, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/maps/blood_gulch'

class BloodGulchAssets(unittest.TestCase):
 def test_native_source_and_provenance_are_recovered(self):
  self.assertTrue((DEST/'source.json').exists(), 'Native Blood Gulch BSP source must be recovered')
  source=json.loads((DEST/'source.json').read_text())
  self.assertEqual(source['map'],'bloodgulch.map')
  self.assertEqual(source['source_material_count'],79)
  self.assertGreater(sum(len(g['faces']) for g in source['groups']),3000)
  self.assertTrue(all((DEST/g['image']).exists() for g in source['groups'] if 'image' in g))
  self.assertGreater(len(source['map_sha256']),60)
  for name,facts in source['images'].items():
   self.assertEqual(hashlib.sha256((DEST/name).read_bytes()).hexdigest(),facts['sha256'],'Native source pixels must remain unchanged')
 def test_adaptation_has_open_pad_and_eight_connected_approaches(self):
  self.assertTrue((DEST/'adaptation.json').exists(), 'Adapted grid must be baked')
  data=json.loads((DEST/'adaptation.json').read_text())
  self.assertEqual((data['width'],data['spacing'],data['origin']),(161,3.0,[-240.0,-240.0]))
  self.assertEqual(len(data['heights']),161*161)
  self.assertTrue(all(math.isfinite(h) for h in data['heights']))
  self.assertFalse(any(data['bridges']))
  for iz in range(58,103):
   for ix in range(58,103):
    self.assertAlmostEqual(data['heights'][iz*161+ix],0.0,places=5)
    self.assertEqual(data['covered'][iz*161+ix],1)
  for route in data['approach_routes']:
   for x,z in route:
    ix=round((x+240)/3);iz=round((z+240)/3)
    self.assertEqual(data['covered'][iz*161+ix],1)
    self.assertLess(abs(data['heights'][iz*161+ix]),.01)
  self.assertEqual(len(data['approach_routes']),8)
  self.assertGreater(len(data['boundary_cap_source_triangles']),0,'Physical native edge caps must be generated')
  self.assertTrue(all(isinstance(i,int) and 0<=i<2425 for i in data['boundary_cap_source_triangles']))
  for route in data['approach_routes']:
   for x,z in route:
    for radius in (3.9,8.5):
     for dx,dz in ((0,0),(-1,0),(1,0),(0,-1),(0,1),(-.707,-.707),(.707,-.707),(-.707,.707),(.707,.707)):
      fx=(x+dx*radius+240)/3;fz=(z+dz*radius+240)/3
      ix=int(fx);iz=int(fz)
      for ox,oz in ((0,0),(1,0),(0,1),(1,1)):
       at=(iz+oz)*161+ix+ox
       self.assertEqual(data['covered'][at],1,'Attack corridor footprint must be covered')
       self.assertLess(abs(data['heights'][at]),.01,'Ordinary and giant footprints need level approaches')
 def test_bundled_castle_and_baked_resources(self):
  self.assertTrue((ROOT/'assets/maps/forest_blood_gulch.json').exists(), 'Blood Gulch castle preset must exist')
  layout=json.loads((ROOT/'assets/maps/forest_blood_gulch.json').read_text())
  original=json.loads((ROOT/'assets/maps/forest_four_gates.json').read_text())
  self.assertEqual(layout['terrain_source'],'blood_gulch')
  self.assertEqual(layout['buildings'],[b for b in original['buildings'] if b['kind']!='mine'])
  self.assertEqual(len(layout['portals']),8)
  self.assertEqual(layout['roads'],[],'Native painted dirt paths must remain visible without tiled road overlays')
  self.assertEqual(layout['trees'],[]);self.assertEqual(layout['ramparts'],[]);self.assertEqual(layout['deposits'],[])
  for name in ['terrain.res','cliffs.res','collision.res','surface.res']:
   self.assertTrue((DEST/name).is_file(),name)

if __name__=='__main__':unittest.main()
