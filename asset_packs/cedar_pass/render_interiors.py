"""Render revised sources with explicit architectural cutaway; leaves exported geometry unchanged."""
from pathlib import Path
import bpy,json,sys
from mathutils import Vector
P=Path(__file__).resolve().parent
exec(compile((P/'build_pack.py').read_text().split('\nspec=')[0],str(P/'build_pack.py'),'exec'))
names=['machiya_open'] if '--checkpoint' in sys.argv else list(json.loads((P/'interiors.json').read_text()))
if '--only' in sys.argv:names=[sys.argv[sys.argv.index('--only')+1]]
for name in names:
 reset();bpy.ops.import_scene.gltf(filepath=str(P/'exports'/f'{name}.glb'))
 for o in list(bpy.context.scene.objects):
  if o.name.startswith(('CP_Roof','CP_Wall_Front','CP_Wall_Right','CP_Upper')):o.hide_render=True
 box('Presentation ground',(0,0,-.14),(70,70,.25),'paper')
 setup_render((11,-15,13),(0,0,1),17 if name!='gatehouse' else 21,P/'previews/interiors'/f'{name}_cutaway.png',(1400,1100))
 bpy.context.scene.cycles.samples=40
 # Large, soft room fill aimed into the revealed shell.
 bpy.ops.object.light_add(type='AREA',location=(0,-3,7));bpy.context.object.data.energy=700;bpy.context.object.data.size=7
 bpy.ops.render.render(write_still=True)
 if name=='inn':
  for o in bpy.context.scene.objects:
   if o.name.startswith('CP_Upper'):o.hide_render=False
  bpy.context.scene.render.filepath=str(P/'previews/interiors/inn_mezzanine.png');bpy.ops.render.render(write_still=True)
