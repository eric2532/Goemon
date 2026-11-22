extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
const Winter=Tour.Winter
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Frostpass/Snow Mountain Woodland/"
const DECREE_REVIEW="res://build/Other Files/Asset Toolkit/Frostpass/Holy Decree/"
const CURSED_MAZE_REVIEW="res://build/Other Files/Asset Toolkit/Frostpass/Cursed Maze/"
const DEEP_MAZE_REVIEW=CURSED_MAZE_REVIEW+"Sixty Floors/In Game/"
const Decree=Winter.Decree

func _initialize():
 create_timer(540).timeout.connect(func():printerr("FROSTPASS_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 check_generated_floors()
 check_decree_layouts()
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/frostpass-route-review.cfg"
 root.add_child(game)
 current_scene=game
 for i in 4:await process_frame
 # Patrol kills can open a modal card picker before the scripted return trip.
 game.settings.forest_level_up_cards=false
 game.find_child("ForestFalan",true,false).pressed.emit()
 var seed_override=OS.get_environment("SNOW_TEST_SEED")
 if seed_override.is_valid_int():
  game.run_seed=int(seed_override)
  game.model.seed_value=game.run_seed
 var route_seed:int=game.model.seed_value
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.equipment_hub.enter_button.pressed.emit()
 for i in 5:await physics_frame
 game.tuning.invincible=true
 game.camera_rig.set_process(false)
 game.camera_rig.set_process_unhandled_input(false)
 var edge:float=Tour.Frontier.OUTER_EDGE.freyja
 await position_at(Tour.Frontier.to_city("freyja",Vector2(3,edge-1)))
 await position_at(Tour.Frontier.to_city("freyja",Vector2(3,edge+1)))
 check(Tour.area(game.model)=="freyja","The existing Falan West Gate opens on foot")
 await position_at(Vector2(-39,419))
 await position_at(Vector2(-39,421))
 check(Tour.area(game.model)=="west_lakes","The West Gate road reaches Western Lakes")
 if errors:await finish();return
 check(road_connected(map_position(),Winter.TRAILHEAD,.55,false),"A dry route reaches Frostpass from the western road")
 check_passage("WesternLakesPassage",Winter.TRAILHEAD,4.5)
 await review("01-Western Lakes entrance",Winter.TRAILHEAD,Vector3(-10,9,21))
 if not await cross(51001):await finish();return
 var first_slot=Vector2i.ZERO
 var total=0
 var trail_ambient=Color.BLACK
 var glacier_mask=PackedByteArray()
 for destination in Winter.MAIN_ROUTE.size():
  var id:int=Winter.MAIN_ROUTE[destination]
  var town=Winter.HOUSES.has(id)
  var climb=id==Winter.TRAIL
  var expected=Winter.patrols(id,route_seed).size() if Winter.LEVELS.has(id) else 0
  check(game.model.enemies.size()==expected and (town or climb or expected>=13),"Caverns are populated and the towns and trail are safe")
  total+=expected
  var levels:Vector2i=Winter.LEVELS.get(id,Vector2i.ZERO)
  var snow_roster={}
  var zombie_skin=Pets.skin("original:2823")
  var hound_skin=Pets.skin("original:2821")
  for row in game.model.enemies.values():
   check(row.level>=levels.x and row.level<=levels.y,"Each encounter uses its floor's level range")
   var handle:int=game.army_runtime.handles.get(row.id,0)
   check(handle!=0,"The enemy belongs to the native army")
   if handle!=0 and row.variant==Roles.CAVE_BEAR:
    check(game.army_runtime.unit_state(handle).pose_row==Habaru.VENOA_BEAR_SKIN,"Bears use their native bear appearance")
   if id in Winter.SNOW_FLOORS:
    var hound=row.skin==hound_skin
    check(row.variant==Roles.GATEKEEPER_HOUND and row.skin in [zombie_skin,hound_skin]
     and row.enemy_name==("地獄妖犬" if hound else "喪屍") and not row.has("boss"),"Snow patrols use the regular zombie and hellhound kits")
    if handle!=0:check(game.army_runtime.unit_state(handle).pose_row==row.skin,"The native enemy uses the matching creature pose row")
    snow_roster[row.level]=int(snow_roster.get(row.level,0)) | (2 if hound else 1)
  if id in Winter.SNOW_FLOORS:
   check(expected==Winter.SNOW_PATROLS,"Each generated floor has a full patrol roster")
   var mask:PackedByteArray=Winter.snow_maze(id,route_seed).bits
   if id==Winter.SNOW_CAVE:glacier_mask=mask.duplicate()
   var chests=game.exploration_loot.slots.filter(func(slot):return slot.active and slot.chest)
   check(not chests.is_empty(),"%s has reachable treasure"%Winter.TITLES[id])
   for chest in chests:
    var local:Vector3=chest.pos/game.model.falan_scale
    var tile=Vector2i(((Vector2(local.x,local.z)-Winter.ORIGIN)/3.0).round())
    check(Tour.Indoor.open_cell(mask,Winter.SIZE,tile.x,tile.y)
     and game.army_runtime.native.can_reach(game.player.position,chest.pos,.50),"Treasure is inside the generated floor and reachable")
   for level in range(39,43):check(snow_roster.get(level,0)==3,"Both snow creatures occur at level %d"%level)
   var mesh:QuadMesh=game.crowd.army.meshes[Roles.GATEKEEPER_HOUND]
   var guard_skins:PackedInt32Array=mesh.material.get_shader_parameter("snow_guard_skins")
   var guard_frames:PackedInt32Array=mesh.material.get_shader_parameter("snow_guard_frames")
   check(zombie_skin in guard_skins and hound_skin in guard_skins and guard_frames.size()==16,
    "Both snow creatures bind eight directional guard frames")
   for refresh in [false,true]:
    if refresh:game.army_runtime.reconcile_pet_loadout()
    var pages:Array=mesh.get_meta("prepared_pages")
    for skin in [zombie_skin,hound_skin]:
     check(Pets.motions().skin_pages[skin].all(func(page):return int(page) in pages),"Both snow creature sprite sets stay loaded when the pet loadout is refreshed")
  check(reachable_cells(id),"Each patrol and doorway lies on the connected walkable floor")
  if climb:
   check_climb()
   trail_ambient=game.world.get_world_3d().environment.ambient_light_color
  else:check_scenery(id,town)
  var snow=id in Winter.SNOW_FLOORS
  var center=Vector2(0,-2) if town or climb or snow else Winter.point(Winter.ROCKS[id][0].get_center())
  await review("%02d-%s"%[destination+1,Winter.TITLES[id].get_slice(" · ",1) if not town else Winter.TITLES[id]],center,
   Vector3(31,88,43) if snow else Vector3(41,53,47) if town or climb else Vector3(32,29,32))
  if snow:
   var maze=Winter.snow_maze(id,route_seed)
   await review("Forest path "+str(id),Winter.point(maze.posts[12]),Vector3(10,19,22))
   await review("Ice ledges "+str(id),Winter.point(maze.rocks[0].get_center()),Vector3(-15,14,20))
  if town:
   var name_:String={51004:"Snowpine market",51005:"Ridgewatch hall",Winter.ABANIS:"Abanis village hall"}[id]
   await review(name_,Winter.point(Winter.HOUSES[id][Winter.MAIN_LOT].get_center()),Vector3(13,10,22))
   if id==Winter.ABANIS:await review("Abanis house fronts",Winter.point(Vector2i(12,17)),Vector3(-12,12,23))
   if not await visit_building(id):await finish();return
   if id==Winter.ABANIS:
    if not await visit_holy_decree():await finish();return
    check(game.world.find_child("AbanisHospitalFacade",true,false)!=null,"The village hospital has a distinct entrance")
    await review("Abanis hospital",Winter.building_door(Winter.ABANIS,5),Vector3(10,9,21))
    if not await visit_highland_room(Winter.ABANIS,5,Winter.ABANIS_HOSPITAL):await finish();return
    if not await cross(Winter.COAST_ROAD):await finish();return
    var near=Winter.point(Winter.ARRIVALS[Winter.COAST_ROAD][0])
    var far=Winter.point(Winter.ARRIVALS[Winter.COAST_ROAD][1])
    check(near.distance_to(far)>65.0 and reachable_cells(Winter.COAST_ROAD),
     "The snowy coastal section is a continuous walk between its gates")
    check(game.world.find_child("UniversityCoastCliffs",true,false) is MeshInstance3D
     and game.world.find_child("UniversityCoastWater",true,false) is MeshInstance3D
     and game.world.find_child("UniversityRoadSnowbanks",true,false) is MeshInstance3D
     and game.world.find_child("SnowyEvergreens",true,false)!=null,
     "The road has solid shoreline, snowbanks, water and snowy trees")
    check_highland_loot(Winter.COAST_ROAD)
    await review("Snowy coast road",Vector2(-5,-2),Vector3(-35,57,59))
    if not await cross(Winter.UNIVERSITY):await finish();return
    check(game.model.enemies.is_empty() and reachable_cells(Winter.UNIVERSITY),"The university courtyard is safe and connected to the road")
    check_scenery(Winter.UNIVERSITY,true)
    var glasshouse=game.world.find_child("UniversityGlasshouse",true,false)
    var observatory=game.world.find_child("UniversityObservatory",true,false)
    check(glasshouse!=null and glasshouse.get_child_count()>=2 and observatory!=null and observatory.get_child_count()>=5,
     "The university has dedicated 3D glasshouse and observatory buildings")
    check(game.world.find_child("UniversityAuditoriumFacade",true,false)!=null
     and game.world.find_child("UniversityCourtyardMosaic",true,false) is MeshInstance3D,
     "The auditorium and courtyard have distinct 3D landmarks")
    check(game.world.find_child("UniversityCourtyardPlanters",true,false)!=null
     and game.world.find_child("UniversityExteriorRoofGarden",true,false)!=null,
     "The courtyard gardens and visible upper terrace are assembled in 3D")
    await review("Magic University",Vector2(0,0),Vector3(34,44,49))
    await review("University observatory",Winter.building_door(Winter.UNIVERSITY),Vector3(12,12,24))
    if not await visit_building(Winter.UNIVERSITY):await finish();return
    for lot:int in [0,1,3]:
     if not await visit_highland_room(Winter.UNIVERSITY,lot,Winter.CAMPUS_ROOMS[lot]):await finish();return
    if not await cross(Winter.COAST_ROAD) or not await cross(Winter.ABANIS):await finish();return
  elif climb:
   var at=Winter.point(Winter.DOORS[id][1])
   check_passage("SnowMountainMouth",at,3.8)
   var rim=game.world.find_child("SnowMountainRimIce",true,false)
   check(rim is MeshInstance3D and rim.mesh.get_aabb().size.x>3.0,"Icicles fit across the recessed mountain mouth")
   await review("Snow Mountain lower switchback",Vector2(-6,16),Vector3(13,16,21))
   await review("Snow Mountain entrance",at+Vector2(0,2),Vector3(5,7,15))
  else:
   for side in Winter.DOORS[id].size():
    var at=Winter.point(Winter.DOORS[id][side])
    var front=signf(Winter.ARRIVALS[id][side].y-Winter.DOORS[id][side].y)
    var inter_floor=id==Winter.ICE_VAULT or (id==Winter.SNOW_CAVE and side==1)
    var frame_name="FrostpassPassage%d"%side
    check_passage(frame_name,at,3.9 if inter_floor else 2.4)
    if snow:
     var landing=game.world.find_child(frame_name,true,false)
     var treads=landing.get_node_or_null("SnowMountainLandingTreads") if landing!=null else null
     check(treads is MeshInstance3D and treads.mesh.get_aabb().size.y<.16 and treads.get_child_count()==0,
      "Each snow entrance has shallow blue treads over the original landing")
     await review("Snow Landing %d-%d"%[id,side],at+Vector2(0,front*2.1),Vector3(4,7,front*14))
    if inter_floor:
     var frame=game.world.find_child(frame_name,true,false)
     var curtain=frame.find_child("FrozenPassageIcicles",false,false) if frame!=null else null
     check(curtain is MeshInstance3D and curtain.mesh.get_aabb().size.y>4.3,"Both sides of the passage have solid ice framing")
     if frame!=null:
      check(frame.has_node("FrozenPassageMolding") and frame.has_node("FrozenPassageLanternBrackets")
       and frame.get_node_or_null("FrozenPassageLight") is OmniLight3D,"The passage has beveled stonework and a lit lantern pair")
      var ribs=frame.get_node_or_null("FrozenPassageInnerStone")
      check(ribs is MeshInstance3D and ribs.mesh.get_aabb().end.z< -1.35 and ribs.mesh.get_aabb().position.z< -3.05
       and frame.get_node_or_null("FrozenPassageRecessLight") is OmniLight3D,"Two fitted stone bands line the lit throat")
      var lining=frame.get_node_or_null("FrozenPassageWallLining")
      check(lining is MeshInstance3D and lining.mesh.get_aabb().size.z>3.5,"Beveled masonry covers the deep passage walls")
      var frost=frame.get_node_or_null("FrozenPassageFrost")
      check(frost is MeshInstance3D and frost.mesh.get_aabb().position.z< -3.65,"Visible frost reaches the rear stonework")
    if inter_floor or side==1:await review("Passage "+str(id),at,Vector3(front*4,5,front*13))
  if id==51001 and not game.model.enemies.is_empty():
   var row:Dictionary=game.model.enemies.values()[0]
   first_slot=row.frostpass_slot
   game.army_runtime.damage_enemy(row.id,row.hp*2.0)
   for i in 5:await physics_frame
   check(get_meta(Winter.SLAIN,{}).has(first_slot),"Native combat records a cleared patrol")
  if id==Winter.SNOW_CAVE:
   await check_snow_strike(hound_skin)
   for skin in [zombie_skin,hound_skin]:
    var row:Dictionary=game.model.enemies.values().filter(func(enemy):return enemy.skin==skin)[0]
    game.army_runtime.damage_enemy(row.id,row.hp*2.0)
    for i in 5:await physics_frame
    check(get_meta(Winter.SLAIN,{}).has(row.frostpass_slot),"Both snow creature types can be defeated through native combat")
  if destination+1<Winter.MAIN_ROUTE.size() and not await cross(Winter.MAIN_ROUTE[destination+1]):await finish();return
 var route_back=Winter.MAIN_ROUTE.slice(0,-1)
 route_back.reverse()
 route_back.append(0)
 for target in route_back:
  if not await cross(target):await finish();return
  if target==Winter.TRAIL:
   check(game.world.get_world_3d().environment.ambient_light_color==trail_ambient
    and game.world.find_child("SnowMountainCrystalLight0",true,false)==null,"Cave lighting ends at the trail")
  if target==51001:
   check(game.model.enemies.size()==Winter.patrols(target).size()-1,"Cleared patrols stay defeated on the return trip")
  if target==Winter.SNOW_CAVE:
   check(game.model.seed_value==route_seed and Winter.snow_maze(target,game.model.seed_value).bits==glacier_mask,
    "Returning to Glacier Cavern keeps the run's generated layout")
   check(game.model.enemies.size()==Winter.patrols(target,route_seed).size()-2,"Defeated snow creatures stay gone on the return trip")
 check(road_connected(map_position(),Vector2(288,0),.55,false),"The return landing connects to the West Gate road")
 await position_at(Vector2(305,0))
 await position_at(Vector2(307,0))
 check(Tour.area(game.model)=="freyja","Western Lakes reconnects to the original West Gate approach")
 if Tour.area(game.model)=="freyja":
  var city_edge:float=Tour.Frontier.INNER_EDGE.freyja
  await position_at(Vector2(3,city_edge+1))
  await position_at(Vector2(3,city_edge-1))
  check(Tour.area(game.model)=="city","The West Gate approach returns to Falan")
 print("FROSTPASS_RESULT seed=",route_seed," encounters=",total," failures=",errors)
 await finish()

func visit_holy_decree()->bool:
 var gate=Decree.ABANIS_WEST_GATE
 var village_ambient=game.world.get_world_3d().environment.ambient_light_energy
 await review("01-Abanis western gate",gate,Vector3(12,10,15),DECREE_REVIEW)
 if not await cross(Decree.WEST_ROAD,Vector2(3,0)):return false
 await review("04-Pulsing Stone Disc",Decree.ROAD_DISC,Vector3(11,17,23),DECREE_REVIEW)
 check_highland_loot(Decree.WEST_ROAD)
 check(game.world.find_child("DecreeStoneDisc",true,false)!=null,"The western road has a modeled stone disc")
 await position_at(Decree.ROAD_DISC+Vector2(0,3))
 await position_at(Decree.ROAD_DISC)
 check(game.model.falan_floor==Decree.WEST_ROAD,"The maze rejects entry without the blade fragment")
 if not await cross(Winter.ABANIS,Vector2(0,-3)):return false
 if not await cross(Decree.HOUSE,Vector2(0,3)):return false
 await review("02-Historian's house",Vector2.ZERO,Vector3(-9,23,22),DECREE_REVIEW)
 if not await cross(Decree.CELLAR,Vector2(0,3)):return false
 await review("03-Time Stone Disc",Decree.RELIC,Vector3(8,11,15),DECREE_REVIEW)
 if not await cross(Decree.PAST,Vector2(0,3)):return false
 check(not get_meta(Decree.BLADE,false),"Time travel leaves the blade available for pickup")
 await position_at(Decree.RELIC+Vector2(0,3))
 await position_at(Decree.RELIC)
 var blade=game.world.find_child("DecreeBladeFragment",true,false)
 check(get_meta(Decree.BLADE,false) and blade is MeshInstance3D and not blade.visible,
  "Approaching the blade records it for this adventure and removes its model")
 if not await cross(Decree.CELLAR,Vector2(0,-3)):return false
 if not await cross(Decree.HOUSE,Vector2(0,-3)):return false
 if not await cross(Winter.ABANIS,Vector2(0,-3)):return false
 if not await cross(Decree.WEST_ROAD,Vector2(3,0)):return false
 if not await cross(Decree.floor_id(1),Vector2(0,3)):return false
 for number in range(1,Decree.FLOOR_COUNT+1):
  var id:int=Decree.floor_id(number)
  var index:int=Decree.section_index(id)
  var guardian=id in Decree.GUARDIAN_FLOORS
  var next:int=Winter.ABANIS if number==Decree.FLOOR_COUNT else Decree.floor_id(number+1)
  var floor_seed:int=game.model.seed_value
  var rows=Decree.encounters(id,floor_seed)
  var start_mask:PackedByteArray=Decree.maze(id,floor_seed).bits
  check_highland_loot(id)
  if not guardian:
   check(game.exploration_loot.slots.filter(func(slot):return slot.active and slot.chest).size()<=1,
    "Each new corridor uses the limited chest budget")
  var guards=game.model.enemies.values().filter(func(row):return row.get("boss",false))
  check(game.model.enemies.size()==rows.size() and guards.size()==(Decree.GUARDIANS[index].size() if guardian else 0),
   "%dF has its native patrols and expected guardians"%number)
  if guardian:
   for expected in Decree.GUARDIANS[index]:
    var skin=Pets.skin(expected[0])
    check(guards.any(func(boss):return boss.skin==skin and boss.enemy_name==expected[1]),
     "%dF still has %s"%[number,expected[1]])
  for row in game.model.enemies.values():
   var handle:int=game.army_runtime.handles.get(row.id,0)
   check(handle!=0 and row.skin>=0 and game.army_runtime.unit_state(handle).pose_row==row.skin,
    "Every dungeon creature has a valid native handle and sprite set")
   check(game.army_runtime.native.can_reach(game.player.position,row.pos,row.footprint),
    "%dF native patrol can reach the approach from its post"%number)
  check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(Decree.UPPER_DOOR),.50),
   "%dF connects its entry and exit"%number)
  var details=game.world.find_child("DecreeMazeDetails",true,false)
  check(details is Node3D and details.find_children("*","CollisionObject3D",true,false).is_empty(),
   "Maze scenery keeps the original navigation")
  if details is Node3D:
   var corridor=details.get_node_or_null("DecreeCorridorDetails")
   var floor_materials=details.get_parent().get_children().filter(func(node):
    return (node is MultiMeshInstance3D and node.material_override is ShaderMaterial
     and node.material_override.shader.resource_path=="res://assets/materials/twin_kings_flagstone.gdshader"))
   check(floor_materials.any(func(node):return node.material_override.get_shader_parameter("corridor_paving")!=guardian),
    "%dF uses the recovered stone family for this floor"%number)
   check(corridor is Node3D and corridor.get_node_or_null("ChamberMazeNiche") is MultiMeshInstance3D,
    "Every passage has batched recesses")
   if corridor is Node3D and guardian and index in [0,1,3]:
    var period_detail=["ChamberMazeOrbStand","ChamberMazeRubble","","ChamberMazeWallRelief"][index]
    check(corridor.get_node_or_null(period_detail) is MultiMeshInstance3D,"The corridor has its source-specific detail")
  var energy=game.world.get_world_3d().environment.ambient_light_energy
  var expected_energy=(.24 if index>=4 else .29)+(0.0 if guardian else .035)
  check(is_equal_approx(energy,expected_energy),"The deeper floors use dimmer ambient light")
  await review_decree_floor(number,id)
  if not guardian:
   if number==2:
    if not await cross(Decree.floor_id(1),Vector2(0,-3)):return false
    if not await cross(id,Vector2(0,3)):return false
    check(game.model.seed_value==floor_seed and Decree.maze(id,game.model.seed_value).bits==start_mask,
     "A round trip keeps the same randomized corridor")
   if not await cross(next,Vector2(0,3)):return false
   continue
  if index<5 and details is Node3D:
   var basins=details.get_node_or_null("ChamberMazeBasin")
   var rubble=details.get_node_or_null("ChamberMazeRubble")
   check(basins is MultiMeshInstance3D and basins.multimesh.instance_count==4,
    "Each guardian platform has four batched basin stands")
   check(rubble is MultiMeshInstance3D and rubble.multimesh.instance_count>0
    and details.get_node_or_null("ChamberMazeWallRelief") is MultiMeshInstance3D,
    "The guardian room has batched rubble and carved wall reliefs")
   if rubble is MultiMeshInstance3D:
    for pose in rubble.multimesh.instance_count:
     var local=rubble.multimesh.get_instance_transform(pose).origin
     check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(Vector2(local.x,local.z)),.30),
      "Rubble uses existing walkable space without adding collision")
  elif number==Decree.FLOOR_COUNT:
   var scenery=game.world.find_child("TwinKingsScenery",true,false)
   check(scenery is Node3D and scenery.find_children("*","CollisionObject3D",true,false).is_empty(),
    "Twin Kings scenery adds no collision to the walkable room")
   if scenery is Node3D:
    var bones=scenery.get_node_or_null("TwinKingsBonePiles")
    var seal=scenery.get_node_or_null("TwinKingsUprightSeal")
    check(bones is MeshInstance3D and bones.mesh.get_surface_count()==3 and bones.mesh.get_aabb().end.y<.72,
     "The layered bone piles share one mesh and stay low to the ground")
    check(details.find_child("ChamberMazeEmberNiche",false,false) is MultiMeshInstance3D,
     "Twin Kings wall niches contain the batched ember details")
    check(scenery.find_children("TwinKingsGoldStatue*","MeshInstance3D",true,false).size()==3
     and seal is Node3D and seal.find_children("*","MeshInstance3D",true,false).size()>=4,
     "The final chamber has three gold statues and a modeled upright seal")
   await review("Upright seal detail",Vector2(-10.2,-17.9),Vector3(-6,9,13),CURSED_MAZE_REVIEW)
  await review("Guardian room %d"%[index+1],Decree.point(Vector2i(11,4)),Vector3(55,70,55),CURSED_MAZE_REVIEW,51.0)
  await position_at(Decree.UPPER_LANDING)
  await position_at(Decree.UPPER_DOOR)
  check(game.model.falan_floor==id,"The next stair stays sealed while its guardian lives")
  for guard in guards:
   game.army_runtime.damage_enemy(guard.id,guard.hp*2.0)
   for tick in 5:await physics_frame
   if guards.size()==2 and guard==guards[0]:
    await position_at(Decree.UPPER_LANDING)
    await position_at(Decree.UPPER_DOOR)
    check(game.model.falan_floor==id and not get_meta(Decree.COMPLETE,false),"Either living king keeps the final seal closed")
  if index==0:
   if not await cross(Decree.floor_id(number-1),Vector2(0,-3)):return false
   if not await cross(id,Vector2(0,3)):return false
   check(game.model.seed_value==floor_seed and Decree.maze(id,game.model.seed_value).bits==start_mask,
    "Returning to the guardian floor keeps the same approach")
   check(game.model.enemies.values().all(func(row):return not row.get("boss",false)),
    "The first guardian stays defeated after leaving and returning")
  if not await cross(next,Vector2(0,3)):return false
  print("HOLY_DECREE_PROGRESS floor=",number," failures=",errors)
 check(get_meta(Decree.COMPLETE,false),"Defeating the Twin Kings completes the Holy Decree branch")
 check(is_equal_approx(game.world.get_world_3d().environment.ambient_light_energy,village_ambient),
  "The darker maze lighting ends at the return to Abanis")
 print("HOLY_DECREE_RESULT floors=",Decree.FLOOR_COUNT," failures=",errors)
 return errors==0

