extends "res://tests/forest-shrine/village_building_wrap_test.gd"

func check_east_il_road():
 game.tuning.invincible=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"Connected Villages"))
 for village in ["il_village","alyut"]:
  var regions=Tour.Regions
  var placement=regions.village_transform(village)
  Tour.travel(game,regions.layout(village),{"arrival":regions.entry_point(village),"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 8:await physics_frame
  var host=regions.canonical_area(village)
  check(Tour.area(game.model)==host,"Legacy village arrivals enter the connected landscape")
  var view=game.model.get_meta("joined_village")
  check(view.waves==null and view.enemies.is_empty(),"Village scenery uses no second simulation")
  var village_root=game.world.find_child("Connected_"+village,true,false)
  check(village_root!=null,"The original village is present inside the outdoor world")
  check(game.world.find_child("VillageCountrysideView",true,false)==null,"The adjoining landscape is playable rather than a decorative background")
  var houses=village_root.find_children("BlueCGVillageBuilding_*","Node3D",true,false)
  check(houses.size()==(8 if village=="il_village" else 5),"Every original building is reused exactly once")
  for house in houses:check_uvs(house)
  var npcs=village_root.find_child("OriginalFalanNPCs",true,false)
  check(npcs.get_child_count()==Tour.VillageNPCs.AREAS[village].size(),"Every original village NPC is retained")
  village_entries(6 if village=="il_village" else 5)
  var mask:Image=regions.Sites.VILLAGES[village][3].get_image()
  var origin:Vector2=regions.Sites.VILLAGES[village][2]
  for z in mask.get_height():
   for x in mask.get_width():
    var tile=mask.get_pixel(x,z)
    if tile.a<.5 or tile.r>.5:continue
    var at:Vector2=placement*(origin+Vector2(x,z)*3)
    check(absf(game.model.surface_height(at.x,at.y)-6)<.01,"Village ground and native army queries share the original floor height")
  var gates=[[regions.IL_GATE,Vector2.LEFT]] if village=="il_village" else [[regions.ALYUT_SOUTH_GATE,Vector2.UP],[regions.ALYUT_NORTH_GATE,Vector2.DOWN]]
  for gate in gates:
   for sign_ in [1,-1]:
    await walk_connected_gate(placement*gate[0],placement.basis_xform(gate[1])*sign_,village)
  if DisplayServer.get_name()!="headless":
   var eyes=[Vector3(20,23,-65),Vector3(110,90,140)] if village=="il_village" else [Vector3(48,22,18),Vector3(25,22,-32),Vector3(135,90,130)]
   var targets=[Vector3(12,7,-180),Vector3(0,6,0)] if village=="il_village" else [Vector3(49,7,140),Vector3(30,7,-180),Vector3(0,6,0)]
   for i in eyes.size():await shot("Connected Villages/"+village+"-"+str(i),village_world(eyes[i],village),village_world(targets[i],village),68)
  for id in ([2001,2002,2010,2012,2013,2014] if village=="il_village" else [2401,2420,2410,2421,2412]):
   var outside:Dictionary=game.model.get_meta("falan_links").filter(func(link):return link.get("floor")==id)[0]
   var heading:float=game.camera_rig.yaw
   await room(id)
   await room(2000 if village=="il_village" else 2400)
   check(map_position().distance_to(outside.at)<6,"Interior exits return to the same connected village doorstep")
   check(absf(wrapf(game.camera_rig.yaw-heading,-PI,PI))<.001,"Village interior round trips preserve the outdoor heading")
   var landing:Vector3=game.player.position/game.model.falan_scale
   check(game.model.terrain.disk_clear(landing,.55) and not game.model.scenery_obstacles.values().any(func(box):return box.grow(.55).has_point(landing+Vector3.UP*.4)),"Village returns retain safe doorway clearance")
  var mouth_id=11003 if village=="il_village" else 11005
  var mouth:Dictionary=regions.site_links(host).filter(func(link):return link.site==mouth_id)[0]
  check(road_connected(map_position(),mouth.at,.55,false),"The village retains a dry route to Habaru")
  await walk_habaru_threshold(mouth.at,regions.frame(host).inverse().basis_xform(Vector2.RIGHT))
  check(game.model.falan_floor==mouth_id,"The existing Habaru entrance still works")
  await walk_habaru_link("exit_id",mouth_id)
  check(Tour.area(game.model)==host and game.model.has_meta("joined_village"),"Habaru exits restore the connected village landscape")
 print("CONNECTED_VILLAGES_RESULT failures=",errors)

