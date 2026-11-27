"""The private architectural role partition must preserve the mapped CUT paint."""
import hashlib
import json
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import recover_elsa_island as source

FOLDER=source.REPORT/'Temple Interior/Central Assembly Candidate'


class CentralSourceTest(unittest.TestCase):
    def test_post_paint_retains_native_pixels_and_separate_cap_samples(self):
        spec=json.loads((FOLDER/'roles.json').read_text())
        self.assertEqual(len(spec['column_candidates']),2)
        original=Image.open(FOLDER/'414-422-native.png').convert('RGBA')
        for row in spec['column_candidates']:
            paint=Image.open(FOLDER/row['paint']).convert('RGB')
            native=Image.open(FOLDER/row['source']).convert('RGBA')
            selected=Image.open(FOLDER/(row['name']+'.png')).convert('RGBA').crop(row['crop'])
            self.assertEqual(native.tobytes(),selected.tobytes())
            x,y,_,_=row['crop']
            self.assertEqual(row['origin'],[spec['native_origin'][0]+x,spec['native_origin'][1]+y])
            for yy in range(native.height):
                for xx in range(native.width):
                    color=native.getpixel((xx,yy))
                    if color[3]:
                        self.assertEqual(paint.getpixel((xx,yy)),color[:3])
                        self.assertEqual(original.getpixel((x+xx,y+yy)),color)
            cap=tuple(row['shape']['cap_paint_pixel'])
            self.assertEqual(paint.getpixel(cap),native.getpixel(cap)[:3])
            self.assertTrue(row['shape']['native_faces'])
            self.assertEqual(row['shape']['sides'],8)
            heights=[v[1] for v in row['shape']['profile']]
            self.assertEqual(heights,sorted(heights,reverse=True))

    def test_disjoint_roles_reconstruct_all_original_visible_pixels(self):
        spec=json.loads((FOLDER/'roles.json').read_text())
        self.assertTrue(spec['candidate_only'])
        original=Image.open(FOLDER/'414-422-native.png').convert('RGBA')
        self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),spec['original_rgba_sha256'])
        claimed=bytearray(original.width*original.height)
        reconstructed=Image.new('RGBA',original.size)
        for role in spec['roles']:
            paint=Image.open(FOLDER/role['paint']).convert('RGBA')
            mask=Image.open(FOLDER/role['mask']).convert('L')
            self.assertEqual(hashlib.sha256(paint.tobytes()).hexdigest(),role['rgba_sha256'])
            self.assertEqual(sum(bool(v) for v in mask.tobytes()),role['selected_pixels'])
            for i,(native,actual,selected) in enumerate(zip(original.getdata(),paint.getdata(),mask.tobytes())):
                if selected:
                    self.assertFalse(claimed[i],(role['name'],i));claimed[i]=1
                    self.assertEqual(actual,native)
                else:self.assertEqual(actual[3],0)
            reconstructed.alpha_composite(paint)
        for i,(a,b) in enumerate(zip(original.getdata(),reconstructed.getdata())):
            if a[3]:self.assertEqual(a,b,i);self.assertTrue(claimed[i])
            else:self.assertEqual(b[3],0)

    def test_role_canvas_matches_each_original_cut_draw(self):
        spec=json.loads((FOLDER/'roles.json').read_text())
        original=Image.open(FOLDER/'414-422-native.png').convert('RGBA')
        count=0
        for proof in spec['sources']:
            self.assertEqual(len(proof['source_pieces']),len(proof['source_cells']))
            for serial,cell in zip(proof['source_pieces'],proof['source_cells']):
                native,origin,record=source.cut_image(59530,serial)
                self.assertEqual(record[0],proof['master'])
                x=(cell[0]+cell[1])*32+origin[0]-spec['native_origin'][0]
                y=(cell[1]-cell[0])*24+origin[1]-spec['native_origin'][1]
                for yy in range(native.height):
                    for xx in range(native.width):
                        color=native.getpixel((xx,yy))
                        if color[3]:self.assertEqual(original.getpixel((x+xx,y+yy)),color,(serial,xx,yy))
                count+=1
        self.assertEqual(count,5)


if __name__=='__main__':unittest.main()
