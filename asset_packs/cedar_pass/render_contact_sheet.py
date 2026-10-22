"""Render the labeled catalog with enough elevation separation to show facades."""
from pathlib import Path
import json
P=Path(__file__).resolve().parent
exec(compile((P/'build_pack.py').read_text().split('\nspec=')[0],str(P/'build_pack.py'),'exec'))
reset()
for i,a in enumerate(json.loads((P/'manifest.json').read_text())):
 x=(i%6)*10;y=-(i//6)*18;obs=import_asset(a['id']);s=6.5/max(a['dimensions_xyz_blender_m'])
 for o in obs:o.location=Vector((x,y,0));o.scale*=s;o.rotation_euler.z=math.radians(-12)
 box('Exhibit plinth',(x,y,-.15),(9,10,.3),'paper')
 bpy.ops.object.text_add(location=(x-4.1,y-4.8,.03));t=bpy.context.object;t.name='Label '+a['id'];t.data.body=a['id'];t.data.size=.50;t.data.extrude=.001;t.data.materials.append(mat('dark'))
setup_render((25,-82,40),(25,-27,2),68,P/'previews/contact_sheet.png',(2400,1700));bpy.context.scene.cycles.samples=32
bpy.ops.wm.save_as_mainfile(filepath=str(P/'sources/contact_sheet.blend'));bpy.ops.render.render(write_still=True)
