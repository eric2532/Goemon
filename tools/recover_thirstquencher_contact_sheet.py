from pathlib import Path
import bpy,json,math
from mathutils import Vector
R=Path(__file__).resolve().parent.parent/'assets/characters/thirstquencher';O=Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Soldiers');(O/'frames').mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'soldier_1.blend'));sc=bpy.context.scene;arm=next(o for o in sc.objects if o.type=='ARMATURE');clips=json.loads((R/'soldier_1_motion.json').read_text())['clips']
sc.render.engine='CYCLES';sc.cycles.samples=8;sc.render.resolution_x=300;sc.render.resolution_y=330;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sc.world.color=(.15,.15,.15)
target=Vector((0,0,.55));bpy.ops.object.camera_add(location=target+Vector((.8,-3,.6)));cam=bpy.context.object;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.7;sc.camera=cam
bpy.ops.object.light_add(type='AREA',location=(0,-2,3));bpy.context.object.data.energy=150;bpy.context.object.data.size=4
for i,clip in enumerate(clips):
 arm.animation_data.action=bpy.data.actions[clip['name']];sc.frame_set(1+clip['ticks']//2);sc.render.filepath=str(O/'frames'/f'{i:02d}_{clip["name"]}.png');bpy.ops.render.render(write_still=True)
