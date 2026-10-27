import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest
import wave
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from asset_pipeline.glb import GLB
from recover_vambee_wolf import streams, pose
from recover_dark_lumina_3 import BASE, SOURCE, RECOVERY, OUT
from recover_skullpion_effects import texture

class FinaleRecoveryTest(unittest.TestCase):
    def test_sprite_pixel_depth(self):
        vram=[0]*2048;present=bytearray([1])*2048
        vram[0]=0x2101;vram[1025]=0x1f;vram[1057]=0x7c00
        self.assertEqual(texture(vram,present,(0,0,1,1),64,8),bytes([255,0,0,255,0,0,255,255]))
        self.assertEqual(len(texture(vram,present,(0,0,1,1),64)),16)

    def test_finale_identity_and_all_source_poses(self):
        data=(RECOVERY/SOURCE).read_bytes();m=json.loads((OUT/'dark_lumina_3_motion.json').read_text())
        self.assertEqual(struct.unpack_from('<I',data)[0],0x73)
        self.assertEqual(m['source_sha256'],hashlib.sha256(data).hexdigest())
        self.assertEqual((len(m['parts']),len(m['clips'])),(17,16))
        for clip in m['clips']:
            for frame in clip['frames']:self.assertEqual(pose(data,frame,17,BASE),m['poses'][frame['pose']])
        idle=m['clips'][0]
        self.assertEqual((idle['source_terminal'],idle['ticks']),(-5,39))
        self.assertEqual(idle['frames'][19]['pose'],idle['frames'][20]['pose'])
        self.assertEqual(idle['frames'][1]['pose'],idle['frames'][-1]['pose'])

    def test_pingpong_parser_retains_variable_holds(self):
        data=struct.pack('<IhHIhHIhHIhH',32,2,0,44,3,0,56,1,0,0,-5,0)+bytes(36)
        clip=streams(data,0,32,0)[0]
        self.assertEqual([f['pose'] for f in clip['frames']],['0x20','0x2c','0x38','0x38','0x2c'])
        self.assertEqual([f['tick'] for f in clip['frames']],[0,2,5,6,7])
        self.assertEqual(clip['ticks'],10)

    def test_blender_round_trips_preserve_meshes_pixels_and_actions(self):
        for name in ['dark_lumina_3','dark_lumina_3_sky_copy','dark_lumina_3_effects']:
            source=GLB.read(OUT/(name+'.glb'));authored=GLB.read(ROOT/'assets/models/enemies/recovered_monsters'/(name+'.glb'))
            nodes={n['name']:n for n in authored.doc['nodes']}
            for node in source.doc['nodes']:
                if 'mesh' not in node:continue
                a=source.doc['meshes'][node['mesh']]['primitives'];b=authored.doc['meshes'][nodes[node['name']]['mesh']]['primitives']
                self.assertEqual(len(a),len(b))
                for left,right in zip(a,b):
                    for key,index in left['attributes'].items():self.assertEqual(source.accessor(index),authored.accessor(right['attributes'][key]))
                    self.assertEqual(source.accessor(left['indices']),authored.accessor(right['indices']))
                    self.assertEqual(len(left.get('targets',[])),len(right.get('targets',[])))
                    for lt,rt in zip(left.get('targets',[]),right.get('targets',[])):
                        self.assertEqual(source.accessor(lt['POSITION']),authored.accessor(rt['POSITION']))
                    self.assertEqual(source.material_key(left['material']),authored.material_key(right['material']))
            self.assertEqual([source.image_bytes(i) for i in source.doc.get('images',[])],[authored.image_bytes(i) for i in authored.doc.get('images',[])])
            self.assertEqual({a['name'] for a in source.doc['animations']},{a['name'] for a in authored.doc['animations']})

    def test_morph_source_endpoints(self):
        fx=GLB.read(OUT/'dark_lumina_3_effects.glb')
        m=fx.doc['meshes'][0]
        self.assertEqual(len(m['extras']['targetNames']),18)
        p=m['primitives'][0];v=fx.accessor(p['attributes']['POSITION'])[0]
        a=fx.accessor(p['targets'][0]['POSITION'])[0];b=fx.accessor(p['targets'][1]['POSITION'])[0]
        self.assertEqual(tuple(v[i]+a[i] for i in range(3)),(51,30,-7))
        self.assertEqual(tuple(v[i]+b[i] for i in range(3)),(131,60,-7))
        meta=json.loads((OUT/'dark_lumina_3_effects_motion.json').read_text())
        self.assertEqual(sum(len(m['names']) for m in meta['morphs'].values()),50)

    def test_effect_and_audio_catalogs_are_complete(self):
        fx=json.loads((OUT/'dark_lumina_3_effects/sources.json').read_text())
        self.assertEqual(sum(s['frames'] for s in fx['sprites'].values()),65)
        self.assertEqual(len(fx['meshes']),12)
        for sprite in fx['sprites'].values():self.assertTrue(all(sprite['visible_pixels']))
        self.assertEqual(fx['sprites']['fire']['palette_rows'],[0x59]*16)
        self.assertEqual(fx['sprites']['water']['hold_ticks'],2)
        self.assertEqual(fx['sprites']['sword_cross']['pixel_depth'],8)
        audio=json.loads((OUT/'audio/dark_lumina_3/sources.json').read_text())
        for cue in ['sword_wave','sword_cross','water_burst','fire_fall','sky_copy','sky_launch','earth_impact','fire_loop','wind_loop','core_charge','core_hit','defeat','ending','core_burst','core_loop','impact','cast','sword_swing','earth_rumble']:
            self.assertTrue((OUT/'audio/dark_lumina_3'/(cue+'.wav')).stat().st_size>44,cue)
        self.assertEqual(len(audio['bank_samples']),22)
        for path in (OUT/'audio/dark_lumina_3').glob('*.wav'):
            with wave.open(str(path)) as sample:
                self.assertGreater(sample.getnframes(),0,path.name)
                self.assertTrue(any(sample.readframes(sample.getnframes())),path.name)

    def test_wind_sequence_uses_its_own_table_and_loop_markers(self):
        from recover_dark_lumina_3_audio import wind_sample
        audio,source=wind_sample()
        self.assertEqual((source['dispatch'],source['descriptor'],source['sequence']),
                         ('050f0001','0x800c8c8c','0x800c8a00'))
        self.assertEqual((source['bank_slot'],source['lookup_index'],source['sample_index'],source['pitch_q8']),
                         (94,12,9,0x4a00))
        self.assertEqual((source['loop_begin'],source['loop_end']),(56,20888))
        target=OUT/'audio/dark_lumina_3'
        self.assertEqual(audio,(target/'wind_sustain.wav').read_bytes())
        self.assertEqual(source,json.loads((target/'wind_sustain_sources.json').read_text()))
        self.assertNotEqual(source['sample_id'],'sample_5dd8ae0842ec5422')
        self.assertEqual(hashlib.sha256((target/'wind_start.wav').read_bytes()).hexdigest(),
                         '2771f1cf1d9518dcb9311de198797cbdfb9e2214719699eae88b78f219ba0a44')

    def test_energy_rendering_and_earth_use_original_packets(self):
        meta=json.loads((OUT/'dark_lumina_3_effects_motion.json').read_text())
        for group,page in [('sword_wave',186),('cast_aura',41),('core_rays',59)]:
            part=next(p for p in meta['parts'] if p['group']==group)
            data=(RECOVERY/part['source_tmd']).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(),part['source_tmd_sha256'])
            primitive,count=struct.unpack_from('<II',data,28);offset=12+primitive
            for _ in range(count):
                _,words,_,mode=struct.unpack_from('<4B',data,offset)
                self.assertTrue(mode&2,group)
                tpage=struct.unpack_from('<H',data,offset+10)[0]
                self.assertEqual(tpage,page);self.assertEqual((tpage>>5)&3,1)
                offset+=4+words*4
        data=(RECOVERY/SOURCE).read_bytes()
        call=struct.unpack_from('<I',data,0x801a12c0-BASE)[0]
        self.assertEqual(call,0x0c000000|((0x801830d8>>2)&0x3ffffff))
        # Source burst initializer: additive flag, 0x300 scale, 24-tick lifetime.
        self.assertEqual(struct.unpack_from('<I',data,0x801ae66c-BASE)[0],0x3c035000)
        self.assertEqual(struct.unpack_from('<I',data,0x801ae694-BASE)[0],0x24020300)
        self.assertEqual(struct.unpack_from('<I',data,0x801ae6b0-BASE)[0],0x24020018)

    def test_original_cast_aura_palette_cycle(self):
        folder=OUT/'dark_lumina_3_effects'
        report=json.loads((folder/'cast_aura_cycle.json').read_text())
        for source,digest in report['source_sha256'].items():
            self.assertEqual(hashlib.sha256((RECOVERY/source).read_bytes()).hexdigest(),digest)
        image=Image.open(folder/'cast_aura_cycle.png').convert('RGBA')
        self.assertEqual(image.size,(256,1024))
        frames=[image.crop((0,i*256,256,(i+1)*256)).tobytes() for i in range(4)]
        self.assertEqual([hashlib.sha256(f).hexdigest() for f in frames],report['frame_rgba_sha256'])
        self.assertEqual(len(set(frames)),4)
        self.assertEqual((report['palette_rect'],report['rotation_entries'],report['fps']),([352,343,16,1],4,30))

if __name__=='__main__':unittest.main()
