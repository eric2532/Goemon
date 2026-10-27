import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest
import wave
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from recover_dark_lumina import BASE,SOURCE
from recover_vambee_wolf import pose
from recover_dark_lumina_audio import sequence

class DarkLuminaRecovery(unittest.TestCase):
 def test_all_source_poses_and_stream_bytes(self):
  root=ROOT/'assets/characters/recovered_monsters';m=json.loads((root/'dark_lumina_2_motion.json').read_text())
  raw=(ROOT/'build/Other Files/Musashi Asset Recovery'/SOURCE).read_bytes()
  self.assertEqual(struct.unpack_from('<I',raw)[0],0x72);self.assertEqual(len(m['parts']),19);self.assertEqual(len(m['clips']),21)
  self.assertEqual(m['source_sha256'],hashlib.sha256(raw).hexdigest())
  for clip in m['clips']:
   for frame in clip['frames']:self.assertEqual(pose(raw,frame,19,BASE),m['poses'][frame['pose']])
   start=int(clip['address'],16);end=start
   while struct.unpack_from('<h',raw,end-BASE+4)[0]>=0:end+=8
   end+=8
   self.assertEqual(hashlib.sha256(raw[start-BASE:end-BASE]).hexdigest(),clip['stream_sha256'])
 def test_complete_battle_audio_and_sequence_delays(self):
  folder=ROOT/'assets/characters/recovered_monsters/audio/dark_lumina_2';m=json.loads((folder/'sources.json').read_text())
  self.assertEqual(len(m['samples']),18);self.assertEqual(len(m['events']),22)
  for name,event in m['events'].items():
   if event.get('control_only'):continue
   p=folder/(name+'.wav');self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),event['sha256'])
   with wave.open(str(p),'rb') as w:self.assertEqual(w.getframerate(),44100);self.assertGreater(w.getnframes(),100)
  self.assertEqual([n['tick'] for n in m['events']['death']['notes']],[0,43,93])
  self.assertEqual([n['tick'] for n in m['events']['recover']['notes']],[0,98])
  self.assertEqual((m['events']['fire_charge']['notes'][0]['gain'],m['events']['fire_charge']['notes'][0]['ramp']),(0,436))
 def test_effect_streams_and_editable_exports(self):
  folder=ROOT/'assets/characters/recovered_monsters/dark_lumina_2_effects';m=json.loads((folder/'sources.json').read_text())
  raw=(ROOT/'build/Other Files/Musashi Asset Recovery'/SOURCE).read_bytes()
  for address,command in [(0x801f2260,0x3a),(0x801f2900,0x2a)]:
   self.assertEqual(raw[address-BASE+43],command);self.assertTrue(command&2)
  self.assertEqual(sum(x['frames'] for x in m['sprites'].values()),48)
  for name,entry in m['meshes'].items():
   source=folder/(name+'.glb');authored=ROOT/'assets/models/enemies/recovered_monsters/dark_lumina_2_effects'/(name+'.glb')
   self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),entry['sha256']);self.assertEqual(source.read_bytes(),authored.read_bytes())
 def test_spin_and_walk_dispatch_and_original_floor_tiles(self):
  folder=ROOT/'assets/characters/recovered_monsters/dark_lumina_2_effects'
  m=json.loads((folder/'spin_sources.json').read_text())
  recovery=ROOT/'build/Other Files/Musashi Asset Recovery'
  raw=(recovery/m['module']).read_bytes();overlay=(recovery/m['overlay']).read_bytes()
  self.assertEqual(hashlib.sha256(raw).hexdigest(),m['module_sha256'])
  self.assertEqual(hashlib.sha256(overlay).hexdigest(),m['overlay_sha256'])
  for address,value in m['instructions'].items():self.assertEqual(struct.unpack_from('<I',raw,int(address,16)-BASE)[0],int(value,16))
  self.assertEqual(struct.unpack_from('<I',overlay,0x80190f40+0x376*4-0x80128158)[0],0x80183a70)
  self.assertEqual(struct.unpack_from('>II',(folder/'spin_debris.png').read_bytes(),16),(32,1024))
  self.assertEqual(m['walk']['ticks'],[15,53]);self.assertEqual(m['spin']['active_ticks'],[7,25])
  sounds=json.loads((folder.parent/'audio/dark_lumina_2/sources.json').read_text())['events']
  self.assertEqual(sounds['step']['id'],'0xb53');self.assertEqual(sounds['hurt']['id'],'0xb56')
 def test_sequence_decoder_rejects_unknown_commands(self):
  with self.assertRaises(ValueError):sequence(lambda address,count:bytes.fromhex('000000ff'),0)

if __name__=='__main__':unittest.main()
