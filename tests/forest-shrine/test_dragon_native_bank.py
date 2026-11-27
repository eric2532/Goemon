"""The staged Jete append preserves every existing row and original source frame."""
import json
from pathlib import Path
import struct
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools')); sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
import cg_assets as cg
from recover_habaru_encounter import body_rows
from prepare_sokia_dragon_summit import REPORT

BASE = REPORT / 'Native bank/Previous cache'
if not BASE.exists():
    BASE = ROOT / 'assets/characters/crossgate/east_region'
STAGED = REPORT / 'Native bank/Staged'


class DragonNativeBankTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = json.loads((BASE / 'motions.json').read_text())
        cls.new = json.loads((STAGED / 'motions.json').read_text())
        cls.a = list(struct.iter_unpack('<4f', (BASE / 'frames.bin').read_bytes()))
        cls.b = list(struct.iter_unpack('<4f', (STAGED / 'frames.bin').read_bytes()))

    def test_all166_existing_frames_timing_metadata_audio_palette_and_pages_preserved(self):
        self.assertEqual(len(self.old['variants']),166); self.assertEqual(len(self.new['variants']),167)
        for key in ['variants','timelines','atlas_paths','skin_pages','variant_heights','variant_sources']:
            self.assertEqual(self.new[key][:len(self.old[key])],self.old[key],key)
        records=json.loads((BASE/'species.json').read_text()); staged=json.loads((STAGED/'species.json').read_text())
        self.assertEqual(staged[:len(records)],records)
        self.assertEqual(self.a[:self.old['clip_count']],self.b[:self.old['clip_count']])
        n=self.old['frame_count']*2
        self.assertEqual(self.a[self.old['clip_count']:self.old['clip_count']+n],self.b[self.new['clip_count']:self.new['clip_count']+n])
        for cue,path in self.old['sounds'].items():self.assertEqual(self.new['sounds'][cue],path)
        with Image.open(BASE/'palette.png')as a,Image.open(STAGED/'palette.png')as b:
            self.assertEqual(a.tobytes(),b.crop((0,0,*a.size)).tobytes())
        self.assertEqual(self.new['atlas_paths'],self.old['atlas_paths'])

    def test_all_jete_frames_pixels_anchors_and_duration_match_original2719(self):
        manifest=self.new;table=self.b;palette=Image.open(STAGED/'palette.png').convert('RGBA')
        record=json.loads((STAGED/'species.json').read_text())[166]
        self.assertEqual((record['id'],record['key']),(100452,'original:2719'))
        ident,_,clips=cg.actor(record['key']);self.assertEqual(ident,100452)
        source={(c['action'],c['direction']):c for c in clips}
        idle,_,oy=cg.frame_parts(record['key'],source[0,4]['index'],0);_,foot=body_rows(idle);shift=oy+foot-10
        images={};colors={};frames=0;clip_count=0
        for ai,action in enumerate(manifest['actions']):
            for direction in range(8):
                header=table[(166*len(manifest['actions'])+ai)*8+direction];original=source[action,direction]
                self.assertEqual(int(header[1]),len(original['frames']));self.assertAlmostEqual(header[2],original['duration']/1000,places=5)
                clip_count+=1
                for index in range(int(header[1])):
                    frame=int(header[0])+index;x,y,w,h=map(int,table[manifest['clip_count']+frame*2])
                    ox,oy,page,row=table[manifest['clip_count']+frame*2+1];row=int(row);path=manifest['atlas_paths'][int(page)]
                    if path not in images:images[path]=Image.open(ROOT/path.removeprefix('res://')).convert('L')
                    if row not in colors:colors[row]=[palette.getpixel((i,row))for i in range(256)]
                    actual=Image.new('RGBA',(w,h));actual.putdata([colors[row][v]for v in images[path].crop((x,y,x+w,y+h)).getdata()])
                    image,sx,sy=cg.frame_parts(record['key'],original['index'],index);box=image.getbbox();image=image.crop(box)
                    self.assertEqual(actual.size,image.size,(action,direction,index));self.assertEqual(actual.tobytes(),image.tobytes(),(action,direction,index))
                    self.assertEqual((ox,oy),(sx+box[0],sy+box[1]-shift),(action,direction,index));frames+=1
        self.assertEqual(clip_count,56)
        (REPORT/'Native bank/original-frame-proof.json').write_text(json.dumps(dict(variants=1,appearance=100452,key=record['key'],
            frames=frames,clips=clip_count,rgba_exact=True,anchors_exact=True,durations_exact=True,native_verified=False,visual_verified=False),indent=2)+'\n')

    def test_selected_timeline_contact_and_audio_match_source_skin16(self):
        source=ROOT/'assets/characters/crossgate/sokia_region';m=json.loads((source/'motions.json').read_text())
        table=list(struct.iter_unpack('<4f',(source/'frames.bin').read_bytes()))
        for ai,action in enumerate(self.new['actions']):
            for direction in range(8):
                actual=self.b[(166*len(self.new['actions'])+ai)*8+direction]
                expected=table[(16*len(m['actions'])+m['actions'].index(action))*8+direction]
                self.assertEqual(actual[1:],expected[1:])
        stride=len(m['timelines'])//len(m['variants'])//8
        for direction in range(8):
            start=(16*8+direction)*stride;expected=m['timelines'][start:start+stride]
            self.assertEqual(self.new['timelines'][(166*8+direction)*42:(166*8+direction+1)*42],expected+[0]*(42-stride))
        for cue,path in m['sounds'].items():
            owner,code=cue.split(':')if ':'in cue else(None,cue)
            if owner is None or int(owner)==16:
                expected=path if path.startswith('res://')else'res://'+str((source/path).relative_to(ROOT))
                self.assertEqual(self.new['sounds'][f'166:{code}'],expected)


if __name__=='__main__':unittest.main()
