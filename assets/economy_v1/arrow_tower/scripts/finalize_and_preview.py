import bpy,os,json
R='/workspace/scratch/23f1a29e8f92/tower_assets_v1'
bpy.ops.wm.open_mainfile(filepath=R+'/firesiege_arrow_tower_v1.blend')
s=bpy.context.scene;s.frame_set(72)
# Connect aiming pivot without moving any modeled geometry.
pivot=bpy.data.objects['LAUNCHER_YAW'];bpy.context.view_layer.update()
for o in bpy.data.collections['TOWER_CANONICAL_PARTS'].objects:
 if o.name.startswith('launcher_') or o.name in ['LAUNCHER_RECOIL','ARROW_PROJECTILE','SOCKET_ARROW_MUZZLE']:
  o.parent=pivot;o.matrix_parent_inverse=pivot.matrix_world.inverted()
# All static and animated exports refreshed after hierarchy improvement.
def select_parts(maxstage=3):
 bpy.ops.object.select_all(action='DESELECT')
 for o in bpy.data.collections['TOWER_CANONICAL_PARTS'].objects:
  if o.type!='MESH' or o.get('stage_min',0)<=maxstage:o.select_set(True)
for label,num in [('empty',0),('frame',1),('assembling',2),('complete',3)]:
 s.frame_set(72);select_parts(num);bpy.ops.export_scene.gltf(filepath=R+'/exports/tower_stage_'+label+'.glb',export_format='GLB',use_selection=True,export_extras=True,export_apply=True,export_animations=False,export_current_frame=True,export_yup=True)
select_parts();original_scene_name=s.name;s.name='Tower_Build_Recoil_Reverse';bpy.ops.export_scene.gltf(filepath=R+'/exports/tower_build_recoil_reverse.glb',export_format='GLB',use_selection=True,export_extras=True,export_apply=True,export_yup=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_anim_slide_to_zero=True,export_nla_strips_merged_animation_name='Tower_Build_Recoil_Reverse',export_force_sampling=True,export_frame_range=True)
s.name=original_scene_name
# Open at completed frame with studio camera view.
s.frame_set(72)
for screen in bpy.data.screens:
 for ar in screen.areas:
  if ar.type=='VIEW_3D':
   ar.spaces.active.region_3d.view_perspective='CAMERA';ar.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=R+'/firesiege_arrow_tower_v1.blend',compress=True)
m=json.load(open(R+'/asset_manifest.json'))
for p in m['parts']:p['parent']=bpy.data.objects[p['name']].parent.name
json.dump(m,open(R+'/asset_manifest.json','w'),indent=2)
# Workbench raster preview uses exact same geometry/timeline and deterministic studio light.
s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=800;s.render.resolution_y=800;s.render.resolution_percentage=100
s.display.shading.light='STUDIO';s.display.shading.studio_light='paint.sl';s.display.shading.color_type='MATERIAL';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True;s.display.shading.cavity_type='BOTH';s.display.shading.curvature_ridge_factor=1.25;s.display.shading.curvature_valley_factor=1.0;s.display.shading.show_specular_highlight=True;s.display.shading.background_type='WORLD';s.world.color=(.24,.265,.28)
s.display.render_aa='16';s.render.image_settings.file_format='PNG';s.render.filepath=R+'/renders/tower_workbench_test.png'
bpy.ops.render.render(write_still=True)
if os.environ.get('FULL_ANIMATION')=='1':
 s.render.filepath=R+'/preview_frames/tower_';s.render.resolution_x=720;s.render.resolution_y=720
 bpy.ops.render.render(animation=True)
