import tempfile
import json
import contextlib
import io
from unittest.mock import patch
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

import prepare_crossgate_cosmetics as cosmetics


class CosmeticPreparationTest(unittest.TestCase):
    def test_crossed_weapons_share_the_icon_and_turn_behind_the_wearer(self):
        entry, atlas, icon = cosmetics.water_dragon_cross(25)
        self.assertEqual(entry['kind'], 'wings')
        self.assertFalse(entry['fixed_facing'])
        self.assertEqual(len(entry['clips']), 8)
        rear=entry['clips']['0:1']['frames'][0]
        front=entry['clips']['0:5']['frames'][0]
        def pixels(frame):
            _,x,y,w,h,_,_=frame
            return atlas.crop((x,y,x+w,y+h))
        self.assertEqual(pixels(front).tobytes(), pixels(rear).transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes())
        small=pixels(rear).crop(pixels(rear).getbbox())
        small.thumbnail((60,60),Image.Resampling.NEAREST)
        expected=Image.new('RGBA',(64,64));expected.alpha_composite(small,((64-small.width)//2,(64-small.height)//2))
        self.assertEqual(icon.tobytes(),expected.tobytes())
        self.assertLess(entry['clips']['0:3']['frames'][0][3],rear[3])

    def test_recolored_uru_hurt_uses_the_head_outline_instead_of_the_collar(self):
        folder=cosmetics.ROOT/'assets/characters/crossgate/ruby'
        source=json.loads((folder/'motions.json').read_text());frame=source['clips']['8:5']['frames'][-1]
        image=cosmetics.frame_image(folder,source,frame);point=[27,10]
        pattern=cosmetics.features(image,point);mask=image.getchannel('A').crop((13,2,42,22)).tobytes()
        destination=folder/'100250';model=json.loads((destination/'motions.json').read_text());target=model['clips']['8:5']['frames'][-1]
        result=cosmetics.reviewed_pose_head(cosmetics.frame_image(destination,model,target),target,[([point[0]+frame[5],point[1]+frame[6]],pattern,mask)],[30,30])
        self.assertIsNotNone(result)
        self.assertLess(abs(result[0]-27)+abs(result[1]-10),8)

    def test_reviewed_reaction_head_rejects_white_trousers_on_a_fallen_saizo(self):
        folder=cosmetics.ROOT/'assets/characters/crossgate/fighters/saizo/106477'
        manifest=json.loads((folder/'motions.json').read_text());frame=manifest['clips']['10:7']['frames'][-1]
        image=cosmetics.frame_image(folder,manifest,frame);point=[13,13]
        mask=image.getchannel('A').crop((-1,5,28,25)).tobytes()
        references=[([point[0]+frame[5],point[1]+frame[6]],cosmetics.features(image,point),mask)]
        self.assertEqual(cosmetics.reviewed_pose_head(image,frame,references,[57,20]),point)

    def test_reviewed_pose_fixes_a_body_match_only_when_the_head_pixels_agree(self):
        head=Image.new('RGBA',(24,28),(45,70,95,255))
        ImageDraw.Draw(head).rectangle((5,8,18,20),fill=(225,165,115,255))
        reference=cosmetics.features(head,(12,5))
        image=Image.new('RGBA',(70,85));image.paste(head,(30,12))
        frame=[0,0,0,70,85,-20,-50]
        self.assertEqual(cosmetics.reviewed_pose_head(image,frame,[([22,-33],reference,None)],[40,65]),[42,17])
        self.assertIsNone(cosmetics.reviewed_pose_head(image,frame,[([22,-33],reference,None)],[42,17]))
        changed=Image.new('RGBA',image.size,(210,10,160,255))
        self.assertIsNone(cosmetics.reviewed_pose_head(changed,frame,[([22,-33],reference,None)],[40,65]))
        mask=image.getchannel('A').crop((28,9,57,29)).tobytes()
        recolored=Image.new('RGBA',image.size,(210,10,160,0));recolored.putalpha(image.getchannel('A'))
        self.assertEqual(cosmetics.reviewed_pose_head(recolored,frame,[([22,-33],reference,mask)],[40,65]),[42,17])
        shifted=Image.new('RGBA',image.size,(210,10,160,0))
        shifted.putalpha(Image.new('L',image.size))
        shifted.paste(recolored.crop((30,12,54,40)),(40,20))
        self.assertEqual(cosmetics.reviewed_pose_head(shifted,frame,[([22,-33],reference,mask)],[40,65]),[52,25])
        self.assertIsNone(cosmetics.silhouette_head(image.getchannel('A'),bytes([255])*580,[42,17]))

    def test_reviewed_fit_rejects_changed_source_pixels(self):
        image=Image.new('RGBA',(24,24),(80,90,100,255));frame=[0,0,0,24,24,0,0]
        fit=dict(root='test',pose='5:0',layout=frame[3:],head=[8,8],sha256=cosmetics.hashlib.sha256(image.tobytes()).hexdigest())
        self.assertEqual(cosmetics.reviewed_head(fit,frame,image),[8,8])
        image.putpixel((4,4),(100,90,80,255))
        with self.assertRaises(ValueError):cosmetics.reviewed_head(fit,frame,image)

    def test_spinning_uru_uses_the_visible_head_view_beyond_the_standing_window(self):
        folder=cosmetics.ROOT/'assets/characters/crossgate/ruby/108921'
        manifest=json.loads((folder/'motions.json').read_text());patterns=[]
        for direction in range(8):
            frame=manifest['clips'][f'0:{direction}']['frames'][0]
            patterns.append(cosmetics.features(cosmetics.frame_image(folder,manifest,frame),(-1-frame[5],-58-frame[6])))
        frame=manifest['weapons'][0]['clips']['5:3']['frames'][4]
        error,point=cosmetics.fit_turning_head(cosmetics.frame_image(folder,manifest,frame),patterns,[-10,41])
        self.assertLess(error,150)
        self.assertLess(abs(point[0]-40)+abs(point[1]-22),5)

    def test_pose_cache_reuses_unchanged_inputs_and_rejects_changed_pixels_or_coordinates(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);folder=root/'model';folder.mkdir()
            image=Image.new('RGBA',(24,24),(90,70,60,255));image.save(folder/'atlas-0.png')
            manifest=dict(key='test',pages=1,clips={'0:5':dict(frames=[[0,0,0,24,24,0,0]])})
            cosmetics.save_json(folder/'motions.json',manifest)
            record=dict(key='1',name='Test',manifest='model/motions.json',crop=[0,0,16,16],bounds=[0,0,16,16])
            cosmetics.save_json(root/'heads.json',[record]);out=root/'cosmetics';out.mkdir()
            report=root/'report';report.mkdir();native={1:(8,8)};calls=[]
            class Client:
                @staticmethod
                def actor(_):return 1,None,[dict(action=0,direction=5,frames=[[1,0,0,0]])]
            class Wardrobe:
                @staticmethod
                def head_coordinates(_):return native
            original=cosmetics.fit_clip
            def counted(*args):calls.append(1);return original(*args)
            with patch.multiple(cosmetics,ROOT=root,OUT=out,REPORT=report,HEADS=root/'heads.json'),patch.object(cosmetics,'model_sources',return_value=([record],{folder/'motions.json':record})),patch.object(cosmetics,'fit_clip',side_effect=counted),contextlib.redirect_stdout(io.StringIO()):
                cosmetics.prepare_anchors(Client,Wardrobe);self.assertEqual(len(calls),1)
                cosmetics.prepare_anchors(Client,Wardrobe);self.assertEqual(len(calls),1)
                image.putpixel((4,4),(100,70,60,255));image.save(folder/'atlas-0.png');cosmetics.atlas.cache_clear()
                cosmetics.prepare_anchors(Client,Wardrobe);self.assertEqual(len(calls),2)
                native[1]=(9,8)
                cosmetics.prepare_anchors(Client,Wardrobe);self.assertEqual(len(calls),3)
                self.assertEqual(cosmetics.struct.unpack('<HHhh',(out/'anchors.bin').read_bytes())[2:],(36,32))
                sources=(out/'model-sources.json').read_bytes();cached=(report/'pose-fit-cache.json').read_bytes()
                cosmetics.prepare_anchors(Client,Wardrobe,sample=True)
                self.assertEqual((out/'model-sources.json').read_bytes(),sources)
                self.assertEqual(json.loads((report/'pose-fit-cache.json').read_text()),json.loads(cached))
                manifest['clips']['8:5']=manifest['clips']['0:5']
                cosmetics.save_json(folder/'motions.json',manifest)
                cosmetics.save_json(out/'head-fits.json',dict(frames=[dict(root='model',stance=0,pose='8:5',frame=0,layout=[24,24,0,0],head=[12,5],sha256=cosmetics.hashlib.sha256(image.tobytes()).hexdigest())]))
                cosmetics.prepare_anchors(Client,Wardrobe)
                self.assertEqual(cosmetics.struct.unpack('<HHhh',(out/'anchors.bin').read_bytes())[2:],(48,20),'A reviewed hurt head must also correct an earlier idle clip sharing the same atlas region')
            cosmetics.atlas.cache_clear()

    def fitted_pose(self,root,pose,native,expected):
        folder=cosmetics.ROOT/'assets/characters/crossgate'/root
        manifest=json.loads((folder/'motions.json').read_text());frames=manifest['clips'][pose]['frames'][:len(native)]
        images=[cosmetics.frame_image(folder,manifest,frame) for frame in frames]
        first=native[0];pattern=cosmetics.features(images[0],(first[0]-frames[0][5],first[1]-frames[0][6]))
        result=cosmetics.fit_clip(frames,lambda i:images[i],native,pattern,expected)
        return [([point[0]+frame[5],point[1]+frame[6]],method) for frame,(point,method,_) in zip(frames,result)]

    def test_missing_horizontal_attack_heads_follow_the_pose_instead_of_standing(self):
        result=self.fitted_pose('weapons/ex-394','5:7',[[-69,-41],None,None,None,None],[0,-67])
        self.assertEqual(result[0],([-69,-41],'native'))
        self.assertTrue(all(-80<point[0]<-50 for point,_ in result))

    def test_inverted_rei_repairs_native_points_above_the_actual_frame(self):
        result=self.fitted_pose('fighters/rei/100798','5:6',[[-15,-39],[-15,-39],[-6,-66],[-6,-100],[-6,-100]],[-15,-39])
        self.assertTrue(all(abs(result[i][0][1]+45)<10 for i in [3,4]))
        self.assertTrue(all(result[i][1]=='native repair' for i in [3,4]))

    def test_empty_pose_uses_continuity_without_claiming_a_pixel_match(self):
        image=Image.new('RGBA',(20,20));frame=[0,0,0,20,20,-10,-20]
        result=cosmetics.fit_clip([frame],lambda _:image,[None],cosmetics.features(image,(10,4)),[0,-16])
        self.assertEqual(result,[([10,4],'pose interpolation',0)])

    def test_rear_kaz_attack_tracks_hair_instead_of_similar_clothing(self):
        folder=cosmetics.ROOT/'assets/characters/crossgate/kazi'
        manifest=json.loads((folder/'motions.json').read_text())
        standing=manifest['clips']['0:1']['frames'][0]
        attack=manifest['clips']['5:1']['frames'][1]
        patterns=cosmetics.features(cosmetics.frame_image(folder,manifest,standing),(6-standing[5],-64.6-standing[6]))
        point,_=cosmetics.track_head(cosmetics.frame_image(folder,manifest,attack),patterns,(6-attack[5],-64.6-attack[6]))
        # The reviewed head is near (105, 91); the rejected shirt match was (101, 120).
        self.assertLessEqual(abs(point[0]-105)+abs(point[1]-91),4)

    def test_tracks_selected_head_when_body_and_effect_move_differently(self):
        head=Image.new('RGBA',(32,35))
        draw=ImageDraw.Draw(head)
        draw.ellipse((4,2,27,31),fill=(66,47,39,255))
        draw.rectangle((8,16,22,26),fill=(224,174,120,255))
        draw.rectangle((11,18,13,20),fill=(20,21,24,255))
        patterns=cosmetics.features(head,(16,5))
        frame=Image.new('RGBA',(120,110))
        frame.paste(head,(53,27));ImageDraw.Draw(frame).rectangle((3,75,115,95),fill=(190,35,240,255))
        point,score=cosmetics.track_head(frame,patterns,(62,24))
        self.assertLessEqual(abs(point[0]-69)+abs(point[1]-32),2)
        self.assertGreaterEqual(score,8)

    def test_masked_fit_follows_the_head_without_exact_neighborhoods(self):
        cosmetics.REPORT.mkdir(parents=True,exist_ok=True)
        head=Image.new('RGBA',(32,35))
        draw=ImageDraw.Draw(head);draw.ellipse((4,2,27,31),fill=(66,47,39,255))
        draw.rectangle((8,16,22,26),fill=(224,174,120,255))
        _,samples=cosmetics.features(head,(16,5))
        frame=Image.new('RGBA',(110,100));frame.paste(head,(45,24))
        point,score=cosmetics.track_head(frame,({},samples),(56,24))
        self.assertLessEqual(abs(point[0]-61)+abs(point[1]-29),2)
        self.assertGreater(score,4)

    def test_empty_head_is_reported_as_a_prepared_fit(self):
        image=Image.new('RGBA',(20,20))
        self.assertEqual(cosmetics.track_head(image,cosmetics.features(image,(8,4)),(8,4)),([8,4],0))

    def test_source_guard_rejects_a_modified_output(self):
        with tempfile.TemporaryDirectory() as folder:
            original_root,original_out=cosmetics.ROOT,cosmetics.OUT
            try:
                cosmetics.ROOT=Path(folder);cosmetics.OUT=Path(folder)/'cosmetics';cosmetics.OUT.mkdir()
                file=cosmetics.OUT/'atlas.png';file.write_bytes(b'original')
                Path(str(file)+'.import').write_text('process/fix_alpha_border=true\n')
                cosmetics.save_json(cosmetics.OUT/'preservation.json',dict(inputs={},outputs={'cosmetics/atlas.png':cosmetics.digest(file)}))
                self.assertEqual(cosmetics.check_local(),[])
                file.write_bytes(b'changed')
                self.assertEqual(len(cosmetics.check_local()),1)
            finally:cosmetics.ROOT,cosmetics.OUT=original_root,original_out


if __name__=='__main__':unittest.main()
