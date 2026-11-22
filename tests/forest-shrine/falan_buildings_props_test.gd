extends "res://tests/forest-shrine/falan_city_recovery_test.gd"
const RECOVERY="res://build/Other Files/Asset Toolkit/Falan Buildings and Props/"
const Houses=preload("res://scripts/forest/forest_falan_houses.gd")
const Lamps=preload("res://scripts/forest/forest_falan_lamps.gd")

func position_at(p:Vector2):
 await super.position_at(p)
 for i in 4:await physics_frame

func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 if DisplayServer.get_name()=="headless":return
 print("FALAN_VIEW ",name_," paused=",paused," time_scale=",Engine.time_scale," visible=",root.visible)
 var stage="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECOVERY+stage))
 game.ui.hide();game.set_process(false);root.grab_focus()
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(RECOVERY+stage+"/"+name_+".png")==OK,"Captured "+name_)
 game.set_process(true);game.ui.show()

func check_east_il_road():
 game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 var scale_:float=game.model.falan_scale
 var signature=collider_signature()
 if "--baseline" in OS.get_cmdline_user_args():
  var baseline=FileAccess.open(RECOVERY+"obstacles-before.txt",FileAccess.WRITE);baseline.store_string(signature)
 else:
  check(signature==FileAccess.get_file_as_string(RECOVERY+"obstacles-before.txt"),"Unrelated scenery matches the historical collider baseline")
  check_details()
 var house_cache=Houses.meshes.duplicate()
 var lamp_cache=Lamps.meshes.duplicate()
 await shot("residential-block",Vector3(-270,22,-75)*scale_,Vector3(-298,12,-115)*scale_,62)
 await shot("market-block",Vector3(-50,25,-100)*scale_,Vector3(-100,12,-145)*scale_,62)
 await shot("canal-houses",Vector3(-140,24,215)*scale_,Vector3(-205,12,245)*scale_,62)
 if DisplayServer.get_name()!="headless" and "--baseline" not in OS.get_cmdline_user_args():
  var study=Node3D.new();game.world.add_child(study)
  study.position=Vector3(2000,0,2000)*scale_;study.scale=Vector3.ONE*scale_
  var floor_=PlaneMesh.new();floor_.size=Vector2(130,30)
  Geo.mesh(study,floor_,Vector3(50,-.02,0),Geo.mat("81967c"))
  for style in 6:Houses.batch(study,"falan_townhouse",style,[Transform3D(Basis.IDENTITY,Vector3(style*20,0,-6))])
  var serials=[10422,10423,10424,10428,10429,10611,10612]
  for i in serials.size():Lamps.batch(study,serials[i],[Transform3D(Basis.IDENTITY,Vector3(i*3.5,0,6))])
  await shot("source-model-study",study.position+Vector3(54,33,100)*scale_,study.position+Vector3(50,6,0)*scale_,52)
  await shot("colored-shops-study",study.position+Vector3(89,20,38)*scale_,study.position+Vector3(90,7,-6)*scale_,48)
  await shot("10003-source-view",study.position+Vector3(41,16,26)*scale_,study.position+Vector3(60,7,-6)*scale_,42)
  await shot("10003-family-study",study.position+Vector3(79,16,26)*scale_,study.position+Vector3(60,7,-6)*scale_,42)
  await shot("10605-pilot-study",study.position+Vector3(59,13,26)*scale_,study.position+Vector3(40,6,-6)*scale_,42)
  for style in range(6,12):Houses.batch(study,"falan_townhouse",style,[Transform3D(Basis.IDENTITY,Vector3((style-6)*20,0,55))])
  await shot("windowed-houses-study",study.position+Vector3(54,33,155)*scale_,study.position+Vector3(50,6,55)*scale_,52)
  await shot("10081-grille-study",study.position+Vector3(19,17,85)*scale_,study.position+Vector3(0,6,55)*scale_,42)
  await shot("10308-flowers-study",study.position+Vector3(119,17,85)*scale_,study.position+Vector3(100,6,55)*scale_,42)
  for style in range(12,15):Houses.batch(study,"falan_townhouse",style,[Transform3D(Basis.IDENTITY,Vector3((style-12)*20,0,105))])
  await shot("remaining-source-houses",study.position+Vector3(24,24,161)*scale_,study.position+Vector3(20,7,105)*scale_,48)
  for style in [15,16]:Houses.batch(study,"falan_townhouse",style,[Transform3D(Basis.IDENTITY,Vector3((style-15)*20,0,155))])
  await shot("long-house-variants",study.position+Vector3(14,20,203)*scale_,study.position+Vector3(10,7,155)*scale_,48)
  study.queue_free()
  for i in 2:await process_frame
 await super.check_east_il_road()
 for key in house_cache:check(is_same(Houses.meshes[key],house_cache[key]),"City returns reuse prepared house meshes")
 for key in lamp_cache:check(is_same(Lamps.meshes[key],lamp_cache[key]),"City returns reuse prepared lamp meshes")
 print("FALAN_BUILDINGS_PROPS_RESULT checks=",checks," failures=",errors)

