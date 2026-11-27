"""Original-frame and established-bank preservation for the Wind branch additions."""
import json
from pathlib import Path
import struct
import sys
import unittest

from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'));sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_assets as cg
from recover_habaru_encounter import body_rows
from prepare_sokia_wind_tower import REPORT

BASE=REPORT/'Native bank/Previous cache'
if not BASE.exists():BASE=ROOT/'assets/characters/crossgate/east_region'
STAGED=REPORT/'Native bank/Staged'


class WindNativeBankTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old=json.loads((BASE/'motions.json').read_text());cls.new=json.loads((STAGED/'motions.json').read_text())
        cls.a=list(struct.iter_unpack('<4f',(BASE/'frames.bin').read_bytes()))
        cls.b=list(struct.iter_unpack('<4f',(STAGED/'frames.bin').read_bytes()))

    def test_all_established_frames_timing_metadata_and_palette_are_preserved(self):
        old=self.old;new=self.new
        self.assertEqual(len(old['variants']),161);self.assertEqual(len(new['variants']),166)
        for key in ['variants','timelines','atlas_paths','skin_pages','variant_heights','variant_sources']:
            self.assertEqual(new[key][:len(old[key])],old[key],key)
        records=json.loads((BASE/'species.json').read_text());staged=json.loads((STAGED/'species.json').read_text())
        self.assertEqual(staged[:len(records)],records)
        self.assertEqual(self.a[:old['clip_count']],self.b[:old['clip_count']])
        n=old['frame_count']*2
        self.assertEqual(self.a[old['clip_count']:old['clip_count']+n],self.b[new['clip_count']:new['clip_count']+n])
        for cue,path in old['sounds'].items():self.assertEqual(new['sounds'][cue],path)
        with Image.open(BASE/'palette.png') as a,Image.open(STAGED/'palette.png') as b:
            self.assertEqual(a.tobytes(),b.crop((0,0,*a.size)).tobytes())

    def test_all_added_frames_match_original_pixels_anchors_and_durations(self):
        manifest=self.new;table=self.b;palette=Image.open(STAGED/'palette.png').convert('RGBA')
        records=json.loads((STAGED/'species.json').read_text());images={};colors={};checked=0;clips_checked=0
        for skin,record in enumerate(records[161:],161):
            key=record['key'];ident,_,clips=cg.actor(key);self.assertEqual(ident,record['id'])
            source={(c['action'],c['direction']):c for c in clips}
            idle,_,oy=cg.frame_parts(key,source[0,4]['index'],0);_,foot=body_rows(idle);shift=oy+foot-10
            for action_index,action in enumerate(manifest['actions']):
                for direction in range(8):
                    clip=table[(skin*len(manifest['actions'])+action_index)*8+direction]
                    original=source[action,direction]
                    self.assertEqual(int(clip[1]),len(original['frames']));self.assertAlmostEqual(clip[2],original['duration']/1000,places=5)
                    clips_checked+=1
                    for index in range(int(clip[1])):
                        frame=int(clip[0])+index;x,y,w,h=map(int,table[manifest['clip_count']+frame*2])
                        ox,oy,page,row=table[manifest['clip_count']+frame*2+1];row=int(row)
                        path=manifest['atlas_paths'][int(page)]
                        if path not in images:images[path]=Image.open(ROOT/path.removeprefix('res://')).convert('L')
                        if row not in colors:colors[row]=[palette.getpixel((i,row))for i in range(256)]
                        actual=Image.new('RGBA',(w,h));actual.putdata([colors[row][v]for v in images[path].crop((x,y,x+w,y+h)).getdata()])
                        image,sx,sy=cg.frame_parts(key,original['index'],index);box=image.getbbox();image=image.crop(box)
                        self.assertEqual(actual.size,image.size,(skin,action,direction,index))
                        self.assertEqual(actual.tobytes(),image.tobytes(),(skin,action,direction,index))
                        self.assertEqual((ox,oy),(sx+box[0],sy+box[1]-shift),(skin,action,direction,index))
                        checked+=1
        self.assertEqual(clips_checked,280)
        (REPORT/'Native bank/original-frame-proof.json').write_text(json.dumps(dict(variants=5,clips=clips_checked,frames=checked,rgba_exact=True,anchors_exact=True,durations_exact=True,native_verified=False,visual_verified=False),indent=2)+'\n')

    def test_new_cached_frames_timeline_and_audio_match_each_upstream_bank(self):
        target=self.new;records=json.loads((STAGED/'species.json').read_text())
        for skin,record in enumerate(records[161:],161):
            source=record['prepared_from'];folder=ROOT/'assets/characters/crossgate'/source['bank']
            manifest=json.loads((folder/'motions.json').read_text());table=list(struct.iter_unpack('<4f',(folder/'frames.bin').read_bytes()))
            for action_index,action in enumerate(target['actions']):
                for direction in range(8):
                    actual=self.b[(skin*len(target['actions'])+action_index)*8+direction]
                    expected=table[(source['skin']*len(manifest['actions'])+manifest['actions'].index(action))*8+direction]
                    self.assertEqual(actual[1:],expected[1:])
            stride=len(manifest['timelines'])//len(manifest['variants'])//8
            for direction in range(8):
                start=(source['skin']*8+direction)*stride;expected=manifest['timelines'][start:start+stride]
                actual=target['timelines'][(skin*8+direction)*42:(skin*8+direction+1)*42]
                self.assertEqual(actual,expected+[0]*(42-stride))
            for cue,path in manifest['sounds'].items():
                owner,code=cue.split(':')if ':'in cue else(None,cue)
                if owner is None or int(owner)==source['skin']:
                    expected=path if path.startswith('res://')else 'res://'+str((folder/path).relative_to(ROOT))
                    self.assertEqual(target['sounds'][f'{skin}:{code}'],expected)


if __name__=='__main__':unittest.main()
