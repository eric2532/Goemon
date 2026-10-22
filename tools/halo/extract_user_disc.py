"""Extract selected native Halo CE assets from a user-supplied Xbox ISO or 7z.
Requires: Python 3, bsdtar for .7z, refinery==2.6.0, reclaimer==2.11.2,
Pillow. Run only on a disc image the user supplies. Original is read-only.
No OpenCE source code is copied into the game or this extraction tool.
"""
import argparse,contextlib,struct,subprocess,tempfile
from pathlib import Path

def extract_map(iso,destination):
 with iso.open('rb') as f:
  for base in (0,0xfd90000,0x2080000,0x18300000):
   f.seek(base+0x10000);hdr=f.read(2048)
   if hdr.startswith(b'MICROSOFT*XBOX*MEDIA'):break
  else:raise ValueError('No supported Xbox XDVDFS partition')
  sector,size=struct.unpack_from('<II',hdr,0x14)
  found=[]
  def directory(sector,size,path=''):
   if size>16*1024*1024:raise ValueError('Unexpected directory size')
   f.seek(base+sector*2048);data=f.read(size);visited=set()
   def entry(offset):
    if offset in visited:return
    visited.add(offset)
    left,right,sec,length,attr,n=struct.unpack_from('<HHIIBB',data,offset)
    name=data[offset+14:offset+14+n].decode('latin1')
    if '/' in name or '\\' in name or name in ('.','..'):raise ValueError('Invalid disc path')
    if left:entry(left*4)
    if attr&0x10:
     if name.lower()=='maps':directory(sec,length,path+name+'/')
    elif (path+name).lower()=='maps/bloodgulch.map':found.append((sec,length))
    if right:entry(right*4)
   entry(0)
  directory(sector,size)
  if len(found)!=1:raise ValueError('Expected one maps/bloodgulch.map')
  sec,size=found[0];f.seek(base+sec*2048);raw=f.read(size)
  if len(raw)!=size:raise ValueError('Truncated ISO')
  destination.write_bytes(raw)

def extract_assets(map_path,destination):
 from refinery.core import RefineryCore
 import reclaimer.meta.wrappers.halo1_map as halo1
 # Reclaimer 2.11.2 treats bytes 28/29 (two signed 8-bit bone indices) as
 # one 16-bit field while endian-swapping Xbox vertices. Restore their order.
 original_swap=halo1.byteswap_comp_verts
 def corrected_swap(block):
  original_swap(block)
  data=block.STEPTREE.data
  for offset in range(0,len(data),32):data[offset+28],data[offset+29]=data[offset+29],data[offset+28]
 halo1.byteswap_comp_verts=corrected_swap
 destination.mkdir(parents=True,exist_ok=True)
 with (destination/'extract.log').open('w') as log,contextlib.redirect_stdout(log),contextlib.redirect_stderr(log):
  r=RefineryCore();m=r.load_map(map_path,autoload_resources=False)
  index=[]
  for i,t in enumerate(m.tag_index.tag_index):
   weapons=('assault rifle','rocket launcher','pistol','shotgun')
   selected=t.path.startswith('characters\\cyborg') or any(t.path.startswith(prefix+w) for w in weapons for prefix in ('weapons\\','sound\\sfx\\weapons\\')) or (t.path.startswith('sound\\sfx\\weapons\\weapon_anims\\') and t.path.split('\\')[-1].startswith(('ar_','rl_','sg_','pistol','shotgun','rocket'))) or t.path=='sound\\sfx\\weapons\\frag grenade\\expl'
   if not selected or t.class_1.enum_name not in ('model','model_animations','bitmap','shader_model','sound','weapon','biped'):continue
   index.append({'id':i,'class':t.class_1.enum_name,'path':t.path})
   r.extract_tag(i,extract_mode='tags',out_dir=destination/'tags',do_printout=False)
   if t.class_1.enum_name in ('model','model_animations','bitmap','sound'):
    r.extract_tag(i,extract_mode='data',out_dir=destination/'data',do_printout=False,bitmap_extract_format='png',decode_adpcm=True)
  import json
  (destination/'extracted_tags.json').write_text(json.dumps(index,indent=2))

def main():
 p=argparse.ArgumentParser();p.add_argument('disc',type=Path);p.add_argument('destination',type=Path);a=p.parse_args()
 with tempfile.TemporaryDirectory(prefix='goemon-halo-extract-') as td:
  tmp=Path(td);iso=a.disc
  if iso.suffix.lower()=='.7z':
   names=subprocess.check_output(['bsdtar','-tf',str(iso)],text=True).splitlines();names=[n for n in names if n.lower().endswith(('.iso','.xiso'))]
   if len(names)!=1 or Path(names[0]).name!=names[0]:raise ValueError('Expected a single flat disc image in archive')
   subprocess.run(['bsdtar','-xf',str(iso),'-C',str(tmp),names[0]],check=True);iso=tmp/names[0]
  map_path=tmp/'bloodgulch.map';extract_map(iso,map_path);extract_assets(map_path,a.destination)
 print('Extracted assets to',a.destination)
if __name__=='__main__':main()
