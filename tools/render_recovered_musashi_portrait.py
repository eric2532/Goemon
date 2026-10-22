"""Render portrait from the recovered editable source, without changing it."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:]
source=Path(args[0]);output=Path(args[1])
if source.suffix=='.blend':
    bpy.ops.wm.open_mainfile(filepath=str(source))
else:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source))
    arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    action=next(a for a in bpy.data.actions if a.name.startswith('Table_00__'))
    for track in arm.animation_data.nla_tracks:track.mute=True
    arm.animation_data.action=action;arm.animation_data.action_slot=action.slots[0]
    bpy.context.scene.frame_set(0)
    bpy.ops.object.camera_add()
    bpy.context.scene.camera=bpy.context.object
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.view_settings.view_transform='Standard'
scene.render.film_transparent=True
scene.render.resolution_x=512;scene.render.resolution_y=512
scene.cycles.samples=16
target=Vector((0,0,.51))
camera=scene.camera;camera.location=target+Vector((.25,-2.5,.22))
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=1.22
scene.render.filepath=str(output)
bpy.ops.render.render(write_still=True)
