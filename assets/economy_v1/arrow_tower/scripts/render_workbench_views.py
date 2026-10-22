import bpy
from mathutils import Vector
R='/workspace/scratch/23f1a29e8f92/tower_assets_v1'
bpy.ops.wm.open_mainfile(filepath=R+'/firesiege_arrow_tower_v1.blend');s=bpy.context.scene;s.frame_set(72)
s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=1100;s.render.resolution_y=1100;s.render.resolution_percentage=100
s.display.shading.light='STUDIO';s.display.shading.studio_light='paint.sl';s.display.shading.color_type='MATERIAL';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True;s.display.shading.cavity_type='BOTH';s.display.shading.curvature_ridge_factor=1.25;s.display.shading.curvature_valley_factor=1.;s.display.shading.show_specular_highlight=True;s.display.shading.background_type='WORLD';s.world.color=(.24,.265,.28);s.display.render_aa='16'
s.render.image_settings.file_format='PNG'
for name,loc in [('quarter',(5.8,-8.5,5.7)),('front',(0,-9,3.9)),('side',(9,0,3.9))]:
 s.camera.location=loc;s.camera.rotation_euler=(Vector((0,-.03,1.8))-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=5.9;s.render.filepath=R+'/renders/tower_'+name+'_studio.png';bpy.ops.render.render(write_still=True)
