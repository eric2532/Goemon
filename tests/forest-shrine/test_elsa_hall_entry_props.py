"""Independent mapped-paint and source-boundary checks for private59530 props."""
import json
from pathlib import Path
import sys
import unittest
from PIL import Image, ImageChops, ImageFilter

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import recover_elsa_island as source
from prepare_elsa_gate import native_layers


class EntryPropsTest(unittest.TestCase):
    CANDIDATE=True
    @classmethod
    def setUpClass(cls):
        cls.folder=source.REPORT/'Temple Interior/Hall Entry Candidate'
        cls.data=json.loads((cls.folder/'props-data.json').read_text())
        cls.props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text())

    def test_background_variant_keeps_native_paint_and_reuses_the_body(self):
        d=self.data;spec=d['spec'];self.assertEqual(d['candidate_only'],self.CANDIDATE);self.assertEqual(d['map'],59530)
        template=json.loads((ROOT/'assets/maps/falan/elsa/props/pedestal-406/data.json').read_text())
        body_shape=spec['body'].copy();self.assertEqual(body_shape.pop('cap_paint_pixel'),[64,56])
        self.assertEqual(body_shape,template['body']);self.assertEqual(spec['orb']['radius'],template['orb']['radius'])
        u,v=d['bg_origin'];_,native=native_layers(self.props['maps']['59530'],(u,v,u+128,v+192),59530)
        self.assertEqual(source.sha(native.tobytes()),d['original_background_sha256'])
        selected=Image.open(self.folder/'bg-pedestal-source.png').convert('RGBA')
        mask=Image.open(self.folder/'bg-pedestal-photo-mask.png').convert('L')
        blue=Image.open(self.folder/'bg-pedestal-blue-mask.png').convert('L')
        cap=Image.open(self.folder/'bg-pedestal-cap-mask.png').convert('L')
        body=Image.open(self.folder/'bg-pedestal-body.png').convert('RGB')
        self.assertEqual(body.getpixel((64,56)),(18,18,18))
        orb=Image.open(self.folder/'bg-pedestal-globe.png').convert('RGBA')
        self.assertEqual(blue.getbbox(),(39,7,89,52))
        self.assertEqual(sum(p>0 for p in mask.getdata()),13946)
        for y in range(192):
            for x in range(128):
                if mask.getpixel((x,y)):
                    self.assertEqual(selected.getpixel((x,y)),native.getpixel((x,y)))
                    if not cap.getpixel((x,y)):self.assertEqual(body.getpixel((x,y)),native.getpixel((x,y))[:3])
                if blue.getpixel((x,y)):self.assertEqual(orb.getpixel((x,y)),native.getpixel((x,y)))
        for name,image in [('selected_source',selected),('selection',mask),('blue',blue),('cap',cap),('body',body),('globe',orb)]:
            self.assertEqual(source.sha(image.tobytes()),d[name+'_sha256'])

    def test_apron_repairs_copy_only_the_same_native_band_beneath_known_props(self):
        d=self.data;rect=d['native_rect'];_,native=native_layers(self.props['maps']['59530'],tuple(rect),59530)
        infill=Image.open(self.folder/'pedestal-apron-infill.png').convert('RGBA')
        sample=d['void_native_sample'];self.assertEqual(native.getpixel((sample[0]-rect[0],sample[1]-rect[1])),tuple(d['void_native_rgba']))
        self.assertEqual(d['map_size'],list(source.reference_map(59530)[:2]))
        bg=Image.open(self.folder/'bg-pedestal-relocated-mask.png').convert('L')
        stairs=Image.open(self.folder/'displaced-floor-mask.png').convert('L')
        group=self.props['groups']['406'];x,y,w,h=group['rect']
        foreground=Image.open(ROOT/f"assets/maps/falan/elsa/props/atlas-{group['page']}.png").convert('RGBA').crop((x,y,x+w,y+h))
        placement=next(p for p in self.props['maps']['59530'] if p['group']=='406')
        self.assertEqual(d['fg_occlusion_padding'],1)
        fg=Image.new('L',native.size);fg.paste(foreground.getchannel('A').filter(ImageFilter.MaxFilter(3)),(placement['anchor'][0]+group['origin'][0]-rect[0],placement['anchor'][1]+group['origin'][1]-rect[1]))
        traced=set();left,right=d['apron_edges']['conservative_parallel_strip']
        for u,v,su,sv in d['repair_samples']:
            point=(u-rect[0],v-rect[1]);sample=(su-rect[0],sv-rect[1]);self.assertNotIn(point,traced);traced.add(point)
            self.assertLessEqual(left,v+.75*u);self.assertLessEqual(v+.75*u,right)
            if v==sv:
                cx,cy=d['medallion_inference']['centre'];aspect=d['medallion_inference']['aspect']
                self.assertEqual(u+su,2*cx)
                self.assertLessEqual((u-cx)**2+((v-cy)/aspect)**2,d['medallion_inference']['radius']**2)
            else:self.assertEqual(v+.75*u,sv+.75*su)
            old=native.getpixel(point)
            self.assertTrue(bg.getpixel(point) or fg.getpixel(point) and (not old[3] or old[:3] in [(0,0,0),(2,2,2)]))
            self.assertEqual(stairs.getpixel(point),0)
            self.assertFalse(bg.getpixel(sample) or fg.getpixel(sample) or stairs.getpixel(sample))
            self.assertEqual(infill.getpixel(point),native.getpixel(sample))
        self.assertEqual(sum(a>0 for a in infill.getchannel('A').getdata()),len(traced))
        self.assertEqual(source.sha(infill.tobytes()),d['infill_sha256']);self.assertFalse(d['unfilled'])
        combined=Image.open(self.folder/'relocated-photo-mask.png').convert('L')
        self.assertIsNone(ImageChops.difference(combined,ImageChops.lighter(stairs,bg)).getbbox())


