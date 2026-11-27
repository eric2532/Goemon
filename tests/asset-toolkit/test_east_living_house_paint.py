"""Private architectural layers retain source paint, not compound foliage."""
import hashlib
import json
import unittest
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'assets/maps/falan/east_region/living_house_paint'

class ShrineHousePaint(unittest.TestCase):
    def test_source_pixels_and_original_doors_are_retained(self):
        data=json.loads((FOLDER/'data.json').read_text())
        catalog=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
        g=catalog['graphics']['1230040'];x,y,w,h=g['rect']
        page=ROOT/'assets/maps/original_crossgate'/catalog['pages'][g['page']]
        source=Image.open(page).convert('RGBA').crop((x,y,x+w,y+h))
        self.assertEqual(hashlib.sha256(source.tobytes()).hexdigest(),data['source_rgba_sha256'])
        self.assertEqual(len(data['houses']),3)
        for house in data['houses']:
            paint=Image.open(FOLDER/house['file']).convert('RGBA');self.assertEqual(paint.size,source.size)
            self.assertEqual(hashlib.sha256(paint.tobytes()).hexdigest(),house['native_rgba_sha256'])
            reds=0
            for original,masked in zip(source.getdata(),paint.getdata()):
                self.assertEqual(original[:3],masked[:3]);self.assertIn(masked[3],(0,original[3]))
                if masked[3]>=128 and masked[0]>masked[1]*1.2 and masked[0]>masked[2]*1.25:reds+=1
            self.assertGreater(reds,50,'Each source-red doorway keeps its actual native paint')
            self.assertLess(house['kept_pixels'],20000,'A house must not replay the complete compound sprite')

if __name__=='__main__':unittest.main()
