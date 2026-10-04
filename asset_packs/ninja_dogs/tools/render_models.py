import bpy,runpy,sys
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'));args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [];ids=[x for x in args if x.isdigit()]
for r in d['DOGS']:
 if ids and r['id'] not in ids:continue
 bpy.ops.wm.open_mainfile(filepath=str(P/'sources'/f"{r['id']}_{r['name']}.blend"));s=bpy.context.scene;scale=s.get('real_scale',1)
 views=['threequarter','portrait'] if '--sample' in args else ['front','side','threequarter','rear','backthreequarter','portrait']
 if '--front' in args:views=['front']
 for view in views:
  target=Vector(r['head'] if view=='portrait' else (0,0,1.00));pos={'threequarter':(4.1,-7,3),'front':(7,0,1.9),'side':(0,-8,2),'rear':(-7,0,2),'backthreequarter':(-4,7,3),'portrait':(4,-6,2.3)}[view];pos=(7,0,2.6) if r['id']=='10' and view=='front' else pos;s.camera.location=Vector(pos)*scale;s.camera.rotation_euler=(target*scale-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=(1.40 if view=='portrait' else (4.4 if r['id']=='10' else 3.2))*scale
  s.render.resolution_x=1000;s.render.resolution_y=900;s.cycles.samples=40 if view in ['threequarter','portrait'] else 24;s.render.filepath=str(P/'renders'/f"{r['id']}_{view}.png");bpy.ops.render.render(write_still=True)
 print('RENDERED',r['id'],flush=True)
