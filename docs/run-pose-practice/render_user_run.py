import bpy
import math
from pathlib import Path
from mathutils import Vector

out = Path(__file__).resolve().parent / 'run-preview'
out.mkdir(exist_ok=True)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.render.resolution_x = 420
scene.render.resolution_y = 420
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = 'BOTH'
scene.display.shading.background_type = 'WORLD'
scene.world.color = (.10,.12,.15)
scene.view_settings.view_transform = 'Standard'
camera = scene.camera
camera.hide_set(False)
camera.hide_render = False
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 3.35
focus = Vector((0,.08,1.35))
camera.location = focus + Vector((5,0,.2))
camera.rotation_euler = (focus-camera.location).to_track_quat('-Z','Y').to_euler()
for frame in range(0,60,2):
    scene.frame_set(frame)
    scene.render.filepath = str(out / ('side-%03d.png' % frame))
    bpy.ops.render.render(write_still=True)
camera.location = focus + Vector((3.5,6,1.7))
camera.rotation_euler = (focus-camera.location).to_track_quat('-Z','Y').to_euler()
for frame in range(0,60,6):
    scene.frame_set(frame)
    scene.render.filepath = str(out / ('three-quarter-%03d.png' % frame))
    bpy.ops.render.render(write_still=True)
print('PREVIEW_READY',out)
