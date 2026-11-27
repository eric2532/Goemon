"""Rebuild Ruby and her escorts outside assets, then compare the live sprite preparation."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import recover_habaru_encounter as recovery
from test_sokia_blood_demon_source import DecodedBank


def prefix_semantics(path):
    bank=DecodedBank(path);clips=bank.clips[:2*6*8]
    frames=[bank.frame(i) for clip in clips for i in range(int(clip[0]),int(clip[0]+clip[1]))]
    sounds={key:hashlib.sha256((ROOT/value.removeprefix('res://') if value.startswith('res://') else path/value).read_bytes()).hexdigest()
            for key,value in bank.manifest['sounds'].items() if int(key.split(':')[0])<2}
    payload=dict(variants=bank.manifest['variants'][:2],clips=clips,frames=frames,timelines=bank.manifest['timelines'][:2*8*28],sounds=sounds)
    return dict(actors=2,frame_references=len(frames),semantic_sha256=hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest())


def verify_native_source(path):
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_assets as cg
    import cg_sounds
    bank=DecodedBank(path);data=bank.manifest
    assert data['actions']==[0,3,5,8,10,1] and data['clip_count']==144
    assert [v['id'] for v in data['variants']]==[100654,101600,101121]
    assert len(data['timelines'])==3*8*28
    assert data['variants'][2]['native_action_sources']=={'3':1}
    frames=0;cues=0
    for skin,(key,cue_map) in enumerate([('original:1184',{111:135}),('original:2913',{103:106,133:135}),('original:2833',{105:106,131:135})]):
        ident,_,source=cg.actor(key);assert ident==data['variants'][skin]['id']
        clips={(c['action'],c['direction']):c for c in source}
        image,_,y=cg.frame_parts(key,clips[0,4]['index'],0)
        top,foot=recovery.body_rows(image);shift=y+foot-10
        assert abs(data['variants'][skin]['standing_height']-(float((ROOT/'scripts/character_proportions.gd').read_text().split('const GOEMON_HEIGHT=')[1].splitlines()[0])+(.6 if skin==0 else .3)))<1e-8
        for slot,action in enumerate(data['actions']):
            source_action=7 if skin==0 and action==5 else 1 if skin==2 and action==3 else action
            for direction in range(8):
                clip=clips[source_action,direction];start,count,duration,scale=bank.clips[(skin*6+slot)*8+direction]
                assert count==len(clip['frames']) and abs(duration-clip['duration']/1000)<1e-6
                assert abs(scale-data['variants'][skin]['standing_height']/(foot-top))<1e-7
                for index in range(int(count)):
                    image,x,y=cg.frame_parts(key,clip['index'],index);box=image.getbbox()
                    expected=(box[2]-box[0],box[3]-box[1],x+box[0],y+box[1]-shift,hashlib.sha256(image.crop(box).tobytes()).hexdigest()) if box else (1,1,x,y-shift,hashlib.sha256(bytes(4)).hexdigest())
                    assert bank.frame(int(start)+index)==expected,(key,source_action,direction,index)
                    frames+=1
                if action==5:
                    source_cues=cg_sounds.clip_cues(clip);row=data['timelines'][(skin*8+direction)*28:(skin*8+direction+1)*28]
                    assert row[:2]==[clip['duration']*.03,len(source_cues)]
                    for index,cue in enumerate(source_cues):
                        assert row[2+index*2:4+index*2]==[cue['atMs']*.03,cue_map[cue['id']]]
                        cues+=1
    return dict(actors=3,clips=144,frame_references=frames,attack_cues=cues,timeline_stride=28)


class BlackPrayerSourceTest(unittest.TestCase):
    def test_original_boss_and_escort_preparation(self):
        actual = ROOT / 'assets/characters/crossgate/black_prayer'
        evidence = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer Ghost'
        evidence.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='sprite-check-', dir=evidence) as folder:
            with patch.object(recovery, 'OUT', Path(folder) / 'habaru'):
                recovery.recover(ROOT.parent / 'Magic Power', ruby=True)
            rebuilt = Path(folder) / 'black_prayer'
            expected = json.loads((rebuilt / 'motions.json').read_text())
            self.assertEqual([v['id'] for v in expected['variants']], [100654,101600,101121])
            self.assertEqual(expected['variants'][2]['native_action_sources'],{'3':1})
            self.assertEqual(expected, json.loads((actual / 'motions.json').read_text()))
            self.assertEqual((rebuilt / 'frames.bin').read_bytes(), (actual / 'frames.bin').read_bytes())
            for path in rebuilt.glob('*.png'):
                with Image.open(path) as source, Image.open(actual / path.name) as live:
                    self.assertEqual((source.mode, source.size, source.tobytes()), (live.mode, live.size, live.tobytes()), path.name)

    def test_every_native_clip_matches_its_original_source(self):
        result=verify_native_source(ROOT/'assets/characters/crossgate/black_prayer')
        self.assertEqual((result['actors'],result['clips'],result['timeline_stride']),(3,144,28))


if __name__ == '__main__':
    unittest.main()
