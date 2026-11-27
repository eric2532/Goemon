extends "res://tests/forest-shrine/falan_final_exteriors_test.gd"
const Architecture=preload("res://scripts/forest/forest_falan_architecture.gd")
const Streets=preload("res://scripts/forest/forest_falan_streets.gd")
const ARCH_OUT="res://build/Other Files/Asset Toolkit/Falan Architecture/"

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var cache=Architecture.meshes.duplicate()
 var expected={};var seen={};var counts={};var metrics={}
 for anchor in Architecture.Data.BINDINGS:
  var row:Array=Architecture.Data.BINDINGS[anchor]
  expected[row[1]]=row[0]
  var box=Architecture.collision(row[0]);box.position+=game.model.scenery_point(anchor)+Houses.offset(game.model,anchor)
  check(game.model.scenery_obstacles[anchor].is_equal_approx(box),"Collision and original house placement share one source footprint")
  var original=game.model.props[anchor]
  game.model.scenery_heights[anchor]=.1
  check(not Houses.source_centered(game.model,anchor),"Raised user scenery keeps its original transform")
  game.model.scenery_heights.erase(anchor)
  game.model.props.erase(anchor)
  check(not Houses.source_centered(game.model,anchor),"Deleted source markers remain deleted")
  game.model.props[anchor]=original
 for row in Architecture.Data.UNMARKED:expected[row[1]]=row[0]
 for batch in game.world.find_children("RecoveredFalanArchitecture*","MultiMeshInstance3D",true,false):
  var serial:int=batch.get_meta("falan_architecture_graphic")
  counts[serial]=counts.get(serial,0)+batch.multimesh.instance_count
  if DisplayServer.get_name()!="headless":
   for i in batch.multimesh.instance_count:
    var pose:Transform3D=batch.multimesh.get_instance_transform(i);var at=Vector2(pose.origin.x,pose.origin.z)
    check(expected.get(at,-1)==serial and not seen.has(at),"Each native house renders once with the correct original graphic")
    check(pose.basis.is_equal_approx(Basis(Vector3.UP,PI*.5)),"Source projection keeps its original world orientation")
    seen[at]=true
 if DisplayServer.get_name()!="headless":check(seen.size()==73,"All 73 native source house stations render")
 for serial in Architecture.Data.GRAPHICS:
  var mesh:Mesh=Architecture.prepare(serial);var triangles=0
  for part in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(part);var indices=arrays[Mesh.ARRAY_INDEX]
   triangles+=(indices.size() if indices!=null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
  metrics[str(serial)]={"instances":counts.get(serial,0),"triangles":triangles,"surfaces":mesh.get_surface_count(),"bounds":str(mesh.get_aabb())}
 var planter_counts={}
 for batch in game.world.find_children("RecoveredFalanPlanters*","MultiMeshInstance3D",true,false):
  var serial:int=batch.get_meta("original_graphic")
  planter_counts[serial]=planter_counts.get(serial,0)+batch.multimesh.instance_count
 for row in [[10426,72],[10427,46],[10452,64],[10453,44]]:check(planter_counts.get(row[0],0)==row[1],"All original planters remain after architecture recovery")
 var links:Array=game.model.get_meta("falan_links")
 for row in Tour.Indoor.Data.DOORS[1000]:
  check(links.any(func(link):return link.at==row[0] and link.get("floor",-1)==row[1]),"Native doorway position and destination remain exact")
  var floor=Vector3(row[0].x,game.model.surface_height(row[0].x,row[0].y)+.5,row[0].y)
  var blocked=[]
  for anchor in game.model.props:
   if Houses.source_centered(game.model,anchor) and game.model.scenery_obstacles[anchor].grow(.35).has_point(floor):blocked.append(anchor)
  for i in Architecture.Data.UNMARKED.size():
   if Architecture.unmarked_bounds(game.model,i).grow(.35).has_point(floor):blocked.append("unmarked %d"%i)
  check(blocked.is_empty(),"Native door remains clear of recovered house walls: "+str(row)+" blockers="+str(blocked))
 for npc in Tour.NPCS.AREAS.city:
  var at:Vector2=npc[0];var floor=Vector3(at.x,game.model.surface_height(at.x,at.y)+.5,at.y)
  var clear=true
  for anchor in Architecture.Data.BINDINGS:
   if game.model.scenery_obstacles[anchor].has_point(floor):clear=false
  for i in Architecture.Data.UNMARKED.size():
   if Architecture.unmarked_bounds(game.model,i).has_point(floor):clear=false
  check(clear,"Original NPC station remains outside recovered house walls: "+str(at))
 for anchor in Architecture.Data.BINDINGS:
  var row:Array=Architecture.Data.BINDINGS[anchor]
  if not metrics[str(row[0])].has("capture"):
   metrics[str(row[0])].capture=true
   var at=Vector3(row[1].x,game.model.surface_height(row[1].x,row[1].y),row[1].y)
   var s:float=game.model.falan_scale
   await shot("architecture-%d-city"%row[0],(at+Vector3(34,Architecture.Proportions.height("house_%d"%row[0],15)*.6+20,34))*s,(at+Vector3.UP*Architecture.Proportions.height("house_%d"%row[0],15)*.5)*s,50)
 var file=FileAccess.open(ARCH_OUT+"procedural-meshes.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "));file.close()
 await super.check_east_il_road()
 for serial in cache:check(is_same(cache[serial],Architecture.meshes[serial]),"Interior and gate returns reuse the same prepared architecture")
 print("FALAN_ARCHITECTURE_RESULT checks=",checks," failures=",errors)
