import bpy,runpy,math
from pathlib import Path
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'))
for r in d['DOGS']:
 if r['id'] not in ['01','05']:continue
 src=P/'sources'/f"{r['id']}_{r['name']}.blend";bpy.ops.wm.open_mainfile(filepath=str(src));M={m.name:m for m in bpy.data.materials}
 if r['id']=='01':
  m=M['parchment'];m.diffuse_color=(.24,.24,.13,1);m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.24,.24,.13,1)
 if r['id']=='05':
  m=M['thread'];m.diffuse_color=(.16,.27,.34,1);m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.16,.27,.34,1)
  for o in list(bpy.data.objects):
   if o.name.startswith('WEAPON | sword retaining cord'):bpy.data.objects.remove(o,do_unlink=True)
  y=-r['body'][1]-.115;z=r['chest'][2]+.03
  for x in [-.18,.14]:
   ps=[(x,y+.055*math.cos(k/40*math.tau),z+.035+.055*math.sin(k/40*math.tau)) for k in range(41)];d['rope']('WEAPON | fitted retaining cord',ps,M,.010,'thread');d['ribbon']('WEAPON | leather saddle anchor',[(x,y+.01,z+.09),(x,y+.09,z+.13),(x,-r['body'][1]-.03,z+.17)],.035,M['leather'],across=(1,0,0))
 bpy.ops.wm.save_as_mainfile(filepath=str(src),compress=True)
