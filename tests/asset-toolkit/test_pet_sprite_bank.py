"""The composed pet bank must preserve existing hounds and valid mantis records."""
import hashlib
import json
import struct
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'assets/characters/crossgate'

class PetSpriteBankTest(unittest.TestCase):
    def test_preserved_sources_and_lookup(self):
        data = json.loads((ASSETS/'guard_pets/motions.json').read_text())
        original = json.loads((ASSETS/'hounds/motions.json').read_text())
        rows = list(struct.iter_unpack('<4f', (ASSETS/'guard_pets/frames.bin').read_bytes()))
        old = list(struct.iter_unpack('<4f', (ASSETS/'hounds/frames.bin').read_bytes()))
        self.assertEqual(data['variants'][:21], original['variants'])
        timeline_stride=data['timeline_stride']
        for row in range(21*8):
            start=row*timeline_stride
            self.assertEqual(data['timelines'][start:start+28],original['timelines'][row*28:(row+1)*28])
            self.assertEqual(data['timelines'][start+28:start+timeline_stride],[0]*(timeline_stride-28))
        self.assertEqual(rows[:original['clip_count']], old[:original['clip_count']])
        self.assertEqual(rows[data['clip_count']:data['clip_count']+original['frame_count']*2],
                         old[original['clip_count']:original['clip_count']+original['frame_count']*2])
        self.assertEqual(data['variants'][31]['key'], 'puk3:823')
        config=json.loads((ROOT/'tools/crossgate_pet_families.json').read_text())
        count=82+sum(len(f['variants']) for f in config['families'])
        self.assertEqual(len(data['variants']),count)
        self.assertEqual(len({v['key'] for v in data['variants']}),count)
        for source, digest in data['sources'].items():
            self.assertEqual(hashlib.sha256((ROOT/source).read_bytes()).hexdigest(), digest, source)
        with Image.open(ASSETS/'guard_pets/palette.png') as palette:
            unpacked=Image.new('RGBA',(256,data['palette_rows']))
            for row in range(data['palette_rows']):
                x=row%8*256;y=row//8
                unpacked.paste(palette.crop((x,y,x+256,y+1)),(0,row))
            with Image.open(ASSETS/'hounds/palette.png') as hound:
                self.assertEqual(unpacked.crop((0,0,hound.width,hound.height)).tobytes(), hound.tobytes())
            self.assertLessEqual(max(palette.size),16384)
            height=data['palette_rows']
        for start,count,duration,scale in rows[:data['clip_count']]:
            self.assertGreater(count,0);self.assertGreater(duration,0)
            self.assertGreaterEqual(start,0);self.assertLessEqual(start+count,data['frame_count'])
        # Effects and source padding cannot make a mantis body smaller than its siblings.
        for skin, variant in enumerate(data['variants'][21:41], 21):
            expected = .0375 / (2 if 119195 <= variant['id'] <= 119199 else 1)
            for row in rows[skin*48:(skin+1)*48]:
                self.assertAlmostEqual(row[3], expected, places=7, msg=variant['key'])
        dragons=json.loads((ASSETS/'dragon_lizards/motions.json').read_text())
        self.assertEqual(data['variants'][41:61], dragons['variants'])
        self.assertEqual(len(dragons['variants']),20)
        self.assertEqual(data['variants'][54]['key'],'puk3:821')
        self.assertNotIn('ch1:339', [v['key'] for v in data['variants']])
        self.assertTrue(all(v['key'] not in {'original:565','original:566','original:567','original:568','original:1355','original:1356','original:1357','original:1358'} for v in data['variants']))
        for skin,variant in enumerate(data['variants'][41:61],41):
            expected=.0375/(2 if 119268<=variant['id']<=119271 else 1)
            for row in rows[skin*48:(skin+1)*48]:self.assertAlmostEqual(row[3],expected,places=7)
        bees=json.loads((ASSETS/'bees/motions.json').read_text())
        expected=[(101310,'original:2862'),(101311,'original:2863'),(101312,'original:2864'),(101313,'original:3170'),(101314,'original:2866'),(102360,'ex:1599'),(102361,'ex:1600'),(102362,'ex:1601'),(102363,'ex:1602'),(102364,'ex:1603'),(108208,'joy-ex:552'),(108333,'puk2:705'),(117136,'puk3:337'),(109879,'puk3:822'),(116562,'puk3:708'),(118949,'v3:1929'),(119190,'ch1:891'),(119191,'ch1:892'),(119192,'ch1:893'),(119193,'ch1:894'),(119194,'ch1:895')]
        self.assertEqual([(v['id'],v['key']) for v in data['variants'][61:82]],expected)
        self.assertEqual(data['variants'][61:82],bees['variants'])
        with Image.open(ASSETS/'bees/portraits.png') as portraits:
            self.assertEqual(portraits.size,(480,480))
            for i in range(21):self.assertIsNotNone(portraits.crop((i%5*96,i//5*96,(i%5+1)*96,(i//5+1)*96)).getbbox())
        for skin,variant in enumerate(data['variants'][61:82],61):
            expected_scale=.0375/(2 if 119190<=variant['id']<=119194 else 1)
            for row in rows[skin*48:(skin+1)*48]:self.assertAlmostEqual(row[3],expected_scale,places=7)
        # All families retain their source clips, frame offsets, palettes and timing.
        frame_offset=0;page_offset=0;palette_offset=0
        families=[('hounds',0),('mantises',21),('dragon_lizards',41),('bees',61)]
        start=82
        for family in config['families']:
            families.append(('companions/'+family['folder'],start));start+=len(family['variants'])
        for name,start in families:
            source=json.loads((ASSETS/name/'motions.json').read_text())
            source_rows=list(struct.iter_unpack('<4f',(ASSETS/name/'frames.bin').read_bytes()))
            stride=len(source.get('actions',[0,3,5,8,10,1]))*8
            for skin in range(len(source['variants'])):
                for clip in range(48):
                    action=source.get('actions',[0,3,5,8,10,1])[clip//8]
                    if action==3:action=source['variants'][skin].get('run_action',3)
                    source_clip=source.get('actions',[0,3,5,8,10,1]).index(action)*8+clip%8
                    old=source_rows[skin*stride+source_clip]
                    if action==8 and not old[1]:
                        old=source_rows[skin*stride+clip%8]
                    self.assertEqual(rows[(start+skin)*48+clip],(old[0]+frame_offset,*old[1:]))
            for i in range(source['frame_count']):
                old=source_rows[source['clip_count']+i*2:source['clip_count']+i*2+2]
                new=rows[data['clip_count']+(frame_offset+i)*2:data['clip_count']+(frame_offset+i)*2+2]
                self.assertEqual(new[0],old[0])
                self.assertEqual(new[1],(*old[1][:2],old[1][2]+page_offset,old[1][3]+palette_offset))
            frame_offset+=source['frame_count'];page_offset+=source['pages']
            with Image.open(ASSETS/name/'palette.png') as palette:
                self.assertEqual(unpacked.crop((0,palette_offset,256,palette_offset+palette.height)).tobytes(),palette.tobytes(),name)
                palette_offset+=palette.height
        for i in range(data['frame_count']):
            x,y,w,h=rows[data['clip_count']+2*i];_,_,page,palette=rows[data['clip_count']+2*i+1]
            self.assertTrue(0<=page<len(data['atlas_paths']) and 0<=palette<height)
            self.assertTrue(w>0 and h>0 and 0<=x<=2048-w and 0<=y<=2048-h)
        for path in data['atlas_paths']:self.assertTrue((ROOT/path.removeprefix('res://')).is_file())
        for preset in (ROOT/'export_presets.cfg').read_text().split('include_filter=')[1:]:
            self.assertIn('assets/characters/crossgate/guard_pets/frames.bin',preset.splitlines()[0])
            self.assertIn('assets/characters/crossgate/guard_pets/motions.json',preset.splitlines()[0])

if __name__=='__main__':unittest.main()
