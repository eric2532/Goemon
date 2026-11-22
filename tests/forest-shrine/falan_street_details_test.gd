extends "res://tests/forest-shrine/falan_city_recovery_test.gd"
const Details=preload("res://scripts/forest/forest_falan_street_details.gd")
const Streets=preload("res://scripts/forest/forest_falan_streets.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const DETAIL_OUT="res://build/Other Files/Asset Toolkit/Falan City Details/"

func _initialize():
 create_timer(420).timeout.connect(func():printerr("FALAN_STREET_DETAILS_TIMEOUT");quit(1))
 run.call_deferred()

func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 if DisplayServer.get_name()=="headless":return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DETAIL_OUT+"after"))
 game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(DETAIL_OUT+"after/"+name_+".png")==OK,"Captured "+name_)
 game.set_process(true);game.ui.show()

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 game.camera_rig.camera.far=5000
 var s:float=game.model.falan_scale
 var serials=[10413,10415,10416,10417,10419,11496,11497,10426,10427,10452,10453]
 var metrics={};var cache={}
 for serial in serials:
  var mesh:Mesh=Details.prepare(serial);cache[serial]=mesh
  var bounds=mesh.get_aabb();var triangles=0;var valid=true
  for surface in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(surface)
   var indices=arrays[Mesh.ARRAY_INDEX]
   triangles+=arrays[Mesh.ARRAY_VERTEX].size()/3 if indices==null or indices.is_empty() else indices.size()/3
   for vertex:Vector3 in arrays[Mesh.ARRAY_VERTEX]:valid=valid and vertex.is_finite()
   for normal:Vector3 in arrays[Mesh.ARRAY_NORMAL]:valid=valid and normal.is_finite() and normal.length_squared()>.5
  check(valid,"Street detail has finite solid geometry: "+str(serial))
  check(bounds.position.y>=-.01 and bounds.end.y<3.7,"Street detail fits its source height: "+str(serial))
  check(mesh.get_surface_count()<=2,"Street detail shares at most two cached material surfaces")
  if serial in [10413,10415,10416,11496,11497]:
   check(mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX].size()==12,"Both sign faces retain original lettering without mirrored text")
   check(mesh.surface_get_material(1).get_shader_parameter("base_texture")==Details.Atlas,"Sign faces use the original street atlas")
  if serial in [10417,10419]:check(mesh.get_surface_count()==1,"Native fence and bollard have no invented sign panel")
  if serial in [11496,11497]:check(triangles>=170,"Oval signboards retain solid sides and backs in the rendered index buffer")
  if serial in [10426,10427,10452,10453]:
   check(is_equal_approx(bounds.end.y,Details.planter_height(serial)),"Tall and short brick beds keep distinct source heights")
  metrics[str(serial)]={"triangles":triangles,"surfaces":mesh.get_surface_count(),"bounds":str(bounds)}
 var counts={}
 for node in game.world.find_children("RecoveredFalanStreetDetail*","MeshInstance3D",true,false):
  var serial:int=node.get_meta("original_graphic");counts[str(serial)]=counts.get(str(serial),0)+1
  check(is_same(node.mesh,cache[serial]),"Placed source props share their immutable prepared mesh")
  var p:Vector3=node.position
  check((Streets.Data.PLANTERS+Streets.Data.MARKET_GOODS).any(func(row):return row[1]==serial and row[0]==Vector2(p.x,p.z)),"Street details keep their native city station")
  check(is_equal_approx(node.rotation.y,Details.yaw(serial)),"Native paired signs retain their original facing")
 var batches=game.world.find_children("RecoveredFalanPlanters*","MultiMeshInstance3D",true,false)
 for node in batches:
  var serial:int=node.get_meta("original_graphic");var count:int=node.multimesh.instance_count
  counts[str(serial)]=counts.get(str(serial),0)+count
  check(is_same(node.multimesh.mesh,cache[serial]),"Local planter batches share the prepared solid mesh")
  if DisplayServer.get_name()!="headless":
   for i in count:
    var pose:Transform3D=node.multimesh.get_instance_transform(i)
    var at=Vector2(pose.origin.x,pose.origin.z)
    check(Streets.Data.PLANTERS.any(func(row):return row[1]==serial and row[0]==at),"Every rendered planter retains its original source station")
    check(pose.basis.is_equal_approx(Basis.IDENTITY),"Planter batches preserve the native wall orientation")
 for serial in serials:
  var native=(Streets.Data.PLANTERS+Streets.Data.MARKET_GOODS).any(func(row):return row[1]==serial)
  check(counts.has(str(serial))==native,"City displays only families actually placed in source map: "+str(serial))
 if DisplayServer.get_name()!="headless":
  var study=Node3D.new();game.world.add_child(study);study.position=Vector3(2500,0,2500)*s;study.scale=Vector3.ONE*s
  var floor_=PlaneMesh.new();floor_.size=Vector2(35,22)
  Geo.mesh(study,floor_,Vector3(10,-.02,0),Geo.mat("82927c"))
  for i in serials.size():
   var serial:int=serials[i];var at=Vector3((i%7)*3.8,0,0 if i<7 else 7)
   Details.place(study,serial,at)
   if i>=7:Geo.mesh(study,Details.foliage(serial),at,null)
   var eye=Vector3(-4,3.8,5.5) if Details.yaw(serial)!=0 else Vector3(-2.4,3.8,6)
   await shot("source-%d-study"%serial,study.position+(at+eye)*s,study.position+(at+Vector3.UP*1.5)*s,44)
  await shot("street-prop-lineup",study.position+Vector3(10,13,25)*s,study.position+Vector3(10,1.2,3.5)*s,60)
  study.queue_free()
  var signs=game.world.find_children("RecoveredFalanStreetDetail11496_*","MeshInstance3D",true,false).filter(func(node):return is_equal_approx(node.position.x,165.0))
  check(signs.size()==1,"Eastern shop sign is available for its in-city review")
  if signs.size()==1:
   var at:Vector3=signs[0].global_position
   await shot("eastern-shop-sign",at+Vector3(-6,4,7)*s,at+Vector3.UP*1.7*s,52)
  var beds=batches.filter(func(node):return node.get_meta("original_graphic")==10426)
  check(not beds.is_empty(),"A placed native brick bed is available for its in-city review")
  if not beds.is_empty():
   var at:Vector3=beds[0].to_global(beds[0].multimesh.get_instance_transform(0).origin)
   await shot("city-brick-planters",at+Vector3(-6,6,8)*s,at+Vector3.UP*s,58)
 var report=FileAccess.open(DETAIL_OUT+"mesh-counts.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"meshes":metrics,"city_instances":counts,"planter_batches":batches.size()},"  "))
 await super.check_east_il_road()
 for serial in cache:check(is_same(cache[serial],Details.meshes[serial]),"Three city returns reuse the same street detail mesh")
 print("FALAN_STREET_DETAILS_RESULT checks=",checks," failures=",errors)