func check_decree_layouts():
 var seeds=range(12)+[61103,2147483646]
 var known={}
 for number in range(1,Decree.FLOOR_COUNT+1):
  var id=Decree.floor_id(number)
  var seen={}
  var first=Decree.maze(id,seeds[0])
  for seed_ in seeds:
   var run=Decree.maze(id,seed_)
   var bits:PackedByteArray=run.bits
   var signature=bits.hex_encode()
   seen[signature]=true
   var cells=connected_floor(bits,Vector2i(11,22),false,.50,Decree.SIZE)
   var open_count=0
   for y in Decree.SIZE.y:
    for x in Decree.SIZE.x:
     var open=Tour.Indoor.open_cell(bits,Decree.SIZE,x,y)
     if open:open_count+=1
     if number%10==0 and y<9:
      check(open==Decree.Corridors.GUARDIAN_ARENA.has_point(Vector2i(x,y)),
       "%dF preserves the guardian arena footprint"%number)
   check(cells.size()==open_count and cells.has(Vector2i(11,2)) and cells.has(Vector2i(11,4)) and cells.has(Vector2i(11,20)),
    "%dF seed %d has connected rooms and stairs"%[number,seed_])
   var expected_posts=7 if number%10==0 else 3
   check(run.posts.size()==expected_posts and run.posts.all(func(cell):
    return cell.distance_squared_to(Vector2i(11,20))>=9 and cell.distance_squared_to(Vector2i(11,4))>=9),
    "%dF keeps its native patrol count and clear arrivals"%number)
   for encounter in Decree.encounters(id,seed_):
    check(cells.has(encounter[0]),"%dF has every native patrol inside the route"%number)
   if seed_==61103:
    check(not known.has(signature) and Decree.floor_number(id)==number,"%dF has a distinct layout and stable identity"%number)
    known[signature]=true
  check(seen.size()>=12,"%dF varies across adventure seeds"%number)
  var replay=Decree.maze(id,seeds[0])
  check(replay.bits==first.bits and replay.posts==first.posts,"%dF replays the same layout and patrol posts"%number)
 print("HOLY_DECREE_GENERATION floors=",Decree.FLOOR_COUNT," seeds=",seeds.size())

