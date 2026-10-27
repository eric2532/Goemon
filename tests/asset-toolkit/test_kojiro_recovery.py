"""Source bytes, all pose samples, original pixels/audio and editable export."""
import hashlib
import json
from pathlib import Path
import sys
import struct
import unittest
import wave
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from asset_pipeline.glb import GLB
from recover_vambee_wolf import pose, rotation
from recover_kojiro import BASE, RECOVERY, OUT, WORK, SEMANTICS, AUDIO_BANK


class KojiroRecoveryTest(unittest.TestCase):
    def test_forward_run_is_not_a_lateral_cycle(self):
        m=json.loads((OUT/'kojiro_motion.json').read_text())
        data=json.loads((OUT/'combat.json').read_text())
        raw=(RECOVERY/m['source']).read_bytes()
        for name,index in SEMANTICS.items():
            self.assertEqual(m['semantics'][name],m['clips'][index]['name'])
        self.assertEqual(data['semantics'],m['semantics'])
        for name,slot,travel_axis in [('run',3,2),('run_right',6,0),('run_left',7,0)]:
            clip=next(c for c in m['clips'] if c['name']==m['semantics'][name])
            self.assertEqual(int(clip['address'],16),struct.unpack_from('<I',raw,0x801904f0-BASE+slot*4)[0])
            feet=[m['poses'][f['pose']][7]['position'] for f in clip['frames']]
            ranges=[max(p[a] for p in feet)-min(p[a] for p in feet) for a in range(3)]
            self.assertGreaterEqual(ranges[travel_axis],16)
            self.assertEqual(ranges[2 if travel_axis==0 else 0],0)

    def test_original_rigid_parts_and_every_sample(self):
        m=json.loads((OUT/'kojiro_motion.json').read_text());g=GLB.read(OUT/'kojiro.glb')
        raw=(RECOVERY/m['source']).read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),m['source_sha256'])
        self.assertEqual((len(m['parts']),len(m['clips'])),(15,21))
        for part in m['parts']:
            original=GLB.read(RECOVERY/part['source_glb'])
            recovered=g.doc['meshes'][g.doc['nodes'][part['node']]['mesh']]
            for a,b in zip(original.doc['meshes'][0]['primitives'],recovered['primitives']):
                for key in a['attributes']:self.assertEqual(original.accessor(a['attributes'][key]),g.accessor(b['attributes'][key]))
                self.assertEqual(original.material_key(a['material']),g.material_key(b['material']))
        for clip,animation in zip(m['clips'],g.doc['animations']):
            for i,frame in enumerate(clip['frames']):
                values=pose(raw,frame,15);self.assertEqual(values,m['poses'][frame['pose']])
                for index,part in enumerate(m['parts']):
                    v=values[index]
                    for prop,expected in [('translation',[v['position'][0],-v['position'][1],-v['position'][2]]),('rotation',rotation(v['angles']))]:
                        channel=next(c for c in animation['channels'] if c['target']==dict(node=part['node'],path=prop))
                        sampler=animation['samplers'][channel['sampler']]
                        self.assertEqual(sampler['interpolation'],'STEP')
                        for a,b in zip(expected,g.accessor(sampler['output'])[i]):self.assertAlmostEqual(a,b,places=5)

    def test_editable_export_keeps_geometry_and_texture_bytes(self):
        a=GLB.read(OUT/'kojiro.glb');b=GLB.read(ROOT/'assets/models/characters/kojiro/kojiro.glb')
        for before,after in zip(a.doc['meshes'],b.doc['meshes']):
            for x,y in zip(before['primitives'],after['primitives']):
                for key in x['attributes']:self.assertEqual(a.accessor(x['attributes'][key]),b.accessor(y['attributes'][key]))
                self.assertEqual(a.material_key(x['material']),b.material_key(y['material']))
        self.assertEqual([a.image_bytes(i) for i in a.doc['images']],[b.image_bytes(i) for i in b.doc['images']])
        m=json.loads((ROOT/'assets/models/characters/kojiro/kojiro_motion.json').read_text())
        self.assertEqual(hashlib.sha256((ROOT/m['authored_source']).read_bytes()).hexdigest(),m['authored_sha256'])
        self.assertEqual(hashlib.sha256((ROOT/'assets/models/characters/kojiro/kojiro.glb').read_bytes()).hexdigest(),m['visual_sha256'])
        clips={c['name']:c for c in m['clips']}
        self.assertEqual(set(clips),{a['name'] for a in b.doc['animations']})
        for name,source,ticks in [('Ground__turning_cut','Source__801e2660',24),('Ground__somersault_cut','Source__801e2708',30)]:
            self.assertTrue(clips[name]['authored'])
            self.assertEqual((clips[name]['source_action'],clips[name]['ticks']),(source,ticks))

    def test_effect_pages_and_source_timing(self):
        m=json.loads((OUT/'effects/sources.json').read_text())
        for name,item in m['sprites'].items():
            pixels=Image.open(OUT/'effects'/f'{name}.png').convert('RGBA')
            self.assertEqual(pixels.size,(item['width'],item['height']*item['frames']))
            self.assertEqual(hashlib.sha256(pixels.tobytes()).hexdigest(),item['rgba_sha256'])
        self.assertEqual(hashlib.sha256((ROOT/m['dust']['texture']).read_bytes()).hexdigest(),m['dust']['texture_sha256'])
        data=json.loads((OUT/'combat.json').read_text())
        self.assertEqual(data['actions']['wind']['releases'],[40,42,44,46])
        self.assertEqual(data['actions']['homing']['spread'],[-512,0,512])
        self.assertEqual(data['actions']['slash']['contacts'],[15])

    def test_phoenix_is_a_heading_rotated_sprite(self):
        raw=(RECOVERY/'raw/SC03.CD.dir/FILE_014.dir/0.4.dec').read_bytes()
        # The wave enables sprite rotation and copies the caster's yaw into screen roll.
        for address,word in [(0x80185d7c,0x0c007287),(0x80185db8,0x3c030800),
                             (0x80186b68,0x94420012),(0x80186b70,0xa4620014)]:
            self.assertEqual(struct.unpack_from('<I',raw,address-BASE)[0],word)
        exe=(RECOVERY/'raw/SLUS_007.26').read_bytes()
        base=struct.unpack_from('<I',exe,0x18)[0]-0x800
        # Slot 3 draws a billboard; its flagged branch rotates the projected corners.
        for address,word in [(0x8006350c,0x8001efe0),(0x8001f69c,0x0c007dcc),
                             (0x8001f748,0x0c008369)]:
            self.assertEqual(struct.unpack_from('<I',exe,address-base)[0],word)

    def test_homing_sprite_pixels_and_continuous_screen_rotation(self):
        from recover_skullpion_effects import load_vram, texture
        raw=(RECOVERY/'raw/SC03.CD.dir/FILE_014.dir/0.4.dec').read_bytes()
        # Homing enables rotation, then clears pitch/yaw and sets roll to yaw + 45 degrees.
        for address,word in [(0x80185c30,0x0c007287),(0x80185c8c,0x3c030800),
                             (0x801867b8,0xa4400010),(0x801867c4,0xa4400012),
                             (0x801867c8,0x962200fe),(0x801867d0,0x24420200),
                             (0x801867d4,0xa4620014)]:
            self.assertEqual(struct.unpack_from('<I',raw,address-BASE)[0],word)
        encoded,w,h,x,y,dx,dy=struct.unpack_from('<HBBHHhh',raw,0x80190590-BASE)
        self.assertEqual((w+1,h+1,dx,dy),(32,32,-16,-16))
        vram,present=load_vram((RECOVERY/'raw/SC03.CD.dir/FILE_014').read_bytes())
        clut=(((encoded>>8)+256)<<6)|0x16
        pixels=texture(vram,present,[x,y,(w+1)//4,h+1],clut)
        self.assertEqual(pixels,Image.open(OUT/'effects/homing.png').convert('RGBA').tobytes())

    def test_duel_loader_selects_the_separate_sound_bank(self):
        raw=(RECOVERY/'raw/SC03.CD.dir/FILE_014.dir/0.4.dec').read_bytes()
        # Loader instructions, not a guess based on which overlay holds the model.
        self.assertEqual(struct.unpack_from('<I',raw,0x80184878-BASE)[0],0x24020039)
        self.assertEqual(struct.unpack_from('<2I',raw,0x801848a8-BASE),(0x3c06800b,0x24c6ee48))
        preceding=0
        for archive in ['MAIN','SC01','SC02']:
            with (RECOVERY/'raw'/(archive+'.CD')).open('rb') as f:
                preceding+=struct.unpack('<I',f.read(4))[0]
        self.assertEqual((0x800aee48-0x800ae830)//8-preceding,17)
        self.assertEqual(AUDIO_BANK,'raw/SC03.CD.dir/FILE_017.dir/0.2')

    def test_complete_duel_bank_and_resolved_event_voices(self):
        m=json.loads((OUT/'audio/sources.json').read_text())
        self.assertEqual(m['bank'],'bank_b05ef369d886ab15')
        self.assertEqual(len(m['bank_samples']),23)
        for sample in m['bank_samples']:
            self.assertEqual((WORK/'Audio Catalog'/(sample['id']+'.vag')).read_bytes(),
                             (RECOVERY/'converted/audio/samples_vag'/(sample['id']+'.vag')).read_bytes())
        expected={0xa35:3,0xa36:4,0xa37:5,0xa7e:12,0xa7f:12,0xa80:13,
                  0xa81:14,0xa82:15,0xa85:16,0xa86:16,0xa87:17}
        for sid,index in expected.items():
            event=m['events'][f'{sid:03x}:0']
            self.assertEqual(event['layers'][0]['sample_index'],index)
            self.assertEqual(event['layers'][0]['bank'],m['bank'])
            self.assertTrue(event['enabled'])
        for event in m['events'].values():
            audio=ROOT/event['file']
            self.assertEqual(hashlib.sha256(audio.read_bytes()).hexdigest(),event['sha256'])
            with wave.open(str(audio),'rb') as w:
                self.assertEqual((w.getnchannels(),w.getsampwidth(),w.getframerate()),(1,2,44100))
        self.assertNotIn('a88:0',m['events'])
        self.assertNotIn('a89:0',m['events'])


if __name__=='__main__':unittest.main()
