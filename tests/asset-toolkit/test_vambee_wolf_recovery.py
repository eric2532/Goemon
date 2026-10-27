"""Verify recovered bytes, mixed pose formats, texture/material data and audio."""
import hashlib
from collections import Counter
import json
from pathlib import Path
import struct
import sys
import unittest
import wave

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from asset_pipeline.glb import GLB
from recover_vambee_wolf import BASE, WOLF, pose, rotation


class MonsterRecoveryTest(unittest.TestCase):
    def test_gorilla_keeps_its_original_arm_swing_and_contact_window(self):
        m=json.loads((ROOT/'assets/characters/recovered_monsters/haya_wolf_motion.json').read_text())
        data=(ROOT/'build/Other Files/Musashi Asset Recovery'/m['source']).read_bytes()
        self.assertEqual(m['source'],'raw/SC04.CD.dir/FILE_002.dir/0.4.dec')
        self.assertEqual(m['semantics']['attack'],'Source__801a1874')
        self.assertEqual(next(c['ticks'] for c in m['clips'] if c['name']==m['semantics']['attack']),40)
        self.assertEqual(struct.unpack_from('<2I',data,0x80181b24-BASE),(0x2462fff1,0x2c420006))
        self.assertEqual(struct.unpack_from('<I',data,0x80181b64-BASE)[0],0x24024012)

    def test_wolf_identity_follows_its_own_actor_and_mesh_list(self):
        data=(ROOT/'build/Other Files/Musashi Asset Recovery'/WOLF).read_bytes()
        m=json.loads((ROOT/'assets/characters/recovered_monsters/karate_wolf_motion.json').read_text())
        self.assertEqual(m['source'],WOLF)
        self.assertEqual((m['groups'][0]['list_address'],len(m['parts'])),('0x801a1134',13))
        self.assertEqual(struct.unpack_from('<I',data,0x8019db10-BASE)[0],0x801a1134)
        # 80182FF8..80183004 passes descriptor8019DB0C to the shared initializer.
        self.assertEqual(struct.unpack_from('<2I',data,0x80182ff8-BASE),(0x3c05801a,0x24a5db0c))
        self.assertEqual(m['semantics']['attack'],'Source__801a84d0')
        self.assertNotEqual(m['parts'][0]['source_tmd_sha256'],json.loads((ROOT/'assets/characters/recovered_monsters/haya_wolf_motion.json').read_text())['parts'][0]['source_tmd_sha256'])

    def test_editable_vambee_round_trip_preserves_oriented_geometry_and_pixels(self):
        def corners(g):
            result=Counter()
            for node in g.doc['nodes']:
                if 'mesh' not in node:continue
                for p in g.doc['meshes'][node['mesh']]['primitives']:
                    arrays={k:g.accessor(v) for k,v in p['attributes'].items()}
                    for semantic in arrays:
                        a=g.doc['accessors'][p['attributes'][semantic]]
                        if a.get('normalized'):
                            divisor={5121:255,5123:65535}[a['componentType']]
                            arrays[semantic]=[tuple(x/divisor for x in row) for row in arrays[semantic]]
                    indices=[row[0] for row in g.accessor(p['indices'])]
                    material=g.doc['materials'][p['material']].get('pbrMetallicRoughness',{})
                    tex=material.get('baseColorTexture');pixels=g.image_bytes(g.doc['images'][g.doc['textures'][tex['index']]['source']]) if tex else b''
                    for start in range(0,len(indices),3):
                        tri=[]
                        for index in indices[start:start+3]:
                            values=[]
                            for semantic in ['POSITION','NORMAL','TEXCOORD_0','COLOR_0']:
                                if semantic in arrays:
                                    row=arrays[semantic][index]
                                    if semantic=='COLOR_0':row=row[:3]
                                    values.append((semantic,tuple(round(x,4) for x in row)))
                            tri.append(tuple(values))
                        canonical=min(tuple(tri[i:]+tri[:i]) for i in range(3))
                        result[(node['name'],hashlib.sha256(pixels).hexdigest(),canonical)]+=1
            return result
        for name in ['vambee','karate_wolf','haya_wolf','dark_lumina_2']:
            source=GLB.read(ROOT/f'assets/characters/recovered_monsters/{name}.glb')
            edited=GLB.read(ROOT/f'assets/models/enemies/recovered_monsters/{name}.glb')
            self.assertEqual(corners(source),corners(edited))
            self.assertEqual([source.image_bytes(i) for i in source.doc['images']],
                             [edited.image_bytes(i) for i in edited.doc['images']])

    def test_all_parts_streams_and_pose_samples_preserve_disc_data(self):
        folder=ROOT/'assets/characters/recovered_monsters';recovery=ROOT/'build/Other Files/Musashi Asset Recovery'
        expected={'haya_wolf':(12,8),'karate_wolf':(13,8),'vambee':(10,19),'flying_vambee':(10,19),'vambee_torso':(6,4),'vambee_legs':(5,1),'flying_vambee_torso':(6,4),'flying_vambee_legs':(5,1)}
        mixed=0
        for name,(parts,clips) in expected.items():
            m=json.loads((folder/(name+'_motion.json')).read_text());g=GLB.read(folder/(name+'.glb'));data=(recovery/m['source']).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(),m['source_sha256'])
            self.assertEqual((len(m['parts']),len(g.doc['animations'])),(parts,clips))
            for part in m['parts']:
                original=GLB.read(recovery/part['source_glb']);merged=g.doc['meshes'][g.doc['nodes'][part['node']]['mesh']]
                for a,b in zip(original.doc['meshes'][0]['primitives'],merged['primitives']):
                    for key in a['attributes']:self.assertEqual(original.accessor(a['attributes'][key]),g.accessor(b['attributes'][key]))
                    self.assertEqual(original.material_key(a['material']),g.material_key(b['material']))
            for clip,animation in zip(m['clips'],g.doc['animations']):
                address=int(clip['address'],16);end=int(clip['frames'][-1]['command_address'],16)+16
                self.assertEqual(hashlib.sha256(data[address-BASE:end-BASE]).hexdigest(),clip['stream_sha256'])
                for index,frame in enumerate(clip['frames']):
                    self.assertEqual(pose(data,frame,parts),m['poses'][frame['pose']])
                    if not frame['packed']:mixed+=1
                    for part_index,part in enumerate(m['parts']):
                        sample=m['poses'][frame['pose']][part_index]
                        expected_trs={'translation':[sample['position'][0],-sample['position'][1],-sample['position'][2]],'rotation':rotation(sample['angles'])}
                        for prop,values in expected_trs.items():
                            channel=next(c for c in animation['channels'] if c['target']==dict(node=part['node'],path=prop));sampler=animation['samplers'][channel['sampler']]
                            self.assertEqual(sampler['interpolation'],'STEP')
                            for a,b in zip(values,g.accessor(sampler['output'])[index]):self.assertAlmostEqual(a,b,places=5)
        self.assertEqual(mixed,72)

    def test_source_confirmed_sounds_and_complete_retained_banks(self):
        recovery=ROOT/'build/Other Files/Musashi Asset Recovery'
        for name,ids in [('haya_wolf',['7e4:0','a9c:0']),('karate_wolf',['a9d:0','a9e:0']),('vambee',['a9b:2','cba:2'])]:
            m=json.loads((ROOT/'assets/characters/recovered_monsters/audio'/name/'sources.json').read_text())
            self.assertTrue(all(key in m['events'] for key in ids))
            self.assertEqual(hashlib.sha256((recovery/m['owner']).read_bytes()).hexdigest(),m['owner_sha256'])
            owner=(recovery/m['owner']).read_bytes();header=struct.unpack_from('<HHHHIHHIII',owner,len(owner)-28)
            column=struct.unpack_from('<h',owner,header[4]-0x800c7f08+(m['source_resource_level']-header[2])*2)[0]-1
            self.assertEqual(column,m['scene_column'])
            for entry in m['events'].values():
                path=ROOT/entry['file'];self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),entry['sha256'])
                with wave.open(str(path),'rb') as w:self.assertEqual((w.getnchannels(),w.getsampwidth(),w.getframerate()),(1,2,44100));self.assertGreater(w.getnframes(),100)
            for bank in m['retained_banks'].values():
                for sample in bank['samples']:
                    vag=ROOT/'build/Other Files/Asset Toolkit/Vambee and Haya Wolf/Audio Catalog'/name/(sample['id']+'.vag')
                    self.assertEqual(vag.read_bytes(),(recovery/'converted/audio/samples_vag'/(sample['id']+'.vag')).read_bytes())


if __name__=='__main__':unittest.main()