func review_decree_floor(number:int,id:int):
 if DisplayServer.get_name()=="headless":return
 var info=Decree.floor_info(id,game.model.seed_value)
 var bits:PackedByteArray=info[2].hex_decode()
 var side=Vector2(1,-1).normalized()
 var depth=Vector2(1,1).normalized()
 var near=Vector2(INF,INF)
 var far=-near
 for y in Decree.SIZE.y:
  for x in Decree.SIZE.x:
   if not Tour.Indoor.open_cell(bits,info[0],x,y):continue
   var p=Decree.point(Vector2i(x,y))
   var projected=Vector2(p.dot(side),p.dot(depth))
   near=near.min(projected)
   far=far.max(projected)
 var center=(near+far)*.5
 var span=far-near
 var offset=Vector3(55,81,55)
 var height=maxf(span.x/1.6,span.y*offset.normalized().y)*game.model.falan_scale+18.0
 await review("%02dF"%number,side*center.x+depth*center.y,offset,DEEP_MAZE_REVIEW,height)
 var paving_focus={1:Vector2i(15,10),35:Vector2i(17,10),60:Vector2i(15,6)}
 if paving_focus.has(number):
  var focus=Tour.Indoor.DecreeArt.passage_cell(bits,paving_focus[number])
  await review("%02dF paving detail"%number,Decree.point(focus),offset,DEEP_MAZE_REVIEW,15.0)

