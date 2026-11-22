import sys
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools'))
import prepare_kazi_fixed_design as fixed


class FixedKaziArtwork(unittest.TestCase):
    def test_rebuilding_cannot_use_the_active_drafts_as_identity_references(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);output=root/'prepared'
            reference=root/'revisions/iai-left-hip/references/preferred-slash-proportions.png'
            reference.parent.mkdir(parents=True)
            image=Image.new('RGBA',(256,384))
            ImageDraw.Draw(image).rectangle((95,90,160,255),fill=(40,40,40,255))
            image.save(reference);image.save(root/'identity-long-blade.png')
            (root/'jobs.json').write_text('[]')
            jobs=[dict(token=f'0-{d}',action=0,direction=d,target=str(reference),cols=1,rows=1,frames=1) for d in range(8)]
            pinned=root/'pinned.json';pinned.write_text(json.dumps(jobs))
            with patch.object(fixed.hd,'WORK',root),patch.multiple(fixed,WORK=output,SOURCE_RECIPE=pinned):
                fixed.prepare(['skip-writing-art'])
            self.assertEqual(len(json.loads((output/'jobs.json').read_text())),8)

    def test_stitching_keeps_every_original_run_pose_once(self):
        self.assertEqual(sorted(fixed.RUN_ORDER),list(range(18)))
        self.assertEqual(fixed.RUN_ORDER[0],0)
        self.assertEqual(fixed.RUN_ORDER[9],13)

    def test_palette_edit_preserves_every_pixel_outside_the_marking(self):
        image=Image.new('RGBA',(48,48),(190,155,120,255))
        draw=ImageDraw.Draw(image)
        draw.rectangle((18,12,25,22),fill=(75,90,60,255))
        for x,color in [(0,(170,30,230,255)),(1,(60,60,60,255)),(2,(180,140,60,255)),(3,(20,20,20,255)),(4,(75,90,60,0))]:
            draw.line((x,0,x,47),fill=color)
        result,count=fixed.clean_marking(image)
        self.assertEqual(count,8*11)
        self.assertEqual(result.getchannel('A').tobytes(),image.getchannel('A').tobytes())
        for y in range(48):
            for x in range(48):
                if 18<=x<=25 and 12<=y<=22:
                    r,g,b,a=result.getpixel((x,y))
                    self.assertGreater(r,g)
                else:self.assertEqual(result.getpixel((x,y)),image.getpixel((x,y)))

    def test_leaning_head_is_found_independently_of_the_body(self):
        image=Image.new('RGBA',(240,260));draw=ImageDraw.Draw(image)
        draw.rectangle((140,25,190,95),fill=(40,40,40,255))
        draw.rectangle((45,120,155,245),fill=(35,35,35,255))
        source=Image.new('RGBA',(240,260));draw=ImageDraw.Draw(source)
        draw.rectangle((70,25,120,95),fill=(60,60,60,255))
        draw.rectangle((60,120,140,245),fill=(35,35,35,255))
        layer,mask,top,neck=fixed.head_layer(image,220)
        self.assertEqual(top,25)
        self.assertEqual(neck,165)
        result=fixed.lock_head(image,source,220,220,True)
        self.assertEqual(result.getpixel((165,50)),(60,60,60,255))
        self.assertEqual(result.crop((0,120,240,260)).tobytes(),image.crop((0,120,240,260)).tobytes())

    def test_hip_correction_moves_the_grip_left_and_keeps_head_feet_and_blade(self):
        target=Image.new('RGBA',(240,260));source=Image.new('RGBA',(240,260))
        for image in (target,source):
            draw=ImageDraw.Draw(image)
            draw.rectangle((70,25,120,95),fill=(60,60,60,255))
            draw.rectangle((45,120,155,245),fill=(35,35,35,255))
        ImageDraw.Draw(target).rectangle((130,145,140,156),fill=(185,140,70,255))
        ImageDraw.Draw(target).rectangle((0,140,110,142),fill=(40,40,40,255))
        ImageDraw.Draw(target).rectangle((0,173,40,174),fill=(40,40,40,255))
        ImageDraw.Draw(source).rectangle((70,145,80,156),fill=(185,140,70,255))
        ImageDraw.Draw(source).rectangle((10,185,40,187),fill=(40,40,40,255))
        result=fixed.borrow_hip_pose(target,source,220,220)
        self.assertEqual(result.getpixel((75,150)),(185,140,70,255))
        self.assertEqual(result.getpixel((135,150)),(35,35,35,255))
        self.assertEqual(result.getpixel((5,140))[3],0)
        self.assertEqual(result.getpixel((5,174))[3],0)
        self.assertEqual(result.getpixel((20,186)),(40,40,40,255))
        self.assertEqual(result.crop((0,0,240,100)).tobytes(),target.crop((0,0,240,100)).tobytes())
        self.assertEqual(result.crop((0,225,240,260)).tobytes(),target.crop((0,225,240,260)).tobytes())


if __name__=='__main__':unittest.main()
