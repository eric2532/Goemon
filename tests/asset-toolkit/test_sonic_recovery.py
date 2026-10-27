"""Focused recovery checks; run with the bundled Python (NumPy/Pillow)."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tools/sonic')]
from asset_pipeline.glb import GLB
from audio import adpcm, midi, event_wave

class SonicRecoveryTests(unittest.TestCase):
    def test_blue_effect_round_trip(self):
        from collections import Counter
        from PIL import Image
        import io
        folder=ROOT/'assets/characters/recovered_sonic'
        manifest=json.loads((folder/'effects_manifest.json').read_text())
        for name,count in [('effect_trail',12),('effect_ball',100)]:
            source=folder/(name+'.glb')
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),manifest['models'][name]['sha256'])
            a=GLB.read(source);b=GLB.read(ROOT/'assets/models/characters/sonic'/(name+'.glb'))
            def corners(g):
                values=[]
                for mesh in g.doc['meshes']:
                    for p in mesh['primitives']:
                        positions=g.accessor(p['attributes']['POSITION']);uvs=g.accessor(p['attributes']['TEXCOORD_0'])
                        values.extend(tuple(round(v,4) for v in positions[i]+uvs[i]) for row in g.accessor(p['indices']) for i in row)
                return Counter(values)
            self.assertEqual(sum(corners(a).values()),count*3)
            self.assertEqual(corners(a),corners(b))
            def pixels(g):
                mat=g.doc['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']
                im=g.doc['images'][g.doc['textures'][mat]['source']]
                image=Image.open(io.BytesIO(g.image_bytes(im))).convert('RGBA')
                return image.size,image.tobytes()
            self.assertEqual(pixels(a),pixels(b))

    def test_dsp_known_predictor_and_truncation(self):
        block=bytes([0,0x17,0x8f,0,0,0,0,0])
        self.assertEqual(adpcm(block,[0]*16,4),[1,7,-8,-1])
        with self.assertRaises(AssertionError):adpcm(block[:4],[0]*16,4)

    def test_midi_running_status(self):
        track=bytes.fromhex('00c00500903c7f603c0000ff2f00')
        data=b'MThd'+struct.pack('>IHHH',6,0,1,480)+b'MTrk'+struct.pack('>I',len(track))+track
        self.assertEqual(midi(data)['events'],[[0,192,5],[0,144,60,127],[96,144,60,0]])

    def test_recovered_asset_integrity(self):
        folder=ROOT/'assets/characters/recovered_sonic'
        manifest=json.loads((folder/'source_manifest.json').read_text())
        for name,entry in manifest['models'].items():
            path=folder/(name+'.glb')
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),entry['sha256'])
            model=GLB.read(path)
            triangles=sum(len(model.accessor(p['indices']))//3 for m in model.doc['meshes'] for p in m['primitives'])
            self.assertEqual(triangles,entry['triangles'])
            self.assertEqual(len(model.doc['animations']),len(entry['clips']))
            self.assertTrue(all(len(model.image_bytes(im))>0 for im in model.doc['images']))
        self.assertEqual(manifest['models']['sonic']['triangles'],1993)
        self.assertEqual(len(manifest['models']['sonic']['clips']),73)

    def test_source_tables_and_pitch(self):
        native=json.loads((ROOT/'assets/characters/recovered_sonic/native_tables.json').read_text())
        self.assertAlmostEqual(native['physics']['run_accel'],.05,places=6)
        self.assertAlmostEqual(native['physics']['weight'],.08,places=6)
        self.assertEqual(native['animations'][0]['clip'],'Sonic Stand')
        self.assertEqual(native['animations'][0]['rate'],.5)
        self.assertEqual(native['clip_frames']['Sonic Run'],32)
        audio=json.loads((ROOT/'assets/audio/recovered_sonic/source_manifest.json').read_text())
        self.assertEqual(audio['sonic']['events']['homing']['rate'],22050)
        self.assertEqual(audio['sonic']['events']['dash']['rate'],22050)

    def test_native_audio_pitch_and_waveform_preservation(self):
        import wave
        folder=ROOT/'assets/audio/recovered_sonic'
        manifest=json.loads((folder/'source_manifest.json').read_text())
        for group in ['sonic','voice','common']:
            for name,event in manifest[group]['events'].items():
                self.assertEqual(event['note'],48)
                self.assertEqual(event['delay_samples'],0)
                self.assertLessEqual(abs(event['rate']-event['native_rate']),.5)
                with wave.open(str(folder/(name+'.wav'))) as wav:
                    self.assertEqual(wav.getframerate(),event['rate'])
                    pcm=wav.readframes(wav.getnframes())
                sample=manifest[group]['samples'][event['sample']]
                if 'file' in sample:
                    with wave.open(str(folder/sample['file'])) as raw:self.assertEqual(pcm,raw.readframes(raw.getnframes()))
        # Expected SRC values from the supplied GCAX routine, not the unused sequence note.
        for name in ['wall_voice','damage_voice','jump_voice_1','jump_voice_2']:
            self.assertEqual(manifest['voice']['events'][name]['src_ratio'],33647)
            self.assertEqual(manifest['voice']['events'][name]['rate'],16429)
        self.assertEqual(manifest['sonic']['events']['charge']['src_ratio'],45158)
        sample={'rate':32859,'pcm':[0,123,-456],'loop_start':0,'end':3}
        programs=[[{'splits':[{'sample':0,'base_note':66,'fine_tune':116,'envelope':[31,0,0,0,31,0]}]}]]
        pcm,event=event_wave([sample],programs,{'division':480,'events':[[0,'tempo',500000],[2,192,0],[5,144,60,127]]})
        self.assertEqual(pcm,sample['pcm'])
        self.assertEqual(event['rate'],16429)
        self.assertEqual(event['note_seconds'],0)
        self.assertAlmostEqual(event['sequence_note_seconds'],5/960)

    def test_prepared_welds_preserve_uvs_faces_and_motion(self):
        prepared=ROOT/'build/Other Files/Asset Toolkit/Sonic/Research/sonic-prepared.glb'
        if not prepared.exists():self.skipTest('Run tools/sonic/prepare.py with the supplied disc first')
        a=GLB.read(ROOT/'assets/characters/recovered_sonic/sonic.glb');b=GLB.read(prepared)
        self.assertEqual(a.animation_digest(),b.animation_digest())
        self.assertEqual([a.image_bytes(im) for im in a.doc['images']],[b.image_bytes(im) for im in b.doc['images']])
        moved=0
        for node_id,node in enumerate(a.doc['nodes']):
            if 'mesh' not in node:continue
            for src,dst in zip(a.doc['meshes'][node['mesh']]['primitives'],b.doc['meshes'][node['mesh']]['primitives']):
                self.assertEqual(a.accessor(src['indices']),b.accessor(dst['indices']))
                self.assertEqual(a.accessor(src['attributes']['TEXCOORD_0']),b.accessor(dst['attributes']['TEXCOORD_0']))
                joints=b.accessor(dst['attributes']['JOINTS_0'])
                moved+=sum(j[0]!=node_id for j in joints)
                self.assertTrue(all(w==(1.,0.,0.,0.) for w in b.accessor(dst['attributes']['WEIGHTS_0'])))
        self.assertGreater(moved,68) # Repeated triangle corners share the same 68 source weld vertices.

if __name__=='__main__':unittest.main()