func check_generated_floors():
 var replays=range(64)+[500,40821,2147483646]
 for id in Winter.SNOW_FLOORS:
  var layouts={}
  var first=Winter.snow_maze(id,replays[0])
  for seed_ in replays:
   var maze=Winter.snow_maze(id,seed_)
   layouts[maze.bits.hex_encode()]=true
   var reachable=connected_floor(maze.bits,Winter.ARRIVALS[id][0],false)
   var required:Array=Winter.DOORS[id]+Winter.ARRIVALS[id]+maze.posts
   var open_count=0
   for y in Winter.SIZE.y:
    for x in Winter.SIZE.x:
     if Tour.Indoor.open_cell(maze.bits,Winter.SIZE,x,y):open_count+=1
   check(reachable.size()==open_count and required.all(func(cell):return reachable.has(cell)),
    "The generated snow floor is connected for seed %d"%seed_)
   check(open_count>=490,"The larger snow floor still has at least 490 walkable cells")
   var unique={}
   for post in maze.posts:unique[post]=true
   check(maze.posts.size()==Winter.SNOW_PATROLS and unique.size()==maze.posts.size(),"A full set of distinct patrol posts fits")
  var replay=Winter.snow_maze(id,replays[0])
  check(replay.bits==first.bits and replay.rocks==first.rocks and replay.posts==first.posts,"The same adventure seed recreates the layout, ice islands and patrol slots")
  check(layouts.size()>60,"Different adventure seeds produce different chambers and corridors")
 print("SNOW_GENERATION seeds=",replays.size()," floors=",Winter.SNOW_FLOORS.size())

