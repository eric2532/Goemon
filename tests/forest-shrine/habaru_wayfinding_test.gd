extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Play Goemon --script this file -- --il-habaru-alyut

func check_il_habaru_alyut():
 game.tuning.invincible=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"Habaru Wayfinding"))
 for row in [["east_coast",11003,"HabaruIlMouth","il_village",2000,6],["north_coast",11005,"HabaruAlyutMouth","alyut",2400,5]]:
  await open_area(row[0])
  var terrain_node=game.world.find_child("WindMeadowValley",true,false)
  check(terrain_node.get_child(0).material_override.get_shader_parameter("freyja_grass_tile").w>.5,"Active countryside and village views share the original grass fallback")
  var mouth:Dictionary=Tour.Regions.site_links(Tour.area(game.model)).filter(func(link):return link.site==row[1])[0]
  var back=Tour.Regions.frame(Tour.area(game.model)).inverse().basis_xform(Vector2.RIGHT)
  var across=Vector2(back.y,-back.x)
  var recess=game.world.find_child(row[2],true,false)
  check(recess!=null and not recess.has_node("HabaruTimberLandmark"),"Habaru uses a large rock entrance without an added timber frame or lamps")
  var opening:MeshInstance3D=recess.get_node("HabaruCliffRecess")
  check(opening.mesh.get_aabb().size.x>18 and opening.mesh.get_aabb().size.y>13,"The rock entrance is substantially wider and taller")
  for name_ in ["ArchivedCliffForms","ArchivedGateRidges"]:
   var cliff=game.world.find_child(name_,true,false) as MeshInstance3D
   check(cliff!=null and cliff.material_override.get_shader_parameter("entrance_cut_count")==1,
    "Both overlapping cliff layers leave the Habaru opening visible")
  var label=game.world.find_child("HabaruCaveLandmark",true,false) as Label3D
  check(label!=null and label.visibility_range_end>=140 and label.position.y>game.model.surface_height(mouth.at.x,mouth.at.y)+7,
   "Habaru is named above the entrance and readable before reaching it")
  check(game.world.find_children("HabaruTrailLabel*","Label3D",true,false).size()==6,"Six roadside signs follow each village approach")
  for at:Vector2 in Tour.Regions.HABARU_TRAIL[row[0]]:
   if row[0]=="east_coast":at=Tour.Regions.coast_to_gate(at)
   check(road_connected(at,mouth.at,.55,false),"Each wayfinding checkpoint belongs to the existing dry cave trail")
  await position_at(mouth.at-back*22)
  game.camera_rig.yaw=atan2(-back.x,-back.y)
  game.camera_rig.pitch=.36
  game.camera_rig.reset_follow()
  for i in 20:game.camera_rig.update_camera(1.0/60.0)
  var camera:Camera3D=game.camera_rig.camera
  var title_top:Vector3=label.global_position+Vector3.UP*1.3*game.model.falan_scale
  check(not camera.is_position_behind(label.global_position) and Rect2(Vector2.ZERO,Vector2(root.size)).grow(-20).has_point(camera.unproject_position(title_top)),
   "The cave title fits in the normal walking camera from the approach")
  if DisplayServer.get_name()!="headless":
   await shot("Habaru Wayfinding/"+row[0]+"-walking",camera.global_position,camera.global_position-camera.global_basis.z,camera.fov)
  await walk_habaru_threshold(mouth.at,back)
  check(game.model.falan_floor==row[1],"The landmark preserves the original cave threshold on foot")
  for side in [-3.2,3.2]:
   await open_area(row[0])
   var approach:Vector2=mouth.at-back*2+across*side
   var p:Vector3=game.model.world_point(approach)/game.model.falan_scale
   check(not game.model.scenery_obstacles.values().any(func(box):return box.grow(.55).has_point(p+Vector3.UP*.4)),"The enlarged entrance has clear access on both sides")
   await walk_habaru_threshold(mouth.at+across*side,back)
   check(game.model.falan_floor==row[1],"Both sides of the enlarged mouth enter the same dungeon on foot")
  await open_area(row[0])
  await site(row[4],row[3])
  village_entries(row[5])
  var round_houses=game.world.find_children("BlueCGVillageBuilding_*","MeshInstance3D",true,false).filter(func(node):return node.get_meta("source_graphic",0) in [11268,11269])
  check(round_houses.size()==1,"Each village restores its original round thatched building")
  for house in round_houses:
   var arrays:Array=house.mesh.surface_get_arrays(0)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   check(normals.size()>300 and Vector2(vertices[0].x,vertices[0].z).dot(Vector2(normals[0].x,normals[0].z))>0,
    "The tiered round house has outward-facing solid walls")
   if DisplayServer.get_name()!="headless":
    await shot("Habaru Wayfinding/"+row[3]+"-round-house",house.global_position+Vector3(20,15,20),house.global_position+Vector3.UP*8,65)
  var frontage=game.world.find_child("VillageFrontages",true,false)
  var village_root=game.world.find_child("Connected_"+row[3],true,false)
  check(village_root!=null,"The complete village shares the playable countryside")
  var joined_terrain=game.world.find_child("WindMeadowValley",true,false)
  check(joined_terrain.get_child(0).material_override.get_shader_parameter("use_connected_village")==true,"Village ground paint is part of the outdoor terrain")
  check(frontage!=null,"The village reuses Falan's street furniture and gardens")
  if frontage!=null:
   var signs=frontage.find_children("VillageServiceSign*","Label3D",true,false)
   check(signs.size()==row[5],"Every village service has a readable sign")
   var positions:Array=frontage.get_meta("placements",[])
   print("VILLAGE_FRONTAGES ",row[3]," services=",signs.size()," furnished_positions=",positions.size())
   check(positions.size()>=row[5]*3,"Each village has furnished frontages and planted beds")
   for at:Vector2 in positions:
    check(game.model.get_meta("falan_links").all(func(link):return (Tour.Regions.village_transform(row[3])*at).distance_to(link.at)>3.0),"Street furniture preserves door and gate clearance")
   check(frontage.find_children("*","CollisionObject3D",true,false).is_empty(),"New scenery leaves existing navigation and collision ownership intact")
  if DisplayServer.get_name()!="headless":
   var s:float=game.model.falan_scale
   var p=Vector3(8,22,56) if row[3]=="il_village" else Vector3(-5,20,25)
   var target=Vector3(-20,10,14) if row[3]=="il_village" else Vector3(-33,8,-15)
   await shot("Habaru Wayfinding/"+row[3]+"-street",village_world(p,row[3]),village_world(target,row[3]),65)
   var sign_=frontage.find_child("VillageServiceSign",true,false)
   if sign_!=null:
    await shot("Habaru Wayfinding/"+row[3]+"-frontage",sign_.global_position+Vector3(8,3,10),sign_.global_position-Vector3.UP,65)
   var seen={}
   for house in game.world.find_children("BlueCGVillageBuilding_*","MeshInstance3D",true,false):
    var id:int=house.get_meta("source_graphic")
    if seen.has(id):continue
    seen[id]=true
    await shot("Village Fidelity/"+row[3]+"-building-"+str(id),house.global_position+Vector3(-24,22,24),house.global_position+Vector3.UP*8,65)
  for id in ([2001,2002,2010,2012,2013,2014] if row[3]=="il_village" else [2401,2420,2410,2421,2412]):
   await room(id)
   await room(row[4])
 print("HABARU_WAYFINDING_RESULT failures=",errors)
