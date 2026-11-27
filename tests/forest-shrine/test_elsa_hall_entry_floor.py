"""Independent original-client RGB/extent checks for the staged entry UV pages."""
import hashlib
import json
from pathlib import Path
import sys
import unittest
from PIL import Image, ImageChops

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import recover_elsa_island as source


class HallEntryFloorTest(unittest.TestCase):
    def test_animation_flags_match_original_headers(self):
        catalog=json.loads((ROOT/'assets/maps/falan/elsa/scenery/data.json').read_text())
        for serial,clip in catalog['animations'].items():
            _,_,_,native=source.scenery_frame(int(serial))
            self.assertEqual((clip['flags'],clip['opacity'],clip['duration']),
                             (native['flags'],native['opacity'],native['duration']))
        for serial in ['113651','113652']:
            self.assertEqual(catalog['animations'][serial]['flags']&8,8)

    def test_private_pages_preserve_source_rgb_and_limit_alpha_changes(self):
        folder=source.REPORT/'Temple Interior/Hall Entry Candidate'
        spec=json.loads((folder/'floor-data.json').read_text());mask=Image.open(folder/spec.get('role_mask_file','displaced-floor-mask.png')).convert('L')
        self.assertEqual(spec['map'],59530);self.assertTrue(spec['candidate_only'])
        self.assertEqual(hashlib.sha256(mask.tobytes()).hexdigest(),spec['source_mask_sha256'])
        width,_,planes=source.reference_map(59530);rect=spec['native_rect'];pages={};non_matte_removed=0
        for key,row in spec['placements'].items():
            index=int(key);self.assertEqual(planes[0][index],row['serial'])
            original,origin,_=source.cut_image(59530,row['serial']);self.assertEqual(list(origin),row['origin'])
            self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),row['source_sha256'])
            page=row['page']
            if page not in pages:pages[page]=Image.open(folder/f'floor-atlas-{page}.png').convert('RGBA')
            x,y,w,h=row['rect'];self.assertEqual((w,h),original.size);actual=pages[page].crop((x,y,x+w,y+h))
            self.assertEqual(hashlib.sha256(actual.tobytes()).hexdigest(),row['rgba_sha256'])
            self.assertIsNone(ImageChops.difference(original.convert('RGB'),actual.convert('RGB')).getbbox())
            u=(index%width+index//width)*32+origin[0]-rect[0];v=(index//width-index%width)*24+origin[1]-rect[1]
            role=mask.crop((u,v,u+w,v+h))
            for yy in range(h):
                for xx in range(w):
                    a=original.getpixel((xx,yy));b=actual.getpixel((xx,yy))
                    self.assertLessEqual(b[3],a[3])
                    if a[3]!=b[3]:
                        self.assertTrue(role.getpixel((xx,yy)) or a[:3]==(2,2,2))
                        if not role.getpixel((xx,yy)) and a[:3]!=(2,2,2):non_matte_removed+=1
        self.assertEqual(non_matte_removed,0,'Only the actual native2,2,2 matte may disappear outside the relocated photos')


if __name__=='__main__':unittest.main()
