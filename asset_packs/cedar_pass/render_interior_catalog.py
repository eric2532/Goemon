"""Blender-rendered six-room cutaway catalog from current exports."""
from pathlib import Path
import json
P=Path(__file__).resolve().parent
exec(compile((P/'build_pack.py').read_text().split('\nspec=')[0],str(P/'build_pack.py'),'exec'))
reset();meta=json.loads((P/'interiors.json').read_text())
labels={'machiya_open':'MERCHANT SHOP','inn':'INN / GROUND FLOOR','tea_house_open':'TEA HOUSE','warehouse':'WAREHOUSE','shrine':'SHRINE HALL','gatehouse':'GATEHOUSE / GUARD BAYS'}
for i,name in enumerate(['machiya_open','inn','tea_house_open','warehouse','shrine','gatehouse']):
 a=meta[name];x=(i%3)*12;y=-(i//3)*19;obs=import_asset(name);s=8/max(a['dimensions_xyz_blender_m'][0],a['dimensions_xyz_blender_m'][1])
 for o in obs:
  o.location=Vector((x,y,0));o.scale*=s
  if o.name.startswith(('CP_Roof','CP_Wall_Front','CP_Wall_Right','CP_Upper')):o.hide_render=True
 box('Catalog plinth',(x,y,-.15),(10.8,12,.3),'paper')
 bpy.ops.object.text_add(location=(x-4.8,y-5.6,.03));t=bpy.context.object;t.data.body=labels[name];t.data.size=.45;t.data.materials.append(mat('dark'))
setup_render((24,-41,34),(12,-9,1),43,P/'previews/interiors/interior_contact_sheet.png',(1800,1400));bpy.context.scene.cycles.samples=32
bpy.ops.wm.save_as_mainfile(filepath=str(P/'sources/interior_contact_sheet.blend'));bpy.ops.render.render(write_still=True)
