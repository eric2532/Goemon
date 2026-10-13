import bpy
R='/workspace/scratch/23f1a29e8f92/tower_assets_v1'
bpy.ops.wm.open_mainfile(filepath=R+'/firesiege_arrow_tower_v1.blend');s=bpy.context.scene
s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=720;s.render.resolution_y=720;s.render.resolution_percentage=100
s.display.shading.light='STUDIO';s.display.shading.studio_light='paint.sl';s.display.shading.color_type='MATERIAL';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True;s.display.shading.cavity_type='BOTH';s.display.shading.curvature_ridge_factor=1.25;s.display.shading.curvature_valley_factor=1.;s.display.shading.show_specular_highlight=True;s.display.shading.background_type='WORLD';s.world.color=(.24,.265,.28);s.display.render_aa='8'
s.render.image_settings.file_format='PNG';s.render.filepath=R+'/preview_frames/tower_';s.frame_start=1;s.frame_end=180
bpy.ops.render.render(animation=True)
