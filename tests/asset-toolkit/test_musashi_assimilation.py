"""Disc provenance, native release markers and absolute driver pitch ramps."""
import hashlib
import json
from pathlib import Path
import sys
import unittest
import wave

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from musashi_pitch import driver_pitch_notes
from asset_pipeline.glb import GLB


class MusashiAssimilation(unittest.TestCase):
    def test_absolute_two_stage_driver_curve(self):
        # Retail Homing hit0xA7D: curve800678A4, initial note0x3200.
        curve=[1,40,13312,40,17920,11264,90,40]
        notes=driver_pitch_notes(12800,curve,43)
        self.assertEqual(notes[:3],[12800,12840,12880])
        self.assertEqual(notes[13],13312)
        self.assertEqual(notes[14],13352)
        self.assertEqual(notes[40],14392)
        self.assertEqual(notes[41],14302)
        self.assertEqual(notes[42],14212)

    def test_source_events_geometry_and_audio(self):
        recovery=ROOT/'build/Other Files/Musashi Asset Recovery'
        assets=ROOT/'assets/characters/recovered_musashi/assimilation'
        report=json.loads((assets/'sources.json').read_text())
        for module,digest in report['sources'].items():
            source=recovery/f'raw/MAIN.CD.dir/FILE_{int(module):03}.dir/1.1'
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),digest)
        self.assertEqual(report['joint_frame_checks'],1426)
        self.assertLess(report['maximum_float32_transform_error'],.00001)
        visual=json.loads((recovery/'visual_manifest.json').read_text())
        source_models={m['id']:m for m in visual['models']}
        for name,tick in [('fence',2),('three_fire',2),('throw',5)]:
            self.assertEqual([e['tick'] for e in report['clips'][name]['events'] if e['word']=='0x7'],[tick])
        for name,count in [('dkick',96),('three_way',36),('homing',25),('grenade',18)]:
            glb=GLB.read(assets/(name+'.glb'))
            self.assertEqual(report['models'][name]['polygons'],count)
            self.assertFalse(any('UNRESOLVED' in m.get('name','') for m in glb.doc['materials']))
            entry=report['models'][name]
            occurrence=next(o for o in visual['model_occurrences'] if o['source']==f"raw/MAIN.CD.dir/FILE_{entry['module']:03}.dir/1.1" and o['offset']==entry['offset'])
            original=GLB.read(recovery/source_models[occurrence['model']]['path'])
            for old,new in zip(original.doc['meshes'][0]['primitives'],glb.doc['meshes'][0]['primitives']):
                self.assertEqual(old['attributes'].keys(),new['attributes'].keys())
                for attribute in old['attributes']:
                    self.assertEqual(original.accessor(old['attributes'][attribute]),glb.accessor(new['attributes'][attribute]))
            for mesh in glb.doc['meshes']:
                for primitive in mesh['primitives']:
                    self.assertEqual(glb.accessor(primitive['indices'])[:3],[(0,),(2,),(1,)])
        audio=ROOT/'assets/audio/recovered_musashi'
        clips=json.loads((audio/'assimilation_provenance.json').read_text())['clips']
        self.assertEqual(len(clips),8)
        self.assertEqual({c['sound_id'].lower() for c in clips},{'0x839','0x8ef','0x8f0','0x8e8','0xa7d','0x8f3','0x8e7','0xa64'})
        for clip in clips:
            path=audio/Path(clip['file']).name
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),clip['sha256'])
            with wave.open(str(path),'rb') as wav:
                self.assertEqual((wav.getnchannels(),wav.getsampwidth(),wav.getframerate()),(1,2,44100))


if __name__=='__main__':unittest.main()
