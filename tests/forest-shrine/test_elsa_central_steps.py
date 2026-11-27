"""Native paint/projection, connected source flights and confirmed walking mask."""
import hashlib
import json
import math
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import recover_elsa_island as source

FOLDER=source.REPORT/'Temple Interior/Central Assembly Candidate/Steps'
VERTICAL=math.sqrt(2*((32/3)**2-8**2))


class CentralStepsTest(unittest.TestCase):
    def test_all_recorded_client_flags_agree_with_reference_and_remain_explicit(self):
        data=json.loads((FOLDER/'data.json').read_text())
        width,height,planes=source.reference_map(59530)
        flags=source.client_map(59530)[1][4];known=0
        for i,flag in enumerate(flags):
            if not flag&0xc000:continue
            self.assertEqual(bool(flag&256),bool(planes[2][i]),(i%width,i//width));known+=1
        self.assertGreater(known,7000)
        for proof in data['walkability_proofs']:
            x,y=proof['cell'];index=y*width+x
            self.assertEqual(proof['client_flag'],flags[index])
            self.assertEqual(proof['reference_flag'],planes[2][index])

    def test_visible_surface_paint_is_native_and_occluders_are_not_smeared(self):
        data=json.loads((FOLDER/'data.json').read_text())
        native=Image.open(FOLDER/'original-native.png').convert('RGBA')
        self.assertEqual(hashlib.sha256(native.tobytes()).hexdigest(),data['native_rgba_sha256'])
        occluders=[Image.open(FOLDER.parent/(name+'-mask.png')).convert('L') for name in ['right-post','left-post','right-half-arch']]
        for name,mask_name in [('floor-paint.png','confirmed-floor-mask.png'),('native-paint.png','confirmed-tread-mask.png')]:
            paint=Image.open(FOLDER/name).convert('RGB');mask=Image.open(FOLDER/mask_name).convert('L')
            self.assertGreater(sum(bool(v) for v in mask.tobytes()),1000)
            for y in range(native.height):
                for x in range(native.width):
                    if not mask.getpixel((x,y)):continue
                    self.assertEqual(paint.getpixel((x,y)),native.getpixel((x,y))[:3])
                    self.assertTrue(all(m.getpixel((x,y))==0 for m in occluders))
        colours=set(native.getdata())
        for name,colour in data['colours'].items():
            self.assertIn(tuple(colour),colours)
            self.assertEqual(Image.open(FOLDER/(name+'.png')).getpixel((0,0)),tuple(colour[:3]))

    def test_original_projection_and_the_two_flight_connections(self):
        data=json.loads((FOLDER/'data.json').read_text())
        self.assertTrue(data['candidate_only'])
        lower,upper=data['flights'];self.assertEqual([lower['name'],upper['name']],['lower','upper'])
        self.assertAlmostEqual(lower['bottom'],0.)
        self.assertAlmostEqual(upper['bottom'],lower['top'])
        self.assertAlmostEqual(data['turn_height'],lower['top'])
        self.assertAlmostEqual(data['top_height'],upper['top'])
        self.assertEqual(sum(face['role'].endswith('native tread') for face in data['surfaces']),25)
        self.assertEqual(sum('original riser band' in face['role'] for face in data['surfaces']),26)
        for face in data['surfaces']:
            self.assertEqual(len(face['points']),len(face['uv']))
            if face['paint'] not in ['native','floor']:continue
            for point,pixel in zip(face['points'],face['uv']):
                x,y,z=point
                actual=[(x+z)*32/3,(z-x)*8-y*VERTICAL]
                wanted=[pixel[i]+data['native_origin'][i] for i in [0,1]]
                self.assertLess(math.dist(actual,wanted),1e-7)
        native=Image.open(FOLDER/'original-native.png').convert('RGBA')
        for group in data['source_balusters']:
            for marker in group:
                x,y=marker['native'];samples=[]
                for yy in range(round(y)-2,round(y)+3):
                    for xx in range(round(x)-2,round(x)+3):
                        if 0<=xx<native.width and 0<=yy<native.height:samples.append(native.getpixel((xx,yy)))
                self.assertTrue(any(a and r>25 and r>g*1.1 and g>b*1.1 for r,g,b,a in samples),'Every baluster placement has a native gold-detail witness')

    def test_ground_repair_uses_paving_only_inside_removed_art_and_open_cells(self):
        data=json.loads((FOLDER/'ground-infill.json').read_text())
        paint=Image.open(FOLDER/'ground-infill.png').convert('RGBA')
        native=Image.open(FOLDER/'original-native.png').convert('RGBA')
        portal=FOLDER.parent/'Portal'
        bg=Image.open(portal/'bg-photo-mask.png').convert('L')
        portal_data=json.loads((portal/'data.json').read_text())
        tile,offset,cut=source.cut_image(59530,1856)
        palette=set(tile.getdata());width,height,planes=source.reference_map(59530)
        self.assertEqual(planes[0][92*width+99],1856)
        self.assertEqual(hashlib.sha256(paint.tobytes()).hexdigest(),data['rgba_sha256'])
        count=0
        for y in range(paint.height):
            for x in range(paint.width):
                pixel=paint.getpixel((x,y))
                if not pixel[3]:continue
                count+=1;self.assertIn(pixel,palette)
                u,v=x+data['origin'][0],y+data['origin'][1]
                cx=math.floor(u/64-v/48+.5);cy=math.floor(u/64+v/48+.5)
                self.assertTrue(0<=cx<width and 0<=cy<height)
                self.assertEqual(planes[2][cy*width+cx],0,'Infill cannot extend the archived walking boundary')
                bx,by=u-portal_data['rect'][0],v-portal_data['rect'][1]
                removed_bg=0<=bx<bg.width and 0<=by<bg.height and bg.getpixel((bx,by))
                self.assertTrue(native.getpixel((x,y))[3] or removed_bg,'Only relocated source art owns the repair footprint')
        self.assertEqual(count,data['pixels']);self.assertGreater(count,1000)


if __name__=='__main__':unittest.main()
