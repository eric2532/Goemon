from pathlib import Path
import bpy,math,json
from mathutils import Vector,Matrix
folder=Path(__file__).resolve().parent;p=folder/'Samurai_Weapon_Workbench.blend'
bpy.ops.wm.open_mainfile(filepath=str(p));bpy.context.preferences.filepaths.save_version=0
for i in range(4):
 angle=i*math.pi/2;R=Matrix.Rotation(angle,3,'Z')
 for j,center in enumerate([(.138,-.082,.23),(.085,-.166,.23)]):
  ob=bpy.data.objects['Guard stepped arm %d.%d'%(i+1,j+1)];old=R@Vector(center);new=Vector(center)
  for v in ob.data.vertices:v.co+=new-old
  ob.data.update()
bpy.data.objects['Katana detail root'].location.z=.74
bpy.data.objects['Sheath detail — original size'].location.z=.74
detail=bpy.data.scenes['02 — Katana and unchanged sheath'];cam=detail.camera
cam.rotation_euler=(Vector((0,0,1.3))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.95
# Clear material preview with a neutral background; lamp extras remain hidden.
for workspace in bpy.data.workspaces:
 for screen in workspace.screens:
  for area in screen.areas:
   if area.type=='VIEW_3D':
    space=area.spaces.active;space.shading.background_type='WORLD';space.shading.studiolight_rotate_z=.5
bpy.context.window.scene=bpy.data.scenes['01 — Samurai with maroon katana']
bpy.ops.wm.save_as_mainfile(filepath=str(p))
for scene_name,filename in [('01 — Samurai with maroon katana','samurai-preview.png'),('02 — Katana and unchanged sheath','katana-detail.png')]:
 sc=bpy.data.scenes[scene_name];sc.render.filepath=str(folder/filename);bpy.ops.render.render(write_still=True,scene=sc.name)
# Close-up above the guard shows the four open stepped arms and blade collar.
saved_pos=cam.location.copy();saved_rot=cam.rotation_euler.copy();saved_scale=cam.data.ortho_scale
cam.location=Vector((.3,-.65,1.67));cam.rotation_euler=(Vector((-.28,0,.97))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.70
detail.render.resolution_x=1100;detail.render.resolution_y=1000;detail.render.filepath=str(folder/'guard-closeup.png');bpy.ops.render.render(write_still=True,scene=detail.name)
# Temporary close-up framing is only for its render; keep the saved general views.
cam.location=saved_pos;cam.rotation_euler=saved_rot;cam.data.ortho_scale=saved_scale
print('SAMURAI_POLISH_OK',flush=True)
