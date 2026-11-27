"""Centred ridge inputs only cover the exact native graphic's original anchor."""
from pathlib import Path
import subprocess
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools'))
from audit_freyja_union import ridge_source_anchor,matching_station


class RidgeAnchorAudit(unittest.TestCase):
    def test_alternate_source_cannot_overwrite_client_evidence(self):
        script=Path(__file__).resolve().parents[2]/'tools/audit_freyja_union.py'
        result=subprocess.run([sys.executable,str(script),'--source-map','/tmp/not-loaded-map100.dat'],capture_output=True,text=True)
        self.assertEqual(result.returncode,2)
        self.assertIn('separate --out folder',result.stderr)

    def test_asymmetric_footprint_centre_round_trips(self):
        lookup={12542:{'east':3,'south':5}}
        row=[7.,4.,12542,9,15,12,True]  # source anchor (6,6)
        self.assertEqual(ridge_source_anchor(row,lookup),(6.,6.))
        objects=[0]*100;objects[66]=12542
        self.assertEqual(matching_station(10,10,objects,*ridge_source_anchor(row,lookup),row[2]),66)
        self.assertIsNone(matching_station(10,10,objects,*row[:2],row[2]))

    def test_half_cell_centres_never_substitute_a_different_graphic(self):
        row=[6.5,5.5,12538];lookup={12538:{'east':2,'south':2}}
        self.assertEqual(ridge_source_anchor(row,lookup),(6.,6.))
        objects=[0]*100;objects[66]=12537
        self.assertIsNone(matching_station(10,10,objects,*ridge_source_anchor(row,lookup),row[2]))
        self.assertIsNone(matching_station(10,10,objects,6.5,6.,12537))


if __name__=='__main__':unittest.main()