class PublishedEntryPropsTest(EntryPropsTest):
    CANDIDATE=False

    @classmethod
    def setUpClass(cls):
        cls.folder=ROOT/'assets/maps/falan/elsa/scenery/entry-pedestals'
        cls.data=json.loads((cls.folder/'data.json').read_text())
        cls.props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text())

    def test_published_floor_relocates_confirmed_bg_and_preserves_every_unselected_pixel(self):
        d=json.loads((self.folder/'floor-data.json').read_text())
        self.assertFalse(d['candidate_only'])
        self.assertEqual(d['removed_matte_pixels'],0)
        self.assertEqual(set(d['regions']),{'bg_pedestals','bg_stair'})
        self.assertEqual(d['regions']['bg_pedestals']['selected_pixels'],13946)
        self.assertGreater(d['relocated_photo_pixels'],13946)
        mask=Image.open(self.folder/d['role_mask_file']).convert('L')
        self.assertEqual(source.sha(mask.tobytes()),d['source_mask_sha256'])
        width,_,planes=source.reference_map(59530);pages={};rect=d['native_rect']
        ground=d.get('ground_infill');repair=None
        if ground:repair=Image.open(ROOT/'assets/maps/falan/elsa/scenery/temple-bg-stair/parent-ground.png').convert('RGBA')
        for key,row in d['placements'].items():
            index=int(key);self.assertEqual(planes[0][index],row['serial'])
            native,origin,_=source.cut_image(59530,row['serial']);self.assertEqual(row['origin'],list(origin))
            self.assertEqual(source.sha(native.tobytes()),row['source_sha256'])
            if row['page'] not in pages:pages[row['page']]=Image.open(self.folder/f"floor-atlas-{row['page']}.png").convert('RGBA')
            x,y,w,h=row['rect'];actual=pages[row['page']].crop((x,y,x+w,y+h))
            self.assertEqual(actual.size,native.size);self.assertEqual(source.sha(actual.tobytes()),row['rgba_sha256'])
            u=(index%width+index//width)*32+origin[0]-rect[0];v=(index//width-index%width)*24+origin[1]-rect[1]
            role=mask.crop((u,v,u+w,v+h))
            patch=repair.crop((u+rect[0]-ground['native_rect'][0],v+rect[1]-ground['native_rect'][1],u+rect[0]-ground['native_rect'][0]+w,v+rect[1]-ground['native_rect'][1]+h)) if repair else None
            for yy in range(h):
                for xx in range(w):
                    a=native.getpixel((xx,yy));b=actual.getpixel((xx,yy))
                    if patch is not None and patch.getpixel((xx,yy))[3]:self.assertEqual(b,patch.getpixel((xx,yy)))
                    else:self.assertEqual(b,(*a[:3],0 if role.getpixel((xx,yy)) else a[3]))


if __name__=='__main__':unittest.main()
