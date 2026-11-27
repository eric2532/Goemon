"""Round cactus repair keeps native plant/ground paint and cropped flowers."""
import hashlib
import json
import unittest
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'assets/maps/falan/east_region/round_cactus'

class RoundCactusSource(unittest.TestCase):
    def test_native_partition_and_detail_crop_contract(self):
        data=json.loads((FOLDER/'data.json').read_text())
        catalog=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
        for token,spec in data['graphics'].items():
            g=catalog['graphics'][token];x,y,w,h=g['rect']
            source=Image.open(ROOT/'assets/maps/original_crossgate'/catalog['pages'][g['page']]).convert('RGBA').crop((x,y,x+w,y+h))
            self.assertEqual(hashlib.sha256(source.tobytes()).hexdigest(),spec['source_rgba_sha256'])
            body=Image.open(FOLDER/(token+'-body.png')).convert('RGBA');ground=Image.open(FOLDER/(token+'-ground.png')).convert('RGBA')
            detail=Image.open(FOLDER/(token+'-detail.png')).convert('RGBA')
            for a,b,c,d in zip(source.getdata(),body.getdata(),ground.getdata(),detail.getdata()):
                self.assertEqual(a[:3],b[:3]);self.assertEqual(a[:3],c[:3]);self.assertEqual(a[:3],d[:3]);self.assertEqual(a[3],b[3]+c[3]+d[3])
            for index,box in enumerate(spec.get('details',[])):
                crop=Image.open(FOLDER/f'{token}-detail-{index}.png').convert('RGBA')
                self.assertEqual(crop.size,(box[2]-box[0],box[3]-box[1]))
                self.assertEqual(crop.tobytes(),detail.crop(tuple(box)).tobytes())
                base=spec['detail_attachments'][index];self.assertGreaterEqual(detail.getpixel((int(base[0]),int(base[1])))[3],128)

if __name__=='__main__':unittest.main()
