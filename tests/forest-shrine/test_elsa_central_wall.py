"""Source ownership and closed volume for the central BG masonry wall."""
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import sys
import unittest
import statistics
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import recover_elsa_island as source
from prepare_elsa_gate import native_layers

FOLDER=source.REPORT/'Temple Interior/Central Assembly Candidate/Wall'
VERTICAL=math.sqrt(2*((32/3)**2-8**2))


class CentralWallTest(unittest.TestCase):
    def test_original_visible_wall_pixels_and_arch_ownership(self):
        data=json.loads((FOLDER/'data.json').read_text())
        original=Image.open(FOLDER/'original-background.png').convert('RGBA')
        _,fresh=native_layers([],tuple(data['rect']),59530)
        self.assertEqual(original.tobytes(),fresh.tobytes())
        paint=Image.open(FOLDER/'native-paint.png').convert('RGBA')
        mask=Image.open(FOLDER/'observed-wall-mask.png').convert('L')
        portal=FOLDER.parent/'Portal'
        portal_data=json.loads((portal/'data.json').read_text())
        excluded=Image.open(portal/'bg-photo-mask.png').convert('L')
        self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),data['source_background_sha256'])
        self.assertEqual(sum(bool(v) for v in mask.tobytes()),data['observed_pixels'])
        self.assertGreater(data['observed_pixels'],40000)
        for y in range(mask.height):
            for x in range(mask.width):
                if not mask.getpixel((x,y)):continue
                self.assertEqual(paint.getpixel((x,y)),original.getpixel((x,y)))
                u,v=x+data['rect'][0],y+data['rect'][1]
                px,py=u-portal_data['rect'][0],v-portal_data['rect'][1]
                self.assertEqual(excluded.getpixel((px,py)),0,'The wall cannot steal the joined arch/post paint')

    def test_other_architecture_stays_in_original_bg_and_foot_tracks_source_contact(self):
        data=json.loads((FOLDER/'data.json').read_text());mask=Image.open(FOLDER/'observed-wall-mask.png').convert('L')
        other=Image.open(FOLDER/'other-architecture-mask.png').convert('L');native=Image.open(FOLDER/'original-background.png').convert('RGBA')
        self.assertEqual(sum(bool(v) for v in other.tobytes()),data['other_architecture_pixels'])
        floor=json.loads((FOLDER/'floor-data.json').read_text());combined=Image.open(FOLDER/'combined-bg-photo-mask.png').convert('L')
        for y in range(other.height):
            for x in range(other.width):
                if not other.getpixel((x,y)):continue
                self.assertEqual(mask.getpixel((x,y)),0)
                self.assertEqual(combined.getpixel((x+data['rect'][0]-floor['native_rect'][0],y+data['rect'][1]-floor['native_rect'][1])),0,'Every nonwall source pixel must remain with its original BG owner')
        for u,v in [(6170,-334),(6363,-491)]:
            point=(u-data['rect'][0],v-data['rect'][1]);self.assertEqual(mask.getpixel(point),0);self.assertEqual(other.getpixel(point),255)
        self.assertEqual({r['role'] for r in data['source_roles']},{'masonry/window','wall coping','FG422 continuation','FG414 continuation'})
        evidence=data['foot_evidence'];q=evidence['contact_q']
        self.assertEqual(q,data['wall']['foot_intercept'])
        for u in range(evidence['corridor'][0],evidence['corridor'][1]+1,5):
            samples={}
            for row in range(*evidence['search_q']):
                values=[native.getpixel((x-data['rect'][0],round(row-.75*x)-data['rect'][1])) for x in range(u-2,u+3)]
                self.assertTrue(all(c[3] and max(c[:3])>3 for c in values))
                samples[row]=statistics.median(max(c[:3]) for c in values)
            self.assertLessEqual(samples[q],min(samples.values())+evidence['tolerance_rgb'],'Foot must stay in the original dark plinth/floor contact band')
        record=json.loads((FOLDER/'floor-data.json').read_text());pages={}
        for u,v,index in [(6170,-334,18013),(6363,-491,17821)]:
            row=record['placements'].get(str(index))
            if row is None:continue # No derivative means the unchanged original CUT remains its owner.
            art,offset,_=source.cut_image(59530,row['serial']);width=199
            at=((index%width+index//width)*32+offset[0],(index//width-index%width)*24+offset[1])
            if row['page'] not in pages:pages[row['page']]=Image.open(FOLDER/f"floor-atlas-{row['page']}.png").convert('RGBA')
            x,y,w,h=row['rect'];self.assertEqual(pages[row['page']].getpixel((x+u-at[0],y+v-at[1])),art.getpixel((u-at[0],v-at[1])))

    def test_bg_derivative_cannot_restore_previous_arch_photographs(self):
        record=json.loads((FOLDER/'floor-data.json').read_text())
        mask=Image.open(FOLDER/'combined-bg-photo-mask.png').convert('L')
        previous=Image.open(FOLDER.parent/'Portal/bg-photo-mask.png').convert('L')
        self.assertEqual(mask.size,previous.size)
        self.assertTrue(all(not before or after for before,after in zip(previous.tobytes(),mask.tobytes())))
        pages={};width=source.reference_map(59530)[0];rect=record['native_rect']
        for key,row in record['placements'].items():
            original,offset,_=source.cut_image(59530,row['serial'])
            self.assertEqual(list(offset),row['origin'])
            if row['page'] not in pages:pages[row['page']]=Image.open(FOLDER/('floor-atlas-%d.png'%row['page'])).convert('RGBA')
            x,y,w,h=row['rect'];paint=pages[row['page']].crop((x,y,x+w,y+h))
            self.assertEqual(original.size,paint.size)
            self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),row['source_sha256'])
            index=int(key);u=(index%width+index//width)*32+offset[0]-rect[0];v=(index//width-index%width)*24+offset[1]-rect[1]
            selected=mask.crop((u,v,u+w,v+h))
            for before,after,owned in zip(original.getdata(),paint.getdata(),selected.getdata()):
                self.assertEqual(before[:3],after[:3])
                self.assertEqual(after[3],0 if owned else before[3])

    def test_closed_volume_projection_and_window_free_rear(self):
        data=json.loads((FOLDER/'data.json').read_text())
        self.assertTrue(data['candidate_only']);edges=Counter()
        self.assertEqual(len(data['surfaces']),6)
        for face in data['surfaces']:
            points=[tuple(p) for p in face['points']]
            for a,b in zip(points,points[1:]+points[:1]):edges[tuple(sorted([a,b]))]+=1
            if face['paint']!='native':continue
            for (x,y,z),(u,v) in zip(points,face['uv']):
                self.assertAlmostEqual((x+z)*32/3,u+data['native_origin'][0])
                self.assertAlmostEqual((z-x)*8-y*VERTICAL,v+data['native_origin'][1])
        self.assertEqual(set(edges.values()),{2},'Every boundary edge has two closed incident faces')
        self.assertEqual(len(edges),12)
        center=[sum(p[k] for f in data['surfaces'] for p in f['points'])/24 for k in range(3)]
        for face in data['surfaces']:
            a,b,c=face['points'][:3];u=[c[k]-a[k] for k in range(3)];v=[b[k]-a[k] for k in range(3)]
            normal=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            offset=[sum(p[k] for p in face['points'])/len(face['points'])-center[k] for k in range(3)]
            self.assertGreater(sum(normal[k]*offset[k] for k in range(3)),0,'Every closed face must point outwards so the source front is visible from outside')
        native=Image.open(FOLDER/'original-background.png').convert('RGBA')
        palette=set(native.getdata())
        rear=Image.open(FOLDER/'rear-paint.png').convert('RGBA')
        self.assertTrue(all(not p[3] or p in palette for p in rear.getdata()))
        self.assertNotEqual(rear.tobytes(),Image.open(FOLDER/'native-paint.png').convert('RGBA').tobytes(),'Hidden rear repeats masonry, not the front window')


if __name__=='__main__':unittest.main()
