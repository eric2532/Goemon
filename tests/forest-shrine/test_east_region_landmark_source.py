"""The landmark derivative keeps native art, measured bounds and explicit inferred depth."""
import hashlib
import json
import math
from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from prepare_east_region_landmarks import PATCHES
from recover_venoa_walls import native_without_ground_shadow


class EastLandmarkSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=ROOT/'assets/maps/original_crossgate'
        cls.catalog=json.loads((cls.base/'east/catalog.json').read_text())
        cls.out=ROOT/'assets/maps/falan/east_region/landmarks'
        cls.data=json.loads((cls.out/'profiles.json').read_text())

    def test_native_graphics_and_calibrated_projection(self):
        self.assertEqual(self.data['source_catalog_sha256'],hashlib.sha256((self.base/'east/catalog.json').read_bytes()).hexdigest())
        self.assertAlmostEqual(self.data['calibration']['vertical'],math.sqrt(2*((32/3)**2-8**2)))
        for token,spec in self.data['graphics'].items():
            self.assertEqual(spec['native_rgba_sha256'],self.catalog['graphics'][token]['rgba_sha256'],token)
        self.assertGreaterEqual(len(self.data['inferred']),3)

    def test_measured_parts_stay_within_the_native_drawing(self):
        for token,spec in self.data['graphics'].items():
            width,height=self.catalog['graphics'][token]['rect'][2:]
            houses=[spec] if spec['kind']=='hip_house' else spec.get('houses',[])
            for house in houses:
                for point in house['feet']+house['eaves']+[house['apex']]:
                    self.assertTrue(0<=point[0]<=width and 0<=point[1]<=height,(token,point))
                self.assertGreater(house['wall_pixels'],0,token)
            for stair in spec.get('stairs',[]):
                self.assertGreater(stair['steps'],1,token)
                self.assertGreater(stair['height_pixels'],0,token)
            for row in spec.get('towers',[])+spec.get('trunks',[]):
                self.assertEqual(row['profile'][0][0],0,token)
                self.assertEqual(row['profile'][-1][0],1,token)
                if 'top' in row:self.assertTrue(0<=row['top'][0]<=width and 0<=row['top'][1]<=height,(token,row['top']))

    def test_leaf_panels_keep_source_pixels_and_only_remove_alpha(self):
        pages={}
        for token,spec in self.data['graphics'].items():
            if spec['kind']!='native_foliage' and not spec.get('crowns'):continue
            g=self.catalog['graphics'][token];page=g['page']
            if page not in pages:pages[page]=Image.open(self.base/self.catalog['pages'][page]).convert('RGBA')
            x,y,w,h=g['rect'];original=pages[page].crop((x,y,x+w,y+h))
            derivatives=[]
            if spec['kind']=='native_foliage':derivatives.append((original,self.out/f'{token}-foliage.png'))
            for i,box in enumerate(spec.get('crowns',[])):derivatives.append((original.crop(tuple(box)),self.out/f'{token}-crown-{i}.png'))
            for source,path in derivatives:
                actual=Image.open(path).convert('RGBA')
                self.assertEqual(actual.size,source.size,path.name)
                for before,after in zip(source.getdata(),actual.getdata()):
                    self.assertLessEqual(after[3],before[3],path.name)
                    if after[3]:self.assertEqual(after[:3],before[:3],path.name)
            for index,box in enumerate(spec.get('crowns',[])):
                anchor=spec['crown_anchors'][index];leaf=Image.open(self.out/f'{token}-crown-{index}.png').convert('RGBA')
                self.assertGreaterEqual(leaf.getpixel((int(anchor[0]-box[0]),int(anchor[1]-box[1])))[3],192,(token,index,'branch junction must be inside opaque leaves'))

    def test_cloth_keeps_original_rgb_and_only_removes_alpha(self):
        graphic=self.catalog['graphics']['1230059'];x,y,w,h=graphic['rect']
        original=Image.open(self.base/self.catalog['pages'][graphic['page']]).convert('RGBA').crop((x,y,x+w,y+h))
        cloth=Image.open(self.out/'mast-cloth.png').convert('RGBA')
        self.assertEqual(cloth.convert('RGB').tobytes(),original.convert('RGB').tobytes())
        clean,_=native_without_ground_shadow(original)
        self.assertTrue(all(a<=b for a,b in zip(cloth.getchannel('A').tobytes(),clean.getchannel('A').tobytes())))

    def test_living_axes_preserve_individual_source_shapes(self):
        graphics=self.data['graphics']
        cut_forms=[]
        for serial in [1230039,1230064,1230062,1230063,1230065,1230066,1230040]:
            spec=graphics[str(serial)];w,h=self.catalog['graphics'][str(serial)]['rect'][2:]
            self.assertEqual(len(spec['crown_ground_pixels']),len(spec['crowns']))
            for stem in spec['trunks']:
                trace=stem['trace'];self.assertEqual(trace[0][:2],stem['base'])
                self.assertTrue(all(0<=x<=w and 0<=y<=h and radius>0 for x,y,radius in trace))
                self.assertTrue(all(a[1]>b[1] for a,b in zip(trace,trace[1:])))
                if stem['cut_stump']:
                    cut_forms.append(serial);self.assertEqual(stem['stump_diameter'],107)
                    self.assertEqual(len(stem['rim_offsets']),32)
                    self.assertTrue(all(math.isfinite(v) and abs(v)<30 for v in stem['rim_offsets']))
            self.assertTrue(all(home['living_root_walls'] for home in spec['houses']))
        self.assertEqual(cut_forms,[1230039,1230062,1230063,1230065])
        shrine=graphics['1230040'];self.assertEqual(len(shrine['towers']),4)
        for spire in shrine['towers']:self.assertEqual(len(spire['ring_materials']),len(spire['profile'])-1)

    def test_reverse_relief_keeps_native_alpha_and_its_explicit_material_contract(self):
        pages={}
        continued_motifs={1233018,1233019,1233181,1233182}
        for token,spec in self.data['graphics'].items():
            if spec['kind']!='relief':continue
            front=Image.open(self.out/f'{token}-front.png').convert('RGBA');back=Image.open(self.out/f'{token}-back.png').convert('RGBA')
            graphic=self.catalog['graphics'][token];page=graphic['page']
            if page not in pages:pages[page]=Image.open(self.base/self.catalog['pages'][page]).convert('RGBA')
            x,y,w,h=graphic['rect'];native=pages[page].crop((x,y,x+w,y+h))
            clean,_=native_without_ground_shadow(native)
            digest=lambda image:hashlib.sha256(image.tobytes()).hexdigest()
            self.assertEqual(digest(front),digest(clean),token)
            self.assertEqual(digest(front.getchannel('A')),digest(back.getchannel('A')),token)
            self.assertIsNotNone(back.getchannel('A').getbbox(),token)
            self.assertGreater(spec['depth'],0,token)
            self.assertTrue(spec['edges'],token)
            if int(token) in continued_motifs:
                self.assertEqual(digest(back),digest(clean),token)
                self.assertIn('unrecorded',spec['inferred_reverse_material'])
                self.assertGreater(len({p[:3] for p in back.getdata() if p[3]}),1,token)
            else:
                self.assertNotEqual(digest(front.convert('RGB')),digest(back.convert('RGB')),token)
                if int(token) in (1233010,1233011,1233014,1233015):
                    self.assertGreater(len({p[:3] for p in back.getdata() if p[3]}),1,token)

    def test_surface_samples_are_opaque_and_reused_model_exists(self):
        surfaces=Image.open(self.out/'surfaces.png').convert('RGBA')
        for index,(name,recipe) in enumerate(PATCHES.items()):
            x=(index%4)*128;y=(index//4)*128
            alpha=surfaces.crop((x,y,x+128,y+128)).getchannel('A')
            if recipe[2]:self.assertIsNotNone(alpha.getbbox(),name)
            else:self.assertEqual(alpha.getextrema(),(255,255),name)
        for spec in self.data['graphics'].values():
            if spec['kind']=='tree':self.assertTrue((ROOT/'assets/models/environments/wind_meadow'/(spec['asset']+'.glb')).exists(),spec['asset'])

    def test_classic_exact_owners_and_thin_bridge_art_are_enrolled(self):
        graphics=self.data['graphics']
        for serial in [11082,11081,10606,11084,11268,10013,11273,10607,10603,11272,10304,10077,11278,11417,11420,10605,11269,12548,12563,12565,12564,17636,10657,10655,17572,11010,17638]:
            self.assertIn(str(serial),graphics,serial)
        self.assertEqual(graphics['10077']['kind'],'classic_reuse')
        self.assertEqual(graphics['10077']['kit'],'falan_house')
        for spec in graphics.values():
            if spec['kind']=='classic_reuse':self.assertTrue((ROOT/spec['owner']).is_file(),spec['owner'])
        for serial in [1260162,1260163,1260164,1260165,1260166,1260167,1260168,1260169,1260172,1260173,1260177]:
            self.assertEqual(graphics[str(serial)]['kind'],'native_floor_piece')
        for serial in range(15012,15021):
            self.assertEqual(graphics[str(serial)]['kind'],'source_rock')
            self.assertEqual(graphics[str(serial)]['height_frame'],'original-owner')


if __name__=='__main__':unittest.main()
