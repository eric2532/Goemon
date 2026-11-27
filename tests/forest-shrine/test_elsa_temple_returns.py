"""Corroborated temple scripts, exact return points and native NPC paint."""
import json
from pathlib import Path
import re
import sys
import struct
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import recover_elsa_island as source


class TempleReturnsTest(unittest.TestCase):
    def test_encounter_bank_uses_effective_animation_records(self):
        population=json.loads((ROOT/'assets/maps/falan/elsa/population.json').read_text())
        tables={}
        for row in population['species']:
            pack,index=row['key'].rsplit(':',1)
            if pack not in tables:
                raw=(source.cg.SOURCE/source.cg.GAME_PACKS[pack][2]).read_bytes()
                tables[pack]=[struct.unpack_from('<IIHH',raw,i*12) for i in range(len(raw)//12)]
            latest=max(i for i,record in enumerate(tables[pack]) if record[0]==row['id'])
            self.assertEqual(int(index),latest,row['id'])
        corrected=next(row for row in population['species'] if row['id']==101913)
        self.assertEqual(corrected['key'],'original:2971')
        bank=json.loads((ROOT/'assets/characters/crossgate/elsa_region/motions.json').read_text())
        self.assertEqual([row['id'] for row in bank['variants']],[row['id'] for row in population['species']])
        folder=ROOT/'assets/characters/crossgate/elsa_region'
        raw=(folder/'frames.bin').read_bytes()
        pages=[Image.open(folder/f'atlas-{i}.png').convert('L') for i in range(bank['pages'])]
        palette=Image.open(folder/'palette.png').convert('RGBA')
        skin=population['species'].index(corrected)
        clips={(c['action'],c['direction']):c for c in source.cg.actor(corrected['key'])[2]}
        from recover_habaru_encounter import body_rows
        idle,_,oy=source.cg.frame_parts(corrected['key'],clips[0,4]['index'],0)
        _,foot=body_rows(idle);shift=oy+foot-10
        checked=0
        for action_index,action in enumerate(bank['actions']):
            for direction in range(8):
                clip=clips[action,direction]
                row=(skin*len(bank['actions'])+action_index)*8+direction
                start,count,duration,_=struct.unpack_from('<4f',raw,row*16)
                self.assertEqual(int(count),len(clip['frames']))
                self.assertAlmostEqual(duration,clip['duration']/1000,places=6)
                for frame in range(int(count)):
                    at=(bank['clip_count']+(int(start)+frame)*2)*16
                    x,y,w,h=map(round,struct.unpack_from('<4f',raw,at))
                    ox,py,page,pal=map(round,struct.unpack_from('<4f',raw,at+16))
                    native,sx,sy=source.cg.frame_parts(corrected['key'],clip['index'],frame)
                    bounds=native.getbbox();native=native.crop(bounds)
                    self.assertEqual((ox,py),(sx+bounds[0],sy+bounds[1]-shift))
                    self.assertEqual((w,h),native.size)
                    colors=[palette.getpixel((i,pal)) for i in range(256)]
                    actual=bytes(v for i in pages[page].crop((x,y,x+w,y+h)).tobytes() for v in colors[i])
                    expected=bytes(v for p in native.getdata() for v in (p if p[3] else (0,0,0,0)))
                    self.assertEqual(actual,expected,(action,direction,frame));checked+=1
        print('ELSA_EFFECTIVE_ENCOUNTER_SOURCE frames=',checked,' species=',len(population['species']))

    def test_only_the_three_named_template_events_are_admitted(self):
        population=json.loads((ROOT/'assets/maps/falan/elsa/population.json').read_text())
        self.assertEqual(population['art']['103010:4']['key'],'original:3171')
        self.assertEqual(population['art']['101532:6']['key'],'original:2911')
        links=json.loads((ROOT/'assets/maps/falan/elsa/links.json').read_text())
        cases=[([79,55],[175,62]),([59,93],[200,96]),([81,133],[228,128])]
        for i,(cell,landing) in enumerate(cases,1):
            script=f'me_warp_family_{i}.txt'
            actor=next(a for a in source.npc_rows() if a['map']==59530 and a['cell']==cell and a['script']==script)
            self.assertTrue(source.active_actor(actor));self.assertEqual(actor['graphic'],103010)
            text=(source.SOURCE/script).read_bytes().decode('gb18030')
            native=[int(v) for v in re.search(r'Warp\s+0,(\d+),(\d+),(\d+)',text).groups()]
            self.assertEqual(native,[59520,*landing])
            row=next(a for a in links if a.get('temple_return') and a['cell']==cell)
            self.assertEqual((row['source'],row['target'],row['landing']),(59530,59520,landing))
            self.assertEqual(row['original_client_parity'],'unverified')
            self.assertIn('Level > 49',row['snapshot_condition'])
            self.assertEqual(sum(a['id']==actor['id'] for a in population['npcs']),1)
        for actor in source.npc_rows():
            if int(actor['id'])>=1000000 and not source.temple_return(actor):self.assertFalse(source.active_actor(actor))

    def test_repacked_npc_paint_matches_native_pixels(self):
        population=json.loads((ROOT/'assets/maps/falan/elsa/population.json').read_text())
        atlas=Image.open(ROOT/'assets/maps/falan/elsa/npc-atlas.png').convert('RGBA')
        lookup=source.lib.serial_index()
        tables={}
        for token,row in population['art'].items():
            if row['key'].startswith('graphic:'):
                graphic=lookup[int(row['key'].split(':')[1])]
                original=source.lib.image_from_record(graphic['pack'],graphic['row']);origin=[graphic['x'],graphic['y']]
            else:
                pack,index=row['key'].rsplit(':',1)
                if pack not in tables:
                    raw=(source.cg.SOURCE/source.cg.GAME_PACKS[pack][2]).read_bytes()
                    tables[pack]=[struct.unpack_from('<IIHH',raw,i*12) for i in range(len(raw)//12)]
                latest=max(i for i,record in enumerate(tables[pack]) if record[0]==int(token.split(':')[0]))
                self.assertEqual(int(index),latest,'NPC appearance must use the effective last AnimeInfo row')
                _,_,clips=source.cg.actor(row['key']);direction=int(token.split(':')[1])
                idle=[c for c in clips if c['action']==0]
                clip=next((c for c in idle if c['direction']==direction),idle[0] if len(idle)==1 else None)
                self.assertIsNotNone(clip)
                original,x,y=source.cg.frame_parts(row['key'],clip['index'],0);origin=[x,y]
            box=original.getbbox();original=original.crop(box)
            self.assertEqual(row['origin'],[origin[0]+box[0],origin[1]+box[1]])
            x,y,w,h=row['rect'];prepared=atlas.crop((x,y,x+w,y+h))
            self.assertEqual(prepared.size,original.size,token)
            self.assertEqual(prepared.tobytes(),original.tobytes(),token)
            self.assertEqual(row['rgba_sha256'],source.sha(original.tobytes()),token)


if __name__=='__main__':unittest.main()
