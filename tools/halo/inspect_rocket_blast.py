"""Read the user's retail rocket radii; no engine source is copied or modified."""
import argparse, contextlib, hashlib, io, json
from pathlib import Path
from refinery.core import RefineryCore

p=argparse.ArgumentParser()
p.add_argument('map',type=Path)
p.add_argument('output',type=Path)
a=p.parse_args()
with contextlib.redirect_stdout(io.StringIO()),contextlib.redirect_stderr(io.StringIO()):
 r=RefineryCore();m=r.load_map(a.map,autoload_resources=False)
for index,tag in enumerate(m.tag_index.tag_index):
 if tag.class_1.enum_name=='damage_effect' and tag.path=='weapons\\rocket launcher\\explosion':
  meta=m.get_meta(index)
  result={
   'source_map':a.map.name,'source_sha256':hashlib.sha256(a.map.read_bytes()).hexdigest(),
   'tag':tag.path,'falloff_radius_halo_units':float(meta.radius[0]),'cutoff_radius_halo_units':float(meta.radius[1]),
   'occlusion_core_radius_halo_units':float(meta.damage.aoe_core_radius),
   'metres_per_halo_unit':3.048,
   'engine_reference':{'revision':'6ec42856d73e258e5a8c7e9cd19161f46d89d0e4','path':'source/objects/damage.c','functions':['area_of_effect_cause_damage','area_of_effect_cause_damage_to_object']},
   'adaptation':{'arena_scale':3.0,'full_damage_radius_metres':float(meta.radius[0])*3.048*3,'cutoff_radius_metres':float(meta.radius[1])*3.048*3,'note':'Larger Goemon enemies; separate arena adaptation, not the retail Halo radius.'}
  }
  a.output.write_text(json.dumps(result,indent=2)+'\n')
  print(json.dumps(result,indent=2));break
else:raise SystemExit('Retail rocket damage effect was not found')
