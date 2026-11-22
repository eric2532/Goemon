extends "res://tests/forest-shrine/sokia_desert_recovery_test.gd"
const FINE_REVIEW="res://build/Other Files/Asset Toolkit/Sokia Fine Scenery/"
func shot(label_:String,eye:Vector3,target:Vector3,fov:float,_refresh:bool=false):
 if DisplayServer.get_name()=="headless":return
 var before=paused;paused=true;game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for frame in 3:await process_frame
 RenderingServer.force_draw()
 var folder=FINE_REVIEW+("before/" if "--baseline" in OS.get_cmdline_user_args() else "after/")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 check(root.get_texture().get_image().save_png(folder+label_+".png")==OK,"Captured "+label_)
 game.set_process(true);game.ui.show();paused=before
func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var signatures={}
 for area in ["sokia_coast","sokia_desert"]:
  await open_area(area);signatures[area]=collision_signature()
  if not "--baseline" in OS.get_cmdline_user_args():
   var expected=0;var actual=0
   for row in Sokia.Data.SCENERY[area]:
    if row[1] in Sokia.Details.Data.PALMS:expected+=1
   for batch in game.world.find_children("NativeSokiaPalm_*","MultiMeshInstance3D",true,false):
    actual+=batch.multimesh.instance_count
    check(batch.multimesh.mesh==Sokia.Details.palm(batch.get_meta("source_graphic")),"Native palms share one complete cached 3D variant")
   check(actual==expected,"Every native palm anchor uses its matching solid variant in "+area)
   var cliff=game.world.find_child("ArchivedCliffForms",true,false)
   check(cliff.material_override.get_shader_parameter("cliff_face")==preload("res://assets/maps/falan/sokia_cliff_face.png"),"Source contour refinements preserve the recovered sandstone paint")
  var cell=Vector2(285,315) if area=="sokia_coast" else Vector2(414,298)
  var point=game.model.world_point(Tour.Regions.frame(area).inverse()*(cell*3))
  await shot(area,point+Vector3(55,68,70),point,62)
 if "--baseline" in OS.get_cmdline_user_args():
  var file=FileAccess.open(FINE_REVIEW+"collision-before.json",FileAccess.WRITE);file.store_string(JSON.stringify(signatures))
 else:
  check(signatures==JSON.parse_string(FileAccess.get_file_as_string(FINE_REVIEW+"collision-before.json")),"Fine scenery preserves all source physics, native plans and travel links")
  var variants={}
  for serial in Sokia.Details.Data.PALMS:
   var mesh=Sokia.Details.palm(serial);var arrays=mesh.surface_get_arrays(0);var valid=true
   for normal:Vector3 in arrays[Mesh.ARRAY_NORMAL]:
    if not normal.is_finite() or normal.length_squared()<.5:valid=false
   check(valid,"Prepared trunk and feathered fronds have finite normals: "+str(serial))
   check(mesh.get_surface_count()==1 and mesh.get_aabb().size.z>1 and mesh.get_aabb().size.y>2,"Native palms have complete solid crowns and trunks")
   variants[serial]={"bounds":str(mesh.get_aabb()),"triangles":mesh.get_faces().size()/3}
  var file=FileAccess.open(FINE_REVIEW+"palm-meshes.json",FileAccess.WRITE);file.store_string(JSON.stringify(variants,"  "))
  if DisplayServer.get_name()!="headless":
   var study=Node3D.new();study.position=Vector3(2000,0,2000)*game.model.falan_scale;study.scale=Vector3.ONE*game.model.falan_scale;game.world.add_child(study)
   var floor_=PlaneMesh.new();floor_.size=Vector2(40,29);Geo.mesh(study,floor_,Vector3.ZERO,Geo.mat("b8ad91"))
   var ids=[11188,11189,11194,11197,11203,11207]
   for i in ids.size():Geo.mesh(study,Sokia.Details.palm(ids[i]),Vector3((i%3-1)*11,0,(i/3)*12-6),null)
   await shot("palm-families-front",study.to_global(Vector3(20,17,36)),study.to_global(Vector3(0,5,0)),52)
   await shot("palm-families-back",study.to_global(Vector3(-21,17,-36)),study.to_global(Vector3(0,5,0)),52)
   study.queue_free()
 print("SOKIA_FINE_RESULT checks=",checks," failures=",errors)
