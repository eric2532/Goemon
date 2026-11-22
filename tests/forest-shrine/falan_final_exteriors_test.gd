extends "res://tests/forest-shrine/falan_magic_shop_test.gd"
const Special=preload("res://scripts/forest/forest_falan_special_exteriors.gd")

func _initialize():
 # Nine interior visits plus the full rendered family review need more than the base tour's 220 seconds.
 create_timer(600).timeout.connect(func():printerr("FALAN_FINAL_EXTERIORS_TIMEOUT");quit(1))
 run.call_deferred()

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 check(Special.retired(game.model,Special.RETIRED),"The exact extra placeholder is recognized as absent from the original city")
 check(not game.model.scenery_obstacles.has(Special.RETIRED),"The original garden gap has no invented house collision")
 var retired_item=game.model.props[Special.RETIRED]
 game.model.props[Special.RETIRED]=retired_item.merged({"rotation":1},true)
 check(not Special.retired(game.model,Special.RETIRED),"Edited extra placeholders remain user scenery")
 game.model.props[Special.RETIRED]=retired_item
 var source_rows=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/city_building_surfaces.json")).composites
 var meshes={}
 var metrics={}
 for anchor in Special.SPECS:
  var row:Array=Special.spec(game.model,anchor)
  check(not row.is_empty(),"Original marker activates source exterior "+str(Special.SPECS[anchor][0]))
  if row.is_empty():continue
  check(source_rows.any(func(source):return source.reference_graphic==row[0] and Vector2(source.source_center[0],source.source_center[1])==row[4] and Vector2(source.source_footprint[0],source.source_footprint[1])==row[5]),"Runtime source center and dimensions match the archived object")
  var nodes=game.world.find_children("RecoveredFalanExterior%d"%row[0],"MeshInstance3D",true,false)
  check(nodes.size()==1,"Exactly one solid exterior is built for source "+str(row[0]))
  var mesh:Mesh=Special.prepare(row);meshes[row[0]]=mesh
  var bounds:AABB=mesh.get_aabb()
  metrics[str(row[0])]={"triangles":mesh.get_faces().size()/3,"surfaces":mesh.get_surface_count(),"bounds":str(bounds),"source_footprint":str(row[5])}
  check(game.model.CityArchitecture.Proportions.matches(mesh,"special_%d"%row[0],row[7]),"Exterior height and width match the native source camera")
  var valid=true
  for part in mesh.get_surface_count():
   for normal:Vector3 in mesh.surface_get_arrays(part)[Mesh.ARRAY_NORMAL]:
    if not normal.is_finite():valid=false
  check(valid,"Source exterior geometry has finite normals")
  var original=game.model.props[anchor]
  for changed in [original.merged({"rotation":original.rotation+1},true),original.merged({"scale":original.scale+.01},true)]:
   game.model.props[anchor]=changed
   check(Special.spec(game.model,anchor).is_empty(),"Edited markers keep their custom source and collision")
  game.model.props[anchor]=original
  game.model.scenery_heights[anchor]=.1
  check(Special.spec(game.model,anchor).is_empty(),"Raised source markers keep their custom appearance")
  game.model.scenery_heights.erase(anchor)
  var doors=game.model.get_meta("falan_links",[]).filter(func(link):return link.get("floor",0)==row[8])
  check(not doors.is_empty(),"Original source room link is retained")
  for door in doors:
   var at:Vector2=door.at
   var p=Vector3(at.x,1,at.y)
   check(not game.model.scenery_obstacles.values().any(func(box):return box.grow(.55).has_point(p)),"Original room door has clear physical access: "+str(row[8]))
  var s:float=game.model.falan_scale;var center=Vector3(row[4].x,row[6]*.5,row[4].y)
  var offset=Basis(Vector3.UP,row[7])*Vector3(24,row[6]*.6+8,29)
  await shot("source-%d-city"%row[0],(center+offset)*s,center*s,52)
  if DisplayServer.get_name()!="headless":
   var study=MeshInstance3D.new();study.mesh=mesh;study.position=Vector3(2500,0,2500)*s;study.scale=Vector3.ONE*s;game.world.add_child(study)
   await shot("source-%d-study"%row[0],study.position+Vector3(25,row[6]*.7+10,30)*s,study.position+Vector3.UP*row[6]*.5*s,50)
   study.queue_free()
   for i in 2:await process_frame
  await room(row[8])
  if Tour.area(game.model)!="interior":return
  var exits=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="city")
  check(not exits.is_empty(),"Source room has its original return link")
  if exits.is_empty():return
  await position_at(exits[0].at)
  if Tour.area(game.model)=="interior":await walk_through_entry()
  check(Tour.area(game.model)=="city","Original room returns to its source building")
 await super.check_east_il_road()
 for anchor in Special.SPECS:
  var row:Array=Special.SPECS[anchor]
  check(is_same(meshes[row[0]],Special.prepare(row)),"City returns reuse every prepared distinctive mesh")
 var file=FileAccess.open(RECOVERY+"final-seven-meshes.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "))
 print("FALAN_FINAL_EXTERIORS_RESULT checks=",checks," failures=",errors)
