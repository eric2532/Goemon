"""Recover CE's real campaign sword from the user's read-only Xbox disc/map.

Requires requirements.txt. The retail weapon has no first-person model or
animation references; build_energy_sword.py documents the playable adaptation.
All extracted native tags and pixels stay separately editable.
"""
import argparse,contextlib,json,struct,wave
from pathlib import Path
from extract_weapon_effects import normalize,references
from decode_extracted_assets import model,anim


def extract_iso_map(iso,destination,name='a50.map'):
 with iso.open('rb') as f:
  for base in (0,0xfd90000,0x2080000,0x18300000):
   f.seek(base+0x10000);header=f.read(2048)
   if header.startswith(b'MICROSOFT*XBOX*MEDIA'):break
  else:raise ValueError('No Xbox XDVDFS partition')
  found=[]
  def walk(sector,length,path=''):
   if length>16*1024*1024:raise ValueError('Invalid directory size')
   f.seek(base+sector*2048);data=f.read(length);seen=set()
   def entry(offset):
    if offset in seen:return
    seen.add(offset);left,right,sec,size,flags,count=struct.unpack_from('<HHIIBB',data,offset)
    item=data[offset+14:offset+14+count].decode('latin1')
    if '/' in item or '\\' in item or item in ('.','..'):raise ValueError('Invalid disc path')
    if left:entry(left*4)
    if flags&0x10:
     if item.lower()=='maps':walk(sec,size,path+item+'/')
    elif (path+item).lower()=='maps/'+name:found.append((sec,size))
    if right:entry(right*4)
   entry(0)
  walk(*struct.unpack_from('<II',header,0x14))
  if len(found)!=1:raise ValueError('Expected one maps/'+name)
  sec,length=found[0];f.seek(base+sec*2048);data=f.read(length)
  if len(data)!=length:raise ValueError('Truncated map')
  destination.write_bytes(data)


def extract(map_path,destination,chief_source):
 from refinery.core import RefineryCore
 import reclaimer.meta.wrappers.halo1_map as halo1
 original=halo1.byteswap_comp_verts
 def corrected(block):
  original(block);data=block.STEPTREE.data
  for offset in range(0,len(data),32):data[offset+28],data[offset+29]=data[offset+29],data[offset+28]
 halo1.byteswap_comp_verts=corrected
 destination.mkdir(parents=True,exist_ok=True)
 with (destination/'extraction.log').open('w') as log,contextlib.redirect_stdout(log),contextlib.redirect_stderr(log):
  r=RefineryCore();m=r.load_map(map_path,autoload_resources=False)
  lookup={(t.class_1.enum_name,t.path):i for i,t in enumerate(m.tag_index.tag_index)}
  pending=[i for i,t in enumerate(m.tag_index.tag_index) if t.path.startswith('weapons\\energy sword\\') or t.class_1.enum_name=='sound' and 'stand_sword_melee' in t.path]
  extracted={}
  while pending:
   i=pending.pop(0)
   if i in extracted:continue
   t=m.tag_index.tag_index[i];meta=m.get_meta(i)
   extracted[i]={'class':t.class_1.enum_name,'path':t.path,'native':normalize(meta)}
   for ref in references(meta):
    if (ref['class'],ref['path']) in lookup:pending.append(lookup[(ref['class'],ref['path'])])
   r.extract_tag(i,extract_mode='tags',out_dir=destination/'tags',do_printout=False)
   if t.class_1.enum_name in ('model','bitmap','sound'):
    r.extract_tag(i,extract_mode='data',out_dir=destination/'source_data',do_printout=False,bitmap_extract_format='png',decode_adpcm=True)
  for wav in (destination/'source_data').rglob('*.wav'):
   data=bytearray(wav.read_bytes());struct.pack_into('<I',data,4,len(data)-8);wav.write_bytes(data)
  (destination/'native_tags.json').write_text(json.dumps({'map':map_path.name,'unit_facts':{'halo_world_unit_meters':3.048,'jms_unit_meters':.03048},'tags':list(extracted.values())},indent=2))
  models=list((destination/'source_data/weapons/energy sword').rglob('*.jms'))
  high=next((p for p in models if 'superhigh' in p.name),models[0])
  decoded={'sword':model(high),'adapted_first_person_animations':{name:anim(chief_source/f'weapons/pistol/fp/animations/first-person {clip}.jmm') for name,clip in [('idle','idle'),('ready','ready'),('firing','melee')]},'provenance':{'sword_mesh':str(high.relative_to(destination)),'first_person':'Retail CE sword interface first_person_model and first_person_animations are empty. Native Chief pistol idle/ready/melee arm clips are adapted to a one-handed sword grip; firing means melee swing, not an original sword FP animation.'}}
  (destination/'decoded_energy_sword.json').write_text(json.dumps(decoded,separators=(',',':')))
 return destination

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('disc_or_map',type=Path);p.add_argument('--destination',type=Path,default=Path(__file__).resolve().parents[2]/'assets/blender/master_chief/energy_sword');p.add_argument('--chief-source',type=Path,default=Path(__file__).resolve().parents[2]/'assets/blender/master_chief/source_data');args=p.parse_args()
 if args.disc_or_map.suffix.lower()=='.map':extract(args.disc_or_map,args.destination,args.chief_source)
 else:
  import tempfile
  with tempfile.TemporaryDirectory(prefix='goemon-energy-sword-') as temp:
   path=Path(temp)/'a50.map';extract_iso_map(args.disc_or_map,path);extract(path,args.destination,args.chief_source)
 print('Recovered native sword source',args.destination)
