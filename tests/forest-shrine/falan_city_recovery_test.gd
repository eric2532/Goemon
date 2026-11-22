extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Reuse the tour's normal title/Equipment/Enter Map setup with --east-il-road.
const REVIEW="res://build/Other Files/Asset Toolkit/Falan City Recovery/"
var checks=0

func check(ok:bool,message:String):
 checks+=1
 super.check(ok,message)

func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 if DisplayServer.get_name()=="headless":return
 var stage="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"City Recovery"))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+stage))
 await super.shot("City Recovery/"+name_,eye,target,fov,refresh_army)
 check(DirAccess.copy_absolute(ProjectSettings.globalize_path(OUT+"City Recovery/"+name_+".png"),
  ProjectSettings.globalize_path(REVIEW+stage+"/"+name_+".png"))==OK,"Saved matched city view")

func check_east_il_road():
 game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 game.camera_rig.camera.far=5000
 var before="--baseline" in OS.get_cmdline_user_args()
 var venture:Dictionary=get_meta("falan_venture")
 var saved=JSON.stringify(venture)
 var scale_:float=game.model.falan_scale
 if not before:
  check(not game.model.terrain.uses_baked_apron(),"Falan has no inherited valley apron")
  var heights:PackedFloat32Array=game.model.terrain.terrain_field().get_meta("heights")
  var highest=0.0
  for height in heights:highest=maxf(highest,height)
  check(highest<=6.01,"Only archived city ground heights remain, without the old cliff rim")
  check(not game.model.terrain.contains(-477,-477),"Retired valley terrain does not open native paths outside the city")
  check(game.world.find_children("Foliage_*","Node3D",true,false).is_empty(),"City dressing uses source gardens, without random valley foliage")
  check(game.world.find_children("terraced_mountain_*","MultiMeshInstance3D",true,false).is_empty(),"The old mountain ring is absent")
  check(game.world.find_children("mossy_boulder_*","MultiMeshInstance3D",true,false).is_empty(),"The source city has no invented boulder dressing")
  var pond=game.world.find_child("OriginalFalanPond",true,false)
  check(pond is MeshInstance3D,"The pond uses recovered original artwork")
  if pond is MeshInstance3D:
   var points:PackedVector3Array=pond.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   var centers={}
   for i in range(0,points.size(),6):
    var center=(points[i]+points[i+2])*.5
    centers[Vector2(center.x,center.z)]=true
   check(centers.size()==9 and (game.model.CityGardens.Data.LILY_TILES+game.model.CityGardens.POND_WATER).all(func(p):return centers.has(p)),"Every original lily/water tile keeps its exact source anchor")
  var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
  check(npcs!=null and npcs.get_child_count()==78,"All original city NPCs remain")
 await shot("employment-office",Vector3(-220,18,-78)*scale_,Vector3(-252,8,-116)*scale_,65)
 await shot("western-pond",Vector3(-330,23,55)*scale_,Vector3(-350,5.5,34)*scale_,62)
 await shot("city-overview",Vector3(450,650,650)*scale_,Vector3(0,5,0)*scale_,64)
 if not before:
  for area in ["freyja","east_gate","south_gate"]:
   if Tour.area(game.model)!="city":return
   var edge:float=Tour.Frontier.OUTER_EDGE[area]
   await position_at(Tour.Frontier.to_city(area,Vector2(3,edge-1)))
   await position_at(Tour.Frontier.to_city(area,Vector2(3,edge+1)))
   check(Tour.area(game.model)==area,"City still crosses its original "+area)
   if Tour.area(game.model)!=area:return
   var inner:float=Tour.Frontier.INNER_EDGE[area]
   await position_at(Vector2(3,inner+1))
   await position_at(Vector2(3,inner-1))
   check(Tour.area(game.model)=="city","The original gate returns to Falan from "+area)
  check(JSON.stringify(venture)==saved,"City recovery never rewrites the saved adventure")
  var layout:Dictionary=venture.falan_areas.city.duplicate(true)
  layout.rocks=[{"x":-35,"z":-20,"scale":.7,"rotation":23.0}]
  layout.props.append({"kind":"moss_rock","x":-34,"z":-20,"scale":.8,"rotation":41.0,"height":1.0})
  var custom=Doc.Model.new()
  custom.reset(42,{},layout,false)
  check(custom.rocks.has(Vector2i(-35,-20)) and custom.rocks[Vector2i(-35,-20)].scale==.7,"User-placed rocks remain saved scenery")
  var anchor=custom.Scenery.anchor(layout.props[-1])
  check(custom.props.get(anchor,{}).get("kind")=="moss_rock" and custom.scenery_heights.get(anchor)==1.0,"User-placed reusable rocks retain their type and height")
  check(FileAccess.file_exists("res://assets/models/environments/wind_meadow/mossy_boulder.glb"),"The reusable rock master/export remains available")
  var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/forest-shrine/reference/maps/forest_falan_city.json"))
  legacy.trees=[{"x":-32,"z":74,"scale":1.14,"rotation":270}]
  check(Doc.validate(legacy).is_empty(),"Exact retired tree markers remain loadable at the archive edge")
  legacy.trees[0].rotation=271
  check(not Doc.validate(legacy).is_empty(),"Changed user scenery still receives the dry-ground check")
 print("FALAN_CITY_RECOVERY_RESULT checks=",checks," failures=",errors," nodes=",get_node_count()," resources=",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