func check_snow_strike(skin:int):
 var row:Dictionary=game.model.enemies.values().filter(func(enemy):return enemy.skin==skin)[0]
 var runtime=game.army_runtime
 var cell:Vector2i=Winter.patrols(Winter.SNOW_CAVE,game.model.seed_value)[row.frostpass_slot.y]
 var at=Winter.point(cell)
 runtime.set_pose(runtime.handles[row.id],game.model.world_point(at),0)
 runtime.record_events=true
 runtime.event_log.clear()
 await position_at(at+Vector2(0,-2.15))
 var special=false
 for frame in 550:
  await physics_frame
  if runtime.event_log.any(func(event):
   return event.kind=="status" and event.get("source_id")==row.id and event.get("action_index")==Habaru.DOUBLE_EDGE and event.amount>0):
   special=true
   break
 check(special,"The live hellhound reaches the 諸刃 contact marker")
 if special:
  var snapshot=runtime.render_snapshot()
  var index=snapshot.logical_ids.find(row.id)
  check(index>=0 and int(game.crowd.army.pose_sample(snapshot,index).g)%8==7,
   "The live 諸刃 strike uses its single-lunge presentation")
  await review("Hellhound Double Edge",at,Vector3(5,4,-9))
 runtime.record_events=false
 runtime.event_log.clear()

func visit_building(town:int)->bool:
 var room:int=Winter.TOWN_BUILDINGS[town]
 var art=Tour.Indoor.WinterRooms
 var at=Winter.building_door(town)
 var sill=game.model.world_point(at)
 check(game.army_runtime.native.can_reach(sill,game.model.world_point(at+Vector2(0,3)),.50),
  "The house entrance connects to the town street")
 if not await cross(room,Vector2(0,3)):return false
 var title:String=Winter.TITLES[room]
 var market=room==Winter.MARKET
 var root_name="SnowpineMarketInterior" if market else "RidgewatchHallInterior"
 if room==Winter.ABANIS_HALL:root_name="AbanisVillageHallInterior"
 if room==Winter.STUDY_HALL:root_name="UniversityStudyHallInterior"
 var detail="SnowpineMarketCounter" if market else "RidgewatchHearth"
 if room==Winter.ABANIS_HALL:detail="AbanisChiefsDesk"
 var node=game.world.find_child(root_name,true,false)
 check(node!=null and node.find_child(detail,true,false)!=null,title+" has its solid main furnishing")
 if room==Winter.ABANIS_HALL and node!=null:
  check(node.find_child("AbanisParlorStove",true,false)!=null
   and node.find_child("AbanisClothDisplay",true,false)!=null,
   title+" has a parlor stove and the village cloth display")
 elif node!=null:
  var wall_detail=node.find_child("SnowpineCurtain" if market else "RidgewatchBanner",true,false)
  check(wall_detail is MeshInstance3D and wall_detail.mesh.get_surface_count()==2,
   title+" has a folded 3D wall hanging with a separate hem")
  var prop=node.find_child("SnowpineBalanceScale" if market else "RidgewatchWallCrest",true,false)
  check(prop!=null,title+" has its fitted room props")
  if not market:
   var ledger=node.find_child("RidgewatchPlanningLedger",true,false)
   var platter=node.find_child("RidgewatchServingPlatter",true,false)
   check(ledger is MeshInstance3D and platter is MeshInstance3D,"The hall tables have different sets of 3D props")
  if room==Winter.STUDY_HALL:check(node.has_node("UniversityStudyInstruments"),"The classroom has original study props")
 check(game.model.enemies.is_empty(),title+" is safe")
 if room in [Winter.ABANIS_HALL,Winter.STUDY_HALL]:check_highland_loot(room)
 var exit=Winter.building_exit(room)
 check(map_position().distance_to(exit-Vector2(0,3))<.4,title+" lands past the exit trigger")
 check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(Vector2.ZERO),.50),
  title+" has a walkable center aisle")
 var stock=art.fixture(Winter.INTERIORS[room],"counter" if market else "left_table")
 check(not game.army_runtime.native.can_reach(game.player.position,stock,.50),title+" furniture blocks native movement")
 if room==Winter.ABANIS_HALL:
  await review("Abanis village hall interior",Vector2(0,1.5),Vector3(-12,31,29))
  await review("Abanis village hall details",Vector2(-3.5,-3),Vector3(-7,14,17))
 else:
  await review(title+" interior",Vector2(0,-2.5),Vector3(-13,23,25))
  await review(title+" details",Vector2(2.7,-8.6) if market else Vector2(0,-11),Vector3(-4,5.1,12.8))
 if room==Winter.STUDY_HALL and not await visit_roof_garden(room):return false
 if room==Winter.HALL:await review("Ridgewatch planning table",Vector2(-10.5,0),Vector3(4,6.5,8.5))
 if not await cross(town,Vector2(0,-3)):return false
 check(map_position().distance_to(at+Vector2(0,3))<=1.56,"Leaving "+title+" returns to its front door")
 return true

