"""The Sokia crop proof must include disconnected ground and never count water as missing land."""
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from recover_sokia import source_coverage

class WholeSourceCoverage(unittest.TestCase):
 def test_every_disconnected_component_is_counted(self):
  report=source_coverage(4,2,[6000,0,6000,5000,6000,0,6000,5008],
                         [1,0,1,0,0,0,0,0],[True,False,True,False,True,False,True,False],
                         {'a':{'bounds':[0,0,1,2]},'b':{'bounds':[2,0,1,2]}},[2,0,0,0,0,0,0,0])
  self.assertEqual([r['cells'] for r in report['components']],[2,2])
  self.assertEqual(report['outside_crops']['ground_serials'],{5000:1,5008:1})
  self.assertEqual(report['outside_crops']['decoder_open_cells'],0)
 def test_an_unseeded_island_cannot_be_silently_omitted(self):
  with self.assertRaisesRegex(AssertionError,'land outside'):
   source_coverage(3,1,[6000,5000,6000],[0,0,0],[True,False,True],
                   {'current':{'bounds':[0,0,1,1]}},[0,0,0])
 def test_flagged_entrances_cannot_be_silently_omitted(self):
  with self.assertRaisesRegex(AssertionError,'flagged entrances outside'):
   source_coverage(2,1,[6000,5000],[0,0],[True,False],
                   {'current':{'bounds':[0,0,1,1]}},[0,2])

if __name__=='__main__':unittest.main()
