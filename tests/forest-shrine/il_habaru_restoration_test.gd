extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Play Goemon --script this file -- --il-habaru-alyut

func check_il_habaru_alyut():
 game.tuning.invincible=true
 await open_area("east_coast")
 await site(2000,"il_village")
 village_entries(6)
 var buildings=game.world.find_children("BlueCGVillageBuilding_*","Node3D",true,false)
 check(buildings.size()==8,"All eight Il buildings use original facade graphics")
 check(game.world.find_child("ArchivedIlGardens",true,false)!=null,"Il restores its original small scenery anchors")
 var source_ground=false
 for mesh in game.world.find_children("*","MeshInstance3D",true,false):
  if mesh.material_override is ShaderMaterial and mesh.material_override.get_shader_parameter("use_freyja_surface")==true:
   source_ground=true
 check(source_ground,"Il terrain uses the original village tile atlas")
 if DisplayServer.get_name()!="headless":
  var s:float=game.model.falan_scale
  await shot("Il Restoration/village",village_world(Vector3(180,170,210),"il_village"),village_world(Vector3(0,6,5),"il_village"),64)
  await shot("Il Restoration/street",village_world(Vector3(8,22,56),"il_village"),village_world(Vector3(-20,10,14),"il_village"),65)
 for id in [2001,2002,2010,2012,2013,2014]:
  await room(id)
  await room(2000)
 await leave_village("east_coast")
 var mouth=Tour.Regions.site_links(Tour.Regions.canonical_area("east_coast")).filter(func(l):return l.site==11003)[0]
 check(road_connected(map_position(),mouth.at,.55,false),"The surrounding landscape connects Il to the original cave entrance")
 await position_at(mouth.at)
 if game.model.falan_floor!=11003:await walk_through_entry()
 check(game.model.falan_floor==11003,"The side dungeon opens onto Habaru's original Il passage")
 check_ceiling()
 if DisplayServer.get_name()!="headless":await shot("Il Restoration/cave-passage",Vector3(10,5,12),Vector3(-8,3,-6),68)
 await walk_habaru_link("floor",11004)
 var boss:Vector2=Tour.Regions.Sites.HABARU_FORMATION[0]
 await position_at(boss+Vector2(0,15))
 for i in 20:await physics_frame
 check(game.model.enemies.size()==10,"The original boss and nine bears retain their native encounter")
 check_ceiling()
 if DisplayServer.get_name()!="headless":await shot("Il Restoration/bear-chamber",Vector3(boss.x+3,6,boss.y+22),Vector3(boss.x,3,boss.y+5),72,true)
 for enemy in game.model.enemies.values():game.army_runtime.damage_enemy(enemy.id,100000)
 for i in 12:await physics_frame
 check(game.model.enemies.is_empty(),"Clearing the native bear pack retires every unit")
 await walk_habaru_link("floor",11005)
 check_ceiling()
 await walk_habaru_link("floor",11004)
 await position_at(boss+Vector2(0,15))
 for i in 12:await physics_frame
 check(game.model.enemies.is_empty(),"The cleared bear chamber remains cleared on re-entry")
 await walk_habaru_link("floor",11003)
 print("IL_HABARU_RESTORATION_RESULT failures=",errors)
