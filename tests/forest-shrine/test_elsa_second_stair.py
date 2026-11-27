"""Independent source paint, riser evidence and BG ownership preservation."""
import hashlib
import json
import math
import statistics
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import recover_elsa_island as source
from prepare_elsa_gate import native_layers

FOLDER=source.REPORT/'Temple Interior/Central Assembly Candidate/Second Stair'
VERTICAL=math.sqrt(2*((32/3)**2-8**2))


class SecondStairTest(unittest.TestCase):
    def test_parent_cut_floor_keeps_native_geometry_and_scopes_every_changed_pixel(self):
        folder=FOLDER/'Parent Floor';record=json.loads((folder/'floor-data.json').read_text())
        repair=Image.open(FOLDER/'parent-ground.png').convert('RGBA')
        origin=record['ground_infill']['native_rect'][:2]
        mask=Image.open(folder/record['role_mask_file']).convert('L');rect=record['native_rect']
        width,_,planes=source.reference_map(59530);pages={};filled=0;covered=Image.new('L',repair.size)
        for key,row in record['placements'].items():
            index=int(key);self.assertEqual(planes[0][index],row['serial'])
            native,offset,_=source.cut_image(59530,row['serial']);self.assertEqual(list(offset),row['origin'])
            self.assertEqual(source.sha(native.tobytes()),row['source_sha256'])
            if row['page'] not in pages:pages[row['page']]=Image.open(folder/f"floor-atlas-{row['page']}.png").convert('RGBA')
            x,y,w,h=row['rect'];actual=pages[row['page']].crop((x,y,x+w,y+h))
            self.assertEqual(actual.size,native.size);self.assertEqual(source.sha(actual.tobytes()),row['rgba_sha256'])
            u=(index%width+index//width)*32+offset[0];v=(index//width-index%width)*24+offset[1]
            patch=repair.crop((u-origin[0],v-origin[1],u-origin[0]+w,v-origin[1]+h))
            photo=mask.crop((u-rect[0],v-rect[1],u-rect[0]+w,v-rect[1]+h))
            for yy in range(h):
                for xx in range(w):
                    old=native.getpixel((xx,yy));new=actual.getpixel((xx,yy));infill=patch.getpixel((xx,yy))
                    if infill[3]:
                        self.assertEqual(new,infill);filled+=1;covered.putpixel((u-origin[0]+xx,v-origin[1]+yy),255)
                    else:self.assertEqual(new,(*old[:3],0 if photo.getpixel((xx,yy)) else old[3]))
        self.assertEqual(filled,record['inferred_ground_pixels']);self.assertGreater(filled,0)
        self.assertEqual(covered.tobytes(),repair.getchannel('A').tobytes(),'Every inferred pixel must have existing native CUT geometry')

    def test_parent_paving_preserves_visible_art_and_original_open_cells(self):
        from prepare_elsa_second_stair_ground import RECT,PAVING_RECT
        record=json.loads((FOLDER/'parent-ground.json').read_text())
        _,native=native_layers([],RECT,59530)
        self.assertEqual(source.sha(native.tobytes()),record['source_rgba_sha256'])
        paint=Image.open(FOLDER/'parent-ground.png').convert('RGBA')
        photo=Image.open(FOLDER/'bg-photo-mask.png').convert('L')
        width,_,planes=source.reference_map(59530)
        _,_,labels,_=source.components(59530)
        scope=json.loads((source.REPORT/'scope.json').read_text())
        components=set(scope['rooms']['59530']['components'])
        _,tile=native_layers([],PAVING_RECT,59530);selected=0
        self.assertEqual(source.sha(tile.tobytes()),record['patches'][0]['rgba_sha256'])
        self.assertEqual(tile.tobytes(),Image.open(FOLDER/'parent-paving-native-witness.png').convert('RGBA').tobytes())
        self.assertEqual(source.sha(photo.tobytes()),record['stair_photo_mask_sha256'])
        for y in range(paint.height):
            for x in range(paint.width):
                pixel=paint.getpixel((x,y))
                if not pixel[3]:continue
                selected+=1;u,v=x+RECT[0],y+RECT[1]
                cx,cy=math.floor(u/64-v/48+.5),math.floor(u/64+v/48+.5)
                self.assertEqual(planes[2][cy*width+cx],0)
                self.assertIn(labels[cy*width+cx],components)
                original=native.getpixel((x,y));px,py=u-6150,v-80
                relocated=0<=px<photo.width and 0<=py<photo.height and photo.getpixel((px,py))
                self.assertTrue(not original[3] or max(original[:3])<=3 or relocated,'Every exposed source pixel must remain unchanged')
                tx,ty=(u-PAVING_RECT[0])%128,(v-PAVING_RECT[1])%96
                self.assertEqual(pixel,tile.getpixel((tx if tx<64 else 127-tx,ty if ty<48 else 95-ty)))
        self.assertEqual(selected,record['pixels']);self.assertGreater(selected,0)

    def test_installed_stair_retains_reviewed_source_and_support(self):
        installed=ROOT/'assets/maps/falan/elsa/scenery/temple-bg-stair'
        mesh=json.loads((installed/'mesh.json').read_text())
        staged=json.loads((FOLDER/'data.json').read_text())
        self.assertFalse(mesh.pop('candidate_only'));staged.pop('candidate_only')
        self.assertEqual(mesh,staged,'Normal Explore must use the source-verified geometry, without unrelated private architecture')
        support=json.loads((installed/'data.json').read_text())
        self.assertFalse(support['candidate_only'])
        self.assertEqual(support['geometry_sha256'],mesh['geometry_sha256'])
        self.assertEqual(support['steps'],json.loads((FOLDER/'support-data.json').read_text())['steps'])
        for name in ['native-paint.png','body.png','body-native-witness.png','cap.png','stone.png','stone_shadow.png','charcoal.png','gold.png','original-background.png','confirmed-floor-mask.png','bg-photo-mask.png']:
            self.assertEqual((installed/name).read_bytes(),(FOLDER/name).read_bytes(),name)
        ground=json.loads((installed/'parent-ground.json').read_text());staged=json.loads((FOLDER/'parent-ground.json').read_text())
        self.assertFalse(ground.pop('candidate_only'));staged.pop('candidate_only');ground.pop('path');staged.pop('path')
        self.assertEqual(ground,staged)
        for name in ['parent-ground.png','parent-ground-original.png','parent-ground-mask.png','parent-paving-native-witness.png']:
            self.assertEqual((installed/name).read_bytes(),(FOLDER/name).read_bytes(),name)
        canonical=ROOT/'assets/maps/falan/elsa/scenery/entry-pedestals';prepared=FOLDER/'Parent Floor'
        floor=json.loads((canonical/'floor-data.json').read_text());staged=json.loads((prepared/'floor-data.json').read_text())
        self.assertFalse(floor.pop('candidate_only'));self.assertTrue(staged.pop('candidate_only'));self.assertEqual(floor,staged)
        for name in ['published-bg-photo-mask.png',*[f'floor-atlas-{i}.png' for i in range(floor['pages'])]]:
            self.assertEqual((canonical/name).read_bytes(),(prepared/name).read_bytes(),name)

    def test_native_paint_and_all_post_witnesses(self):
        data=json.loads((FOLDER/'data.json').read_text())
        rect=tuple(data['native_origin']+[data['native_origin'][i]+data['size'][i] for i in [0,1]])
        _,native=native_layers([],rect,59530)
        self.assertEqual(native.tobytes(),Image.open(FOLDER/'original-background.png').convert('RGBA').tobytes())
        self.assertEqual(hashlib.sha256(native.tobytes()).hexdigest(),data['native_rgba_sha256'])
        paint=Image.open(FOLDER/'native-paint.png').convert('RGBA');mask=Image.open(FOLDER/'confirmed-floor-mask.png').convert('L')
        self.assertGreater(sum(bool(v) for v in mask.tobytes()),10000)
        for original,prepared,selected in zip(native.getdata(),paint.getdata(),mask.getdata()):
            if selected:self.assertEqual(original,prepared)
        self.assertEqual([len(p) for p in data['source_balusters']],[6,5])
        for group in data['source_balusters']:
            for marker in group:
                x,y=marker['native']
                samples=[native.getpixel((xx,yy)) for yy in range(round(y)-2,round(y)+3) for xx in range(round(x)-2,round(x)+3)]
                if marker.get('role'):
                    self.assertTrue(any(a and min(r,g,b)>70 and max(r,g,b)-min(r,g,b)<15 for r,g,b,a in samples))
                else:self.assertTrue(any(a and r>25 and r>g*1.1 and g>b*1.1 for r,g,b,a in samples))
        palette=set(native.getdata())
        for name,value in data['colours'].items():self.assertIn(tuple(value),palette)
        body=data['body_paint'];r=body['native_rect']
        witness=native.crop((r[0]-rect[0],r[1]-rect[1],r[2]-rect[0],r[3]-rect[1]))
        self.assertEqual(hashlib.sha256(witness.tobytes()).hexdigest(),body['source_sha256'])
        self.assertEqual(witness.tobytes(),Image.open(FOLDER/'body-native-witness.png').convert('RGBA').tobytes())
        self.assertTrue(set(Image.open(FOLDER/'body.png').convert('RGBA').getdata()).issubset(set(witness.getdata())),'Concealed plinth can only use its native gray material, without facade fragments')
        profile=data['corbel_profile'];self.assertLess(min(width for _,width in profile),profile[0][1]*.5)
        for face in data['surfaces']:
            if face['paint']!='body':continue
            self.assertTrue(all(0<=u<=512 and 0<=v<=512 for u,v in face['uv']))

    def test_eleven_observed_bands_and_connected_heights(self):
        data=json.loads((FOLDER/'data.json').read_text());lower,upper=data['flights']
        self.assertTrue(data['candidate_only']);self.assertEqual(len(lower['rises']),8);self.assertEqual(len(upper['rises']),3)
        for flight in [lower,upper]:
            for rise,pixels in zip(flight['rises'],flight['source_riser_pixels']):self.assertAlmostEqual(rise*VERTICAL/pixels,data['inferred_rise_scale'])
        self.assertAlmostEqual(lower['bottom'],0);self.assertAlmostEqual(upper['bottom'],lower['top'])
        self.assertEqual(sum('observed riser' in f['role'] for f in data['surfaces']),11)
        self.assertEqual(sum('original tread' in f['role'] for f in data['surfaces']),11)
        support=json.loads((FOLDER/'support-data.json').read_text())
        self.assertEqual(support['geometry_sha256'],data['geometry_sha256'])
        self.assertTrue(support['steps']['external_visual'] and support['candidate_only'])
        self.assertLess(support['lower_ramp']['gradient'],.55)
        native=Image.open(FOLDER/'original-background.png').convert('RGBA')
        probe=data['lower_probe'];a,b=probe['native_start'],probe['native_end'];actual=[]
        for i in range(probe['samples']+1):
            t=i/probe['samples'];x=a[0]+(b[0]-a[0])*t;y=a[1]+(b[1]-a[1])*t
            actual.append(statistics.median(native.getpixel((round(x+k*.82)-6150,round(y+k*.57)-80))[0] for k in range(-5,6)))
        self.assertEqual(actual,probe['median_red'],'Riser evidence must match fresh native pixels, not stale diagnostic values')
        for first,last in data['lower_probe']['dark_runs']:
            values=data['lower_probe']['median_red'][first:last+1]
            self.assertLess(min(values),110)
        for lo,hi in [(130,137),(147,155),(165,172)]:
            self.assertTrue(all(native.getpixel((6380-6150,y-80))[0]<65 for y in range(lo,hi+1)))
        for face in data['surfaces']:
            self.assertTrue(all(math.isfinite(v) for p in face['points'] for v in p))
            if face['paint']!='native':continue
            for (x,y,z),(u,v) in zip(face['points'],face['uv']):
                self.assertAlmostEqual((x+z)*32/3,u+data['native_origin'][0])
                self.assertAlmostEqual((z-x)*8,v+data['native_origin'][1],msg='Walkable floor must retain original map XZ rather than shift along the camera ray')

    def test_union_bg_mask_and_original_cut_rgb_are_preserved(self):
        record=json.loads((FOLDER/'floor-data.json').read_text())
        mask=Image.open(FOLDER/'combined-bg-photo-mask.png').convert('L')
        previous=Image.open(FOLDER.parent/'Wall/combined-bg-photo-mask.png').convert('L')
        self.assertTrue(all(not a or b for a,b in zip(previous.tobytes(),mask.crop((0,0,*previous.size)).tobytes())))
        pages={}
        for row in record['placements'].values():
            original,origin,_=source.cut_image(59530,row['serial'])
            self.assertEqual(list(origin),row['origin'])
            if row['page'] not in pages:pages[row['page']]=Image.open(FOLDER/('floor-atlas-%d.png'%row['page'])).convert('RGBA')
            x,y,w,h=row['rect'];prepared=pages[row['page']].crop((x,y,x+w,y+h))
            self.assertEqual(prepared.size,original.size)
            self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),row['source_sha256'])
            for a,b in zip(original.getdata(),prepared.getdata()):self.assertEqual(a[:3],b[:3]);self.assertTrue(b[3]==a[3] or b[3]==0)
        photo=Image.open(FOLDER/'bg-photo-mask.png').convert('L')
        # The white paving outside the left blue rail keeps its original BG owner.
        for u,v in [(6210,300),(6240,245),(6260,215)]:self.assertEqual(photo.getpixel((u-6150,v-80)),0)


if __name__=='__main__':unittest.main()