func visit_highland_room(town:int,lot_index:int,room:int)->bool:
 var door=Winter.building_door(town,lot_index)
 if not await cross(room,Vector2(0,3)):return false
 var detail:Array={
  Winter.WORKSHOP:["UniversityArcaneWorkbench","University workshop","bench"],
  Winter.GLASSHOUSE:["UniversityGrowingBeds","University glasshouse interior","west_bed"],
  Winter.ABANIS_HOSPITAL:["AbanisWardBeds","Abanis hospital interior","ward"],
  Winter.AUDITORIUM:["UniversityLecternStage","University auditorium","west_seats"],
 }[room]
 var fixture:String=detail[0]
 var title:String=detail[1]
 var furniture=game.world.find_child(fixture,true,false)
 check(furniture!=null and game.model.enemies.is_empty(),title+" has its own 3D furnishings")
 if room==Winter.ABANIS_HOSPITAL:
  check(game.world.find_child("AbanisDispensary",true,false)!=null,title+" has a separate medicine station")
 if room==Winter.WORKSHOP:
  check(game.world.find_child("UniversityForgeBank",true,false)!=null
   and game.world.find_child("UniversityWeaponRack",true,false) is MeshInstance3D,title+" has forges and a weapon rack")
 if room==Winter.GLASSHOUSE:
  check(game.world.find_child("UniversityBotanicalWorkbench",true,false) is MeshInstance3D,title+" has a potting bench")
  var plots=game.world.find_children("University*CropPlot","Node3D",true,false)
  check(plots.size()==2,title+" has both crop plots")
  for plot in plots:
   var rows=plot.find_children("UniversityCropFurrow*","MeshInstance3D",false,false)
   var fence=plot.get_node_or_null("UniversityPlotFence")
   var footprint=AABB(Vector3(-3,-.02,-6),Vector3(6,1.32,12))
   check(rows.size()==4 and rows.all(func(row):
    return (is_zero_approx(row.position.z) and row.mesh.get_aabb().size.z>9.0
     and footprint.encloses(row.transform*row.mesh.get_aabb()))),title+" has four straight furrows within each plot")
   check(fence is MeshInstance3D and footprint.encloses(fence.mesh.get_aabb()),title+" has a low timber fence within each plot")

 check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(Vector2.ZERO),.50),
  title+" has a clear center aisle")
 var first=Tour.Indoor.WinterRooms.fixture(Winter.INTERIORS[room],detail[2])
 check(not game.army_runtime.native.can_reach(game.player.position,game.model.world_point(Vector2(first.x,first.z)),.50),
  title+" accounts for its fixtures in navigation")
 check_highland_loot(room)
 await review(title,Vector2(0,1.5),Vector3(12 if room==Winter.WORKSHOP else -12,31,29))
 match room:
  Winter.WORKSHOP:
   await review("University workshop details",Vector2(-9,-2),Vector3(6,7,10))
   await review("University weapon rack",Vector2(10,-2),Vector3(-9,6,9))
  Winter.GLASSHOUSE:await review("University glasshouse details",Vector2(-10.5,-1),Vector3(6,9,10))
  Winter.ABANIS_HOSPITAL:await review("Abanis hospital details",Vector2(8,-1),Vector3(-6,11,14))
 if room==Winter.AUDITORIUM and not await visit_roof_garden(room):return false
 if not await cross(town,Vector2(0,-3)):return false
 check(map_position().distance_to(door+Vector2(0,3))<=1.56,title+" returns to its own door")
 return true

func visit_roof_garden(hall:int)->bool:
 if not await cross(Winter.ROOF_GARDEN,Vector2(0,3)):return false
 var own:Vector2=Winter.ROOF_LANDINGS[hall]
 var other:Vector2=Winter.ROOF_LANDINGS[Winter.AUDITORIUM if hall==Winter.STUDY_HALL else Winter.STUDY_HALL]
 check(map_position().distance_to(own-Vector2(0,3))<.42,"Each stair arrives at its own rooftop landing")
 check(game.world.find_child("UniversityRoofPlanters",true,false)!=null
  and game.world.find_children("UniversityGardenStairs*","Node3D",true,false).size()==2
  and game.world.get_world_3d().environment.background_color==Color("b0c8d7"),
  "The rooftop is an outdoor garden with two modeled stair landings")
 var treads=game.world.find_children("UniversityStoneTread*","MeshInstance3D",true,false)
 check(treads.size()==10 and treads.all(func(tread):return tread.position.y<0.0),
  "Both rooftop wells have descending stone treads")
 for landing:Vector2 in Winter.ROOF_LANDINGS.values():
  check(not game.army_runtime.native.can_reach(game.player.position,game.model.world_point(landing+Vector2(0,3)),.50),
   "The stairwell is outside the walkable terrace")
 check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(other-Vector2(0,3)),.50),
  "The two rooftop landings are connected by a walkable terrace")
 var melon=Tour.Indoor.WinterRooms.fixture(Winter.INTERIORS[Winter.ROOF_GARDEN],"east_melons")
 check(not game.army_runtime.native.can_reach(game.player.position,game.model.world_point(Vector2(melon.x,melon.z)),.50),
  "The raised melon beds block movement")
 check(game.world.find_children("UniversityMelonBed*","Node3D",true,false).size()==2
  and game.world.find_children("UniversityRibbedMelon*","MeshInstance3D",true,false).size()>=8,
  "Both growing beds contain modeled melon rows")
 check_highland_loot(Winter.ROOF_GARDEN)
 if hall==Winter.STUDY_HALL:
  await review("University rooftop garden",Vector2(0,-1),Vector3(26,39,42))
  await review("University melons and stairs",Vector2(12,6),Vector3(-8,19,-13))
 if not await cross(hall,Vector2(0,-3)):return false
 check(map_position().distance_to(Winter.ROOF_STAIRS[hall]+Vector2(0,3))<.42,"Roof stair returns to its own hall")
 return true

func check_passage(name_:String,at:Vector2,depth:float):
 var frame=game.world.find_child(name_,true,false)
 check(frame is Node3D and Vector2(frame.position.x,frame.position.z).distance_to(at)<=2.1,
  "The recessed mouth lines up with the walk-in link")
 if frame==null:return
 var reveal=frame.find_child("TunnelReveal",false,false)
 check(reveal is MeshInstance3D and reveal.mesh.get_aabb().size.z>=depth,"The entrance has a recessed 3D throat")

