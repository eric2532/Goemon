"""Frame the source models for convenient editing and set a usable saved camera."""
from pathlib import Path
import bpy,json
from mathutils import Vector
R=Path(__file__).resolve().parents[2]
for slug in ['masked_raider','reed_archer','daruma_breaker','lantern_runner']:
 source=R/'assets/blender/enemies/forest_redesign_v01'/f'{slug}.blend'
 bpy.ops.wm.open_mainfile(filepath=str(source))
 report=json.loads((R/'docs/enemy-concepts/3d-v01'/f'{slug}-report.json').read_text());height=report['height'];focus=Vector((0,0,height*.51))
 cam=bpy.context.scene.camera;cam.location=focus+Vector((7,10,1.7));cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=max(height*1.2,(report['bounds_max'][0]-report['bounds_min'][0])*1.28)
 bpy.context.scene.render.filepath=str(R/'docs/enemy-concepts/3d-v01'/f'{slug}-three-quarter.png')
 for screen in bpy.data.screens:
  for area in screen.areas:
   if area.type=='VIEW_3D':
    space=area.spaces.active;space.shading.type='MATERIAL';space.overlay.show_extras=False
    if space.region_3d:
     space.region_3d.view_location=focus;space.region_3d.view_distance=height*1.7;space.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
 bpy.ops.object.select_all(action='DESELECT')
 bpy.ops.wm.save_as_mainfile(filepath=str(source))
 print('PREPARED_EDITABLE_SOURCE',slug)
