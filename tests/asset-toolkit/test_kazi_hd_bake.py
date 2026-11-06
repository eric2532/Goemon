import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('kazi_hd', ROOT / 'tools/prepare_crossgate_kazi_hd.py')
hd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hd)


class KaziIllustratedBake(unittest.TestCase):
    def test_body_calibration_ignores_larger_violet_effect(self):
        image = Image.new('RGBA', (160, 160))
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, 159, 159), fill=(150, 0, 255, 255))
        draw.rectangle((60, 30, 99, 129), fill=(30, 30, 30, 255))
        self.assertEqual(hd.body_bounds(image), (60, 30, 100, 130))

    def test_white_collar_does_not_shrink_the_character(self):
        image = Image.new('RGBA', (160, 160))
        draw = ImageDraw.Draw(image)
        draw.rectangle((60, 20, 99, 49), fill=(30, 30, 30, 255))
        draw.rectangle((55, 55, 104, 139), fill=(30, 30, 30, 255))
        self.assertEqual(hd.body_bounds(image), (55, 20, 105, 140))

    def test_long_thin_sword_does_not_enlarge_body_bounds(self):
        image = Image.new('RGBA', (180, 180))
        draw = ImageDraw.Draw(image)
        draw.rectangle((60, 50, 104, 140), fill=(30, 30, 30, 255))
        draw.rectangle((100, 5, 104, 90), fill=(30, 30, 30, 255))
        draw.rectangle((100, 90, 164, 94), fill=(30, 30, 30, 255))
        self.assertEqual(hd.body_bounds(image), (60, 50, 105, 141))

    def test_incomplete_illustrated_set_cannot_be_published(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            (work / 'jobs.json').write_text('[]')
            with patch.object(hd, 'WORK', work):
                with self.assertRaisesRegex(AssertionError, '56 illustrated masters remain'):
                    hd.bake()

    def test_sheet_row_drift_cannot_sink_the_feet(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            work, source, review = root/'masters', root/'original', root/'review'
            work.mkdir(); source.mkdir()
            image = Image.new('RGBA', (256, 768))
            draw = ImageDraw.Draw(image)
            draw.rectangle((95,90,160,255), fill=(30,30,30,255))
            draw.rectangle((95,444,160,609), fill=(30,30,30,255))
            image.save(work/'0-5.png')
            image.save(work/'identity-master.png'); image.save(work/'identity-long-blade.png')
            clip = dict(duration=.8, sounds=[], frames=[[0]*7]*2)
            (source/'motions.json').write_text(json.dumps(dict(clips={'0:5':clip})))
            (work/'jobs.json').write_text(json.dumps([dict(target=str(work/'0-5.png'),
                action=0, direction=5, cols=1, rows=2, frames=2)]))
            with patch.multiple(hd, ROOT=root, WORK=work, SOURCE=source, REVIEW=review):
                hd.bake(pilot=True)
            frames = json.loads((review/'Candidate/motions.json').read_text())['clips']['0:5']['frames']
            self.assertEqual(frames[0],frames[1])
            self.assertEqual(frames[0][6]+frames[0][4],14)

    def test_packing_keeps_motion_audio_and_body_registration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            work, source, review = root/'masters', root/'original', root/'review'
            work.mkdir(); source.mkdir()
            image = Image.new('RGBA', (256, 384))
            ImageDraw.Draw(image).rectangle((95, 90, 160, 255), fill=(30, 30, 30, 255))
            target = work/'0-5.png'
            image.save(target); image.save(work/'identity-master.png'); image.save(work/'identity-long-blade.png')
            running = image.copy()
            ImageDraw.Draw(running).rectangle((0, 222, 255, 383), fill=(0, 0, 0, 0))
            running.save(work/'3-5.png')
            wide_running = Image.new('RGBA',(256,384))
            ImageDraw.Draw(wide_running).rectangle((78,90,177,221),fill=(30,30,30,255))
            wide_running.save(work/'3-3.png')
            falling = Image.new('RGBA',(256,1536))
            for row in range(3):
                falling.alpha_composite(image,(0,row*384))
            ImageDraw.Draw(falling).rectangle((35,1322,220,1367),fill=(30,30,30,255))
            falling.save(work/'10-5.png')
            clip = dict(duration=.8, sounds=[dict(frame=3, sound=103)], frames=[[0]*7])
            (source/'motions.json').write_text(json.dumps(dict(clips={'0:5': clip, '3:5': dict(clip, duration=.5),'3:3':dict(clip,duration=.5),
                '10:5':dict(clip,duration=1.2,frames=[[0]*7]*4)})))
            (work/'jobs.json').write_text(json.dumps([dict(target=str(target), token='0-5',
                action=0, direction=5, cols=1, rows=1, frames=1), dict(target=str(work/'3-5.png'), token='3-5',
                action=3, direction=5, cols=1, rows=1, frames=1),dict(target=str(work/'3-3.png'),
                action=3,direction=3,cols=1,rows=1,frames=1),dict(target=str(work/'10-5.png'),
                action=10,direction=5,cols=1,rows=4,frames=4)]))
            with patch.multiple(hd, ROOT=root, WORK=work, SOURCE=source, REVIEW=review):
                hd.bake(pilot=True)
            manifest = json.loads((review/'Candidate/motions.json').read_text())
            prepared = manifest['clips']['0:5']
            self.assertEqual(prepared['duration'], clip['duration'])
            self.assertEqual(prepared['sounds'], clip['sounds'])
            page, x, y, width, height, origin_x, origin_y = prepared['frames'][0]
            atlas = Image.open(review/f'Candidate/atlas-{page}.png')
            self.assertEqual(atlas.crop((x, y, x+width, y+height)).getbbox(), (0, 0, width, height))
            self.assertEqual(height, 166)
            self.assertEqual(origin_y+height, 14)
            self.assertEqual(origin_x+width/2, 0)
            run_clip = manifest['clips']['3:5']
            self.assertEqual(run_clip['frames'][0][4],148)
            wide_clip = manifest['clips']['3:3']
            self.assertNotEqual(run_clip['authoring_head_width'],wide_clip['authoring_head_width'])
            self.assertEqual(run_clip['authoring_units'],wide_clip['authoring_units'])
            self.assertEqual(wide_clip['frames'][0][4],148)
            fallen = manifest['clips']['10:5']['frames'][-1]
            self.assertEqual(fallen[6]+fallen[4],14)
            self.assertTrue(manifest['illustrated'])


if __name__ == '__main__':
    unittest.main()
