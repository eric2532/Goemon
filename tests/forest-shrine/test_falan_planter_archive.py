"""Verify every city planter station and its paint against the preserved archive."""
import hashlib
import json
from pathlib import Path
import re
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
if not (ROOT.parent/"Magic Power/tools/cg_library.py").is_file():
    raise unittest.SkipTest("Falan planter comparison needs the adjacent Magic Power archive")
sys.path[:0] = [str(ROOT/"tools"),str(ROOT.parent/"Magic Power/tools")]
import cg_library as library
from build_freyja_destinations import load_map


class FalanPlanterArchiveTest(unittest.TestCase):
    def test_all_226_source_stations_and_four_variants_are_exact(self):
        width,_,_,objects,_ = load_map(library,1000)
        expected=[]
        for i,serial in enumerate(objects):
            if serial in [10426,10427,10452,10453]:
                expected.append((3*(i//width-134),3*(153-i%width),serial))
        section=(ROOT/"assets/maps/falan/city_street_data.gd").read_text().split("const PLANTERS=[",1)[1].split("\n]",1)[0]
        actual=[tuple(map(int,row))for row in re.findall(r"Vector2\((-?\d+),(-?\d+)\),(\d+)",section)]
        self.assertEqual(actual,expected)
        self.assertEqual(len(actual),226)
        self.assertEqual([sum(row[2]==s for row in actual)for s in [10426,10427,10452,10453]],[72,46,64,44])

    def test_original_planter_pixels_and_leaf_colors_are_preserved(self):
        path=ROOT/"assets/maps/falan"
        body=Image.open(path/"city_planter_art.png").convert("RGBA")
        leaves=Image.open(path/"city_planter_leaves.png").convert("RGBA")
        provenance=json.loads((path/"city_street_surfaces.json").read_text())
        for i,serial in enumerate([10426,10427,10452,10453]):
            entry=library.serial_index()[serial]
            original=library.image_from_record(entry["pack"],entry["row"])
            self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),provenance["graphics"][str(serial)]["rgba_sha256"])
            region=(i*64,0,i*64+original.width,original.height)
            self.assertEqual(body.crop(region).tobytes(),original.tobytes())
            visible=0
            for source,leaf in zip(original.getdata(),leaves.crop(region).getdata()):
                if leaf[3]:
                    visible+=1
                    self.assertEqual(leaf,source)
            self.assertGreater(visible,500)


if __name__=="__main__":unittest.main()
