extends "res://tests/forest-shrine/falan_street_details_test.gd"
const Houses=preload("res://scripts/forest/forest_falan_houses.gd")

func _initialize():
 create_timer(600).timeout.connect(func():printerr("FALAN_PLANTER_RECOVERY_TIMEOUT");quit(1))
 run.call_deferred()

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var s:float=game.model.falan_scale
 var seen={};var counts={}
 for batch in game.world.find_children("RecoveredFalanPlanters*","MultiMeshInstance3D",true,false):
  var serial:int=batch.get_meta("original_graphic")
  counts[serial]=counts.get(serial,0)+batch.multimesh.instance_count
  if DisplayServer.get_name()!="headless":
   for i in batch.multimesh.instance_count:
    var p:Vector3=batch.multimesh.get_instance_transform(i).origin
    var at=Vector2(p.x,p.z)
    check(not seen.has(at),"Each original planter station renders exactly once")
    seen[at]=serial
 for row in Streets.Data.PLANTERS:
  if DisplayServer.get_name()!="headless":check(seen.get(row[0],0)==row[1],"All 226 stations retain their original graphic and exact anchor")
 for row in [[10426,72],[10427,46],[10452,64],[10453,44]]:
  check(counts.get(row[0],0)==row[1],"Every archived planter variant is present: "+str(row[0]))
 var links:Array=game.model.get_meta("falan_links")
 for row in Streets.Data.PLANTERS:
  var bounds: AABB=Details.prepare(row[1]).get_aabb()
  bounds.position+=Streets.ground(game.model,row[0])
  var clear=true
  for link in links:
   if bounds.grow(.55).has_point(game.model.world_point(link.at)/s):clear=false
  for npc in Tour.NPCS.AREAS.city:
   if bounds.grow(.35).has_point(game.model.world_point(npc[0])/s):clear=false
  check(clear,"Native planter geometry preserves live entrance and NPC access")
 var leaf_cache=Details.canopies.duplicate()
 for serial in [10426,10427,10452,10453]:
  var canopy:Mesh=Details.foliage(serial)
  var material:ShaderMaterial=canopy.surface_get_material(0)
  check(material.get_shader_parameter("source_paint")==Details.LeafAtlas and material.get_shader_parameter("source_cutout")==true,"Planter leaves use preserved native foliage paint on solid reused geometry")
  check(canopy.get_aabb().size.y>.2 and canopy.get_aabb().size.z>.5,"Planter foliage retains volume rather than a single billboard")
 for anchor in Houses.Data.SOURCE_CENTERS:
  var at:Vector2=Houses.Data.SOURCE_CENTERS[anchor]
  var expected=game.model.CityArchitecture.collision(Houses.ArchitectureData.BINDINGS[anchor][0])
  expected.position+=game.model.scenery_point(anchor)+Houses.offset(game.model,anchor)
  check(game.model.scenery_obstacles[anchor].is_equal_approx(expected),"The recovered house collider uses its source footprint")
  if DisplayServer.get_name()!="headless":
   var found=false
   for batch in game.world.find_children("*","MultiMeshInstance3D",true,false):
    if not batch.has_meta("falan_architecture_graphic") or batch.get_meta("falan_architecture_graphic")!=Houses.ArchitectureData.BINDINGS[anchor][0]:continue
    for i in batch.multimesh.instance_count:
     var origin:Vector3=batch.multimesh.get_instance_transform(i).origin
     if Vector2(origin.x,origin.z).is_equal_approx(at):found=true
   check(found,"The rendered house and collider share the exact recovered source center")
   var center=Streets.ground(game.model,at)
   await shot("restored-plot-%d-%d"%[anchor.x,anchor.y],(center+Vector3(-24,26,32))*s,(center+Vector3.UP*4)*s,55)
 for anchor in [Vector2i(-28,42),Vector2i(-14,36),Vector2i(-7,23),Vector2i(24,22)]:
  var entries=game.model.get_meta("falan_links").filter(func(link):return link.get("house_anchor")==anchor)
  check(entries.size()==1,"The preserved generic room has one clear entrance after recovery")
  if entries.size()!=1:continue
  var entry:Dictionary=entries[0]
  check(Streets.Data.PLANTERS.all(func(row):return row[0].distance_to(entry.at)>=2.60),"Generic room entrances no longer exclude native planter stations")
  var generic:Array=game.model.get_meta("falan_links").filter(func(link):return link.get("floor")==0)
  await room(0,generic.find(entry))
  if Tour.area(game.model)!="interior":return
  var exits=game.model.get_meta("falan_links").filter(func(link):return link.to=="city")
  check(not exits.is_empty(),"The preserved generic room retains its city return")
  if exits.is_empty():return
  await position_at(exits[0].at)
  if Tour.area(game.model)=="interior":await walk_through_entry()
  check(Tour.area(game.model)=="city","Relocated generic entrance returns to its source garden")
 await super.check_east_il_road()
 for serial in leaf_cache:check(is_same(leaf_cache[serial],Details.canopies[serial]),"Repeated city returns reuse native-painted canopy meshes")
 print("FALAN_PLANTER_RECOVERY_RESULT checks=",checks," failures=",errors)
