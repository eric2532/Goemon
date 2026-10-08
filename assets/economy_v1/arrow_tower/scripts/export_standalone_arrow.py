import bpy,json
from mathutils import Vector
R='/workspace/scratch/23f1a29e8f92/tower_assets_v1'
bpy.ops.wm.open_mainfile(filepath=R+'/firesiege_arrow_tower_v1.blend');main=bpy.context.scene;main.frame_set(72);bpy.context.view_layer.update()
scene=bpy.data.scenes.new('03_ARROW_PROJECTILE');scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
coll=bpy.data.collections.new('ARROW_PROJECTILE_STANDALONE');scene.collection.children.link(coll)
root=bpy.data.objects.new('ARROW_PROJECTILE_ROOT',None);coll.objects.link(root);root['stable_id']='firesiege.arrow.root';root['pivot']='arrow tip at origin';root['forward_axis']='-Y';root['units']='meters'
source_names=['arrow_head','arrow_shaft','arrow_fletching_0','arrow_fletching_1','arrow_fletching_2']
tip=Vector((0,-1.72,1.86))
for name in source_names:
 src=bpy.data.objects[name];matrix=src.matrix_world.copy();obj=src.copy();obj.animation_data_clear();obj.parent=None;obj.matrix_parent_inverse.identity();obj.matrix_world=matrix;obj.location-=tip;obj.name=name.replace('arrow_','Arrow_');coll.objects.link(obj);obj.parent=root;obj['stable_id']='firesiege.arrow.'+name;obj['part_role']='projectile';obj['source_part']=name
marker=bpy.data.objects.new('SOCKET_ARROW_TIP',None);coll.objects.link(marker);marker.parent=root;marker['stable_id']='firesiege.arrow.tip';marker['forward_axis']='-Y'
bpy.context.window.scene=scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=R+'/exports/arrow_projectile.glb',export_format='GLB',use_selection=True,export_extras=True,export_apply=True,export_yup=True,export_animations=False,export_current_frame=True)
bpy.context.window.scene=main;main.frame_set(72)
bpy.ops.wm.save_as_mainfile(filepath=R+'/firesiege_arrow_tower_v1.blend',compress=True)
import runpy
runpy.run_path(R+'/scripts/prune_arrow_payload.py')
print('ARROW_EXPORTED')
