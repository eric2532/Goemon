"""Source bytes and every recovered rigid-pose sample must survive assembly."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest
import wave
import zlib

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from asset_pipeline.glb import GLB
from recover_skullpion import BASE,rotation

class SkullpionRecovery(unittest.TestCase):
 def test_prepared_castle_model_preserves_rom_geometry_colors_and_streams(self):
  old=GLB.read(ROOT/'assets/characters/recovered_skullpion/skullpion.glb')
  new=GLB.read(ROOT/'assets/models/enemies/skullpion.glb')
  self.assertEqual(len(new.doc['meshes']),22);self.assertEqual(len(new.doc['materials']),81)
  self.assertEqual(len(new.doc['animations']),27)
  for a,b in zip(old.doc['meshes'],new.doc['meshes']):
   self.assertEqual(len(a['primitives']),len(b['primitives']))
   for p,q in zip(a['primitives'],b['primitives']):
    material=new.doc['materials'][q['material']]
    self.assertIn('KHR_materials_unlit',material.get('extensions',{}))
    for key in ['POSITION','TEXCOORD_0']:
     if key in p['attributes']:self.assertEqual(old.accessor(p['attributes'][key]),new.accessor(q['attributes'][key]))
    source=old.accessor(p['attributes']['COLOR_0']);index=q['attributes']['COLOR_0'];colors=new.accessor(index)
    accessor=new.doc['accessors'][index]
    divisor={5121:255,5123:65535}[accessor['componentType']] if accessor.get('normalized') else 1
    for aa,bb in zip(source,colors):
     for x,y in zip(aa,bb):self.assertAlmostEqual(x,y/divisor,places=5)
  nodes={i:n['name'] for i,n in enumerate(old.doc['nodes'])}
  output_nodes={i:n['name'] for i,n in enumerate(new.doc['nodes'])}
  for animation in old.doc['animations']:
   copy=next(a for a in new.doc['animations'] if a['name']==animation['name'])
   self.assertEqual(len(animation['channels']),len(copy['channels']))
   for channel in animation['channels']:
    target=nodes[channel['target']['node']],channel['target']['path']
    other=next(c for c in copy['channels'] if (output_nodes[c['target']['node']],c['target']['path'])==target)
    a=animation['samplers'][channel['sampler']];b=copy['samplers'][other['sampler']]
    self.assertEqual(a['interpolation'],b['interpolation'])
    for key in ['input','output']:self.assertEqual(old.accessor(a[key]),new.accessor(b[key]))

 def test_source_geometry_textures_and_all_motion_samples(self):
  out=ROOT/'assets/characters/recovered_skullpion';r=ROOT/'build/Other Files/Musashi Asset Recovery'
  m=json.loads((out/'motion.json').read_text());g=GLB.read(out/'skullpion.glb');d=(r/m['source']).read_bytes()
  self.assertEqual(hashlib.sha256(d).hexdigest(),m['source_sha256'])
  self.assertEqual(len(m['parts']),22);self.assertEqual(len(g.doc['animations']),22)
  for part in m['parts']:
   source=GLB.read(r/part['source_glb']);node=g.doc['nodes'][part['node']]
   old=source.doc['meshes'][0]['primitives'];new=g.doc['meshes'][node['mesh']]['primitives']
   self.assertEqual(len(old),len(new))
   for a,b in zip(old,new):
    count=g.doc['accessors'][b['attributes']['POSITION']]['count']
    self.assertEqual(g.accessor(b['indices']),[(i+j,) for i in range(0,count,3) for j in (0,2,1)])
    self.assertEqual(a['attributes'].keys(),b['attributes'].keys())
    for key in a['attributes']:self.assertEqual(source.accessor(a['attributes'][key]),g.accessor(b['attributes'][key]))
    self.assertEqual(source.material_key(a['material']),g.material_key(b['material']))
  checks=0
  for clip,animation in zip(m['clips'],g.doc['animations']):
   stream=clip['streams'][0]
   for frame in stream['frames']:
    address=int(frame['pose'],16)
    for i,part in enumerate(m['parts']):
     raw=struct.unpack_from('<6h',d,address-BASE+i*12)
     expected={'translation':(raw[0],-raw[1],-raw[2]),'rotation':rotation(raw[3:])}
     for prop in expected:
      channel=next(c for c in animation['channels'] if c['target']=={'node':part['node'],'path':prop})
      sm=animation['samplers'][channel['sampler']];self.assertEqual(sm['interpolation'],'STEP')
      times=g.accessor(sm['input']);row=next(k for k,t in enumerate(times) if abs(t[0]-frame['tick']/30)<1e-5)
      actual=g.accessor(sm['output'])[row]
      for x,y in zip(actual,expected[prop]):self.assertAlmostEqual(x,y,places=5)
      checks+=1
  self.assertGreater(checks,17000)
  self.assertEqual(sum(c['streams'][0]['terminal']=='external_hold' for c in m['clips']),3)

 def test_drill_and_impact_use_original_parts_with_correct_outer_faces(self):
  out=ROOT/'assets/characters/recovered_skullpion';r=ROOT/'build/Other Files/Musashi Asset Recovery'
  for name,count,clips in [('drill',3,1),('impact',1,0)]:
   m=json.loads((out/(name+'_motion.json')).read_text());g=GLB.read(out/(name+'.glb'))
   self.assertEqual(len(m['parts']),count);self.assertEqual(len(g.doc.get('animations',[])),clips)
   for part in m['parts']:
    old=GLB.read(r/part['source_glb'])
    for a,b in zip(old.doc['meshes'][0]['primitives'],g.doc['meshes'][g.doc['nodes'][part['node']]['mesh']]['primitives']):
     for key in a['attributes']:self.assertEqual(old.accessor(a['attributes'][key]),g.accessor(b['attributes'][key]))
     self.assertEqual(g.accessor(b['indices'])[:3],[(0,),(2,),(1,)])
   if clips:self.assertEqual(m['clips'][0]['ticks'],20)

 def test_complete_original_sound_bank_and_playable_cues(self):
  out=ROOT/'assets/characters/recovered_skullpion/audio';r=ROOT/'build/Other Files/Musashi Asset Recovery'
  report=json.loads((out/'sources.json').read_text());owner=(r/report['owner']).read_bytes()
  self.assertEqual(hashlib.sha256(owner).hexdigest(),report['owner_sha256'])
  self.assertEqual(len(report['events']),57);self.assertEqual(len(report['bank_samples']),25)
  for sid,entry in report['events'].items():
   path=ROOT/entry['file'];self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),entry['sha256'])
   with wave.open(str(path),'rb') as wav:
    self.assertEqual((wav.getnchannels(),wav.getsampwidth(),wav.getframerate()),(1,2,44100));self.assertGreater(wav.getnframes(),100)
   for layer in entry['layers']:
    offset=int(layer['record_address'],16)-int(report['owner_base'],16)
    self.assertEqual(owner[offset:offset+20].hex(),layer['record_hex'])
  self.assertEqual(len(report['events']['55c']['layers']),2)
  self.assertEqual(len(report['events']['565']['layers']),3)
  catalog=ROOT/'build/Other Files/Asset Toolkit/Skullpion/Audio Catalog'
  for sample in report['bank_samples']:
   self.assertEqual((catalog/(sample['id']+'.vag')).read_bytes(),(r/'converted/audio/samples_vag'/(sample['id']+'.vag')).read_bytes())

 def test_original_vram_animation_pixels_and_volley(self):
  out=ROOT/'assets/characters/recovered_skullpion/effects';report=json.loads((out/'sources.json').read_text())
  for name,frames in [('sand',8),('dust',12),('volley',12)]:
   raw=(out/(name+'.png')).read_bytes();width,height=struct.unpack_from('>2I',raw,16)
   self.assertEqual(height,(128 if name=='sand' else 32)*frames)
   data=b'';offset=8
   while offset<len(raw):
    length,=struct.unpack_from('>I',raw,offset);kind=raw[offset+4:offset+8];payload=raw[offset+8:offset+8+length]
    self.assertEqual(zlib.crc32(kind+payload),struct.unpack_from('>I',raw,offset+8+length)[0])
    if kind==b'IDAT':data+=payload
    offset+=12+length
   scan=zlib.decompress(data);pixels=b''.join(scan[y*(width*4+1)+1:(y+1)*(width*4+1)] for y in range(height))
   expected=report['volley'] if name=='volley' else report['animations'][name]
   self.assertEqual(hashlib.sha256(pixels).hexdigest(),expected['rgba_sha256'])
  self.assertEqual(report['volley']['spread_source'],[0,512,-512])

if __name__=='__main__':unittest.main()
