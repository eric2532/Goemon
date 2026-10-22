"""Read-only recovery of native Xbox Blood Gulch BSP and source bitmap pixels.

Usage: research-venv/bin/python tools/halo/extract_blood_gulch.py disc.iso
Requires tools/halo/requirements.txt; extracted geometry remains in Halo units.
Battle clearing/roads/base removal happen only in build_blood_gulch.py.
"""
import argparse, contextlib, hashlib, json, struct, tempfile
from pathlib import Path
from extract_energy_sword import extract_iso_map
from extract_weapon_effects import normalize

ROOT=Path(__file__).resolve().parents[2]

def extract(map_path, destination, log_path):
 from refinery.core import RefineryCore
 destination.mkdir(parents=True,exist_ok=True)
 (destination/'source_data').mkdir(exist_ok=True)
 (destination/'source_data'/'.gdignore').touch()
 log_path.parent.mkdir(parents=True,exist_ok=True)
 with log_path.open('w') as log,contextlib.redirect_stdout(log),contextlib.redirect_stderr(log):
  refinery=RefineryCore();m=refinery.load_map(map_path,autoload_resources=False)
  tags=m.tag_index.tag_index
  lookup={(t.class_1.enum_name,t.path):i for i,t in enumerate(tags)}
  bsp_id=next(i for i,t in enumerate(tags) if t.class_1.enum_name=='scenario_structure_bsp' and 'bloodgulch' in t.path)
  bsp=m.get_meta(bsp_id)
  # Xbox's render vertices are 32-byte compressed records; surfaces are LE u16 triplets.
  faces=list(struct.iter_unpack('<3H',bytes(bsp.surface.STEPTREE)))
  groups=[];shaders={};images={}
  for lm in bsp.lightmaps.STEPTREE:
   for mat in lm.materials.STEPTREE:
    path=mat.shader.filepath;klass=mat.shader.tag_class.enum_name
    shader_id=lookup[(klass,path)];shader=m.get_meta(shader_id)
    if path not in shaders:shaders[path]={'class':klass,'native':normalize(shader)}
    group={'shader':path,'vertices':[],'faces':[list(f) for f in faces[mat.surfaces:mat.surfaces+mat.surface_count]]}
    raw=bytes(mat.compressed_vertices.STEPTREE)
    for i in range(mat.vertices_count):
     x,y,z,n,b,t,u,v=struct.unpack_from('<3f3I2f',raw,i*32)
     group['vertices'].append({'p':[x,y,z],'uv':[u,v],'packed_normal':n})
    assert all(max(f)<len(group['vertices']) for f in group['faces'])
    group['role']='ground' if path.endswith('blood ground') else 'cliff' if path.endswith('cap_cliff01b') else 'boulder' if path.endswith('beavercreek boulder') else 'removed_base'
    if group['role']!='removed_base':
     diffuse=shader.senv_attrs.diffuse
     for field,alias in [('base_map','image'),('primary_detail_map','detail_image'),('secondary_detail_map','secondary_image')]:
      reference=getattr(diffuse,field)
      if not reference.filepath:continue
      name='source_'+reference.filepath.split('\\')[-1].replace(' ','_')+'.png'
      group[alias]=name
      if name not in images:
       bitmap_id=lookup[('bitmap',reference.filepath)]
       refinery.extract_tag(bitmap_id,extract_mode='data',out_dir=destination/'source_data',bitmap_extract_format='png',do_printout=False)
       matches=list((destination/'source_data').rglob(reference.filepath.split('\\')[-1]+'*.png'))
       assert len(matches)==1,(reference.filepath,matches)
       pixels=matches[0].read_bytes();(destination/name).write_bytes(pixels)
       images[name]={'bitmap':reference.filepath,'sha256':hashlib.sha256(pixels).hexdigest()}
     group['detail_scale']=float(diffuse.primary_detail_map_scale)
    groups.append(group)
  data={'map':'bloodgulch.map','map_sha256':hashlib.sha256(map_path.read_bytes()).hexdigest(),'bsp_tag':tags[bsp_id].path,'source_material_count':len(groups),'halo_unit_meters':3.048,'bounds_halo_units':[list(getattr(bsp,'world_bounds_'+axis)) for axis in 'xyz'],'groups':groups,'shaders':shaders,'images':images}
  (destination/'source.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
 return data

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('disc_or_map',type=Path);p.add_argument('--log',type=Path,default=Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/blood-gulch-castle/extraction.log'));p.add_argument('--destination',type=Path,default=ROOT/'assets/maps/blood_gulch');args=p.parse_args()
 if args.disc_or_map.suffix.lower()=='.map':data=extract(args.disc_or_map,args.destination,args.log)
 else:
  with tempfile.TemporaryDirectory(prefix='goemon-bloodgulch-') as temp:
   source=Path(temp)/'bloodgulch.map';extract_iso_map(args.disc_or_map,source,'bloodgulch.map');data=extract(source,args.destination,args.log)
 print('BLOOD_GULCH_SOURCE',len(data['groups']),'materials',sum(len(g['faces']) for g in data['groups']),'native triangles',len(data['images']),'source images')
