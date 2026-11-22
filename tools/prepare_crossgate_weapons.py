"""Prepare verified native weapon sprites; preserve existing authored/default sets."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from PIL import Image
from recover_crossgate_kazi import pack_frames
from prepare_crossgate_kazi_attack import packed_frame
from recover_crossgate_special_skins import SKINS as SPECIAL_SKINS, CAST_SKINS

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/characters/crossgate'
OUT=ART/'weapons'
LABELS={'斧':'axe','弓':'bow','空手':'unarmed','劍':'sword','杖':'staff','槍':'polearm'}
REVIEWED=dict(zip([105836,105737,105738,105739,105740,105741,106174,106181,106182,106183,106184,106185],list(LABELS.values())*2))
REVIEWED.update(dict(zip([106234,106235,106236,106237,106239,106240],LABELS.values())))
REVIEWED[111619]='unarmed'
ACTIONS=(0,1,3,5,6,8,9,10)

def prepare(source,check=False,kaz_only=False):
 sys.path.insert(0,str(source/'tools'))
 import cg_assets as cg
 import cg_sounds
 import cg_library
 skins=json.loads((source/'godot/assets/exploration/skins.json').read_text())['skins']
 families={m['id']:skin for skin in skins for m in skin['members']}
 shin=json.loads((ART/'shin/skins.json').read_text())
 roster={34:[ART/'kazi/motions.json']+sorted((ART/'kazi/skins').glob('*/motions.json')),
  35:[ART/'ruby/motions.json']+sorted((ART/'ruby').glob('*/motions.json')),36:[ART/'maze/motions.json'],
  37:[ART/f'shin/{s[0]}/motions.json' for s in shin if not s[3]]+[ART/root/str(skin)/'motions.json' for char,root,skin,*_ in SPECIAL_SKINS if char==37],
  38:[ART/f'shin/{s[0]}/motions.json' for s in shin if s[3]]+[ART/root/str(skin)/'motions.json' for char,root,skin,*_ in CAST_SKINS if char==38],
  39:sorted((ART/'fighters/saizo').glob('*/motions.json')),
  40:sorted((ART/'fighters/bog').glob('*/motions.json')),
  42:sorted((ART/'fighters/emilia').glob('*/motions.json')),
  43:sorted((ART/'fighters/lancelot').glob('*/motions.json')),
  44:sorted((ART/'fighters/pete').glob('*/motions.json')),
  45:sorted((ART/'fighters/grace').glob('*/motions.json')),
  46:sorted((ART/'fighters/rei').glob('*/motions.json')),
  47:sorted((ART/'fighters/cedi').glob('*/motions.json')),
  48:sorted((ART/'fighters/bei').glob('*/motions.json')),
  49:sorted((ART/'fighters/moe').glob('*/motions.json')),
  50:sorted((ART/'fighters/ami').glob('*/motions.json')),
  51:sorted((ART/'fighters/kumago').glob('*/motions.json'))}
 if kaz_only:roster={34:roster[34]}
 catalog={};needed={};audio={}
 for character,paths in roster.items():
  catalog[str(character)]={}
  for path in paths:
   data=json.loads(path.read_text());ident=cg.actor(data['key'])[0]
   family=families.get(ident,{'members':[]})
   candidates={} if 'source_weapons' in data else {REVIEWED.get(m['id'],LABELS.get(m['label'])):m['key'] for m in family['members']}
   candidates.pop(None,None)
   # Effect skins retain their prepared weapon art, not a plain sibling's outfit.
   if (character==34 and len(family['members'])!=6) or (character==38 and int(data['id']) not in (100053,100055,120440)):candidates={}
   if character==34 and int(data['id'])==105608:
    # Several unrelated outfits reuse ID 105608. These are the matching red/black poses.
    candidates=dict(zip(LABELS.values(),(f'joy-ex:{i}' for i in range(418,424))))
   if character==38 and int(data['id'])==120440:
    # Nonconsecutive custom records: idle/attack art and native cues agree.
    candidates={'axe':'ch1:658','bow':'ch1:659','sword':'ch1:660','staff':'ch1:661','polearm':'ch1:662'}
   native={}
   if character in (36,39):native={'sword':0,'kunai':1,'unarmed':2}
   elif character==34:native={'sword':0}
   elif character in (35,42):native={'staff':0}
   elif character==43:native={'bow':0}
   else:
    for index,stance in enumerate([data]+data.get('weapons',[])):
     weapon=stance.get('weapon','sword')
     if weapon=='fixed':weapon='polearm' if int(stance.get('source_id',0)) in (100055,108313) else 'unarmed' if int(stance.get('source_id',0))==118986 else 'sword'
     native[weapon]=index
   if character==38 and int(data['id'])==120440:native={'sword':0}
   if 'source_weapons' in data:native={s['weapon']:i for i,s in enumerate([data]+data.get('weapons',[]))}
   routes={weapon:{'native':index} for weapon,index in native.items()}
   routes.update(data.get('prepared_weapons',{}))
   for weapon,key in candidates.items():
    if weapon in routes:continue
    root='res://assets/characters/crossgate/weapons/'+key.replace(':','-')+'/'
    routes[weapon]={'root':root};needed[key]=weapon
    if character==38 and int(data['id'])==120440 and weapon=='staff':routes[weapon]['native']=1
   skin=0 if character==36 or (character==35 and 'source_weapons' not in data) else int(data['id'])
   catalog[str(character)][str(skin)]=routes
 assert len(catalog)==len(roster) and catalog['34']['102488']=={'sword':{'native':0}}
 OUT.mkdir(exist_ok=True)
 existing={}
 for path in (ROOT/'assets/audio/crossgate').rglob('*.wav'):existing.setdefault(path.name.lower(),[]).append(path)
 frames_checked=0
 for number,(key,weapon) in enumerate(sorted(needed.items()),1):
  folder=OUT/key.replace(':','-');ident,pack,source_clips=cg.actor(key)
  original={(c['action'],c['direction']):c for c in source_clips if c['frames']}
  assert all((action,direction)in original for action in ACTIONS for direction in range(8)),key
  if check:
   data=json.loads((folder/'motions.json').read_text())
   assert data['key']==key and data['source_id']==ident and data['weapon']==weapon,key
   atlases=[Image.open(folder/f'atlas-{i}.png').convert('RGBA') for i in range(data['pages'])]
   for pose,c in original.items():
    if pose[0] not in ACTIONS:continue
    saved=data['clips'][f'{pose[0]}:{pose[1]}']
    assert saved['source_frames']==[list(f) for f in c['frames']] and saved['duration']==c['duration']/1000,(key,pose)
    assert len(saved['frames'])==len(c['frames']),(key,pose)
    if pose[0]==5:
     cues=cg_sounds.clip_cues(c);contacts=[cue for cue in cues if cue['flag']>=10000];swings=[cue for cue in cues if cue['flag']<10000]
     assert saved['contacts']==[cue['atMs']/1000 for cue in contacts] and saved['contact_cues']==[cue['id'] for cue in contacts] and saved['sounds']==swings,(key,pose)
     assert saved['contact']==contacts[0]['frame']/len(c['frames']),(key,pose)
     if weapon=='bow':assert saved['release']==contacts[0]['atMs']/1000 and saved['draw']==(swings[0]['atMs']/1000 if swings else 0.0),(key,pose)
    for i,f in enumerate(saved['frames']):
     im,x,y=cg.frame_parts(key,c['index'],i);box=im.getbbox();page,left,top,w,h,ox,oy=f
     assert atlases[page].crop((left,top,left+w,top+h)).tobytes()==im.crop(box).tobytes(),(key,pose,i)
     assert (ox,oy)==(x+box[0],y+box[1]),(key,pose,i)
     frames_checked+=1
   continue
  folder.mkdir(exist_ok=True);unique={};clips={};sounds={}
  for (action,direction),c in original.items():
   if action not in ACTIONS:continue
   frames=[packed_frame(*cg.frame_parts(key,c['index'],i),unique) for i in range(len(c['frames']))]
   assert all(f is not None for f in frames),(key,action,direction)
   clip={'duration':c['duration']/1000,'frames':frames,'source_clip':c['index'],'source_frames':c['frames']}
   if action==5:
    cues=cg_sounds.clip_cues(c)
    contacts=[cue for cue in cues if cue['flag']>=10000]
    swings=[cue for cue in cues if cue['flag']<10000]
    assert contacts,(key,direction)
    clip.update(contacts=[cue['atMs']/1000 for cue in contacts],contact_cues=[cue['id'] for cue in contacts],sounds=swings,
     contact=contacts[0]['frame']/len(frames),swing=swings[0]['frame']/len(frames) if swings else max(0,contacts[0]['frame']-1)/len(frames))
    if weapon=='bow':clip.update(draw=swings[0]['atMs']/1000 if swings else 0.0,release=contacts[0]['atMs']/1000)
    for cue in cues:
     sound_id=str(cue['id'])
     if sound_id not in audio:
      filename=Path(cue['file']).name;raw=(cg.SOURCE/'se'/filename).read_bytes();digest=hashlib.sha256(raw).hexdigest()
      found=next((p for p in existing.get(filename.lower(),[])if hashlib.sha256(p.read_bytes()).hexdigest()==digest),None)
      if found is None:
       found=OUT/'audio'/filename;found.parent.mkdir(exist_ok=True);found.write_bytes(raw)
      audio[sound_id]={'file':'res://'+str(found.relative_to(ROOT)),'sha256':digest}
     sounds[sound_id]=audio[sound_id]['file']
   clips[f'{action}:{direction}']=clip
  pages=pack_frames(clips,unique,folder)
  data={'key':key,'source_id':ident,'weapon':weapon,'pages':pages,'clips':clips,'audio':sounds}
  (folder/'motions.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
  print(f'{number}/{len(needed)} {key} {weapon}: {len(clips)} clips, {pages} pages',flush=True)
 if not check:
  if kaz_only:
   catalog_path=OUT/'catalog.json'
   published=json.loads(catalog_path.read_text())|catalog
   audio=audio|json.loads((OUT/'audio.json').read_text())
  else:published=catalog
  (OUT/'catalog.json').write_text(json.dumps(published,indent=2)+'\n')
  (OUT/'audio.json').write_text(json.dumps(audio,indent=2)+'\n')
  # Reuse the original inventory staff, cropped only at transparent margins.
  if not kaz_only:
   im=cg_library.image_from_record('original',13800)
   im.crop(im.getbbox()).save(ROOT/'assets/ui/crossgate/weapons/staff.png')
 else:
  published=json.loads((OUT/'catalog.json').read_text())
  assert ({'34':published['34']} if kaz_only else published)==catalog
  for sound in json.loads((OUT/'audio.json').read_text()).values():
   assert hashlib.sha256((ROOT/sound['file'].removeprefix('res://')).read_bytes()).hexdigest()==sound['sha256']
 print(f'WEAPONS {"CHECK" if check else "PREPARE"}: {sum(map(len,catalog.values()))} appearances, {len(needed)} new source sets, {frames_checked} exact frame/origin checks',flush=True)
 if not check:
  images=(image for key in needed for image in (OUT/key.replace(':','-')).glob('*.png')) if kaz_only else list(OUT.rglob('*.png'))+[ROOT/'assets/ui/crossgate/weapons/staff.png']
  for image in images:
   settings=image.with_suffix('.png.import')
   if settings.exists():settings.write_text(settings.read_text().replace('process/fix_alpha_border=false','process/fix_alpha_border=true'))
   else:settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://'+str(image.relative_to(ROOT))+'"\n[params]\ncompress/mode=0\nprocess/fix_alpha_border=true\nmipmaps/generate=false\n')

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('source',type=Path);parser.add_argument('--check',action='store_true');parser.add_argument('--kaz-only',action='store_true')
 args=parser.parse_args();prepare(args.source.resolve(),args.check,args.kaz_only)