func check_climb():
 var floor_mesh=game.world.find_child("SnowMountainTrailFloor",true,false)
 check(floor_mesh is MeshInstance3D and floor_mesh.get_aabb().size.y>9.8,"The rendered trail gains real elevation")
 if floor_mesh is MeshInstance3D:
  var tread=floor_mesh.material_override.get_shader_parameter("detail_texture")
  check(tread is ImageTexture and floor_mesh.material_override.get_shader_parameter("carved_detail"),
   "The snow surface uses the compacted tread mask")
 var grove=game.world.find_child("SnowMountainTrailGrove",true,false)
 var canopy=grove.get_node_or_null("cg_woodland_Canopy") if grove!=null else null
 check(canopy is MultiMeshInstance3D and canopy.multimesh.instance_count>=18,"The trail has clustered snow-dusted trees")
 check(game.world.find_children("SnowMountainAmberMarker*","MeshInstance3D",true,false).size()==2,
  "Two amber waymarkers frame the cave approach")
 var cliffs=game.world.find_child("SnowMountainCliffFaces",true,false)
 var cornices=game.world.find_child("SnowMountainCornices",true,false)
 check(cliffs is MeshInstance3D and cornices is MeshInstance3D and cliffs.mesh.get_aabb().size.z>84.0
  and cornices.mesh.get_aabb().size.z>84.0,"Both sides have continuous rock strata and modeled snow shelves")
 var walk:PackedByteArray=Winter.floor_info(Winter.TRAIL)[2].hex_decode()
 var tread_points=Tour.Indoor.WinterArt.TRAIL_TREAD
 for index in tread_points.size()-1:
  for i in 17:
   var point:Vector2=tread_points[index].lerp(tread_points[index+1],i/16.0)
   var cell=Vector2i(((point-Winter.ORIGIN)/3.0).round())
   check(Tour.Indoor.open_cell(walk,Winter.SIZE,cell.x,cell.y),"The snow tread follows the walkable switchbacks")
 for row in [4,9,13,18,22]:
  for col in Winter.SIZE.x:
   if not Tour.Indoor.open_cell(walk,Winter.SIZE,col,row):continue
   var point:Vector3=game.model.world_point(Winter.point(Vector2i(col,row)))
   var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP)
   ray.exclude=[game.player.get_rid()]
   var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
   check(not hit.is_empty() and hit.collider.get_meta("snow_mountain_ground",false) and absf(hit.position.y-point.y)<.08,
    "The walkable trail collider matches the game's terrain height")
   break

func check_scenery(id:int,town:bool):
 if town:
  var prop_name:String={51004:"SnowpineMarketProps",51005:"RidgewatchHallProps",
   Winter.ABANIS:"AbanisVillageSquare",Winter.UNIVERSITY:"UniversityCourtyard"}[id]
  var props=game.world.find_child(prop_name,true,false)
  var roofs=game.world.find_children("*","MeshInstance3D",true,false).filter(func(node):
   return node.has_meta("frostpass_roof_profile"))
  var profiles={}
  for roof in roofs:profiles[roof.get_meta("frostpass_roof_profile",-1)]=true
  check(props!=null and props.find_children("*","MeshInstance3D",true,false).size()>1,"The main town facade has solid 3D props")
  check(roofs.size()==Winter.HOUSES[id].size() and profiles.size()>1,"Town roofs use more than one fitted profile")
  var bank=game.world.find_child("TownSnowbanks",true,false)
  var cliff=game.world.find_child("SnowyPalisadeCliffs",true,false)
  var grove=game.world.find_child("SnowyEvergreens",true,false)
  check(bank is MeshInstance3D and cliff is MeshInstance3D,"Snowbanks and cliffs are solid meshes")
  check(grove!=null and grove.get_children().any(func(part):
   return part.get_meta("crossgate_tree_part","")=="Canopy" and part.material_override.get_shader_parameter("snow_amount")>0.0),
   "The reusable evergreens get a town-only snow material")
  if id in [Winter.ABANIS,Winter.UNIVERSITY]:check_highland_loot(id)
  if id==Winter.ABANIS:
   check(game.world.find_children("AbanisHouseDetails*","Node3D",true,false).size()==Winter.HOUSES[id].size(),
    "Abanis has fitted timber and snow details on all six houses")
   check(game.world.find_child("AbanisCurbSnow",true,false) is MeshInstance3D
    and game.world.find_child("AbanisStreetTrees",true,false)!=null,"The village lanes have snowbanks and lamp-side greenery")
   var curb_props=game.world.find_child("AbanisStreetProps",true,false)
   check(curb_props!=null and curb_props.find_children("*","StaticBody3D",true,false).size()==3,
    "The bench and supplies have collision along the outside of the village streets")
  return
 var rocks:Array=Winter.snow_maze(id,game.model.seed_value).rocks if id in Winter.SNOW_FLOORS else Winter.ROCKS[id]
 if id in Winter.SNOW_FLOORS:
  var ice=game.world.find_child("SnowMountainIceMass",true,false)
  var tips=game.world.find_child("SnowMountainIceTips",true,false)
  check(ice is MeshInstance3D and tips is MeshInstance3D and ice.mesh.get_surface_count()==1
   and ice.mesh.get_aabb().size.y>6.7 and tips.mesh.surface_get_array_index_len(0)>2000,
   "The cavern has solid ice masses with batched satellite shards")
  var lights=game.world.find_children("SnowMountainCrystalLight*","OmniLight3D",true,false)
  check(lights.size()==rocks.size() and game.world.get_world_3d().environment.ambient_light_color==Color("bccbed"),
   "The cool cave fill and local crystal lights are active")
 var mass=game.world.find_child("FrostpassRockMass",true,false)
 check(mass is MeshInstance3D and mass.mesh.get_aabb().size.y>5.0,"Cave walls have solid crags behind the boundary faces")
 var walls=game.world.find_child("FrostpassRockWalls",true,false)
 check(walls is MeshInstance3D and walls.mesh.get_surface_count()==1,"The walls are one batched 3D mesh")
 if walls==null:return
 var walk=Tour.Indoor.walk_mask(id,Winter.SIZE,Winter.floor_info(id)[2].hex_decode(),game.model.seed_value)
 var floor_tiles=0
 var edges=0
 for z in Winter.SIZE.y:
  for x in Winter.SIZE.x:
   if not Tour.Indoor.open_cell(walk,Winter.SIZE,x,z):continue
   floor_tiles+=1
   for step:Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
    if not Tour.Indoor.open_cell(walk,Winter.SIZE,x+step.x,z+step.y):edges+=1
 var expected=edges*2*(Tour.Indoor.WinterArt.WALL_PROFILE.size()-1)*6
 check(walls.mesh.surface_get_array_index_len(0)==expected,"Every open-to-rock edge supports a full wall profile")
 check(walls.mesh.get_aabb().size.y>5.0,"The wall profile has full-height stone relief")
 if id in [Winter.SNOW_CAVE,Winter.ICE_VAULT]:
  var grove=game.world.find_child("SnowMountainWoodland",true,false)
  var canopy=grove.get_node_or_null("cg_woodland_Canopy") if grove!=null else null
  var verge=game.world.find_child("SnowMountainLowerTrees",true,false)
  var low=verge.get_node_or_null("cg_silverleaf_Canopy") if verge!=null else null
  var sapling_grove=game.world.find_child("SnowMountainSaplings",true,false)
  var saplings=sapling_grove.get_node_or_null("cg_silverleaf_Canopy") if sapling_grove!=null else null
  var trunks=game.world.find_children("SnowMountainPathTrunk*","StaticBody3D",true,false)
  check(canopy is MultiMeshInstance3D and low is MultiMeshInstance3D and low.multimesh.instance_count>=18
   and saplings is MultiMeshInstance3D and saplings.multimesh.instance_count>=8
   and trunks.size()==low.multimesh.instance_count+saplings.multimesh.instance_count
   and canopy.material_override.get_shader_parameter("snow_breakup")>.5,
   "Both snow floors have layered broadleaf groves with solid trunks along wide paths")
  var drifts=game.world.find_child("SnowMountainWoodlandDrifts",true,false)
  check(drifts is MeshInstance3D and drifts.mesh.get_aabb().size.y>1.0,
   "Snow banks seat the roots in the cave shoulders")
  var bank_drifts=game.world.find_child("SnowMountainBankDrifts",true,false)
  check(bank_drifts is MeshInstance3D and bank_drifts.mesh.get_aabb().size.y<.42,
   "Rounded drifts soften the banks close to the snow surface")
  var roots=game.world.find_child("SnowMountainExposedRoots",true,false)
  check(roots is MeshInstance3D and roots.get_child_count()==0,"Batched roots leave native movement to the existing solid trunks")
  var ice_floor=game.world.find_child("SnowMountainFrozenFloor",true,false)
  check(ice_floor is MeshInstance3D and ice_floor.mesh.surface_get_array_index_len(0)==floor_tiles*6,
   "The continuous frozen surface follows the full walk mask")
  if ice_floor is MeshInstance3D:
   check(ice_floor.material_override.get_shader_parameter("powder_cover")>.95,
    "Snow blankets the floor with exposed ice close to the crystals")
   var bank_colors:=Array(ice_floor.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR])
   check(bank_colors.any(func(color):return color.r==0.0) and bank_colors.any(func(color):return color.r>=.5),
    "The snow surface grades from the middle of each chamber to its generated banks")
   var pools:PackedVector4Array=ice_floor.material_override.get_shader_parameter("crystal_pools")
   for i in rocks.size():
    var light=game.world.find_child("SnowMountainCrystalLight%d"%i,true,false)
    check(i<pools.size() and light is OmniLight3D and Vector2(pools[i].x,pools[i].y).is_equal_approx(Vector2(light.position.x,light.position.z)),
     "The ice sheen starts under its crystal light")
  check(walls.material_override.get_shader_parameter("wall_glaze")==true
   and walls.material_override.get_shader_parameter("powder_cover")>.7,"Both snow floors have snow-dusted rock banks")
  var shelves=game.world.find_child("SnowMountainWallIce",true,false)
  check(shelves is MeshInstance3D and shelves.mesh.surface_get_array_index_len(0)>180,
   "Ice shelves carry modeled hanging ice")
  var ledges=game.world.find_child("SnowMountainLedges",true,false)
  check(ledges is MeshInstance3D and ledges.mesh.surface_get_array_index_len(0)>400,
   "The ice shelves project from the rock as a batched 3D mesh")
  var crust=game.world.find_child("SnowMountainLedgeFrost",true,false)
  check(crust is MeshInstance3D and ledges is MeshInstance3D
   and crust.mesh.surface_get_array_index_len(0)==ledges.mesh.surface_get_array_index_len(0),
   "Frost caps follow the modeled ledge lips")

