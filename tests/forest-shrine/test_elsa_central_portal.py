"""Independent source layers, original BG alpha scope and shared pack regression."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import recover_elsa_island as source
from prepare_elsa_hall_entry_floor import pack

FOLDER=source.REPORT/'Temple Interior/Central Assembly Candidate/Portal'


class CentralPortalTest(unittest.TestCase):
    def test_existing_pedestal_uv_packing_is_unchanged(self):
        folder=ROOT/'assets/maps/falan/elsa/scenery/entry-pedestals'
        expected=json.loads((folder/'floor-data.json').read_text())
        mask=Image.open(folder/expected['role_mask_file']).convert('L')
        with tempfile.TemporaryDirectory() as name:
            output=Path(name)
            actual,_=pack(mask,expected['native_rect'],output,512,clear_matte=False)
            for key in actual:self.assertEqual(actual[key],expected[key],key)
            for i in range(actual['pages']):
                self.assertEqual(Image.open(output/f'floor-atlas-{i}.png').tobytes(),
                                 Image.open(folder/f'floor-atlas-{i}.png').tobytes())

    def test_existing_private_stair_uv_packing_is_unchanged(self):
        folder=source.REPORT/'Temple Interior/Hall Entry Candidate'
        expected=json.loads((folder/'floor-data.json').read_text())
        mask=Image.open(folder/expected['role_mask_file']).convert('L')
        with tempfile.TemporaryDirectory() as name:
            output=Path(name)
            actual,_=pack(mask,expected['native_rect'],output,2048,clear_matte=True)
            for key in actual:self.assertEqual(actual[key],expected[key],key)
            for i in range(actual['pages']):
                self.assertEqual(Image.open(output/f'floor-atlas-{i}.png').tobytes(),
                                 Image.open(folder/f'floor-atlas-{i}.png').tobytes())

    def test_portal_floor_keeps_native_rgb_extents_and_unselected_alpha(self):
        spec=json.loads((FOLDER/'floor-data.json').read_text())
        self.assertTrue(spec['candidate_only'])
        self.assertEqual(spec['removed_matte_pixels'],0)
        rect=spec['native_rect'];mask=Image.open(FOLDER/spec['role_mask_file']).convert('L')
        pages=[Image.open(FOLDER/f'floor-atlas-{i}.png').convert('RGBA') for i in range(spec['pages'])]
        width,height,planes=source.reference_map(59530)
        removed=0
        for key,row in spec['placements'].items():
            index=int(key);serial=planes[0][index]
            self.assertEqual(serial,row['serial'])
            native,origin,_=source.cut_image(59530,serial)
            self.assertEqual(list(origin),row['origin'])
            x,y,w,h=row['rect'];actual=pages[row['page']].crop((x,y,x+w,y+h))
            self.assertEqual(actual.size,native.size)
            u=(index%width+index//width)*32+origin[0]-rect[0]
            v=(index//width-index%width)*24+origin[1]-rect[1]
            selected=mask.crop((u,v,u+w,v+h))
            for before,after,chosen in zip(native.getdata(),actual.getdata(),selected.tobytes()):
                self.assertEqual(before[:3],after[:3])
                self.assertEqual(after[3],0 if chosen else before[3])
                if before[3] and chosen:removed+=1
        self.assertEqual(removed,spec['relocated_photo_pixels'])

    def test_arch_and_post_derivatives_retain_their_selected_native_layer(self):
        data=json.loads((FOLDER/'data.json').read_text())
        background=Image.open(FOLDER/'native-background.png').convert('RGBA')
        foreground=Image.open(FOLDER/'native-foreground.png').convert('RGBA')
        mask=Image.open(FOLDER/'bg-photo-mask.png').convert('L')
        for proof in data['excluded_background_coping']['probes']:
            x=proof['native'][0]-data['rect'][0];y=proof['native'][1]-data['rect'][1]
            self.assertEqual(list(background.getpixel((x,y))),proof['rgba'])
            self.assertEqual(mask.getpixel((x,y)),0,'Wall coping stays with its original background owner')
        for row in data['columns']:
            original=background if row['name']=='left-bg-post' else foreground
            native=Image.open(FOLDER/row['source']).convert('RGBA')
            paint=Image.open(FOLDER/row['paint']).convert('RGB')
            x,y,_,_=row['crop']
            for yy in range(native.height):
                for xx in range(native.width):
                    color=native.getpixel((xx,yy))
                    if not color[3]:continue
                    self.assertEqual(original.getpixel((x+xx,y+yy)),color)
                    self.assertEqual(paint.getpixel((xx,yy)),color[:3])
        row=data['arch'];paint=Image.open(FOLDER/row['paint']).convert('RGBA')
        solid=Image.open(FOLDER/row['solid']).convert('RGB');x,y,_,_=row['crop']
        for yy in range(paint.height):
            for xx in range(paint.width):
                color=paint.getpixel((xx,yy))
                if not color[3]:continue
                self.assertIn(color,[background.getpixel((x+xx,y+yy)),foreground.getpixel((x+xx,y+yy))])
                self.assertEqual(solid.getpixel((xx,yy)),color[:3])
        for u,v in row['source_contacts']:
            self.assertAlmostEqual(u*row['foot'][0]+row['foot'][1],v)
        cap_mask=Image.open(FOLDER.parent/'right-post-mask.png').convert('L')
        for x,y in [(502,290),(503,290),(504,291),(505,292),(506,292),(507,293)]:
            self.assertGreater(cap_mask.getpixel((x,y)),0,'Native bright cap edges belong to the post')
        occupied={(x,y) for y in range(paint.height) for x in range(paint.width) if paint.getpixel((x,y))[3]}
        pending=[occupied.pop()]
        while pending:
            x,y=pending.pop()
            # Native antialias tips may join the contour diagonally by one pixel.
            for point in [(x+dx,y+dy) for dx in [-1,0,1] for dy in [-1,0,1] if dx or dy]:
                if point in occupied:occupied.remove(point);pending.append(point)
        self.assertFalse(occupied,'Column-cap edge pixels must not become detached arch fragments')


if __name__=='__main__':unittest.main()
