"""Native bank recovery preserves original pixels, origins, clocks, cues and audio."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import unittest

from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_assets as cg
import cg_sounds
from prepare_sokia_population import prepare,ARCHIVE
from recover_habaru_encounter import body_rows
BANK=ROOT/'assets/characters/crossgate/sokia_region'


class DecodedBank:
 def __init__(self,path):
  self.path=path;self.manifest=json.loads((path/'motions.json').read_text())
  rows=list(struct.iter_unpack('<4f',(path/'frames.bin').read_bytes()))
  self.clips=rows[:self.manifest['clip_count']];self.frames=rows[self.manifest['clip_count']:]
  paths=self.manifest.get('atlas_paths',[f'atlas-{i}.png'for i in range(self.manifest['pages'])])
  self.pages=[Image.open(ROOT/p.removeprefix('res://')if p.startswith('res://')else path/p).convert('L')for p in paths]
  palette=Image.open(path/'palette.png').convert('RGBA')
  self.palettes=[[palette.getpixel((x,y))for x in range(256)]for y in range(palette.height)]
  self.hashes={}
 def frame(self,index):
  rect,other=self.frames[index*2:index*2+2]
  x,y,w,h=map(int,rect);ox,oy,page,palette=map(int,other)
  key=(x,y,w,h,page,palette)
  if key not in self.hashes:
   image=self.pages[page].crop((x,y,x+w,y+h));colors=self.palettes[palette]
   rgba=Image.merge('RGBA',[image.point([c[channel]for c in colors])for channel in range(4)])
   self.hashes[key]=hashlib.sha256(rgba.tobytes()).hexdigest()
  return (w,h,ox,oy,self.hashes[key])


def verify_preserved(before,after):
 old=DecodedBank(before);new=DecodedBank(after)
 assert new.manifest['variants'][:len(old.manifest['variants'])]==old.manifest['variants']
 assert new.manifest['actions']==old.manifest['actions']
 old_stride=len(old.manifest['timelines'])//len(old.manifest['variants'])//8
 new_stride=len(new.manifest['timelines'])//len(new.manifest['variants'])//8
 for row in range(len(old.manifest['variants'])*8):
  assert new.manifest['timelines'][row*new_stride:row*new_stride+old_stride]==old.manifest['timelines'][row*old_stride:(row+1)*old_stride]
 count=0
 for a,b in zip(old.clips,new.clips):
  assert a==b
  for frame in range(int(a[0]),int(a[0]+a[1])):
   assert old.frame(frame)==new.frame(frame)
   count+=1
 for key,name in old.manifest['sounds'].items():
  assert new.manifest['sounds'][key]==name
  a=ROOT/name.removeprefix('res://')if name.startswith('res://')else old.path/name
  b=ROOT/name.removeprefix('res://')if name.startswith('res://')else new.path/name
  assert a.read_bytes()==b.read_bytes()
 return count


def verify_source(path,species=None,skin_offset=0):
 bank=DecodedBank(path)
 if species is None:
  _,data=prepare();species=data['extra_species'][:13]
 assert [r['id']for r in bank.manifest['variants'][skin_offset:skin_offset+len(species)]]==[r['id']for r in species]
 audio=json.loads((ARCHIVE/'godot/assets/sounds/manifest.json').read_text())['sounds']
 stride=len(bank.manifest['timelines'])//len(bank.manifest['variants'])//8
 assert stride in (32,42)
 frames=0;clips_checked=0;cues_checked=0
 for skin,record in enumerate(species,start=skin_offset):
  ident,_,clips=cg.actor(record['key']);assert ident==record['id']
  action_sources=record.get('native_action_sources',{})
  assert bank.manifest['variants'][skin].get('native_action_sources',{})==action_sources
  clips={(c['action'],c['direction']):c for c in clips}
  idle=clips[0,4];image,_,y=cg.frame_parts(record['key'],idle['index'],0)
  top,foot=body_rows(image);shift=y+foot-10
  for action_index,action in enumerate(bank.manifest['actions']):
   for direction in range(8):
    source=clips[action_sources.get(str(action),action),direction];packed=bank.clips[(skin*len(bank.manifest['actions'])+action_index)*8+direction]
    start,count,duration,scale=packed
    assert count==len(source['frames']) and abs(duration-source['duration']/1000)<1e-6
    assert abs(scale-bank.manifest['variants'][skin]['standing_height']/(foot-top))<1e-7
    clips_checked+=1
    for index in range(int(count)):
     image,x,y=cg.frame_parts(record['key'],source['index'],index);box=image.getbbox();assert box
     expected=(box[2]-box[0],box[3]-box[1],x+box[0],y+box[1]-shift,hashlib.sha256(image.crop(box).tobytes()).hexdigest())
     assert bank.frame(int(start)+index)==expected,(record['id'],action,direction,index)
     frames+=1
    if action!=5:continue
    cues=cg_sounds.clip_cues(source)
    contacts=sorted({c['id']for c in cues if 10000<=c['flag']<20000})
    sounds=sorted({c['id']for c in cues if not 10000<=c['flag']<20000})
    row=bank.manifest['timelines'][(skin*8+direction)*stride:(skin*8+direction+1)*stride]
    assert row[:2]==[source['duration']*.03,len(cues)]
    for index,cue in enumerate(cues):
     opcode=[135,138,164,165][contacts.index(cue['id'])]if 10000<=cue['flag']<20000 else [106,112,131,157][sounds.index(cue['id'])]
     assert row[2+index*2:4+index*2]==[cue['atMs']*.03,opcode]
     target=bank.manifest['sounds'][f'{skin}:{opcode}']
     actual=ROOT/target.removeprefix('res://')if target.startswith('res://')else path/target
     assert actual.read_bytes()==(ARCHIVE/'godot/assets'/audio[str(cue['id'])]['file']).read_bytes()
     cues_checked+=1
 return dict(actors=len(species),clips=clips_checked,frames=frames,cues=cues_checked)


class BloodDemonSource(unittest.TestCase):
 def test_original_thirteen_source_prefix(self):
  result=verify_source(BANK)
  self.assertEqual(result['actors'],13);self.assertEqual(result['clips'],728)
  self.assertGreater(result['frames'],3000);self.assertGreater(result['cues'],100)
 def test_measured_family_fit_and_no_unverified_encounter_activation(self):
  _,data=prepare();blood=next(s for s in data['extra_species']if s['id']==101211)
  self.assertEqual((blood['id'],blood['key'],blood['source_body_pixels']),(101211,'original:2843',113))
  self.assertEqual(blood['source_scale_reference'],{'key':'ex:1727','body_pixels':84})
  self.assertAlmostEqual(blood['height'],113/84)
  index=data['base_species_count']+blood['skin']
  self.assertFalse(any(m[0]==index for g in data['groups'].values()for m in g['members']))
 def test_scripted_asset_identities_and_measured_fits_remain_unplaced(self):
  _,data=prepare();wanted={101613:('original:2920',62,8),101214:('original:2846',147,9),101921:('original:2973',132,10)}
  for appearance,(key,pixels,skin)in wanted.items():
   row=next(s for s in data['extra_species']if s['id']==appearance)
   self.assertEqual((row['key'],row['source_body_pixels'],row['skin']),(key,pixels,skin))
   self.assertAlmostEqual(row['height'],pixels/84)
   index=data['base_species_count']+skin
   self.assertFalse(any(m[0]==index for g in data['groups'].values()for m in g['members']))
 def test_wolf_source_and_coherent_ghost_source_keep_existing_fits(self):
  _,data=prepare()
  expected={101031:('original:2819',11,83*1.4/78),101121:('original:2833',12,1.15)}
  for appearance,(key,skin,height)in expected.items():
   row=next(s for s in data['extra_species']if s['id']==appearance)
   self.assertEqual((row['key'],row['skin']),(key,skin));self.assertAlmostEqual(row['height'],height)
  ghost=next(s for s in data['extra_species']if s['id']==101121)
  self.assertEqual(ghost['native_action_sources'],{'3':1})
  _,_,clips=cg.actor(ghost['key'])
  raw_run=[c for c in clips if c['action']==3]
  self.assertEqual(len(raw_run),8)
  for clip in raw_run:
   self.assertEqual(len(clip['frames']),1)
   self.assertIsNone(cg.frame_parts(ghost['key'],clip['index'],0)[0].getbbox())


if __name__=='__main__':unittest.main()