func check_highland_loot(id:int):
 var floor_info=Tour.Indoor.floor_info(id,game.model.seed_value)
 var walk:PackedByteArray=floor_info[2].hex_decode()
 for slot in game.exploration_loot.slots:
  if not slot.active or not slot.chest:continue
  var at:Vector3=slot.pos/game.model.falan_scale
  var tile=Vector2i(((Vector2(at.x,at.z)-floor_info[1])/3.0).round())
  check(Tour.Indoor.open_cell(walk,floor_info[0],tile.x,tile.y),"Highland treasure stays inside the playable area")
  if id==Winter.ROOF_GARDEN:
   check(not Winter.ROOF_LANDINGS.values().any(func(stair):return Vector2(at.x,at.z).distance_squared_to(stair)<36.0),
    "Treasure stays clear of the rooftop stairs")

func cross(target:int,approach:Vector2=Vector2.INF)->bool:
 var links=game.model.get_meta("falan_links",[]).filter(func(link):
  return link.to=="freyja_outside" and link.area=="west_lakes" if target==0 else link.get("floor",-1)==target)
 check(links.size()==1,"There is one door to "+str(target))
 if links.size()!=1:return false
 var before=game.model
 if approach.is_finite():await position_at(links[0].at+approach)
 await position_at(links[0].at)
 if before==game.model and not approach.is_finite():await walk_through_entry()
 for i in 6:await physics_frame
 var reached=Tour.area(game.model)=="west_lakes" if target==0 else game.model.falan_floor==target
 check(reached,"The door loads "+str(target))
 return reached

func reachable_cells(id:int)->bool:
 var info=Tour.Indoor.floor_info(id)
 var bits=Tour.Indoor.walk_mask(id,info[0],info[2].hex_decode(),game.model.seed_value)
 var seen=connected_floor(bits,Winter.ARRIVALS[id][0],true)
 var required:Array=Winter.DOORS[id]+Winter.ARRIVALS[id]
 if Winter.LEVELS.has(id):required.append_array(Winter.patrols(id,game.model.seed_value))
 if id in Winter.SNOW_FLOORS:
  var hound_routes=connected_floor(bits,Winter.ARRIVALS[id][0],true,.84)
  check(Winter.patrols(id,game.model.seed_value).all(func(cell):return hound_routes.has(cell)),
   "Ground-level trunks leave the native hellhound routes open")
 return required.all(func(cell):return seen.has(cell))

func connected_floor(bits:PackedByteArray,start:Vector2i,check_native:bool,radius:float=.50,grid_size:Vector2i=Winter.SIZE)->Dictionary:
 var queue:Array[Vector2i]=[start]
 var seen={start:true}
 for cell:Vector2i in queue:
  for step in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next=cell+step
   if seen.has(next) or not Tour.Indoor.open_cell(bits,grid_size,next.x,next.y):continue
   if check_native:
    var from:Vector3=game.model.world_point(Winter.point(cell))
    var to:Vector3=game.model.world_point(Winter.point(next))
    if not game.army_runtime.native.can_reach(from,to,radius):continue
   seen[next]=true
   queue.append(next)
 return seen

func review(filename:String,at:Vector2,offset:Vector3,folder:String=REVIEW,ortho_size:float=0.0):
 if DisplayServer.get_name()=="headless":return
 var was_paused=paused
 paused=true
 game.ui.hide()
 game.set_process(false)
 var labels=game.world.find_children("*","Label3D",true,false).filter(func(label):
  return label.visible and label.name not in ["FrostpassTrailSign","SnowpineMarketSign","HighlandHallSign","UniversityStairSign"] and not str(label.name).begins_with("HighlandRouteSign"))
 for label in labels:label.hide()
 var camera:Camera3D=game.camera_rig.camera
 var projection=camera.projection
 var size=camera.size
 var target:Vector3=game.model.world_point(at,1.0)
 camera.global_position=target+offset
 camera.look_at(target)
 camera.fov=65
 if ortho_size>0.0:
  camera.projection=Camera3D.PROJECTION_ORTHOGONAL
  camera.size=ortho_size
 camera.reset_physics_interpolation()
 for i in 4:await process_frame
 RenderingServer.force_draw()
 var output=folder+"Seed %d/"%game.model.seed_value
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 check(root.get_texture().get_image().save_png(output+filename+".png")==OK,"Captured "+filename)
 camera.projection=projection
 camera.size=size
 for label in labels:label.show()
 game.set_process(true)
 game.ui.show()
 paused=was_paused
