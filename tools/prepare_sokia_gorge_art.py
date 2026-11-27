"""Give the existing continuous cliff owner the gorge's unchanged source wall paint."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from PIL import Image,ImageOps
from recover_falan_forts import native_stone
from recover_falan_architecture import opaque_paint

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/sokia/scenery'

def prepare():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
 import cg_library as lib
 source=(ROOT.parent/'Magic Power/data/crossgate/source/BlueCrossgate/map/0/15526.dat').read_bytes()
 width,height,floor,objects,flags=lib.parse_map(source)
 cliffs=json.loads((OUT/'cliffs.json').read_text());profiles={};graphics={};coverage={}
 lookup=lib.serial_index()
 for serial in sorted({s for s in objects if 13080<=s<=13115}):
  row=cliffs['graphics'][str(serial+200000)]
  if row.get('void_only'):continue
  native=lookup[serial];image=lib.image_from_record(native['pack'],native['row'])
  assert row['rgba_sha256']==hashlib.sha256(image.tobytes()).hexdigest()
  profile=copy.deepcopy(row['profile']);profile['paint_source']=serial;profile['paint_rect']=row['rect']
  profiles[str(serial)]=profile
  coverage[serial]=sum(p[3]>=128 and max(p[:3])>45 for p in image.getdata())/(image.width*image.height)
  graphics[str(serial)]=dict(origin=row['origin'],footprint=[max(1,native['east']),max(1,native['south'])])
 # Reuse the continuous cliff owner's established full-face fallback for shadow fragments.
 for key,profile in profiles.items():
  serial=int(key);family=13080+(serial-13080)//12*12
  if coverage[serial]<.35:profile['paint_source']=max((s for s in coverage if family<=s<family+12),key=coverage.get)
 # Extend the existing unchanged face atlas with a source-rock cap for unseen tops.
 atlas=Image.open(OUT/'cliffs.png').convert('RGBA');paint=Image.new('RGBA',(atlas.width,atlas.height+132));paint.paste(atlas,(0,0))
 native=lookup[13080];original=lib.image_from_record(native['pack'],native['row'])
 patch=original.crop((22,65,45,120)).resize((64,64),Image.Resampling.BICUBIC)
 cap=Image.new('RGBA',(128,128));cap.paste(patch,(0,0));cap.paste(ImageOps.mirror(patch),(64,0));cap.paste(ImageOps.flip(cap.crop((0,0,128,64))),(0,64))
 paint.paste(cap,(2,atlas.height+2))
 wall_tiles={};wall_sources={}
 for family in [13080,13092,13104]:
  serial=max((s for s in coverage if family<=s<family+12),key=coverage.get)
  native=lookup[serial];original=lib.image_from_record(native['pack'],native['row'])
  # A full, opaque body patch avoids projecting border/occluder texels down a grazing face.
  candidates=[]
  for y in range(25,original.height-64):
   for x in range(max(1,original.width-32)):
    crop=original.crop((x,y,x+32,y+64))
    colored=sum(p[3]>=128 and max(p[:3])>45 for p in crop.getdata())
    candidates.append((colored,-abs(y-original.height*.4),x,y))
  _,_,x,y=max(candidates);box=[x,y,x+32,y+64]
  patch=native_stone(opaque_paint(original.crop(box)),.55).resize((128,128),Image.Resampling.BICUBIC)
  # The established fort-paint recipe joins edge texels without mirroring whole rocks.
  pixels=patch.load()
  for axis in [0,1]:
   for edge in range(8):
    weight=.5*(1-edge/8)**2
    for along in range(128):
     a=(edge,along)if axis==0 else(along,edge);b=(127-edge,along)if axis==0 else(along,127-edge);left=pixels[a];right=pixels[b]
     pixels[a]=tuple(round(q*(1-weight)+r*weight)for q,r in zip(left,right));pixels[b]=tuple(round(r*(1-weight)+q*weight)for q,r in zip(left,right))
  assert patch.getchannel('A').getextrema()==(255,255),('A solid rock tile cannot retain sprite cutout holes',family)
  at=[134+(family-13080)//12*132,atlas.height+2,128,128];paint.paste(patch,at[:2])
  for s in coverage:
   if family<=s<family+12:wall_tiles[str(s)]=at
  wall_sources[str(family)]=dict(serial=serial,source_rgba_sha256=hashlib.sha256(original.tobytes()).hexdigest(),body_patch=box,recipe='Existing opaque_paint edge extension, native_stone(.55) and fort edge-texel join; no source image is modified.')
 anchors=[[i%width,i//width,s]for i,s in enumerate(objects)if 13080<=s<=13115]
 assert len(anchors)==250
 data=dict(schema=1,map=15526,size=[width,height],source_sha256=hashlib.sha256(source).hexdigest(),anchors=anchors,profiles=profiles,graphics=graphics,minimum_crown_fraction=.7,tile_unseen_faces=True,wall_tiles=wall_tiles,wall_paint_sources=wall_sources,wall_tile_scale=[128/3,128/6],wall_preview=[],
  cap_paint={name:[2,atlas.height+2,128,128]for name in ['rock','snow','cave','undersea','freyja']},
  background=dict(serial=100,source_rgba_sha256=hashlib.sha256(lib.image_from_record(lookup[100]['pack'],lookup[100]['row']).tobytes()).hexdigest(),interpretation='Opaque cache background outside the source cave is enclosed in darkness; raw tile100 is retained.'),
  stair=dict(serial=17954,source_rgba_sha256=hashlib.sha256(lib.image_from_record(lookup[17954]['pack'],lookup[17954]['row']).tobytes()).hexdigest(),owner='forest_habaru_stairs.gd',anchors=[[i%width,i//width]for i,s in enumerate(objects)if s==17954]),
  limits='Existing continuous cliff mass and stone stair builders; original profiles/anchors retained. Rectified wall/cap paint comes from one opaque body patch within each original12-graphic family, using the established native-stone/edge-join recipe to avoid stretching border/occluder texels. Inferred cap corners stay above70% of their measured crown. Rock volume, caps and unseen cave background are inferred. No collider, walk mask, terrain height or port is authored here.')
 return data,paint

def main():
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args();data,paint=prepare()
 if args.check:
  assert json.loads((OUT/'gorge-mass.json').read_text())==data
  old=Image.open(OUT/'gorge-mass.png');assert old.size==paint.size and old.tobytes()==paint.tobytes()
 else:
  (OUT/'gorge-mass.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n');paint.save(OUT/'gorge-mass.png')
 print('SOKIA_GORGE_ART_SOURCE_CHECK anchors=',len(data['anchors']),'stair_anchors=',len(data['stair']['anchors']))

if __name__=='__main__':main()
