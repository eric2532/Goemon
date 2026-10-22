import bpy,runpy,sys
from pathlib import Path
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'));args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for r in d['DOGS']:
 if args and r['id'] not in args:continue
 src=P/'sources'/f"{r['id']}_{r['name']}.blend";bpy.ops.wm.open_mainfile(filepath=str(src));assert not bpy.context.scene.get('real_scale'),'Run before final physical scaling'
 for o in list(bpy.data.objects):
  if o.name.startswith('FACE |'):bpy.data.objects.remove(o,do_unlink=True)
 M={m.name:m for m in bpy.data.materials};d['face'](r,M);bpy.context.view_layer.update();d['turn_face'](r);bpy.ops.wm.save_as_mainfile(filepath=str(src),compress=True);print('REFINED FACE',r['id'],flush=True)
