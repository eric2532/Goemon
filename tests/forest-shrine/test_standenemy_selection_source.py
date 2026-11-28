"""Keep original alternative selection authenticated against pinned server bytes."""
import json
from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from recover_standenemy_selection import recover
class StandEnemySource(unittest.TestCase):
 def test_pinned_original_parser_and_single_encounter_selection(self):
  expected=json.loads((ROOT/'assets/references/standenemy-selection.json').read_text())
  self.assertEqual(recover(),expected)
  self.assertEqual(expected['parser_cases'][0]['encounters'],[9034,9035,9036])
  self.assertTrue(all(row['construction_calls']==1 for row in expected['selection_cases']))
if __name__=='__main__':unittest.main()
