"""Non-destructive animation preview. Open kai.blend and run with Blender --background.
Renders side and three-quarter idle/run/sprint poses into tests/. Does not save the source.
"""
import bpy
from mathutils import Vector
from pathlib import Path
root=Path(__file__).resolve().parents[1];rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');s=bpy.context.scene
s.render.resolution_x=480;s.render.resolution_y=480
cam=s.camera
for view,pos in [('side',(8,1.2,2.4)),('threequarter',(3.5,7.4,2.15))]:
 cam.location=pos;cam.rotation_euler=(Vector((0,0,1.55))-cam.location).to_track_quat('-Z','Y').to_euler()
 for clip in ('Idle','Run','Sprint'):
  rig.animation_data.action=bpy.data.actions[clip]
  for frame in (0,15,30,45):
   s.frame_set(frame);bpy.context.view_layer.update();s.render.filepath=str(root/'tests'/f'anime-neck-{view}-{clip}-{frame}.png');bpy.ops.render.render(write_still=True)
