"""Independently decode the original cave creatures and guardian skins and compare every prepared source frame."""
import json
import hashlib
import struct
import sys
import unittest
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
ARCHIVE=ROOT.parent/'Magic Power'
sys.path.insert(0,str(ARCHIVE/'tools'))
sys.path.insert(0,str(ROOT/'tools'))
import cg_assets as cg
import cg_sounds
from recover_habaru_encounter import body_rows
from recover_cursed_maze_encounters import prepare,SOURCE,NPC

class CursedSource(unittest.TestCase):
 def test_original_battle_reinforcement_growth_and_art(self):
  from recover_cursed_summon import recover,PROOF
  proof=recover(ARCHIVE)
  self.assertEqual(json.loads(PROOF.read_text()),proof)
  data=json.loads((ROOT/'assets/characters/crossgate/cursed_maze/spells/manifest.json').read_text())
  self.assertEqual(data['summon_factory_sha256'],hashlib.sha256(PROOF.read_bytes()).hexdigest())
  self.assertEqual(data['summon']['scales'],proof['cases'][0]['scales'])
  self.assertEqual(data['summon']['opacity'],proof['cases'][1]['rgba_alpha']/255)
  clip=data['clips'][proof['resource']];info=cg.metadata(proof['key'])
  self.assertEqual((clip['frames'],clip['duration']),(7,400))
  self.assertEqual((ROOT/clip['runtime_path'][6:]).read_bytes(),cg.png(cg.sheet_image(proof['key'],0,info=info)))

 def test_original_status_and_magic_seal_factories(self):
  from recover_cursed_effect_factories import recover,PROOF
  proof=recover(ARCHIVE)
  self.assertEqual(json.loads(PROOF.read_text()),proof)
  data=json.loads((ROOT/'assets/characters/crossgate/cursed_maze/spells/manifest.json').read_text())
  self.assertEqual(data['effect_factory_sha256'],hashlib.sha256(PROOF.read_bytes()).hexdigest())
  self.assertEqual(data['status_icons'],[str(row['resource']) for row in proof['cases'][:6]])
  self.assertEqual(data['death'],str(proof['death']['objects'][0]['resource']))
  for row in proof['cases']+proof['death']['objects']:
   ref=str(row['resource']);clip=data['clips'][ref];key=data['native_clips'][ref]['key']
   info=cg.metadata(key)
   self.assertEqual((clip['frames'],clip['duration'],clip['bounds']),(info['clips'][0]['frameCount'],info['clips'][0]['duration'],info['clips'][0]['bounds']))
   self.assertEqual((ROOT/clip['runtime_path'][6:]).read_bytes(),cg.png(cg.sheet_image(key,0,info=info)))

 def test_pinned_floor_rosters_and_guardian_coordinates(self):
  gd,proof=prepare(SOURCE,NPC,ARCHIVE)
  self.assertEqual((ROOT/'assets/maps/original_crossgate/maze_encounters.gd').read_text(),gd)
  self.assertEqual(json.loads((ROOT/'assets/maps/original_crossgate/maze-encounters.json').read_text()),proof)

 def test_guardian_skill_records_spell_bytes_and_reference_scale(self):
  folder=ROOT/'assets/characters/crossgate/cursed_maze/spells'
  data=json.loads((folder/'manifest.json').read_text())
  source=ARCHIVE/'research/cgmsv-20261031/source/gmsv/data'
  rows={r[0]:r for l in (source/'enemyai.txt').read_text(encoding='gb18030').splitlines() if (r:=l.split('\t'))[0].isdigit()}
  techniques=set()
  for profile in data['profiles']:
   row=rows[str(profile['ai'])];self.assertEqual(profile['raw'],'\t'.join(row))
   expected=[(int(row[21+i]),int(row[1+i] or 0),int(row[11+i] or 0),int(row[31+i])) for i in range(10) if row[21+i]]
   self.assertEqual([(r['tech'],r['condition'],r['target'],r['chance']) for r in profile['rules']],expected)
   techniques.update(r['tech'] for r in profile['rules'])
  self.assertEqual(len(techniques),42);self.assertEqual(len(data['profiles']),7)
  for record in list(data['clips'].values())+list(data['sounds'].values()):
   self.assertEqual(hashlib.sha256((ROOT/record['runtime_path'][6:]).read_bytes()).hexdigest(),record['sha256'])
  body=data['reference_body'];clip=next(c for c in cg.actor(body['key'])[2] if c['action']==body['action'] and c['direction']==body['direction'])
  first,last=body_rows(cg.frame_parts(body['key'],clip['index'],body['frame'])[0])
  self.assertEqual(data['reference_body_pixels'],last-first)
  print('CURSED_GUARDIAN_SOURCE seven profiles, 42 technique records, original sheet/audio hashes and source pixel scale verified')

 def test_original_creature_frames_origins_clocks_and_audio(self):
  folder=ROOT/'assets/characters/crossgate/cursed_maze'
  data=json.loads((folder/'motions.json').read_text());raw=(folder/'frames.bin').read_bytes()
  pages=[Image.open(folder/f'atlas-{i}.png').convert('L') for i in range(data['pages'])]
  palette=Image.open(folder/'palette.png').convert('RGBA')
  sound_manifest=json.loads((ARCHIVE/'godot/assets/sounds/manifest.json').read_text())['sounds']
  frames=0
  for skin,key in enumerate(['original:2840','original:2905','original:2980','original:2978','original:2979']):
   ident,_,clips_=cg.actor(key);self.assertEqual(ident,data['variants'][skin]['id'])
   clips={(c['action'],c['direction']):c for c in clips_}
   idle,_,oy=cg.frame_parts(key,clips[0,4]['index'],0);_,foot=body_rows(idle);shift=oy+foot-10
   for action_index,action in enumerate(data['actions']):
    for direction in range(8):
     clip=clips.get((action,direction),clips[0,direction]);row=(skin*len(data['actions'])+action_index)*8+direction
     start,count,duration,_=struct.unpack_from('<4f',raw,row*16)
     self.assertEqual(int(count),len(clip['frames']));self.assertAlmostEqual(duration,clip['duration']/1000,places=6)
     for frame in range(int(count)):
      at=(data['clip_count']+(int(start)+frame)*2)*16
      x,y,w,h=map(round,struct.unpack_from('<4f',raw,at));ox,py,page,pal=map(round,struct.unpack_from('<4f',raw,at+16))
      source,sx,sy=cg.frame_parts(key,clip['index'],frame);bounds=source.getbbox()
      source=source.crop(bounds);self.assertEqual((ox,py),(sx+bounds[0],sy+bounds[1]-shift))
      self.assertEqual(source.size,(w,h))
      colors=[palette.getpixel((i,pal)) for i in range(256)]
      decoded=bytes(v for i in pages[page].crop((x,y,x+w,y+h)).tobytes() for v in colors[i])
      expected=bytes(v for p in source.getdata() for v in (p if p[3] else (0,0,0,0)))
      self.assertEqual(decoded,expected,(key,action,direction,frame));frames+=1
     if action!=5:continue
     cues=cg_sounds.clip_cues(clip);offset=(skin*8+direction)*28
     contacts=sorted({c['id'] for c in cues if 10000<=c['flag']<20000})
     sounds=sorted({c['id'] for c in cues if not 10000<=c['flag']<20000})
     self.assertEqual(data['timelines'][offset:offset+2],[clip['duration']*.03,len(cues)])
     for i,cue in enumerate(cues):
      opcode=[135,138,164,165][contacts.index(cue['id'])] if 10000<=cue['flag']<20000 else [106,112,131,157][sounds.index(cue['id'])]
      self.assertEqual(data['timelines'][offset+2+i*2:offset+4+i*2],[cue['atMs']*.03,opcode])
      path=data['sounds'][f'{skin}:{opcode}'];prepared=ROOT/path[6:] if path.startswith('res://') else folder/path
      self.assertEqual(prepared.read_bytes(),(ARCHIVE/'godot/assets'/sound_manifest[str(cue['id'])]['file']).read_bytes())
  print('CURSED_CREATURE_SOURCE frames=',frames,'eight facings, source origins, contacts and original audio verified')

if __name__=='__main__':unittest.main()
