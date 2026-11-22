extends "res://tests/forest-shrine/il_habaru_restoration_test.gd"
## Play Goemon --script this file -- --il-habaru-alyut

func check_il_habaru_alyut():
 await super.check_il_habaru_alyut()
 if errors:return
 await open_area("east_coast")
 await site(2000,"il_village")
 check_vista()
 if DisplayServer.get_name()!="headless":
  var s:float=game.model.falan_scale
  await shot("Alyut Restoration/il-outward-view",village_world(Vector3(15,20,-65),"il_village"),village_world(Vector3(12,7,-155),"il_village"),68)
 await leave_village("east_coast")
 await walk_to_north_coast()
 if Tour.area(game.model)!="north_coast":return
 var mouth=Tour.Regions.site_links("north_coast").filter(func(l):return l.site==11005)[0]
 var gates=Tour.Regions.site_links("north_coast").filter(func(l):return l.site==2400)
 check(gates.size()==2,"Both original Alyut gates remain available")
 for gate in gates:
  check(road_connected(mouth.at,gate.at,.55,false),"The landscape retains a dry road from Habaru to each Alyut gate")
 await site(2400,"alyut")
 if Tour.area(game.model)!="north_coast":return
 check_vista()
 check(game.world.find_children("BlueCGVillageBuilding_*","MeshInstance3D",true,false).size()==5,"All five Alyut buildings use recovered original facades")
 check(game.world.find_child("ArchivedAlyutGardens",true,false)!=null,"Alyut restores its small landscape details")
 if DisplayServer.get_name()!="headless":
  var s:float=game.model.falan_scale
  await shot("Alyut Restoration/alyut-village",village_world(Vector3(160,155,170),"alyut"),village_world(Vector3(0,6,0),"alyut"),62)
  await shot("Alyut Restoration/alyut-south-outward",village_world(Vector3(48,20,22),"alyut"),village_world(Vector3(49,7,130),"alyut"),67)
  await shot("Alyut Restoration/alyut-north-outward",village_world(Vector3(25,20,-35),"alyut"),village_world(Vector3(30,7,-140),"alyut"),67)
 for id in [2401,2420,2410,2421,2412]:
  await room(id)
  await room(2400)
 await room(2412)
 await room(2499)
 await room(2412)
 await room(2400)
 print("ALYUT_RESTORATION_RESULT failures=",errors)

func walk_to_north_coast():
 var mouth=Tour.Regions.site_links(Tour.Regions.canonical_area("east_coast")).filter(func(l):return l.site==11003)[0]
 await position_at(mouth.at)
 if game.model.falan_floor!=11003:await walk_through_entry()
 check(game.model.falan_floor==11003,"The original Il mouth opens onto Habaru")
 await walk_habaru_link("floor",11004)
 var boss:Vector2=Tour.Regions.Sites.HABARU_FORMATION[0]
 await position_at(boss+Vector2(0,15))
 for i in 16:await physics_frame
 for enemy in game.model.enemies.values():game.army_runtime.damage_enemy(enemy.id,100000)
 for i in 12:await physics_frame
 await walk_habaru_link("floor",11005)
 await walk_habaru_link("exit_id",11005)
 check(Tour.area(game.model)=="north_coast","Habaru's original exit reaches the Alyut countryside on foot")

func check_vista():
 var village:String=Tour.Regions.CONNECTED_VILLAGES[Tour.area(game.model)]
 check(game.world.find_child("Connected_"+village,true,false)!=null,"The complete village shares the playable landscape")
 check(game.world.find_child("VillageCountrysideView",true,false)==null,"The countryside is real terrain rather than a background view")
 var terrain=game.world.find_child("WindMeadowValley",true,false)
 var ground:ShaderMaterial=terrain.get_child(0).material_override
 check(ground.get_shader_parameter("clip_village")!=true,"The outdoor landscape remains visible from the village")
 check(ground.get_shader_parameter("use_connected_village")==true,"The shared ground reuses original village paint")
