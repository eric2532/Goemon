extends "res://tests/forest-shrine/falan_buildings_props_test.gd"
const Workshop=preload("res://scripts/forest/forest_falan_workshop.gd")

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 check(Workshop.active(game.model),"Both original workshop markers activate one exterior")
 var nodes=game.world.find_children("RecoveredFalanWorkshop10301","MeshInstance3D",true,false)
 check(nodes.size()==1,"The two workshop placeholders render as one cached assembly")
 if not nodes.is_empty():
  check(is_same(nodes[0].mesh,Workshop.prepare()),"Workshop instances reuse the prepared solid mesh")
  var bounds:AABB=nodes[0].mesh.get_aabb()
  check(Workshop.Proportions.matches(nodes[0].mesh,"special_10301",0),"Workshop height and width match its native source")
  var sane=true
  for part in nodes[0].mesh.get_surface_count():
   for normal:Vector3 in nodes[0].mesh.surface_get_arrays(part)[Mesh.ARRAY_NORMAL]:
    if not normal.is_finite() or normal.y<-.001:sane=false
  check(sane,"Workshop walls and roof faces point outward")
 for anchor in Workshop.MARKERS:
  var original=game.model.props[anchor]
  var changed=original.duplicate();changed.rotation+=1;game.model.props[anchor]=changed
  check(not Workshop.active(game.model),"Rotating either workshop marker restores its custom appearance")
  game.model.props[anchor]=original
  game.model.scenery_heights[anchor]=.1
  check(not Workshop.active(game.model),"Raising either workshop marker keeps its custom appearance")
  game.model.scenery_heights.erase(anchor)
 check(not game.model.scenery_obstacles.has(Vector2i(-35,24)),"The obsolete second workshop block no longer obstructs the source street")
 var source_box:AABB=game.model.scenery_obstacles[Vector2i(-38,26)]
 check(Vector2(source_box.position.x,source_box.position.z).is_equal_approx(Vector2(Workshop.ORIGIN.x+Workshop.BODY.position.x,Workshop.ORIGIN.z+Workshop.BODY.position.z)),"Workshop collision follows the original source footprint")
 for door in [Vector2(-219,159),Vector2(-219,141)]:
  check(not source_box.has_point(Vector3(door.x,1,door.y)),"Both original workshop door positions remain outside the wall")
 var scale_:float=game.model.falan_scale
 await shot("workshop-city",Vector3(-192,24,179)*scale_,Vector3(-229,7,150)*scale_,54)
 await shot("workshop-smith-entrance",Vector3(-202,10,171)*scale_,Vector3(-220,5,159)*scale_,48)
 await shot("workshop-second-entrance",Vector3(-202,10,131)*scale_,Vector3(-220,5,141)*scale_,48)
 for index in 2:
  await room(1071,index)
  if Tour.area(game.model)!="interior":return
  var exits=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="city")
  check(not exits.is_empty(),"Workshop interior retains its original city exits")
  if exits.is_empty():return
  await position_at(exits[mini(index,exits.size()-1)].at)
  if Tour.area(game.model)=="interior":await walk_through_entry()
  check(Tour.area(game.model)=="city","Both workshop door routes return to Falan")
 var cached=Workshop.prepare()
 await super.check_east_il_road()
 check(is_same(cached,Workshop.prepare()),"Gate returns reuse the workshop mesh")
 print("FALAN_WORKSHOP_RESULT checks=",checks," failures=",errors)