func check_details():
 var architecture=game.model.CityArchitecture
 var count=0;var lamps=0;var styles={}
 for batch in game.world.find_children("*","MultiMeshInstance3D",true,false):
  if batch.has_meta("falan_architecture_graphic"):
   var serial:int=batch.get_meta("falan_architecture_graphic")
   count+=batch.multimesh.instance_count
   check(is_same(batch.multimesh.mesh,architecture.prepare(serial)),"Source houses share their cached solid mesh")
   var mesh:Mesh=batch.multimesh.mesh
   check(mesh.get_surface_count()==2,"Prepared native facade parts and slate roofs use two shared surfaces")
   check(mesh.surface_get_material(0).get_shader_parameter("base_texture")==architecture.Atlas,"Facades retain rectified native windows, doors and timber")
   check(mesh.surface_get_material(1).get_shader_parameter("architecture_roof")==true,"Slate rows stay on the roof surface")
   var valid=true
   for surface in mesh.get_surface_count():
    var arrays=mesh.surface_get_arrays(surface)
    for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:valid=valid and p.is_finite()
    for n:Vector3 in arrays[Mesh.ARRAY_NORMAL]:valid=valid and n.is_finite() and n.length_squared()>.9
   check(valid,"Source-contour meshes have finite vertices and outward unit normals")
   var bounds=mesh.get_aabb()
   check(bounds.size.x>5 and bounds.size.z>5 and bounds.size.y>5 and bounds.end.y<45,"Native buildings retain bounded solid volume")
  if batch.has_meta("falan_lamp_graphic"):
   lamps+=batch.multimesh.instance_count;styles[batch.get_meta("falan_lamp_graphic")]=true
 check(count==architecture.Data.BINDINGS.size()+architecture.Data.UNMARKED.size(),"All 72 native ordinary houses render exactly once")
 check(lamps>25 and styles.size()==7,"All seven original city lamp families remain")
 for anchor in Houses.Data.LEGACY:
  var original:Dictionary=game.model.props[anchor]
  check(Houses.source_centered(game.model,anchor),"Every unchanged source house uses its native position")
  for changed in [original.merged({"rotation":original.rotation+1},true),original.merged({"scale":original.scale+.01},true)]:
   check(Houses.family(anchor,changed)==-1,"Edited house appearances retain their saved ownership")
  check(Houses.family(Vector3i(anchor.x,anchor.y,10000),original)==-1,"Raised custom house anchors remain separate")
 print("FALAN_RECOVERED houses=",count," lamps=",lamps," styles=",styles.size())

func collider_signature()->String:return model_signature(game.model)

static func model_signature(model)->String:
 var workshop=preload("res://scripts/forest/forest_falan_workshop.gd")
 var magic=preload("res://scripts/forest/forest_falan_magic_shop.gd")
 var special=preload("res://scripts/forest/forest_falan_special_exteriors.gd")
 # Compare unaffected scenery with the historical baseline; validate the corrected source footprint separately.
 var normalized={}
 var keys=model.trees.keys()+model.rocks.keys()+model.props.keys()
 for key in keys:
  if normalized.has(key):continue
  if (workshop.active(model) and key in workshop.MARKERS) or (magic.active(model) and key is Vector2i and key==magic.ANCHOR) or not special.spec(model,key).is_empty() or special.retired(model,key) or Houses.source_centered(model,key):
   var item=model.props[key]
   var box=preload("res://scripts/forest/forest_scenery.gd").bounds(item.kind,item.scale,item.rotation)
   box.position+=model.scenery_point(key);normalized[key]=box
  elif model.props.has(key) and not model.CivicExterior.shell(key,model.props[key]).is_empty():
   var spec:Array=model.CivicExterior.shell(key,model.props[key]);var size_:Vector3=spec[4];var at:Vector2=spec[3]
   normalized[key]=AABB(Vector3(at.x-size_.x*.5,model.scenery_point(key).y,at.y-size_.z*.5),size_)
  elif model.scenery_obstacles.has(key):normalized[key]=model.scenery_obstacles[key]
 # Regenerate the historical garden filtering against the restored old blocks.
 var current_obstacles=model.scenery_obstacles;var current_cells=model.scenery_cells
 model.scenery_obstacles=normalized;model.scenery_cells={}
 var scenery=preload("res://scripts/forest/forest_scenery.gd")
 for key in normalized:
  var local:AABB=normalized[key];local.position-=model.scenery_point(key)
  for tile in scenery.footprint(scenery.cell(key),local):
   if not model.scenery_cells.has(tile):model.scenery_cells[tile]=[]
   model.scenery_cells[tile].append(key)
 var fort=[]
 for row in model.CityFortifications.Data.FORTIFICATIONS:
  if row[1] in [10646,10662]:continue
  var extent=Vector3(9,17.5,9)
  if row[1]==10640:extent=Vector3(9.02,13.3,4.6)
  elif row[1]==10641:extent=Vector3(4.6,13.3,9.02)
  elif row[1] in range(10642,10646):extent=Vector3(5.4,8.6,5.4)
  fort.append(model.CityFortifications.Court.bounds(row[0],extent))
 for i in fort.size():model.register_archive_obstacle(fort[i],i)
 var garden=model.CityGardens.plan(model)
 for i in garden.obstacles.size():model.register_archive_obstacle(garden.obstacles[i][0],fort.size()+i)
 var signature=var_to_str(model.scenery_obstacles).sha256_text()
 model.scenery_obstacles=current_obstacles;model.scenery_cells=current_cells
 return signature
