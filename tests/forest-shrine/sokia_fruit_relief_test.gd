extends "res://tests/forest-shrine/sokia_fine_scenery_test.gd"
const FRUIT_REVIEW="res://build/Other Files/Asset Toolkit/Sokia Fruit Relief/"
func shot(label_:String,eye:Vector3,target:Vector3,fov:float,_refresh:bool=false):
 if DisplayServer.get_name()=="headless":return
 var before=paused;paused=true;game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for frame in 3:await process_frame
 RenderingServer.force_draw()
 var folder=FRUIT_REVIEW+("before/" if "--baseline" in OS.get_cmdline_user_args() else "after/")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 check(root.get_texture().get_image().save_png(folder+label_+".png")==OK,"Captured "+label_)
 game.set_process(true);game.ui.show();paused=before
func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var signatures={}
 for area in ["sokia_coast","sokia_desert","kili"]:
  await open_area(area);signatures[area]=collision_signature()
  var cell=Vector2(285,315) if area=="sokia_coast" else Vector2(414,298)
  var point=game.model.world_point(Vector2.ZERO if area=="kili" else Tour.Regions.frame(area).inverse()*(cell*3))
  await shot(area,point+Vector3(55,68,70),point,62)
  if area=="sokia_coast":
   var mouth=game.model.world_point(Tour.Regions.frame(area).inverse()*(Vector2(356,334)*3))
   await shot("cliff-strata",mouth+Vector3(-18,9,-10)*game.model.falan_scale,mouth+Vector3.UP*3.5*game.model.falan_scale,57)
 var study=Node3D.new();study.position=Vector3(2000,0,2000)*game.model.falan_scale;study.scale=Vector3.ONE*game.model.falan_scale;game.world.add_child(study)
 var floor_=PlaneMesh.new();floor_.size=Vector2(28,15);Geo.mesh(study,floor_,Vector3.ZERO,Geo.mat("b8ad91"))
 for i in 3:Geo.mesh(study,Sokia.Details.palm([11194,11196,11204][i]),Vector3((i-1)*8,0,0),null)
 await shot("leaves-and-fruit",study.to_global(Vector3(15,11,22)),study.to_global(Vector3(0,4,0)),52)
 var crown=Sokia.Details.crown_point(11204)
 var fruit_target=Vector3(8.15,crown.y-.75,.4)
 await shot("fruit-close",study.to_global(fruit_target+Vector3(1.85,.35,4.6)),study.to_global(fruit_target),43)
 study.queue_free()
 if "--baseline" in OS.get_cmdline_user_args():
  var file=FileAccess.open(FRUIT_REVIEW+"collision-before.json",FileAccess.WRITE);file.store_string(JSON.stringify(signatures))
 else:
  check(signatures==JSON.parse_string(FileAccess.get_file_as_string(FRUIT_REVIEW+"collision-before.json")),"Fruit, leaves and cliff relief preserve player physics, native plans and travel links")
  check(Sokia.Details.Data.FRUITS.keys()==[11204] and Sokia.Details.Data.FRUITS[11204].size()==6,"Only the recorded fruit palm carries the six native yellow lobes")
  check(Sokia.Details.Data.PALMS[11196][5].is_empty(),"The original single-trunk broad-leaf palm has no invented companion trunk")
  for serial in [11194,11195,11196,11204]:
   var mesh=Sokia.Details.palm(serial);var arrays=mesh.surface_get_arrays(0);var valid=true;var fruit=[];var dry=0
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
    if not normal.is_finite() or normal.length_squared()<.5:valid=false
    if serial==11204 and arrays[Mesh.ARRAY_TEX_UV2][i]==Sokia.Details.Data.TILES.fruit_11204:fruit.append(arrays[Mesh.ARRAY_VERTEX][i])
    if serial==11194 and arrays[Mesh.ARRAY_TEX_UV2][i]==Sokia.Details.Data.TILES.dry_leaf_11194:dry+=1
   check(valid and mesh.get_surface_count()==1,"Native leaf folds and fruit retain finite normals and the complete shared mesh")
   if serial==11194:check(dry>500,"The dry lower crown uses its own native gold paint")
   if serial==11204:
    check(fruit.size()>1000 and Sokia.Details.Data.FRUIT_SHAPES[11204].size()==6,"All six source-profiled solid fruits use the native fruit paint")
    check(fruit.all(func(p):return p.y<crown.y and p.y>crown.y-1.5 and p.z>crown.z+.08),"Solid fruit hangs beneath the crown on the visible side of its stalk")
  var old=SurfaceTool.new();old.begin(Mesh.PRIMITIVE_TRIANGLES)
  Entrances.ridge(old,Vector3.ZERO,Vector2(4,4),12,12557,true)
  old.generate_normals();var original=old.commit()
  var detailed=SurfaceTool.new();detailed.begin(Mesh.PRIMITIVE_TRIANGLES)
  Entrances.ridge(detailed,Vector3.ZERO,Vector2(4,4),12,12557,true,.5)
  detailed.generate_normals();var refined=detailed.commit()
  check(refined.get_faces().size()>original.get_faces().size(),"Native cliff strata add real inset geometry")
  check(original.get_aabb().grow(.002).encloses(refined.get_aabb()),"Strata keep the established rock silhouette and footprint")
  var vertices=refined.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  check(Array(original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]).all(func(p):return Array(vertices).any(func(q):return p.distance_to(q)<.002)),"Every original crag silhouette vertex survives the carved seam")
 print("SOKIA_FRUIT_RESULT checks=",checks," failures=",errors)
