extends SceneTree
const Doc=preload("res://scripts/forest/forest_map_document.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const OUT="res://build/Other Files/BlueCG Map Study/"
const Dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Zombie=preload("res://scripts/forest/crowd/zombie_sprites.gd")
const Captain=preload("res://scripts/forest/crowd/captain_sprites.gd")
const Habaru=preload("res://scripts/forest/crowd/habaru_sprites.gd")
const Undersea=preload("res://scripts/forest/crowd/undersea_sprites.gd")
const Grave=preload("res://scripts/forest/crowd/grave_sprites.gd")
const Ruby=preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
const Entrances=preload("res://scripts/forest/forest_freyja_destination_art.gd")
var errors=0
var game
func _initialize():
 create_timer(220).timeout.connect(func():printerr("FALAN_TIMEOUT paused=",paused," phase=",game.model.phase if is_instance_valid(game) and game.model!=null else "no model"," upgrade=",is_instance_valid(game.team_upgrade_picker) if is_instance_valid(game) else false);quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 if not ok:
  errors+=1
  printerr("FALAN_FAIL ",message)
func run():
 root.size=Vector2i(1440,900)
 root.title="Goemon · Freyja and Falan Interior Review"
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/freyja-interiors/review.cfg"
 root.add_child(game)
 current_scene=game
 for i in 4:await process_frame
 game.settings.forest_level_up_cards=false
 var saved=Doc.new(false)
 var saved_error=saved.read_file(Doc.MAP_FOLDER.path_join(Doc.saved_filename("Freyja and Falan - Test")))
 check(saved_error.is_empty(),"Existing Falan start map validates: "+saved_error)
 if not saved_error.is_empty():await finish();return
 var button=game.find_child("ForestFalan",true,false)
 check(button is Button and button.is_visible_in_tree(),"The title visibly offers the existing Freyja and Falan save")
 if errors:quit(1);return
 button.pressed.emit()
 check(game.rogue_roster_open,"The title shortcut opens the normal fighter selection")
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.model.team_progression.cards_enabled=false
 check(is_instance_valid(game.equipment_hub) and game.model.phase=="preparing","Fighter selection opens Equipment for the saved map")
 check(Tour.area(game.model)=="city","Fighter selection opens Falan City")
 var venture:Dictionary=get_meta("falan_venture",{})
 check(venture.get("falan_areas",{}).size()==4 and not venture.get("terrain_detail","").is_empty(),"The single save carries the West Gate and all linked areas")
 var spawn:Vector3=game.player.position
 check(map_position().distance_to(Vector2(-234,-108))<.01 and game.model.terrain.disk_clear(spawn/game.model.falan_scale,.55),"The player starts on clear ground at the employment plaza")
 check(not game.model.scenery_obstacles.values().any(func(box):return box.grow(.6).has_point(spawn/game.model.falan_scale)),"The player starts outside scenery collision")
 var explore=game.equipment_hub.enter_button
 check(explore.is_visible_in_tree() and explore.text=="Enter Map","Equipment offers the current Enter Map flow")
 explore.pressed.emit()
 check(game.model.phase=="wave" and Tour.area(game.model)=="city","Explore starts inside the reconstructed city")
 for i in 5:await physics_frame
 game.camera_rig.set_process(false)
 game.camera_rig.set_process_unhandled_input(false)
 game.camera_rig.yaw=0
 if "--kili-houses" in OS.get_cmdline_user_args():
  await open_area("kili")
  for id in [3801,3802,3803,3807]:
   await room(id)
   await room(3200)
  print("KILI_HOUSES_RESULT failures=",errors)
  await finish()
  return
 if "--coastal-kili" in OS.get_cmdline_user_args() or "--coastal-venoa" in OS.get_cmdline_user_args():
  if "--coastal-kili" in OS.get_cmdline_user_args():await check_kili()
  else:await check_venoa()
  print("COASTAL_VILLAGE_RESULT failures=",errors)
  await finish()
  return
 if "--water-ground" in OS.get_cmdline_user_args():
  await check_water_ground()
  print("FREYJA_WATER_GROUND_RESULT failures=",errors)
  await finish()
  return
 if "--patrol-progression" in OS.get_cmdline_user_args():
  await check_patrol_progression()
  print("PATROL_PROGRESSION_RESULT failures=",errors)
  await finish()
  return
 if "--frontier-patrols" in OS.get_cmdline_user_args():
  await check_frontier_patrols()
  print("FRONTIER_PATROLS_RESULT failures=",errors)
  await finish()
  return
 if "--alyut-west-roads" in OS.get_cmdline_user_args():
  await check_alyut_west_roads()
  print("ALYUT_WEST_ROADS_RESULT failures=",errors)
  await finish()
  return
 if "--il-habaru-alyut" in OS.get_cmdline_user_args():
  await check_il_habaru_alyut()
  print("IL_HABARU_ALYUT_RESULT failures=",errors)
  await finish()
  return
 if "--habaru-stairs" in OS.get_cmdline_user_args():
  game.tuning.invincible=true
  Tour.travel(game,Tour.Indoor.layout(11003),{"arrival":Vector2(42,-51),"yaw":0.0})
  for i in 16:await physics_frame
  await check_habaru_slimes()
  await check_habaru_slime_contact()
  await walk_habaru_link("floor",11004)
  await walk_habaru_link("floor",11003)
  await walk_habaru_link("floor",11004)
  await position_at(Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,15))
  for i in 16:await physics_frame
  check(game.model.enemies.size()==10,"All ten bears spawn before testing the cleared stair route")
  for enemy in game.model.enemies.values():game.army_runtime.damage_enemy(enemy.id,100000)
  for i in 12:await physics_frame
  await check_habaru_ladder(game.world.habaru_ladder)
  await walk_habaru_link("floor",11005)
  await check_habaru_slimes()
  await walk_habaru_link("floor",11004)
  await position_at(Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,15))
  for i in 16:await physics_frame
  check(game.model.enemies.is_empty(),"The bear fight remains cleared after the Alyut stair round trip")
  await walk_habaru_link("floor",11005)
  print("HABARU_STAIRS_RESULT failures=",errors)
  await finish()
  return
 if "--habaru-ladder" in OS.get_cmdline_user_args():
  var boss:Vector2=Tour.Regions.Sites.HABARU_FORMATION[0]
  Tour.travel(game,Tour.Indoor.layout(11004),{"arrival":boss+Vector2(0,15),"yaw":0.0})
  await position_at(boss+Vector2(0,15))
  game.tuning.invincible=true
  for i in 16:await physics_frame
  check(game.model.enemies.size()==10 and not game.world.habaru_ladder.open,"The native encounter starts with the hatch locked")
  for i in 16:await physics_frame
  for enemy in game.model.enemies.values():game.army_runtime.damage_enemy(enemy.id,100000)
  for i in 12:await physics_frame
  await check_habaru_ladder(game.world.habaru_ladder)
  print("HABARU_LADDER_RESULT failures=",errors)
  await finish()
  return
 if "--mountain-tomato" in OS.get_cmdline_user_args():
  await check_mountain_tomato()
  print("MOUNTAIN_TOMATO_RESULT failures=",errors)
  await finish()
  return
 if "--west-laruka-road" in OS.get_cmdline_user_args():
  await check_west_laruka_road()
  print("WEST_LARUKA_ROAD_RESULT failures=",errors)
  await finish()
  return
 if "--east-il-road" in OS.get_cmdline_user_args():
  await check_east_il_road()
  print("EAST_IL_ROAD_RESULT failures=",errors)
  await finish()
  return
 if "--west-south-gates" in OS.get_cmdline_user_args():
  await check_west_south_gates()
  print("WEST_SOUTH_GATE_RESULT failures=",errors)
  await finish()
  return
 if "--south-venoa-road" in OS.get_cmdline_user_args():
  await check_south_venoa_road()
  print("SOUTH_VENOA_ROAD_RESULT failures=",errors)
  await finish()
  return
 if "--entry-controls" in OS.get_cmdline_user_args():
  await check_entry_controls()
  print("ENTRY_CONTROLS_RESULT failures=",errors)
  await finish()
  return
 if "--castle-exterior" in OS.get_cmdline_user_args():
  await check_castle_exterior()
  print("CASTLE_EXTERIOR_RESULT failures=",errors)
  await finish()
  return
 if "--dungeon-entrances" in OS.get_cmdline_user_args():
  await check_dungeon_entrances()
  print("DUNGEON_ENTRANCES_RESULT failures=",errors)
  await finish()
  return
 if "--freyja-scale" in OS.get_cmdline_user_args():
  await check_freyja_scale()
  print("FREYJA_SCALE_RESULT failures=",errors)
  await finish()
  return
 if "--ruby-boss" in OS.get_cmdline_user_args():
  await check_ruby_boss()
  print("RUBY_BOSS_RESULT failures=",errors)
  await finish()
  return
 if "--forest-grave" in OS.get_cmdline_user_args():
  await check_forest_grave()
  print("FOREST_GRAVE_RESULT failures=",errors)
  await finish()
  return
 if "--ghana-north" in OS.get_cmdline_user_args():
  await check_ghana_north()
  print("GHANA_NORTH_RESULT failures=",errors)
  await finish()
  return
 if "--ghana" in OS.get_cmdline_user_args():
  await check_ghana()
  print("GHANA_RESULT failures=",errors)
  await finish()
  return
 if "--great-wind-road" in OS.get_cmdline_user_args():
  await check_great_wind_road()
  print("GREAT_WIND_ROAD_RESULT failures=",errors)
  await finish()
  return
 if "--kili" in OS.get_cmdline_user_args():
  await check_kili()
  print("KILI_RESULT failures=",errors)
  await finish()
  return
 if "--kili-coast-road" in OS.get_cmdline_user_args():
  await check_kili_coast_road()
  print("KILI_COAST_ROAD_RESULT failures=",errors)
  await finish()
  return
 if "--alyut-west-night" in OS.get_cmdline_user_args():
  await check_alyut_west_night()
  print("ALYUT_WEST_NIGHT_RESULT failures=",errors)
  await finish()
  return
 if "--zombie-random-preview" in OS.get_cmdline_user_args():
  game.tuning.invincible=true
  Tour.travel(game,Tour.Indoor.layout(Zombie.FINAL),{"arrival":Vector2(45,-57),"yaw":0.0})
  for i in 16:await physics_frame
  var maze=Tour.Indoor.ZombieMaze
  var info=Tour.Indoor.floor_info(Zombie.FINAL)
  var bits=Tour.Indoor.walk_mask(Zombie.FINAL,info[0],info[2].hex_decode(),game.model.seed_value)
  var places=[Vector2(45,-57),maze.patrol_point(0,game.model.seed_value),Vector2(-12,-12)]
  for index in places.size():
   var at:Vector2=places[index]
   await position_at(at)
   var cell=Vector2i((at-info[1])/3.0)
   var direction=Vector2.UP
   for candidate:Vector2i in maze.Imur.DIRECTIONS:
    if Tour.Indoor.open_cell(bits,info[0],cell.x+candidate.x*2,cell.y+candidate.y*2):direction=Vector2(candidate);break
   game.camera_rig.yaw=atan2(-direction.x,-direction.y)
   game.camera_rig.pitch=.32
   game.camera_rig.reset_follow()
   for i in 24:
    await physics_frame
    game.camera_rig.update_camera(1.0/60.0)
   check(game.camera_rig.current_distance>2.0,"The gameplay camera has clearance in the random cave")
   await RenderingServer.frame_post_draw
   var folder=ProjectSettings.globalize_path(OUT+"Zombie Random/")
   DirAccess.make_dir_recursive_absolute(folder)
   root.get_texture().get_image().save_png(folder+str(index)+"-gameplay.png")
  check_zombie_maze_paths()
  print("ZOMBIE_RANDOM_PREVIEW_RESULT failures=",errors)
  await finish()
  return
 if "--zombie-cave" in OS.get_cmdline_user_args():
  await check_zombie_cave()
  print("ZOMBIE_CAVE_RESULT failures=",errors)
  await finish()
  return
 if "--venoa-undersea" in OS.get_cmdline_user_args():
  await check_venoa_undersea()
  print("VENOA_UNDERSEA_RESULT failures=",errors)
  await finish()
  return
 if "--undersea-encounters" in OS.get_cmdline_user_args():
  await check_undersea_encounters()
  print("UNDERSEA_ENCOUNTERS_RESULT failures=",errors)
  await finish()
  return
 if "--undersea-portals" in OS.get_cmdline_user_args():
  await check_undersea_portals()
  print("UNDERSEA_PORTALS_RESULT failures=",errors)
  await finish()
  return
 if "--venoa-cave" in OS.get_cmdline_user_args():
  await check_venoa_cave()
  print("VENOA_CAVE_RESULT failures=",errors)
  await finish()
  return
 if "--venoa" in OS.get_cmdline_user_args():
  await check_venoa()
  print("VENOA_RESULT failures=",errors)
  await finish()
  return
 var regions=Tour.Regions
 await open_area("east_coast")
 await site(2000,"il_village")
 village_entries(6)
 await room(2001)
 check(game.world.find_child("OriginalFalanNPCs",true,false).get_child_count()>=4,"Original Il equipment shop NPCs are present")
 if DisplayServer.get_name()!="headless":await shot("il-equipment-shop",Vector3(17,19,23),Vector3(-7,0,-4),62)
 await room(2000)
 await room(2012)
 await room(2099)
 await room(2012)
 await room(2000)
 await leave_village("east_coast")
 await open_area("west_lakes")
 await site(2300,"laruka")
 village_entries(7)
 var entries=game.model.get_meta("falan_links").filter(func(l):return l.get("floor")==2301)
 check(entries.size()==2 and entries[0].at!=entries[1].at,"Both Laruka equipment shop doors work independently")
 await room(2301,1)
 await room(2302)
 await room(2303)
 if DisplayServer.get_name()!="headless":await shot("laruka-workshop",Vector3(25,45,45),Vector3(0,0,4),66)
 await room(2302)
 await room(2301)
 await room(2300,1)
 await room(2306)
 await room(2307)
 await room(2306)
 await room(2300)
 await leave_village("west_lakes")
 await open_area("east_coast")
 var mouth=regions.site_links(regions.canonical_area("east_coast")).filter(func(l):return l.site==11003)[0]
 await position_at(mouth.at)
 await walk_through_entry()
 check(game.model.falan_floor==11003,"The Il entrance opens onto the original Habaru passage")
 await walk_habaru_link("floor",11004)
 check_archived_arena()
 check_single_floor([11003,11005])
 check(game.model.enemies.is_empty(),"The bears wait until the nearby conversation finishes")
 check_ceiling()
 var formation:Array=regions.Sites.HABARU_FORMATION
 var boss:Vector2=formation[0]
 game.tuning.invincible=true
 await position_at(boss+Vector2(0,15))
 for i in 20:await physics_frame
 var units=game.model.enemies.values()
 check(units.size()==10,"The chamber spawns exactly one boss and nine cave bears, got "+str(units.size()))
 check(units.filter(func(e):return e.get("skin")==0).size()==1,"Ozunack uses his own source sprite")
 check(units.filter(func(e):return e.get("skin")==1).size()==9,"Nine native units use the original cave bear sprites")
 check(units.all(func(e):return e.max_hp==(30000.0 if e.habaru_slot==0 else 10000.0)),"熊弟 and his bears use the requested HP")
 check(game.model.get_meta("cave_combat_walls",[]).size()>100,"Native ground and rays use original cave boundaries")
 check(game.army_runtime.handles.size()>=10,"All encounter units reached the native combat runtime")
 var sizes=preload("res://scripts/forest/crowd/habaru_sprites.gd").motions().variants
 check(is_equal_approx(sizes[0].standing_height,preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT*2),"Ozunack is twice the previous height")
 check(is_equal_approx(sizes[1].standing_height,6.7),"The Habaru bears are twice the previous height")
 for row in units:
  var actor=game.army_runtime.enemy_target(row.id)
  check(is_equal_approx(actor.local_combat_box().size.y,Dimensions.body(Habaru,row.skin).size.y*Roles.MAP_ENEMY_SCALE),"Player contact uses the fitted source body and current map enemy scale")
 if errors:quit(1);return
 if DisplayServer.get_name()!="headless":
  await shot("habaru-interior-bears",Vector3(boss.x+1.5,3.8,boss.y+20),Vector3(boss.x,1.8,boss.y+10),68)
 var tracks:Dictionary={}
 for row in units:tracks[row.id]=game.army_runtime.unit_state(game.army_runtime.handles[row.id]).position
 game.tuning.invincible=false
 var normal_hp:float=game.player.hp
 var combat_max_hp:float=game.player.max_hp
 game.player.max_hp=1000.0
 game.player.hp=1000.0
 var old_hp:float=game.player.hp
 for i in 160:
  await physics_frame
  if game.player.hp<old_hp:break
 check(game.player.hp<old_hp and game.player.hp>0,"The cave pack can reach and hit the player with native melee")
 game.tuning.invincible=true
 game.player.max_hp=combat_max_hp
 game.player.hp=normal_hp
 var moved=false
 for row in units:
  var state=game.army_runtime.unit_state(game.army_runtime.handles[row.id])
  moved=moved or state.position.distance_to(tracks[row.id])>.3
 check(moved,"The pack moves using the native navigation")
 for row in units:
  game.army_runtime.damage_enemy(row.id,100000)
 for i in 12:await physics_frame
 check(game.model.enemies.is_empty() and get_meta("habaru_slain",{}).size()==10,"Victory retires all ten combatants and records the clear")
 check_ceiling()
 await walk_habaru_link("floor",11005)
 await walk_habaru_link("exit_id",11005)
 if Tour.area(game.model)!="north_coast":return
 check(game.model.enemies.is_empty(),"The Alyut mouth opens onto the coast with no escaped bears")
 var roads=regions.site_links("north_coast").filter(func(l):return l.site==2400)
 check(roads.size()==2,"Both original Alyut entrances are available from the North Coast")
 var landing=map_position()
 for road in roads:
  check(road_connected(landing,road.at,0.0,false),"The painted dry road connects Habaru to the village")
 await site(2400,"alyut")
 village_entries(5)
 check(game.world.find_child("OriginalFalanNPCs",true,false).get_child_count()>=6,"Original villagers appear as sprites")
 if DisplayServer.get_name()!="headless":
  await shot("alyut-village",village_world(Vector3(29,65,64),"alyut"),village_world(Vector3(-12,6,0),"alyut"),61)
 await room(2401)
 await room(2400)
 await room(2410)
 await room(2400)
 await room(2420)
 await room(2400)
 await room(2421)
 await room(2400)
 await room(2412)
 if DisplayServer.get_name()!="headless":
  await shot("alyut-chief-house",Vector3(12,21,30),Vector3(-7,0,0),58)
 await room(2499)
 await room(2412)
 await room(2400)
 await check_alyut_coast_gates()
 var other=regions.site_links("north_coast").filter(func(l):return l.site==11005)[0]
 await position_at(other.at)
 await walk_through_entry()
 check(game.model.falan_floor==11005,"The Alyut mouth returns to its original entrance passage")
 await walk_habaru_link("floor",11004)
 await position_at(boss+Vector2(0,15))
 for i in 10:await physics_frame
 check(game.model.enemies.is_empty(),"The cleared encounter stays defeated on re-entry")
 print("VILLAGES_AND_HABARU failures=",errors)
 game.tuning.invincible=false
 game.player.invuln=0.0
 game.model.damage_building(1,1000000.0)
 game.player.take_hit(1.0,Vector3.FORWARD)
 check(game.player.hp>0 and game.model.phase=="wave","Only fatal player damage ends this run")
 game.player.invuln=0.0
 game.player.take_hit(1000000.0,Vector3.FORWARD)
 game._physics_process(1.0/60.0)
 check(game.player.hp==0.0 and game.model.phase=="defeat" and game.paused and game.respawn_left==0.0,"Death immediately ends the run without a respawn")
 check(is_instance_valid(game.forest_ui.overlay) and game.forest_ui.overlay.find_children("*","Label",true,false).any(func(label):return label.text=="RUN OVER"),"Run Over is displayed")
 var clock:float=game.model.waves.wave_clock
 game._physics_process(30.0)
 check(game.player.hp==0.0 and game.model.waves.wave_clock==clock,"A defeated run remains stopped")
 print("FALAN_LINK_RESULT failures=",errors)
 await finish()

func finish():
 game.queue_free()
 paused=false
 for i in 4:await process_frame
 quit(1 if errors else 0)

func check_water_ground():
 for row in [["east_gate",Vector2(460,201)],["south_gate",Vector2(416,260)]]:
  var venture:Dictionary=get_meta("falan_venture")
  var at=Tour.Regions.frame(row[0]).inverse()*(row[1]*3.0)
  Tour.travel(game,Tour.outdoor_layout(venture,row[0]),{"arrival":at,"yaw":PI,"velocity":Vector3.ZERO})
  var scale_:float=game.model.falan_scale
  var hp:float=game.player.hp
  game.player.position=Vector3(at.x,Tour.Document.Model.FreyjaTerrain.WATER_HEIGHT+.16,at.y)*scale_
  game.player.velocity=Vector3.ZERO
  game.checkpoint=game.model.world_point(Vector2(3,174))
  for i in 20:await physics_frame
  check(game.player.is_on_floor(),"River water supports Kaz on "+row[0])
  check(absf(game.player.position.y-2.0*scale_)<.30,"Kaz stands at the visible water surface")
  check(not game.world.submerged(game.player.position-Vector3.UP*3),"Water cannot trigger a shore return")
  check(not game.model.terrain.contains(at.x,at.y),"River ground does not open a route for native enemies")
  var from:Vector3=game.player.position
  Input.action_press("move_forward")
  for i in 20:await physics_frame
  Input.action_release("move_forward")
  check(game.player.position.distance_to(from)>1.0 and game.player.position.distance_to(from)<10.0,
   "Kaz can walk on water without moving to the checkpoint")
  check(game.player.hp==hp and game.model.phase=="wave","Walking on river water keeps the run alive")
  if row[0]=="south_gate":
   var bank=Tour.Regions.frame("south_gate").inverse()*(Vector2(420,265)*3.0)
   await position_at(bank)
   game.camera_rig.yaw=PI*.5
   Input.action_press("move_forward")
   for i in 65:await physics_frame
   Input.action_release("move_forward")
   for i in 12:await physics_frame
   check(map_position().x<bank.x-4.0 and game.player.is_on_floor() and absf(game.player.position.y-2.0*scale_)<.30,
    "Walking off the riverbank reaches solid water without a jump")
   check(game.player.hp==hp,"Walking from the bank into the river does no damage")
  if DisplayServer.get_name()!="headless":
   game.camera_rig.update_camera(.2)
   var camera:Camera3D=game.camera_rig.camera
   await shot("East Gate Orientation/"+row[0]+"-water-walking",camera.global_position,game.player.position+Vector3.UP*1.3,63)

func check_patrol_progression():
 var patrols=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
 var expected=[[1,300,30],[2,500,30],[4,1200,35],[3,800,35],[5,2000,40]]
 var out=OUT+"Monster Progression/"
 DirAccess.make_dir_recursive_absolute(out)
 for skin in 5:
  for bonus in [0,2,4]:
   var stats=patrols.progression(skin,bonus)
   check(stats.level==expected[skin][0]+bonus and stats.hp==roundf(expected[skin][1]*(1+.2*bonus)) and stats.damage==roundf(expected[skin][2]*(1+.1*bonus)),"Species base stats and area growth: %d +%d"%[skin,bonus])
   check(stats.xp_reward_tenths==10*stats.level,"Outdoor enemies award one XP per monster level")
 game.set_physics_process(false);game.player.set_physics_process(false)
 game.tuning.invincible=true;game.player.set_auto_attack(false)
 for area in ["east_gate","west_lakes","north_coast","south_lakes"]:
  await open_area(area)
  game.set_physics_process(false);game.player.set_physics_process(false)
  game.paused=true
  var waves=game.model.waves
  var runtime=game.army_runtime
  runtime.finish_integration()
  runtime.refresh_navigation(0)
  for i in waves.patrol_posts.size()+1:waves.tick(12.0,Vector3(0,6,240)*game.model.falan_scale)
  runtime.import_arrivals()
  var checked={}
  for slot in waves.patrol_owners:
   var id:int=waves.patrol_owners[slot]
   if not game.model.enemies.has(id):continue
   var row:Dictionary=game.model.enemies[id]
   var post:Vector4i=waves.patrol_posts[slot]
   var bonus=4 if area in ["north_coast","south_lakes"] else 2 if area=="west_lakes" or post.w in range(1021,1028) else 0
   var want=expected[row.skin] if row.skin<5 else [patrols.LEVELS[row.skin],3000,30]
   var hp=roundf(want[1]*(1+.2*bonus))
   var damage=roundf(want[2]*(1+.1*bonus))
   var state:Dictionary=runtime.unit_state(runtime.handles.get(id,0))
   check(row.level==want[0]+bonus and state.get("max_hp")==hp and state.get("hp")==hp,"Spawned native HP and level: "+area+"/"+str(row.skin))
   check(is_equal_approx(row.damage_scale*patrols.STATS.damage,damage),"Spawned damage scale")
   var key=Vector2i(row.skin,bonus)
   if checked.has(key):continue
   checked[key]=id
   var at:Vector3=state.position
   var target=at
   for direction in [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT]:
    var candidate=at+direction*1.6
    candidate.y=game.model.world_height(candidate.x,candidate.z)
    if runtime.native.can_reach(at,candidate,.55):target=candidate;break
   check(target!=at,"Contact fixture has reachable footing")
   var targets:Dictionary=runtime.external_targets()
   targets.positions[0]=target;targets.targetable[0]=1
   runtime.native.set_targets(targets);runtime.take_events()
   var hits=[]
   for i in 240:
    runtime.native.step(1.0/30)
    hits.append_array(runtime.take_events().filter(func(event):return event.kind=="external_damage" and event.source_id==id))
    if hits.size()>=2:break
   check(hits.size()>=2 and hits.all(func(hit):return is_equal_approx(hit.amount,damage)),"Repeated native contacts deliver %d damage: %s/%d"%[damage,area,row.skin])
  check(checked.size()>=(5 if area=="east_gate" else 1 if area=="south_lakes" else 3),"Established and additional local species/levels appear in "+area)
  print("PATROL_PROGRESSION_POPULATION ",area," ",game.model.enemies.size())
  runtime.native.set_targets(runtime.external_targets());runtime.sync_compatibility()
  if checked.is_empty():continue
  var row:Dictionary=game.model.enemies[checked.get(Vector2i(patrols.TREE,4),checked.values()[0])]
  var actor=runtime.enemy_target(row.id)
  game.player.position=actor.position+Vector3(0,0,6)
  game.model.update_vision(game.player.position)
  var aim:Vector3=actor.combat_bounds().get_center()
  var camera:Camera3D=game.camera_rig.camera
  camera.global_position=aim+Vector3(0,1,10);camera.look_at(aim);camera.reset_physics_interpolation()
  game.paused=false
  await physics_frame
  game.forest_ui._physics_process(0)
  check(game.forest_ui.patrol_target.visible and game.forest_ui.patrol_target.text=="%s · Lv.%d"%[patrols.NAMES[row.skin],row.level],"Aimed native monster displays only its name and level")
  var nodes=game.forest_ui.get_child_count()
  for i in 50:game.forest_ui._physics_process(0)
  check(game.forest_ui.get_child_count()==nodes,"Repeated targeting reuses the same HUD")
  game.paused=true;game.forest_ui._physics_process(0)
  check(not game.forest_ui.patrol_target.visible,"Pause hides the target readout")
  game.paused=false;game.forest_ui._physics_process(0)
  if DisplayServer.get_name()!="headless":
   game.crowd.present_army(runtime.render_snapshot(),[])
   for i in 4:await process_frame
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(out+area+".png")==OK,"Capture visible progression: "+area)
  game.paused=false
  var progression=game.model.team_progression
  progression.reset();progression.cards_enabled=false
  runtime.damage_enemy(row.id,100000)
  check(progression.total_kills==row.level,"Native death grants the outdoor monster's level in XP")
  runtime.damage_enemy(row.id,100000)
  check(progression.total_kills==row.level,"Retired enemy cannot award XP twice")
  game.paused=false
  game.forest_ui._physics_process(0)
  check(not game.forest_ui.patrol_target.visible,"Defeated target clears the level display")

func check_frontier_patrols():
 var patrols=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
 var kaz_height:float=game.player.model.standing_height()
 check(Dimensions.body(patrols,patrols.GOBLIN).size.y<kaz_height*.8,"Goblins remain smaller than Kaz")
 check(patrols.motions().variants[patrols.BEE].id==101313,"The Il encounter uses the original 黃蜂 sprite")
 check(patrols.motions().variants[patrols.TREE].standing_height>=kaz_height*1.6,"The tree is substantially taller than Kaz")
 var edge:float=Tour.Frontier.OUTER_EDGE.east_gate
 game.camera_rig.yaw=.35
 await position_at(Tour.Frontier.to_city("east_gate",Vector2(3,edge-1)))
 await position_at(Tour.Frontier.to_city("east_gate",Vector2(3,edge+1)))
 check(Tour.area(game.model)=="east_gate","The East Gate still opens on foot")
 if Tour.area(game.model)!="east_gate":return
 var east_frame=Tour.Regions.frame("east_gate")
 var start:Vector2=east_frame*map_position()
 Input.action_press("move_forward")
 for i in 24:await physics_frame
 Input.action_release("move_forward")
 var movement:Vector2=east_frame*map_position()-start
 check(movement.x>1.0 and absf(movement.y)<.3,"Holding forward outside the East Gate continues east on the original road")
 var minimap=game.forest_ui.enemy_minimap
 minimap.refresh()
 var west:Vector2=minimap.chart_position(east_frame.inverse()*Vector2(1659,702))
 var east:Vector2=minimap.chart_position(east_frame.inverse()*Vector2(1677,702))
 check(east.x>west.x and absf(east.y-west.y)<.1,"The East Gate chart shows the original canal crossing west to east")
 await chart_capture("east-gate-compass",["Road to Il Village"],"Falan Patrols")
 await verify_patrol_combat(Vector2(3,242),[patrols.BAT,patrols.GOBLIN])
 var seam:Vector2=Tour.Regions.frame("east_gate").inverse()*Vector2(1662,702)
 await position_at(seam-Vector2(0,1))
 Input.action_press("move_forward")
 for i in 45:await physics_frame
 Input.action_release("move_forward")
 check(Tour.area(game.model)==Tour.Regions.canonical_area("east_coast"),"The trail crosses the canal into the far patrol region")
 if Tour.area(game.model)!=Tour.Regions.canonical_area("east_coast"):return
 var forward=Vector3.FORWARD.rotated(Vector3.UP,game.camera_rig.yaw)
 check(forward.x>.99 and absf(forward.z)<.01,"The camera still points east on the far bank")
 var far_bank:Vector2=Tour.Regions.frame(Tour.area(game.model))*map_position()
 check(far_bank.x>1664 and absf(far_bank.y-702)<.3,"Holding forward continues on the same eastbound line across the bridge")
 await verify_patrol_combat(map_position(),[patrols.BEE,patrols.TREE,patrols.BANDIT])

func verify_patrol_combat(landing:Vector2,skins:Array):
 await position_at(landing)
 var runtime=game.army_runtime
 game.paused=true
 runtime.finish_integration()
 var waves=game.model.waves
 for i in waves.patrol_posts.size()+1:
  waves.tick(12.0,game.player.position)
 runtime.import_arrivals()
 var enemies:Array=game.model.enemies.values()
 check(enemies.size()>=20 and enemies.all(func(row):return runtime.handles.has(row.id)),
  "The right patrols are spread across the region and use the native army")
 print("FRONTIER_PATROL_COUNT ",Tour.area(game.model)," ",enemies.size())
 for skin in skins:
  var matches=enemies.filter(func(row):return row.skin==skin)
  check(not matches.is_empty(),"Patrol skin %d is present" % skin)
  if matches.is_empty():continue
  var enemy:Dictionary=matches[0]
  var handle:int=runtime.handles.get(enemy.id,0)
  var state:Dictionary=runtime.unit_state(handle)
  if state.is_empty():continue
  check(state.max_hp==enemy.max_hp and state.hp==enemy.hp,"The native unit owns the species/area HP")
  if skin==waves.Patrols.TREE:
   check(runtime.enemy_target(enemy.id).local_combat_box().size.y>5.2,"The taller tree has a fitted combat box")
  var from:Vector3=state.position
  var target=from
  for direction in [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT]:
   var candidate=from+direction*1.6
   candidate.y=game.model.world_height(candidate.x,candidate.z)
   if runtime.native.can_reach(from,candidate,.55):
    target=candidate
    break
  check(target!=from,"There is room to stand beside the patrol")
  var rows:Dictionary=runtime.external_targets()
  rows.positions[0]=target
  rows.targetable[0]=1
  runtime.native.set_targets(rows)
  runtime.take_events()
  var hits=[]
  for i in 120:
   runtime.native.step(1.0/30)
   hits.append_array(runtime.take_events().filter(func(event):return event.kind=="external_damage" and event.source_id==enemy.id))
   if not hits.is_empty():break
  if hits.is_empty():print("PATROL_CONTACT_TRACE skin=",skin," before=",state," after=",runtime.unit_state(handle)," targets=",rows)
  check(not hits.is_empty() and hits.all(func(hit):return is_equal_approx(hit.amount,waves.Patrols.STATS.damage*enemy.damage_scale)),"Skin %d delivers its scaled damage at its native attack contact" % skin)
 runtime.native.set_targets(runtime.external_targets())
 game.paused=false
 await position_at(landing)
 if DisplayServer.get_name()!="headless":
  for skin in skins:
   var matches=enemies.filter(func(row):return row.skin==skin)
   if matches.is_empty():continue
   var at:Vector3=runtime.unit_state(runtime.handles[matches[0].id]).position
   await shot("Falan Patrols/patrol-%d"%skin,at+Vector3(3,4,9),at+Vector3.UP*1.65,58,true)

func check_alyut_west_roads():
 await open_area("north_coast")
 var coast=Tour.Regions.frame("north_coast").inverse()
 var sites=Tour.Regions.site_links("north_coast")
 var north=sites.filter(func(link):return link.site==2400 and link.arrival.y<0)[0]
 var west=sites.filter(func(link):return link.site==16501)[0]
 var zombie=sites.filter(func(link):return link.site==410)[0]
 var north_gate:Vector2=north.at+Vector2(1.5,0)
 var landing:Vector2=coast*Vector2(1761,150)
 check(game.world.find_child("AlyutNorthGate",true,false)!=null,"The timber gate appears on the road")
 var outdoors=game.model
 await position_at(north_gate+Vector2(0,-4))
 await position_at(north_gate+Vector2(0,4))
 check(game.model==outdoors and Tour.area(game.model)=="north_coast","Alyut's north gate shares the same landscape")
 await position_at(landing)
 check(road_connected(landing,west.at,.55,false),"The archived coastal road reaches Alyut West Cave")
 check(road_connected(landing,zombie.at,.55,false),"The road branches to Zombie Cave")
 check(road_connected(west.at,zombie.at,.55),"The caves are linked by a clear dry path")
 check(game.world.find_child("ArchivedGateRidges",true,false)!=null,"The northwest coast renders archived mountains")
 check(game.world.find_child("BlueCGYellowDiamond",true,false)!=null,"Zombie Cave keeps its yellow diamond")
 if DisplayServer.get_name()!="headless":
  var scale_:float=game.model.falan_scale
  await shot("Alyut West Roads/north-gate",Vector3(-150,30,-224)*scale_,Vector3(-142,5,-174)*scale_,60)
  await shot("Alyut West Roads/coastal-trail",Vector3(-225,101,-284)*scale_,Vector3(-220,6,-219)*scale_,62)
  await shot("Alyut West Roads/zombie-diamond",Vector3(-280,29,-187)*scale_,Vector3(-266,7,-210)*scale_,66)
  var mouth:Vector3=game.model.world_point(west.at)
  await shot("Alyut West Roads/west-cave-mouth",mouth+Vector3(-8,2.7,0)*scale_,mouth+Vector3.UP*1.8*scale_,65)
 await position_at(west.at-west.direction*4)
 await position_at(west.at)
 check(game.model.falan_floor==Captain.ROOM,"Walking through the West Cave mouth opens the Wolf Captain's floor")
 if game.model.falan_floor!=Captain.ROOM:return
 var exit=game.model.get_meta("falan_links").filter(func(link):return link.get("exit_id")==16501)[0]
 await position_at(Vector2(21,51))
 await process_frame
 await position_at(exit.at)
 check(Tour.area(game.model)=="north_coast","Alyut West Cave returns to the road on foot")
 if Tour.area(game.model)!="north_coast":return
 await position_at(zombie.at-zombie.direction*4)
 await position_at(zombie.at)
 check(game.model.falan_floor==Zombie.FINAL,"Walking into the yellow diamond enters the Modified Zombie's floor")

func check_alyut_west_night():
 await open_area("north_coast")
 var mouths=Tour.Regions.site_links("north_coast").filter(func(link):return link.site==16501)
 check(mouths.size()==1,"Day and low tide share the original cave entrance")
 if mouths.is_empty():return
 var mouth:Vector2=mouths[0].at
 var coast=Tour.Regions.frame("north_coast")
 var shore:Vector2=coast.inverse()*(Vector2(550,19)*3)
 check(road_connected(mouth,shore),"The original shore exit rejoins the dry road")
 await position_at(mouth)
 await walk_through_entry(true)
 check(game.model.falan_floor==Captain.ROOM and map_position().distance_to(Vector2(-12,51))<.5,
  "Low tide enters the same hall through a side passage")
 if game.model.falan_floor!=Captain.ROOM:return
 check_venoa_roof()
 check_single_floor([Captain.MEMORIAL])
 await cave_exit("north_coast")
 check(map_position().distance_to(mouth)<.5,"The low-tide exit returns to the shared mouth")
 await site(16501,"interior")
 check(game.model.falan_floor==Captain.ROOM,"The main entrance opens onto the Wolf Captain’s floor")
 await check_wolf_captain()
 if game.model.falan_floor!=Captain.MEMORIAL:return
 check_venoa_roof()
 var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(npcs) and npcs.get_children().any(func(sprite):return sprite.get_meta("npc_name","")=="野狼船长"),
  "The captain's original silent NPC remains in the memorial")
 await cave_exit("north_coast")
 check(map_position().distance_to(shore)<.5,"The memorial exit lands at the original shore")
 check(game.model.terrain.disk_clear(game.player.position/game.model.falan_scale,.55),"The shore landing has room for the player")

func check_wolf_captain():
 check_archived_arena()
 var runtime=game.army_runtime
 var gate:Vector2=Tour.Regions.Sites.CAPTAIN_FORMATION[0][0]
 check(game.model.enemies.is_empty(),"The captain encounter waits until the player approaches")
 var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(npcs) and npcs.get_children().any(func(sprite):return sprite.get_meta("npc_name","")=="札纳克"),
  "Zanark remains a silent original sprite by the entrance")
 game.tuning.invincible=true
 await position_at(gate+Vector2(0,15))
 var units:Array=game.model.enemies.values()
 var bosses=units.filter(func(row):return row.get("captain_slot",-1)==0)
 check(bosses.size()==1 and units.size()==5,"The Wolf Captain and four original escorts arrive together")
 if bosses.is_empty():return
 var boss:Dictionary=bosses[0]
 check(units.all(func(row):return runtime.handles.has(row.id)),"The encounter uses the native army lifecycle")
 check(units.filter(func(row):return row.skin==1).size()==2 and units.filter(func(row):return row.skin==2).size()==2,
  "The crew includes two Sea Bats and two Pirates")
 check(Captain.motions().variants.map(func(row):return int(row.id))==[101114,101252,101822],
  "The shared sprite batch uses the three original Blue CG actors")
 check(boss.hp>800 and runtime.enemy_target(boss.id).local_combat_box().is_equal_approx(Dimensions.body(Captain,0)),"The captain uses the boss health and fitted hitbox")
 if DisplayServer.get_name()!="headless":
  game.player.hide()
  await shot("wolf-captain-crew",Vector3(-9,3.35,15),Vector3(-9,1.65,-9),65)
  await shot("wolf-captain",Vector3(-8.5,3.1,-1.5),Vector3(-9,1.65,-12),58)
  game.player.show()
 await position_at(gate)
 await walk_through_entry()
 check(game.model.falan_floor==Captain.ROOM,"The memorial stays locked during the fight")
 var at:Vector3=runtime.unit_state(runtime.handles[boss.id]).position
 await position_at(Tour.Indoor.safe_point(Captain.ROOM,Vector2(at.x,at.z+3)/game.model.falan_scale))
 game.player.invuln=0
 game.tuning.invincible=false
 runtime.record_events=true
 runtime.event_log.clear()
 var hp:float=game.player.hp
 for i in 110:
  await physics_frame
  if runtime.event_log.any(func(e):return e.kind=="external_damage" and e.source_id==boss.id):break
 check(game.player.hp<hp and runtime.event_log.any(func(e):return e.kind=="external_damage" and e.source_id==boss.id),
  "The captain's original swing delivers native melee damage")
 runtime.record_events=false
 game.tuning.invincible=true
 runtime.damage_enemy(boss.id,boss.max_hp*2)
 for i in 8:await physics_frame
 await position_at(gate)
 await walk_through_entry()
 check(game.model.falan_floor==Captain.ROOM,"Defeating the captain alone does not open the memorial")
 await cave_exit("north_coast")
 await site(16501,"interior")
 await position_at(gate+Vector2(0,15))
 units=game.model.enemies.values()
 check(units.size()==4 and units.all(func(row):return row.captain_slot>0),"Retreat keeps the captain defeated and only respawns surviving crew")
 for row in units:runtime.damage_enemy(row.id,row.max_hp*2)
 for i in 8:await physics_frame
 check(game.model.enemies.is_empty() and get_meta(Captain.SLAIN,{}).size()==5,"Victory retires all five combatants for this run")
 await room(Captain.MEMORIAL)
 await room(Captain.ROOM)
 check(game.model.enemies.is_empty(),"Returning from the memorial keeps the hall cleared")
 await room(Captain.MEMORIAL)

func check_zombie_cave():
 await open_area("north_coast")
 var outdoor_foliage:Node3D=game.world.freyja_foliage
 check(is_instance_valid(outdoor_foliage) and outdoor_foliage.is_visible_in_tree(),"The north coast builds its outdoor foliage")
 var sites=Tour.Regions.site_links("north_coast")
 var mouth=sites.filter(func(link):return link.site==410)
 check(mouth.size()==1,"The Alyut road has one Zombie Cave entrance")
 if mouth.is_empty():return
 var alyut=sites.filter(func(link):return link.site==2400)
 check(alyut.any(func(link):return road_connected(link.at,mouth[0].at)),"Alyut and the yellow diamond share a dry road")
 var west=sites.filter(func(link):return link.site==16501)
 check(west.size()==1 and road_connected(mouth[0].at,west[0].at),"A dry branch joins the two caves west of Alyut")
 await site(16501,"interior")
 check(game.model.falan_floor==Captain.ROOM,"The West Cave branch enters the shared hall")
 if game.model.falan_floor!=Captain.ROOM:return
 check(is_instance_valid(outdoor_foliage) and not outdoor_foliage.is_visible_in_tree(),"Parked outdoor foliage is hidden inside the cave")
 check_venoa_roof()
 var zanark=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(zanark) and zanark.get_children().any(func(sprite):return sprite.get_meta("npc_name","")=="札纳克"),
  "Zanark is a silent original sprite in Alyut West Cave")
 if DisplayServer.get_name()!="headless":
  await shot("alyut-west-cave",Vector3(-20,3.1,-17),Vector3(-21,1.4,-27),60)
 await cave_exit("north_coast")
 check(is_instance_valid(outdoor_foliage) and game.world.freyja_foliage==outdoor_foliage and outdoor_foliage.is_visible_in_tree(),"Returning outdoors reuses the original foliage batches")
 if west.size()==1:
  check(map_position().distance_to(west[0].at)<.5,"West Cave returns to its own trail")
 var portal=game.world.find_child("BlueCGYellowDiamond",true,false)
 check(portal is AnimatedSprite3D and portal.is_playing() and portal.sprite_frames.get_frame_count(&"default")==8,
  "The portal plays the eight original yellow diamond frames")
 if DisplayServer.get_name()!="headless" and portal is AnimatedSprite3D:
  var point:Vector3=portal.global_position
  await shot("zombie-cave-portal",point+Vector3(8,5,8),point+Vector3.DOWN*.5,60)
 await site(410,"interior")
 check(game.model.falan_floor==Zombie.FINAL,"The yellow diamond enters the single lab floor")
 if game.model.falan_floor!=Zombie.FINAL:return
 check_archived_arena()
 check_venoa_roof()
 check_single_floor()
 check_zombie_maze_paths()
 var maze_info=Tour.Indoor.floor_info(Zombie.FINAL)
 var maze_bits=Tour.Indoor.walk_mask(Zombie.FINAL,maze_info[0],maze_info[2].hex_decode(),game.model.seed_value)
 check(game.world.find_child("BlueCGYellowDiamond",true,false)!=null,"The lab has the matching return diamond")
 var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(npcs) and npcs.get_child_count()==1,"The original nurse remains a silent sprite on the lab floor")
 var runtime=game.army_runtime
 game.tuning.invincible=true
 var initial={}
 for row in game.model.enemies.values():initial[row.id]=row.pos
 var hounds=game.model.enemies.values().filter(func(row):return row.get("skin")==Zombie.HELLHOUND)
 check(initial.size()==13 and hounds.size()==3,"The single floor keeps the lab party and all nine patrols")
 check(initial.keys().all(func(id):return runtime.handles.has(id)),"Both patrol types use the native army lifecycle")
 check(Zombie.motions().variants[Zombie.HELLHOUND].id==101030,"The hounds use the original cave Hellhound artwork")
 for i in 100:await physics_frame
 check(hounds.any(func(row):return runtime.unit_state(runtime.handles.get(row.id,0)).get("position",initial[row.id]).distance_to(initial[row.id])>1),
  "Hellhounds roam before the player enters their detection range")
 var zombies=game.model.enemies.values().filter(func(row):return row.skin!=Zombie.HELLHOUND)
 check(zombies.any(func(row):return runtime.unit_state(runtime.handles.get(row.id,0)).get("position",initial[row.id]).distance_to(initial[row.id])>1),
  "Zombies still roam alongside the Hellhounds")
 if DisplayServer.get_name()!="headless" and not hounds.is_empty():
  var at:Vector3=runtime.unit_state(runtime.handles[hounds[0].id]).position
  await shot("zombie-cave-hellhounds",at+Vector3(-2,3.65,8),at+Vector3.UP*1.1,62)
 await cave_exit("north_coast",410)
 check(map_position().distance_to(mouth[0].at)<.5,"The return diamond leads to the Alyut trail")
 await site(410,"interior")
 check(maze_bits==Tour.Indoor.walk_mask(Zombie.FINAL,maze_info[0],maze_info[2].hex_decode(),game.model.seed_value),"Re-entering the cave preserves the maze within this run")
 var links:Array=game.model.get_meta("falan_links")
 var bosses=game.model.enemies.values().filter(func(row):return row.get("zombie_slot",-1)==0)
 check(bosses.size()==1 and game.model.enemies.size()==13,"The Modified Zombie shares the floor with all patrols")
 if bosses.size()!=1:return
 var boss:Dictionary=bosses[0]
 check(boss.max_hp>800 and runtime.handles.has(boss.id),"The boss uses the native combat and health lifecycle")
 for row in game.model.enemies.values():
  if row.id!=boss.id:runtime.damage_enemy(row.id,row.max_hp*2)
 var exit=links.filter(func(link):return link.get("exit_id")==Zombie.FINAL)[0]
 game.tuning.invincible=true
 await position_at(exit.at)
 await walk_through_entry()
 check(game.model.falan_floor==15505,"The lab exit stays locked while the boss lives")
 var boss_at:Vector3=runtime.unit_state(runtime.handles[boss.id]).position
 if DisplayServer.get_name()!="headless":
  await shot("zombie-cave-modified-zombie",boss_at+Vector3(1,3.2,10),boss_at+Vector3.UP*1.5,63)
 await position_at(Vector2(boss_at.x,boss_at.z+2.6)/game.model.falan_scale)
 game.tuning.invincible=false
 runtime.record_events=true
 runtime.event_log.clear()
 var old_hp:float=game.player.hp
 for i in 200:
  await physics_frame
  if runtime.event_log.any(func(e):return e.kind=="external_damage" and e.source_id==boss.id):break
 check(runtime.event_log.any(func(e):return e.kind=="external_damage" and e.source_id==boss.id) and game.player.hp<old_hp,
  "The boss's original attack contact damages the player")
 await check_zombie_attacks(boss)
 if runtime.handles.has(boss.id):return
 if is_instance_valid(game.team_upgrade_picker):
  var progression=game.model.team_progression
  check(game.choose_team_upgrade(progression.offer[0],progression.choice_level()),"Choosing the victory upgrade resumes the run")
 await cave_exit("north_coast",Zombie.FINAL)
 var point=Tour.Regions.frame("north_coast")*map_position()
 check(point.distance_to(Vector2(544,35)*3.0)<.5,"The lab stairs return to the archived roadside exit")
 await site(410,"interior")
 check(game.model.enemies.values().all(func(row):return row.get("zombie_slot",-1)!=0),"Reentering the lab in this run keeps the boss defeated")

func check_zombie_maze_paths():
 var indoor=Tour.Indoor
 var maze=indoor.ZombieMaze
 var info=indoor.floor_info(Zombie.FINAL)
 var size:Vector2i=info[0]
 var bits=indoor.walk_mask(Zombie.FINAL,size,info[2].hex_decode(),game.model.seed_value)
 var queue:Array[Vector2i]=[Vector2i(40,6)]
 var previous={queue[0]:queue[0]}
 var i=0
 while i<queue.size():
  var cell=queue[i]
  i+=1
  for direction:Vector2i in maze.Imur.DIRECTIONS:
   var next=cell+direction
   if not previous.has(next) and indoor.open_cell(bits,size,next.x,next.y):
    previous[next]=cell
    queue.append(next)
 var goal=Vector2i(21,18)
 check(previous.has(goal),"The live maze has a route from the diamond to the boss")
 var blocked=0
 while previous.has(goal) and goal!=Vector2i(40,6):
  var before:Vector2i=previous[goal]
  var pose:Transform3D=game.player.global_transform
  pose.origin=game.model.world_point(info[1]+Vector2(before)*3.0,.16)
  var motion:Vector3=game.model.world_point(info[1]+Vector2(goal)*3.0,.16)-pose.origin
  if game.player.test_move(pose,motion):blocked+=1
  goal=before
 check(blocked==0,"Kaz fits through the generated route without colliding with old walls: "+str(blocked))
 var minimap=game.forest_ui.enemy_minimap
 minimap.refresh()
 var image=minimap.chart.texture.get_image()
 check(image.get_size()==size and image.get_pixel(40,6).a>0,"The map displays the current generated floor")
 check(minimap.chart.pins.any(func(pin):return pin.label=="Modified Zombie"),"The random cave map marks the fixed boss chamber")
 for enemy in game.model.enemies.values():
  var point:Vector3=enemy.pos/game.model.falan_scale
  var cell=Vector2i((Vector2(point.x,point.z)-info[1])/3.0)
  check(previous.has(cell),"Every live zombie and hellhound spawns on a connected route")

func check_zombie_attacks(boss:Dictionary):
 var runtime=game.army_runtime
 var handle:int=runtime.handles[boss.id]
 game.tuning.invincible=true
 runtime.damage_enemy(boss.id,140)
 var wounded:float=runtime.unit_state(handle).hp
 var at:Vector3=runtime.unit_state(handle).position
 await position_at(Vector2(at.x,at.z+2.4)/game.model.falan_scale)
 runtime.event_log.clear()
 var blocked:Dictionary=await zombie_event("external_damage",Zombie.DRAIN,boss.id)
 check(not blocked.is_empty() and is_equal_approx(runtime.unit_state(handle).hp,wounded),"Invulnerability blocks life drain healing")
 runtime.event_log.clear()
 var windup:Dictionary=await zombie_event("status",Zombie.DRAIN,boss.id)
 check(not windup.is_empty(),"The wounded boss tries life drain again")
 if windup.is_empty():return
 var old_hp:float=game.player.hp
 game.player.invuln=0
 game.tuning.invincible=false
 var healed:Dictionary=await zombie_event("status",Zombie.HEAL,boss.id)
 var lost:float=old_hp-game.player.hp
 check(lost>0 and is_equal_approx(runtime.unit_state(handle).hp-wounded,lost*.8),
  "Life drain heals 80 percent of the damage actually taken")
 check(not healed.is_empty() and is_equal_approx(game.model.enemies[boss.id].hp,runtime.unit_state(handle).hp),
  "Life drain updates the native and visible boss health")

 game.tuning.invincible=true
 at=runtime.unit_state(handle).position
 await position_at(Vector2(at.x,at.z+2.4)/game.model.falan_scale)
 runtime.damage_enemy(boss.id,runtime.unit_state(handle).hp-boss.max_hp*.4)
 runtime.event_log.clear()
 var warning:Dictionary=await zombie_event("status",Zombie.CHARGE,boss.id)
 check(not warning.is_empty(),"The boss warns before detonating below half health")
 if warning.is_empty():return
 var center:Vector3=warning.position
 if DisplayServer.get_name()!="headless":
  await shot("zombie-cave-self-destruct",center+Vector3(2,4.25,11),center+Vector3.UP*.6,65)
 var stay:bool="--zombie-blast-hit" in OS.get_cmdline_user_args()
 if not stay:await position_at(Vector2(center.x,center.z+warning.amount+3.0)/game.model.falan_scale)
 game.player.hp=game.player.max_hp
 old_hp=game.player.hp
 game.player.invuln=0
 game.tuning.invincible=false
 var detonation:Dictionary=await zombie_event("status",Zombie.BLAST,boss.id)
 check(not detonation.is_empty(),"The fuse ends in a native detonation")
 for i in 6:await physics_frame
 check((game.player.hp<old_hp) if stay else is_equal_approx(game.player.hp,old_hp),
  "The blast hits inside its radius and can be escaped")
 check(runtime.event_log.filter(func(e):return e.kind=="status" and e.get("action_index")==Zombie.BLAST).size()==1,
  "Self-destruct triggers only once")
 check(get_meta("zombie_slain",{}).has(0) and not runtime.handles.has(boss.id),"Self-destruct retires the boss and unlocks the lab exit")

func zombie_event(kind:String,action:int,boss_id:int,max_frames:int=300)->Dictionary:
 for i in max_frames:
  for event in game.army_runtime.event_log:
   if event.kind==kind and event.get("action_index")==action and event.get("source_id")==boss_id:return event
  await physics_frame
 return {}

func check_castle_exterior():
 var venture:Dictionary=get_meta("falan_venture")
 var castle_links:Array=Tour.LINKS.city.filter(func(link):return link.to=="castle")
 check(castle_links.size()==4,"The city keeps all four castle entrances")
 for link in castle_links:
  await position_at(link.at)
  await walk_through_entry()
  check(Tour.area(game.model)=="castle","Each bridge entrance reaches the castle")
  if Tour.area(game.model)!="castle":return
  var keep=game.world.find_child("ArchivedRoyalKeep",true,false)
  check(is_instance_valid(keep) and keep.get_child_count()>30,"The saved castle uses the rebuilt keep")
  check(game.model.terrain.submerged(Vector3(260,1,150)),"The original island has water beyond its outer masonry")
  if link==castle_links[0]:
   var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
   check(is_instance_valid(npcs) and npcs.get_child_count()==19,"All original courtyard NPCs are present")
   if DisplayServer.get_name()!="headless":
    await shot("Castle Exterior/castle-overview",Vector3(218,237,190)*game.model.falan_scale,Vector3(20,7,1)*game.model.falan_scale,46)
    await shot("Castle Exterior/palace-facade",Vector3(34,28,13)*game.model.falan_scale,Vector3(-32,23,-1)*game.model.falan_scale,56)
   var entry_z:float=game.model.Courtyard.Keep.ENTRY_Z
   var ramp=PhysicsRayQueryParameters3D.create(game.model.world_point(Vector2(-23,entry_z),5.0),game.model.world_point(Vector2(-23,entry_z)),1)
   var hit:Dictionary=game.world.get_world_3d().direct_space_state.intersect_ray(ramp)
   check(not hit.is_empty() and hit.position.y>game.model.world_height(-23,entry_z)+1.5,"The carpeted entrance stair has a walkable ramp")
   await room(1520)
   var exit=game.model.get_meta("falan_links").filter(func(row):return row.get("exit",false))
   check(exit.size()==1,"The palace interior keeps its courtyard return")
   if exit.size()!=1:return
   await position_at(exit[0].at)
   await walk_through_entry()
   check(Tour.area(game.model)=="castle","The palace door returns to the courtyard")
  var passages:Array=Tour.LINKS.castle.duplicate()
  passages.sort_custom(func(a,b):return link.arrival.distance_squared_to(a.at)<link.arrival.distance_squared_to(b.at))
  await position_at(passages[0].at)
  await walk_through_entry()
  check(Tour.area(game.model)=="city","The matching castle bridge returns to Falan")
  if Tour.area(game.model)!="city":return

func check_venoa_undersea():
 await open_area("south_lakes")
 var sites=Tour.Regions.site_links("south_lakes")
 var village=sites.filter(func(link):return link.site==2100)[0]
 var bear=sites.filter(func(link):return link.site==11002)[0]
 var undersea=sites.filter(func(link):return link.site==15592)[0]
 var far_shore=sites.filter(func(link):return link.site==15594)[0]
 var fire=sites.filter(func(link):return link.site==15595)[0]
 await position_at(village.at+Vector2(4,-1.5))
 await position_at(village.at-Vector2(0,1.5))
 check(Tour.area(game.model)=="venoa","The village gate opens on foot")
 if Tour.area(game.model)!="venoa":return
 var gate=game.model.get_meta("falan_links").filter(func(link):return link.to=="freyja_return")[0]
 await position_at(gate.at)
 check(Tour.area(game.model)=="south_lakes","Venoa opens onto the road on foot")
 if Tour.area(game.model)!="south_lakes":return
 var landing:Vector2=Tour.Regions.frame("south_lakes").inverse()*Vector2(993,1443)
 check(map_position().distance_to(landing)<.5,"Venoa opens onto the original outdoor tile")
 check(road_connected(landing,bear.at,.55),"The original mountain road leads from Venoa to the Bear Cave")
 check(road_connected(landing,undersea.at,.55),"A dry trail leads from Venoa to the village-side Undersea Cave")
 check(road_connected(far_shore.at,fire.at,.55),"The opposite shore connects the Undersea Cave to Fire Cave")
 check(not road_connected(landing,far_shore.at),"No overland road joins the two shores")
 if DisplayServer.get_name()!="headless":
  var scale_:float=game.model.falan_scale
  await shot("Venoa Cave Roads/southern-shores",Vector3(-279,196,261)*scale_,Vector3(-264,7,127)*scale_,65)
  var coast_mouth:Vector3=game.model.world_point(undersea.at)
  await shot("Venoa Cave Roads/undersea-approach",coast_mouth+Vector3(5,5,10)*scale_,coast_mouth+Vector3.UP*1.8*scale_,63)
  var bear_mouth:Vector3=game.model.world_point(bear.at)
  await shot("Venoa Cave Roads/bear-cave-approach",bear_mouth+Vector3(0,3,8)*scale_,bear_mouth+Vector3.UP*1.8*scale_,65)
 await position_at(bear.at-bear.direction*4)
 await position_at(bear.at)
 check(game.model.falan_floor==11002,"The village-side Venoa Cave opens on its archived floor")
 if game.model.falan_floor!=11002:return
 var exit=game.model.get_meta("falan_links").filter(func(link):return link.get("exit_id")==11002)[0]
 await position_at(exit.at+Vector2(0,-4))
 await position_at(exit.at)
 check(Tour.area(game.model)=="south_lakes","Venoa Cave returns to the village road on foot")
 if Tour.area(game.model)!="south_lakes":return
 var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(npcs) and npcs.get_children().any(func(sprite):return sprite.get_meta("npc_name","")=="士兵塔拉帕"),"The original entrance guard is present as a sprite")
 await position_at(undersea.at-undersea.direction*4)
 await position_at(undersea.at)
 check(game.model.falan_floor==15593,"The village-side mouth opens the undersea floor on foot")
 if game.model.falan_floor!=15593:return
 check_venoa_roof()
 check_single_floor()
 # The archived lane is two tiles west of the widened reconstruction.
 check_kaz_clearance(Vector2(-18,-15),Vector2(-18,-9),"Kaz can walk the original undersea corridor")
 exit=game.model.get_meta("falan_links").filter(func(link):return link.get("exit_id")==15594)[0]
 await position_at(exit.at+Vector2(4,0))
 await position_at(exit.at)
 check(Tour.area(game.model)=="south_lakes" and map_position().distance_to(far_shore.at)<.5,"The far exit opens on foot onto its own shore")
 if Tour.area(game.model)!="south_lakes":return
 await position_at(far_shore.at-far_shore.direction*4)
 await position_at(far_shore.at)
 check(game.model.falan_floor==15593,"The Fire Cave-side mouth returns to the same floor on foot")
 if game.model.falan_floor!=15593:return
 exit=game.model.get_meta("falan_links").filter(func(link):return link.get("exit_id")==15592)[0]
 await position_at(exit.at+Vector2(-4,0))
 await position_at(exit.at)
 check(Tour.area(game.model)=="south_lakes" and map_position().distance_to(undersea.at)<.5,"The village exit opens on foot onto the original coastal trail")

func check_undersea_portals():
 game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 for row in [["south_lakes",15005,Vector2i(343,497),15003],
             ["sokia_coast",15004,Vector2i(240,265),15003],
             ["south_lakes",15592,Vector2i(299,538),15593],
             ["south_lakes",15594,Vector2i(251,493),15593]]:
  print("UNDERSEA_PORTAL_START ",row[1])
  await open_area(row[0])
  check_undersea_surroundings(row[0])
  var links=game.model.get_meta("falan_links").filter(func(link):return link.get("site")==row[1])
  check(links.size()==1 and links[0].walk_in,"The original undersea mouth is a walk-in link: "+str(row[1]))
  if links.size()!=1:continue
  var mouth=game.world.find_child("UnderseaMouth_%d_%d"%[row[2].x,row[2].y],true,false)
  check(mouth!=null and mouth.get_meta("archive_cell")==row[2] and mouth.has_node("ArchivedUnderseaRecess"),"The original mouth has its own recovered silhouette at "+str(row[2]))
  if mouth!=null:check(mouth.get_meta("source_profile")==Entrances.UNDERSEA_MOUTHS.MOUTHS[row[2]],"The mouth uses the source trace rather than the generic arch")
  var cliff=game.world.find_child("ArchivedCliffForms",true,false)
  check(cliff.material_override.get_shader_parameter("entrance_cut_count")>0,"The old cliff surface is cut away from the original opening")
  var back:Vector2=Tour.Regions.frame(row[0]).inverse().basis_xform(Entrances.Archive.MOUTHS[row[0]][row[2]]).normalized()
  var at:Vector2=links[0].at
  if DisplayServer.get_name()!="headless":
   var point:Vector3=game.model.world_point(at)
   await shot("undersea-mouth-"+str(row[1]),point-Vector3(back.x,0,back.y)*13+Vector3.UP*5,point+Vector3.UP*2.7,64)
   await shot("Undersea Surroundings/coast-"+str(row[1]),point-Vector3(back.x,0,back.y)*34+Vector3(12,29,9),point+Vector3.UP*2,65)
   if row[0]=="sokia_coast":
    var route_point:Vector3=game.model.world_point(Tour.Regions.frame(row[0]).inverse()*(Vector2(253,278)*3.0))
    await shot("Undersea Surroundings/kili-coast-road",route_point+Vector3(37,35,38),route_point+Vector3.UP*2,65)
  await walk_habaru_threshold(at,back)
  print("UNDERSEA_PORTAL_INSIDE ",row[1]," floor=",game.model.falan_floor)
  check(game.model.falan_floor==row[3],"Walking through the original mouth reaches its existing single floor without F")
  if game.model.falan_floor!=row[3]:continue
  for i in 10:await physics_frame
  check(game.model.falan_floor==row[3],"Arrival does not immediately bounce back outside")
  var exits=game.model.get_meta("falan_links").filter(func(link):return link.get("exit_id")==row[1])
  check(exits.size()==1 and exits[0].walk_in and exits[0].undersea_stair==13268,"The same source stair owns the return link")
  if exits.size()!=1:continue
  var cell=Vector2i(((exits[0].at-Tour.Indoor.floor_info(row[3])[1])/3.0).round())
  var stair=game.world.map_features.get_node_or_null("UnderseaStair_%d_%d"%[cell.x,cell.y])
  check(stair!=null and stair.get_meta("blue_cg_serial")==13268 and stair.has_node("HabaruWalkableTreads"),"Blue source stairs and walkable treads share the original warp tile")
  if stair!=null:
   check(stair.get_children().filter(func(node):return node is MeshInstance3D).all(func(node):return node.material_override is ShaderMaterial and node.material_override.get_shader_parameter("original_palette")),"Undersea stair stone keeps the recovered blue palette")
  if DisplayServer.get_name()!="headless":
   var point:Vector3=game.model.world_point(exits[0].at)
   await shot("undersea-stair-"+str(row[1]),point+Vector3(4,4,6),point+Vector3.UP*.7,64)
  await walk_habaru_threshold(exits[0].at,Vector2.UP)
  print("UNDERSEA_PORTAL_OUTSIDE ",row[1]," area=",Tour.area(game.model))
  check(Tour.area(game.model)==row[0],"The blue stair returns to the matching outdoor road without F")
  if Tour.area(game.model)!=row[0]:continue
  for i in 10:await physics_frame
  check(Tour.area(game.model)==row[0],"Returning outside does not retrigger the mouth")

func check_undersea_surroundings(area:String):
 var data=Entrances.UNDERSEA_MOUTHS.SCENERY[area]
 var cells={}
 for row in data:
  check(not cells.has(row[0]) and Entrances.undersea_surroundings(area,row[0]),"Surrounding source placements are unique and inside their archived bounds")
  cells[row[0]]=row[1]
 var root_=game.world.find_child("FreyjaDestinationEntrances",true,false)
 check(root_!=null and root_.get_meta("undersea_surrounding_placements")==data.size(),"The full source surroundings are built")
 var bank=game.world.find_child("ArchivedUnderseaCoastBanks",true,false)
 check(bank!=null and bank.get_meta("archived_placements")>40,"The original grassy banks replace the scattered shore mounds")
 if bank!=null:
  check(bank.material_override.get_shader_parameter("base_texture")==preload("res://assets/maps/falan/undersea_coast_banks.png"),"Shore caps use their original grass-edge art")
 if area=="sokia_coast":
  var water=game.world.find_child("FreyjaWater",true,false)
  check(water.material_override.get_shader_parameter("freyja_ground_index")==preload("res://assets/maps/falan/sokia_ground_index.png"),"Sokia uses its own original water and shore tiles")
  var frame=Tour.Regions.frame(area).inverse()
  check(road_connected(frame*(Vector2(240,265)*3),frame*(Vector2(274,294)*3)),"The original coastal route still reaches Kili's west gate")
  check(data.filter(func(row):return row[1] in range(11188,11209)).size()>10,"The Sokia palm clusters retain their source placements")

func check_undersea_encounters():
 game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 game.model.team_progression.cards_enabled=false
 var venture:Dictionary=get_meta("falan_venture")
 await chart_capture("falan-city",["South Gate"])
 Tour.travel(game,venture.falan_areas.south_gate,{"arrival":Vector2(3,162),"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 5:await physics_frame
 await chart_capture("south-gate",["Venoa Cave, Falan Side","Road to Venoa Village"])
 await open_area("south_lakes")
 await chart_capture("south-lakes",["Venoa Cave, Village Side","Sokia Undersea Cave","Venoa Undersea Cave, Village Side"])
 await site(11002,"interior")
 check_pool_tiles()
 await chart_capture("venoa-bear-cave",["Village Side","Venoa Cave, Lower Floor","Venoa Cave, Miners' Shortcut"])
 await cave_exit("south_lakes")
 await site(15592,"interior")
 check(game.model.falan_floor==15593,"The Venoa Undersea mouth reaches its single floor")
 if game.model.falan_floor!=15593:return
 check_venoa_roof()
 check_single_floor()
 check_pool_tiles()
 await check_undersea_source_colors()
 check_undersea_patrols(15593)
 await chart_capture("venoa-undersea",["Village Side","Fire Cave Side"])
 await cave_exit("south_lakes",15592)
 await site(15005,"interior")
 check(game.model.falan_floor==Undersea.SOKIA,"Sokia Undersea loads from its Freyja entrance")
 if game.model.falan_floor!=Undersea.SOKIA:return
 check_undersea_patrols(Undersea.SOKIA)
 check_pool_tiles()
 await check_undersea_source_colors()
 await chart_capture("sokia-undersea",["熊哥","Sokia Coast","Black Prayer"])
 check(game.world.find_child("BlueCGYellowDiamond",true,false)!=null,"The Black Prayer diamond remains")
 await position_at(Undersea.BOSS_AT+Vector2(0,6))
 var runtime=game.army_runtime
 var group:Array=game.model.enemies.values().filter(func(row):return row.get("undersea_slot",100)<10)
 var bosses=group.filter(func(row):return row.skin==0)
 check(bosses.size()==1 and group.filter(func(row):return row.skin==1).size()==2 and group.filter(func(row):return row.skin==2).size()==2,
  "熊哥 spawns with his two original pairs of escorts")
 if bosses.is_empty():return
 var boss:Dictionary=bosses[0]
 check(boss.max_hp==Undersea.BOSS_HP,"熊哥 uses his level-40 real-time HP")
 game.model.team_progression.cards_enabled=false
 check(game.dungeon_boss_nearby() and runtime.enemy_target(boss.id).local_combat_box().is_equal_approx(Dimensions.body(Undersea,0)),
  "熊哥 uses the native boss camera and his fitted body")
 if DisplayServer.get_name()!="headless":
  var at:Vector3=runtime.unit_state(runtime.handles[boss.id]).position
  await shot("Cave Pools/sokia-boss",at+Vector3(4,4.7,9),at+Vector3.UP*1.7,68)
 for row in game.model.enemies.values():
  if row.id!=boss.id:runtime.damage_enemy(row.id,row.max_hp*2)
 await check_undersea_qigong(boss)
 await check_undersea_support(boss)
 runtime.record_events=true
 runtime.event_log.clear()
 game.tuning.invincible=false
 game.player.invuln=0
 var punch_at:Vector3=runtime.unit_state(runtime.handles[boss.id]).position
 await position_at(Vector2(punch_at.x,punch_at.z+2.3)/game.model.falan_scale)
 for i in 240:
  if runtime.event_log.any(func(e):return e.kind=="external_damage" and e.source_id==boss.id and e.amount>0 and not e.projectile):break
  await physics_frame
 check(runtime.event_log.any(func(e):return e.kind=="external_damage" and e.source_id==boss.id and e.amount>0 and not e.projectile),
  "熊哥 uses his original unarmed punch for normal native melee hits")
 game.tuning.invincible=true
 runtime.apply_hit(runtime.handles[boss.id],{"amount":boss.max_hp*2,"magical":true})
 for i in 10:
  if is_instance_valid(game.team_upgrade_picker):
   game.choose_team_upgrade(game.model.team_progression.offer[0],game.team_upgrade_picker.offered_level)
  await physics_frame
 check(get_meta(Undersea.SLAIN,{}).has(0) and not game.dungeon_boss_nearby(),"Victory retires the boss for this run")
 await cave_exit("south_lakes",15005)
 await site(15005,"interior")
 await position_at(Undersea.BOSS_AT+Vector2(0,6))
 check(game.model.enemies.is_empty(),"Defeated Sokia enemies stay defeated after re-entry")

func check_undersea_qigong(boss:Dictionary):
 var runtime=game.army_runtime
 var handle:int=runtime.handles[boss.id]
 var hp:float=game.player.hp
 game.player.hp=5000
 game.tuning.invincible=false
 runtime.record_events=true
 runtime.event_log.clear()
 var at:Vector3=runtime.unit_state(handle).position
 await position_at(Vector2(at.x,at.z+8.0)/game.model.falan_scale)
 var launched={}
 var hit=false
 var visible=false
 var captured=false
 var qi_mesh=game.crowd.army.presentation.projectile_batches["undersea-qi"].multimesh.mesh
 for i in 1000:
  await physics_frame
  for event in runtime.event_log:
   if event.source_id!=boss.id or event.action_index!=Undersea.QIGONG:continue
   if event.kind=="bullet":launched[event.projectile_id]=true
   if event.kind=="external_damage" and event.amount>0:hit=true
  runtime.event_log.clear()
  var snapshot=runtime.render_snapshot()
  if snapshot.projectile_effects.has(Undersea.QIGONG):
   var index:int=snapshot.projectile_effects.find(Undersea.QIGONG)
   check(snapshot.projectile_scales[index]*4.9536*51.0/63.0>=game.player.Proportions.GOEMON_HEIGHT,"Even the smallest 氣功彈 frame is at least Kaz-sized")
   game.crowd.present_army(snapshot,[])
   visible=visible or game.crowd.army.presentation.projectile_batches["undersea-qi"].multimesh.visible_instance_count>0
   if not captured and launched.size()>=4 and DisplayServer.get_name()!="headless":
    captured=true
    var boss_at:Vector3=runtime.unit_state(handle).position
    runtime.finish_integration()
    game.paused=true
    await shot("undersea-kumage-qigong",boss_at+Vector3(0,7,2.5),boss_at+Vector3(0,1.6,3),68)
    game.paused=false
  if launched.size()>=6 and hit and visible:break
 check(launched.size()>=6 and launched.size()%3==0,"熊哥 repeatedly releases three 氣功彈 through native combat")
 check(hit and game.player.hp<5000,"The physical 氣功彈 projectile can hit Kaz")
 check(visible and qi_mesh==game.crowd.army.presentation.projectile_batches["undersea-qi"].multimesh.mesh,"Repeated casts reuse the original orb artwork and pooled batch")
 game.player.hp=hp
 game.tuning.invincible=true

func check_undersea_support(boss:Dictionary):
 var runtime=game.army_runtime
 var handle:int=runtime.handles[boss.id]
 game.tuning.invincible=true
 var presentation=game.crowd.army.presentation
 var prepared_nodes:int=presentation.get_child_count()
 var ghost_mesh=presentation.batches["undersea-afterimage"].multimesh.mesh
 runtime.record_events=true
 runtime.event_log.clear()
 runtime.apply_hit(handle,{"amount":boss.max_hp*.55,"magical":true})
 var wounded:float=runtime.unit_state(handle).hp
 var at:Vector3=runtime.unit_state(handle).position
 await position_at(Vector2(at.x,at.z+4)/game.model.falan_scale)
 var cast=false
 var healed=false
 var cast_shown=false
 for i in 300:
  await physics_frame
  for event in runtime.event_log:
   if event.source_id!=boss.id:continue
   if event.kind=="status" and event.action_index==Undersea.MEDITATION:cast=true
   if event.kind=="status" and event.action_index==Zombie.HEAL:
    healed=event.amount>0 and event.hp<=boss.max_hp
  runtime.event_log.clear()
  if cast and not cast_shown and DisplayServer.get_name()!="headless":
   cast_shown=true
   await RenderingServer.frame_post_draw
   var batch=game.crowd.army.presentation.batches["undersea-meditation"]
   check(batch.multimesh.visible_instance_count>0,"The original 明鏡止水 art is visible during its cast")
   var center:Vector3=runtime.unit_state(handle).position
   game.paused=true
   check_undersea_cast("undersea-meditation",center,true)
   await shot("undersea-meditation",center+Vector3(0,7,5),center+Vector3.UP*2.3,68)
   game.paused=false
  if cast and healed:break
 check(cast and healed and is_equal_approx(runtime.unit_state(handle).hp,wounded*1.5),"明鏡止水 visibly casts and restores half of 熊哥's current HP, capped at maximum")
 var haze=false
 var opening=false
 for i in 1000:
  await physics_frame
  for event in runtime.event_log:
   if event.kind=="status" and event.source_id==boss.id and event.action_index==Undersea.HAZE:
    if event.amount>0:haze=true
    elif not opening:
     opening=true
     if DisplayServer.get_name()!="headless":
      await RenderingServer.frame_post_draw
      var center:Vector3=runtime.unit_state(handle).position
      check_undersea_cast("undersea-charge",center,false)
      game.paused=true
      await shot("undersea-haze-opening",center+Vector3(0,7,5),center+Vector3.UP*2.3,68)
      game.paused=false
  runtime.event_log.clear()
  if haze:break
 check(haze,"熊哥 activates his timed 陽炎 stance")
 check(opening,"陽炎 emits its body shine when the stance starts, before dodge becomes active")
 if haze and DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  var center:Vector3=runtime.unit_state(handle).position
  game.paused=true
  await shot("undersea-haze",center+Vector3(0,7,2.5),center+Vector3.UP*1.6,68)
  game.paused=false
 if haze:
  var hp:float=runtime.unit_state(handle).hp
  var dodges=0
  for i in 200:
   var hit:Dictionary=runtime.apply_hit(handle,{"amount":.1})
   if not hit.accepted:dodges+=1
  check(dodges>60 and dodges<140,"陽炎 dodges about half of physical hits, not every hit: "+str(dodges)+"/200")
  check(is_equal_approx(hp-runtime.unit_state(handle).hp,(200-dodges)*.1),"Only landed physical hits reduce 熊哥's health")
  if DisplayServer.get_name()!="headless":
   for i in 6:await process_frame
   await RenderingServer.frame_post_draw
   var ghosts=presentation.effects.filter(func(e):return e.kind=="undersea-afterimage").size()
   check(ghosts>0 and ghosts<=6,"Overlapping dodges share at most six short original-sprite afterimages")
   check(presentation.batches["undersea-afterimage"].multimesh.visible_instance_count>0,"The original body afterimages are rendered instead of a floor ring")
   check(presentation.voices.any(func(v):return v.stream==game.sound_library.KAZ_KAGEROU_DODGE),"Dodge reactions use the original Blue CG sound 210")
   var center:Vector3=runtime.unit_state(handle).position
   game.paused=true
   await shot("undersea-haze-dodge",center+Vector3(0,7,5),center+Vector3.UP*1.6,68)
   game.paused=false
  for i in 20:
   var hit:Dictionary=runtime.apply_hit(handle,{"amount":.1,"magical":true})
   check(hit.accepted,"陽炎 does not grant immunity to magic")
  var original_effects=presentation.effects.filter(func(e):return e.kind in ["undersea-afterimage","undersea-charge","undersea-meditation"])
  for i in 330:await physics_frame
  # The live boss may cast again; only the original effect instances must expire.
  check(original_effects.all(func(effect):return not presentation.effects.any(func(active):return is_same(active,effect))),"The original spell and dodge effects retire without leaving a permanent glow")
  check(presentation.get_child_count()==prepared_nodes and presentation.batches["undersea-afterimage"].multimesh.mesh==ghost_mesh,"Repeated native hits reuse the prepared meshes and presentation nodes")
  for i in 20:
   var hit:Dictionary=runtime.apply_hit(handle,{"amount":.1})
   check(hit.accepted,"Physical hits land normally once 陽炎 expires")
  runtime.event_log.clear()
 var batch=game.crowd.army.presentation.batches["undersea-meditation"]
 check(batch.multimesh.mesh!=null,"明鏡止水 uses the shared original seven-frame art batch")
 runtime.record_events=false

func check_undersea_cast(key:String,foot:Vector3,meditation:bool):
 var presentation=game.crowd.army.presentation
 var batch=presentation.batches[key]
 check(batch.multimesh.visible_instance_count==1,"The source body shine is rendered once: "+key)
 if batch.multimesh.visible_instance_count!=1:return
 var record:Dictionary=presentation.effects.filter(func(e):return e.kind==key)[0]
 var basis:Basis=game.get_viewport().get_camera_3d().global_basis.orthonormalized()
 var offset=Vector3(4,-2,1) if meditation else Vector3(22.5,-10.5,1)
 var expected=foot+Vector3.UP*Dimensions.body(Undersea,0).size.y*.55+basis*offset*.02*record.scale
 check(batch.multimesh.get_instance_transform(0).origin.distance_to(expected)<.03,"The shine originates at the body with original source offsets: "+key)
 var data:Color=batch.multimesh.get_instance_custom_data(0)
 check(is_equal_approx(data.r,float(floori(record.age/(2.0/60))%7 if meditation else mini(8,floori(record.age*20)))) ,"The source frame timing is preserved: "+key)
 check(is_equal_approx(data.g,128.0/255 if meditation else 1.0),"The source blend opacity is preserved: "+key)
 var cue=game.sound_library.original_for(game.sound_library.Roster.SHIN_ID,"cg_shin_meditation") if meditation else game.sound_library.CROSSGATE_FLASH
 check(presentation.voices.any(func(v):return v.stream==cue),"The source opening sound is queued: "+key)

func check_undersea_patrols(id:int):
 var rows:Array=game.model.enemies.values()
 check(rows.size()==Undersea.PATROLS[id].size() and rows.all(func(row):return row.has("patrol_radius") and game.army_runtime.handles.has(row.id)),
  "The original monster types patrol using the native army runtime")
 check(Undersea.motions().variants.map(func(row):return int(row.id))==[100802,101721,101700],"All three actors use the archived graphics")
 var info=Tour.Indoor.floor_info(id)
 var original:PackedByteArray=info[2].hex_decode()
 check(Tour.Indoor.walk_mask(id,info[0],original.duplicate(),game.model.seed_value)==original,"The undersea walk grid matches the original tile for tile")
 check(rows.size()>=(40 if id==Undersea.SOKIA else 48) and rows.filter(func(row):return row.skin==1).size()==rows.filter(func(row):return row.skin==2).size(),"Many 水龍蜥 and 蜥蜴戰士 are spread evenly through the source passages")
 for row in rows:
  var p:Vector3=row.pos/game.model.falan_scale
  var cell=Vector2i(((Vector2(p.x,p.z)-info[1])/3.0).round())
  check(Tour.Indoor.open_cell(original,info[0],cell.x,cell.y),"Undersea patrols start on original walkable tiles")
 var edges=game.world.find_child("ArchivedUnderseaEdges",true,false)
 check(edges!=null and edges.get_meta("archived_placements")== (38 if id==Undersea.SOKIA else 35),"All missing original bank-edge details are restored")
 check(edges.get_meta("wall_caps",false) and edges.mesh.get_aabb().position.y>Tour.Indoor.CEILING_HEIGHT-.1,"The original high wall caps stay at the ceiling rather than lying on the floor")
 var roof=game.world.find_child("HabaruRockCeiling",true,false)
 if roof==null:roof=game.world.find_child("SolidCaveCeiling",true,false)
 var roof_bounds:AABB=roof.mesh.get_aabb()
 check(roof_bounds.position.y>=Tour.Indoor.CEILING_HEIGHT and roof_bounds.end.y<Tour.Indoor.ROCK_WALL_HEIGHT,"The sealed blue vault keeps the original high clearance and meets the walls")
 check(roof.material_override.get_shader_parameter("archive_rock")==preload("res://assets/maps/falan/undersea_roof_atlas.png"),"The vault uses recovered rock tops instead of a stretched wall-side texture")
 check(roof.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==(info[0].x*info[0].y*6),"Every original cave cell retains a complete ceiling")
 var shore=game.world.find_child("ArchivedUnderseaShoreCliffs",true,false)
 check(shore!=null and shore.get_meta("archived_faces",0)>0,"Original shoreline banks have visible vertical rock faces")
 if shore!=null:
  var shore_bounds:AABB=shore.mesh.get_aabb()
  check(is_equal_approx(shore_bounds.position.y,Tour.Indoor.RoomArt.POOL_LEVEL) and shore_bounds.end.y>Tour.Indoor.RoomArt.POOL_LEVEL+.1 and shore_bounds.end.y<1,"Shore cliffs meet the water without raising the walkable passages")
 var walls=game.world.find_child("ArchivedCaveRockWalls",true,false)
 var vertices:PackedVector3Array=walls.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var sealed=true
 for vertex in vertices:
  if vertex.y!=0:continue
  var x=absf((vertex.x-info[1].x+1.5)/3.0-roundf((vertex.x-info[1].x+1.5)/3.0))
  var z=absf((vertex.z-info[1].y+1.5)/3.0-roundf((vertex.z-info[1].y+1.5)/3.0))
  if minf(x,z)>.0001:sealed=false
 check(sealed,"Cave wall bases meet the original floor grid without gaps")

func check_pool_tiles():
 var pool=game.world.find_child("ArchivedCavePools",true,false)
 check(pool is MeshInstance3D and is_equal_approx(pool.mesh.get_aabb().position.y,Tour.Indoor.RoomArt.POOL_LEVEL),
  "Archived blue floor tiles form shallow water below the walk surface")
 if game.model.falan_floor in Tour.Dungeons.UNDERSEA_FLOORS:
  for name_ in ["ArchivedRoomFloor","ArchivedCaveRockWalls","ArchivedCavePools","HabaruRockCeiling"]:
   var mesh=game.world.find_child(name_,true,false)
   if mesh==null and name_=="HabaruRockCeiling":mesh=game.world.find_child("SolidCaveCeiling",true,false)
   check(mesh is MeshInstance3D and mesh.material_override.get_shader_parameter("original_palette")==true,"Undersea source colors are preserved on "+name_)
  var walls=game.world.find_child("ArchivedCaveRockWalls",true,false)
  check(walls.material_override.get_shader_parameter("wall_faces")==Tour.Indoor.RoomArt.UnderseaWalls,"Undersea walls use their archived blue-palette faces")
  check(game.world.find_child("ArchivedRoomFloor",true,false).material_override.get_shader_parameter("base_texture")==Tour.Indoor.RoomArt.UnderseaFloor,"Undersea ground uses its blue source palette rather than the default green atlas")
  var banks=game.world.find_child("CaveBankStones",true,false)
  check(banks!=null and banks.material_override.get_shader_parameter("base_texture")==preload("res://assets/maps/falan/undersea_props.png") and banks.material_override.get_shader_parameter("original_palette"),"Original shore overlays use the same blue palette as the cave floor")

func check_undersea_source_colors():
 if DisplayServer.get_name()=="headless":return
 var viewport=SubViewport.new()
 viewport.size=Vector2i(384,128)
 viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var env=WorldEnvironment.new()
 env.environment=game.world.get_world_3d().environment.duplicate()
 viewport.add_child(env)
 var camera=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=2.0
 camera.position=Vector3(0,0,5)
 viewport.add_child(camera)
 var expected=[]
 var names=["ArchivedRoomFloor","ArchivedCaveRockWalls","ArchivedCavePools"]
 for index in names.size():
  var source=game.world.find_child(names[index],true,false)
  var material:ShaderMaterial=source.material_override
  var atlas:Texture2D=material.get_shader_parameter("wall_faces" if index==1 else "floor_atlas" if index==2 else "base_texture")
  var original=atlas.get_image()
  if original.is_compressed():original.decompress()
  var uvs:PackedVector2Array=source.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
  var uv=Vector2.ZERO
  for candidate in uvs:
   if candidate!=Vector2.ZERO and original.get_pixelv(Vector2i(candidate*atlas.get_size())).a>.5:
    uv=candidate
    break
  var pixel=Vector2i(uv*atlas.get_size())
  uv=(Vector2(pixel)+Vector2.ONE*.5)/atlas.get_size()
  expected.append(original.get_pixelv(pixel))
  var mesh=SurfaceTool.new()
  mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
  for point:Vector2 in [Vector2(-.8,-.8),Vector2(-.8,.8),Vector2(.8,.8),Vector2(-.8,-.8),Vector2(.8,.8),Vector2(.8,-.8)]:
   mesh.set_normal(Vector3.BACK)
   mesh.set_uv(uv)
   mesh.add_vertex(Vector3(point.x+(index-1)*2,point.y,0))
  var quad=MeshInstance3D.new()
  quad.mesh=mesh.commit()
  quad.material_override=material
  viewport.add_child(quad)
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 var rendered=viewport.get_texture().get_image()
 for index in names.size():
  var actual=rendered.get_pixel(64+index*128,64)
  var original:Color=expected[index]
  var error=maxf(absf(actual.r-original.r),maxf(absf(actual.g-original.g),absf(actual.b-original.b)))
  check(error<.025,"Rendered undersea "+names[index]+" matches the source palette: "+str(error))
 var folder=ProjectSettings.globalize_path(OUT+"Undersea Palette/")
 DirAccess.make_dir_recursive_absolute(folder)
 rendered.save_png(folder+str(game.model.falan_floor)+"-source-colors.png")
 viewport.queue_free()
 for i in 2:await process_frame
 var shore=game.world.find_child("ArchivedUnderseaShoreCliffs",true,false)
 if shore!=null:
  var arrays=shore.mesh.surface_get_arrays(0)
  var at:Vector3=shore.to_global((arrays[Mesh.ARRAY_VERTEX][0]+arrays[Mesh.ARRAY_VERTEX][2])*.5)
  var normal:Vector3=(shore.global_basis*arrays[Mesh.ARRAY_NORMAL][0]).normalized()
  await shot("undersea-shore-"+str(game.model.falan_floor),at+normal*6+Vector3.UP*1.2,at+Vector3.UP*.3,68,true)

func chart_capture(name_:String,labels:Array,folder:String="Cave Pools"):
 var minimap=game.forest_ui.enemy_minimap
 minimap.refresh()
 check(minimap.chart.texture!=null and minimap.chart.bounds.has_area(),"This area has a live, aligned map")
 for label in labels:
  check(minimap.chart.pins.any(func(pin):return label in pin.label),"The map labels "+label)
 var key=InputEventKey.new()
 key.keycode=KEY_M
 key.physical_keycode=KEY_M
 key.pressed=true
 Input.parse_input_event(key)
 for i in 4:await process_frame
 check(minimap.expanded,"M opens the larger map")
 if DisplayServer.get_name()!="headless" and minimap.expanded:
  await RenderingServer.frame_post_draw
  var image=root.get_texture().get_image()
  var rect=Rect2i(minimap.get_global_rect())
  check(image.get_region(rect).save_png(OUT+folder+"/map-"+name_+".png")==OK,"Captured the "+name_+" map")
 key=key.duplicate()
 key.pressed=false
 Input.parse_input_event(key)
 key=key.duplicate()
 key.pressed=true
 Input.parse_input_event(key)
 for i in 3:await process_frame
 check(not minimap.expanded,"M returns to the compact map")
 key=key.duplicate()
 key.pressed=false
 Input.parse_input_event(key)

func check_great_wind_road():
 await open_area("sokia_coast")
 var regions=Tour.Regions
 var frame=regions.frame("sokia_coast")
 var gates=regions.site_links("sokia_coast").filter(func(link):return link.site==3200)
 check(gates.size()==2,"Both Kili gates are available")
 if gates.size()!=2:return
 await position_at(gates[1].at)
 await walk_through_entry()
 check(Tour.area(game.model)=="kili","The original east approach enters Kili")
 if Tour.area(game.model)!="kili":return
 var east=game.model.get_meta("falan_links").filter(func(link):return link.to=="freyja_outside" and link.caption=="East Gate")
 check(east.size()==1,"Kili has an east exit to the Great Wind road")
 if east.is_empty():return
 await position_at(east[0].at)
 await walk_through_entry()
 check(Tour.area(game.model)=="sokia_coast","The east exit returns to Sokia")
 if Tour.area(game.model)!="sokia_coast":return
 var outside=map_position()
 check((frame*outside).distance_to(Vector2(294,325)*3)<.5,"The east exit preserves the shared walking gate coordinates")
 var mouths=regions.site_links("sokia_coast").filter(func(link):return link.site==13001)
 check(mouths.size()==1,"The new road has one Great Wind Cave entrance")
 if mouths.is_empty():return
 var mouth:Vector2=mouths[0].at
 check(frame*mouth==Vector2(356,334)*3,"The cave keeps the archived western coordinates")
 check(road_connected(outside,mouth,.6),"A continuous walkable road connects Kili to the cave")
 if DisplayServer.get_name()!="headless":
  var point=Vector3(mouth.x,game.model.surface_height(mouth.x,mouth.y),mouth.y)
  await shot("great-wind-cave-road",point+Vector3(-32,15,-13),point+Vector3.UP*2,66)
 await site(13001,"interior")
 check(game.model.falan_floor==13001 and map_position().distance_to(Vector2(-171,-57))<.5,
  "The western mouth enters the original cave floor")
 if game.model.falan_floor!=13001:return
 check_venoa_roof()
 var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(npcs) and npcs.get_children().any(func(sprite):return sprite.get_meta("npc_name","")=="小羊"),
  "The original sheep remains a silent 2D sprite")
 await cave_exit("sokia_coast")
 check(map_position().distance_to(mouth)<.5,"The cave returns to the same road")
 await site(13001,"interior")
 await cave_exit("sokia_desert")
 if Tour.area(game.model)!="sokia_desert":return
 var east_frame=regions.frame("sokia_desert")
 var landing=map_position()
 check((east_frame*landing).distance_to(Vector2(402,304)*3)<.5,"The east exit lands at the archived Sokia coordinates")
 await site(13001,"interior")
 check(game.model.falan_floor==13001 and map_position().distance_to(Vector2(174,3))<.5,
  "The east mouth returns to the original cave stairs")
 if DisplayServer.get_name()!="headless" and game.model.falan_floor==13001:
  await shot("great-wind-cave-east",Vector3(165,3.2,12),Vector3(174,1.5,3),65)
 await cave_exit("sokia_desert")
 if Tour.area(game.model)!="sokia_desert":return
 var joins=regions.Data.LINKS.filter(func(link):return link[0]=="sokia_desert" and link[1]=="ghana_road")
 check(joins.size()==1,"The Ghana road has a walking crossing")
 if joins.is_empty():return
 var seam=Vector2(joins[0][4],joins[0][5])
 var approach:Vector2=east_frame.inverse()*seam
 check(road_connected(landing,approach,.6),"The cave lands on a walkable road to the coast")
 await position_at(approach-Vector2.RIGHT)
 game.player.position.x+=2.0
 for i in 5:await physics_frame
 check(Tour.area(game.model)=="ghana_road","Walking across the coast connects to the Ghana road")
 if Tour.area(game.model)!="ghana_road":return
 var ghana_frame=regions.frame("ghana_road")
 var gate:Vector2=ghana_frame.inverse()*(Vector2(704,148)*3)
 var arrival=map_position()
 check(road_connected(arrival,gate,.6),"The coast road is walkable to Ghana's south gate")
 await position_at(gate)
 check(game.model.terrain.disk_clear(game.player.position/game.model.falan_scale,.6),"Ghana's south gate is on dry ground")
 if DisplayServer.get_name()!="headless":
  var point:Vector3=game.player.position
  await shot("ghana-village-road",point+Vector3(-12,10,18),point,66)
 var reverse:Vector2=ghana_frame.inverse()*(seam-Vector2(9,0))
 await position_at(reverse+Vector2.RIGHT)
 game.player.position.x-=2.0
 for i in 5:await physics_frame
 check(Tour.area(game.model)=="sokia_desert","Walking back across the coast returns toward the cave")

func check_il_habaru_alyut():
 game.tuning.invincible=true
 await open_area("east_coast")
 var sites=Tour.Regions.site_links(Tour.Regions.canonical_area("east_coast"))
 var il=sites.filter(func(link):return link.site==2000)[0]
 var il_mouth=sites.filter(func(link):return link.site==11003)[0]
 await position_at(il.at+Vector2(6,0))
 await position_at(il.at)
 check(Tour.area(game.model)==Tour.Regions.canonical_area("il_village"),"Il shares the outdoor map on foot")
 if Tour.area(game.model)!=Tour.Regions.canonical_area("il_village"):return
 village_entries(6)
 var shore=game.world.find_child("IlArchivedShore",true,false)
 check(is_instance_valid(shore) and shore.mesh.get_surface_count()==1,"Il renders its original shoreline")
 var scale_:float=game.model.falan_scale
 if DisplayServer.get_name()!="headless":
  await shot("Il to Alyut/il-village-shore",village_world(Vector3(148,170,145),"il_village"),village_world(Vector3(0,5,8),"il_village"),63)
 await leave_village("east_coast")
 check(Tour.area(game.model)==Tour.Regions.canonical_area("east_coast"),"Il's gate opens onto the road on foot")
 if Tour.area(game.model)!=Tour.Regions.canonical_area("east_coast"):return
 check(road_connected(map_position(),il_mouth.at,.55,false),"Il shares a continuous dry road with the Habaru entrance")
 await check_habaru_mouth(il_mouth,"HabaruIlMouth",Vector2i(672,223),"habaru-il-entrance")
 check(game.model.falan_floor==11003,"Walking into Habaru opens the original Il-side passage")
 if game.model.falan_floor!=11003:return
 await check_habaru_slimes()
 check_ceiling()
 check_habaru_wall_art(game.world.map_features,11003)
 await walk_habaru_link("floor",11004)
 if game.model.falan_floor!=11004:return
 for i in 8:await physics_frame
 check(game.model.enemies.is_empty() and is_instance_valid(game.habaru_waiting),"熊弟 waits alone at the chamber entrance")
 check(map_position().distance_to(Tour.Regions.Sites.HABARU_FORMATION[0])>22.0,"The chamber entrance is outside talking range")
 check_habaru_wall_art(game.world.map_features,11004)
 await walk_habaru_link("floor",11003)
 if game.model.falan_floor!=11003:return
 await walk_habaru_link("exit_id",11003)
 if Tour.area(game.model)!=Tour.Regions.canonical_area("east_coast"):return
 await walk_habaru_threshold(il_mouth.at,Tour.Regions.frame(Tour.area(game.model)).inverse().basis_xform(Vector2.RIGHT))
 await walk_habaru_link("floor",11004)
 if game.model.falan_floor!=11004:return
 var cave_chart=game.forest_ui.enemy_minimap
 cave_chart.refresh()
 check(cave_chart.chart.pins.any(func(pin):return pin.label=="熊弟"),"The cave map marks 熊弟's chamber")
 check_single_floor([11003,11005])
 await walk_habaru_link("floor",11005,false)
 var ladder=game.world.habaru_ladder
 check(is_instance_valid(ladder) and ladder.cover.collision_layer==1,"The basement hatch stays closed while 熊弟 is alive")
 game.tuning.invincible=true
 var boss:Vector2=Tour.Regions.Sites.HABARU_FORMATION[0]
 await position_at(boss+Vector2(0,15))
 for i in 12:await physics_frame
 var bears=game.model.enemies.values()
 check(bears.size()==10,"The original fight has 熊弟 and nine 穴熊")
 check(bears.all(func(e):return e.max_hp==(30000.0 if e.habaru_slot==0 else 10000.0)),"熊弟 and his bears use the requested HP")
 if DisplayServer.get_name()!="headless":
  var base:Vector3=game.model.world_point(boss+Vector2(0,15))
  await shot("Il to Alyut/habaru-kumatei",base+Vector3(7,8,12),base+Vector3(0,3.4,-8),72,true)
 game.tuning.invincible=false
 var normal_hp:float=game.player.hp
 var normal_max_hp:float=game.player.max_hp
 game.player.max_hp=5000.0
 game.player.hp=5000.0
 var old_hp:float=game.player.hp
 var runtime=game.army_runtime
 runtime.record_events=true
 runtime.event_log.clear()
 var damage_values={}
 var boss_id:int=bears[0].id
 for i in 630:
  await physics_frame
  for event in runtime.event_log:
   if event.kind!="external_damage" or event.external_kind!=0:continue
   if event.source_id==boss_id:
    damage_values.boss=is_equal_approx(event.amount,200.0)
   elif event.action_index==Habaru.DOUBLE_EDGE:
    damage_values.double_edge=is_equal_approx(event.amount,Habaru.ESCORT_DAMAGE*2)
   else:
    damage_values.bear=is_equal_approx(event.amount,Habaru.ESCORT_DAMAGE)
  runtime.event_log.clear()
  if damage_values.size()==3:break
 check(damage_values=={"boss":true,"bear":true,"double_edge":true},"Native contacts deliver 200 for 熊弟, 87 for bears and 174 for 諸刃: "+str(damage_values))
 check(game.player.hp<old_hp and game.player.hp>0,"The bears can close the gap and hit Kaz")
 runtime.record_events=false
 game.tuning.invincible=true
 game.player.max_hp=normal_max_hp
 game.player.hp=normal_hp
 for bear in bears:game.army_runtime.damage_enemy(bear.id,100000)
 for i in 12:await physics_frame
 await check_habaru_ladder(ladder)
 await walk_habaru_link("floor",11005)
 if game.model.falan_floor!=11005:return
 await check_habaru_slimes()
 check_habaru_wall_art(game.world.map_features,11005)
 check_ceiling()
 if DisplayServer.get_name()!="headless":
  await shot("Il to Alyut/habaru-alyut-pools",Vector3(9,7,-54)*scale_,Vector3(12,1,-21)*scale_,68)
 await walk_habaru_link("exit_id",11005)
 check(Tour.area(game.model)=="north_coast","The original Alyut-side cave exit opens on foot")
 if Tour.area(game.model)!="north_coast":return
 var alyut_mouth=map_position()
 var other=Tour.Regions.site_links("north_coast").filter(func(link):return link.site==11005)[0]
 await check_habaru_mouth(other,"HabaruAlyutMouth",Vector2i(691,188),"habaru-alyut-entrance")
 check(game.model.falan_floor==11005,"Walking into Habaru opens the original Alyut-side passage")
 if game.model.falan_floor!=11005:return
 await walk_habaru_link("floor",11004)
 if game.model.falan_floor!=11004:return
 check(game.model.enemies.is_empty(),"The bear fight stays cleared on return through Alyut's stair")
 await walk_habaru_link("floor",11005)
 await walk_habaru_link("exit_id",11005)
 if Tour.area(game.model)!="north_coast":return
 var gates=Tour.Regions.site_links("north_coast").filter(func(link):return link.site==2400)
 check(gates.size()==2,"Both original Alyut gates are available")
 if gates.size()!=2:return
 var south_gate=gates.filter(func(link):return link.arrival.y>0)[0]
 check(road_connected(alyut_mouth,south_gate.at,.55,false),"The dry mountain road reaches Alyut's south gate")
 check(road_connected(alyut_mouth,gates.filter(func(link):return link.arrival.y<0)[0].at,.55,false),"A dry branch reaches Alyut's north gate")
 if DisplayServer.get_name()!="headless":
  await shot("Il to Alyut/alyut-mountain-road",Vector3(157,78,197)*scale_,Vector3(87,5,106)*scale_,61)
  await shot("Il to Alyut/alyut-south-gate",Vector3(-94,36,-115)*scale_,Vector3(-121,8,-80)*scale_,60)
 var outdoors=game.model
 await position_at(south_gate.at+Vector2(0,4))
 await position_at(south_gate.at-Vector2(0,4))
 check(game.model==outdoors,"Alyut's south gate preserves the outdoor world")
 check(game.world.find_child("AlyutSouthGate",true,false)!=null,"The same gate appears in the village")
 await leave_village("north_coast")

func check_habaru_slimes():
 for i in 6:await physics_frame
 var slimes=game.model.enemies.values()
 check(slimes.size()==42 and slimes.all(func(e):return e.skin==Habaru.GREEN_SLIME and game.army_runtime.handles.has(e.id)),
  "Each Habaru passage has forty-two native green slimes")
 check(Habaru.motions().variants[Habaru.GREEN_SLIME].id==101500,"The patrol uses the original green slime sprite")

func check_habaru_slime_contact():
 var enemy:Dictionary=game.model.enemies.values()[0]
 var handle:int=game.army_runtime.handles[enemy.id]
 var start:Vector3=game.army_runtime.unit_state(handle).position
 var nearby=Tour.Indoor.safe_point(game.model.falan_floor,Vector2(start.x,start.z)/game.model.falan_scale+Vector2(0,3))
 await position_at(nearby)
 var hp:float=game.player.hp
 var max_hp:float=game.player.max_hp
 game.player.max_hp=5000
 game.player.hp=5000
 game.tuning.invincible=false
 for i in 210:
  await physics_frame
  if game.player.hp<5000:break
 check(game.player.hp<5000,"The roaming original green slimes approach and hit Kaz in Habaru")
 check(game.army_runtime.unit_state(handle).position.distance_to(start)>.2,"The green slimes move through the passage")
 game.tuning.invincible=true
 game.player.max_hp=max_hp
 game.player.hp=hp

func walk_habaru_link(key:String,target:int,should_open:bool=true):
 var links=game.model.get_meta("falan_links").filter(func(link):return link.get(key)==target)
 check(links.size()==1,"The archive links Habaru to "+str(target))
 if links.size()!=1:return
 var at:Vector2=links[0].at
 var start=game.model.falan_floor
 var serial:int=links[0].get("habaru_stair",0)
 var cell=Vector2i(((at-Tour.Indoor.floor_info(start)[1])/3.0).round())
 var node=game.world.map_features.get_node_or_null("HabaruStair_%d_%d"%[cell.x,cell.y])
 check(serial>0 and node!=null and node.get_meta("blue_cg_serial")==serial and node.has_node("HabaruWalkableTreads"),
  "The original stair geometry and walkable treads are at "+str(cell))
 var props=game.world.find_child("ArchivedBossProps",true,false)
 if is_instance_valid(props):
  check(not props.get_children().any(func(prop):return prop.get_meta("blue_cg_serial",0)==serial),"The old stair sprite cannot overlap the new stair geometry")
 var direction=Tour.Indoor.RoomArt.HabaruStairs.uphill(serial)
 if serial==17955 and start==11005:direction=Vector2.DOWN
 if DisplayServer.get_name()!="headless" and should_open and (serial==17955 or key=="exit_id" or start==11004):
  var p:Vector3=game.model.world_point(at)
  await shot("Il to Alyut/habaru-%d-stair-%d"%[start,serial],p+Vector3(-direction.x*5+3,5,-direction.y*5),p+Vector3.UP*.5,62)
 await walk_habaru_threshold(at,direction)
 var expected=target if key=="floor" else 0
 check(game.model.falan_floor==(expected if should_open else start),
  "Habaru stair or exit reaches the expected map on foot (%d to %d, at %s)"%[start,target,map_position()])

func check_habaru_mouth(link:Dictionary,node_name:String,source_cell:Vector2i,capture:String):
 var recess=game.world.find_child(node_name,true,false)
 check(recess!=null and recess.get_meta("archive_cell")==source_cell and recess.has_node("HabaruCliffRecess"),
  "The cliff mouth sits on its original Freyja tile")
 if DisplayServer.get_name()!="headless":
  var p:Vector3=game.model.world_point(link.at)
  await shot("Il to Alyut/"+capture,p+Vector3(-12,5,4),p+Vector3.UP*2.4,61)
 await walk_habaru_threshold(link.at,Tour.Regions.frame(Tour.area(game.model)).inverse().basis_xform(Vector2.RIGHT))

func walk_habaru_threshold(at:Vector2,direction:Vector2):
 var previous=game.model
 await position_at(at-direction*3.8)
 game.camera_rig.yaw=atan2(-direction.x,-direction.y)
 Input.action_press("move_forward")
 for i in (120 if game.model.falan_floor in Tour.Prayer.FLOORS else 54):
  await physics_frame
  if game.model!=previous:break
 Input.action_release("move_forward")
 await finish_boss_dialogue()
 for i in 3:await physics_frame

func check_habaru_wall_art(room:Node3D,id:int):
 var indoor=Tour.Indoor
 var size:Vector2i=indoor.floor_info(id)[0]
 var source=indoor.RoomArt.habaru_wall_tiles(id,size)
 check(source.size()==size.x*size.y*2,"Habaru has one wall art index per archived map cell")
 var walls=room.get_node_or_null("ArchivedCaveRockWalls") as MeshInstance3D
 if walls==null:
  check(false,"Habaru has visible rock walls")
  return
 var uvs:PackedVector2Array=walls.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
 check(Array(uvs).any(func(uv):return uv!=Vector2.ZERO),"The rock mesh uses the original wall faces")

func check_habaru_ladder(ladder):
 var chamber=game.model
 var scene=game.world.map_features
 check(ladder.open and ladder.cover.collision_layer==0,"Defeating 熊弟 opens the hatch")
 check(not chamber.get_meta("falan_links").any(func(link):return link.get("floor")==11028),"The hatch has no room transition")
 var basement=scene.get_node("HabaruBasement")
 check_habaru_wall_art(basement,11028)
 var roof=basement.get_node("HabaruBasementCeiling")
 check(roof.mesh.get_aabb().end.y<ladder.DEPTH,"The basement roof cannot cross through the upper floor")
 var journal_room=basement.get_node("ArchivedBossProps")
 check(journal_room.get_children().any(func(prop):return prop.get_meta("blue_cg_serial",0)==16511),"The original bookshelves are below the chamber")
 var start=ladder.TOP_EXIT
 for down in [true,false]:
  game.player.global_position=ladder.to_global(start)
  game.camera_rig.yaw=0.0 if down else -PI*.5
  game.player.velocity=Vector3.ZERO
  for i in 6:await physics_frame
  Input.action_press("move_forward")
  for i in 48:
   await physics_frame
   if ladder.climbing:break
  Input.action_release("move_forward")
  check(ladder.climbing,"Walking toward the opening starts climbing")
  var mid_y:float=game.player.global_position.y
  for i in 76:
   await physics_frame
   game.camera_rig.update_camera(1.0/60.0)
  check(ladder.climbing and absf(game.player.global_position.y-mid_y)>2.0,"Kaz moves vertically through the shaft")
  for i in 120:
   await physics_frame
   if not ladder.climbing:break
  start=ladder.BOTTOM_EXIT if down else ladder.TOP_EXIT
  check(game.player.global_position.distance_to(ladder.to_global(start))<.45,"Kaz steps off the ladder at the intended floor")
  check(game.model==chamber and game.world.map_features==scene,"Climbing keeps the same scene and combat state")
  if down:
   for i in 8:await physics_frame
   check(game.player.is_on_floor(),"The basement has a solid walkable floor")
   game.camera_rig.update_camera(1.0/60.0)
   check(game.camera_rig.camera.global_position.y<0,"The camera follows Kaz below the upper floor")
   var map=game.forest_ui.enemy_minimap
   map.refresh()
   check(map.chart.pins.any(func(pin):return pin.label=="Ladder Up"),"The basement map shows the way back up")
   if DisplayServer.get_name()!="headless":
    await shot("Il to Alyut/habaru-connected-ladder",ladder.to_global(Vector3(-7,-6.2,1.7)),ladder.to_global(Vector3(0,-4.9,-.7)),64)
 check(game.model.enemies.is_empty(),"Climbing back up leaves the encounter cleared")

func check_mountain_tomato():
 var edge:float=Tour.Frontier.OUTER_EDGE.east_gate
 await position_at(Tour.Frontier.to_city("east_gate",Vector2(3,edge-1)))
 await position_at(Tour.Frontier.to_city("east_gate",Vector2(3,edge+1)))
 if Tour.area(game.model)!="east_gate":
  check(false,"East Gate opens on foot")
  return
 var cabin=Tour.Regions.site_links("east_gate").filter(func(link):return link.site==1155)[0]
 await position_at(cabin.at-cabin.direction*4)
 await position_at(cabin.at)
 check(game.model.falan_floor==1155,"The woodcutter's house opens on foot")
 if game.model.falan_floor!=1155:return
 var ids=Tour.Regions.Sites.TOMATO_MAPS
 var trail=game.model.get_meta("falan_links").filter(func(link):return link.get("floor")==ids[0])[0]
 check(trail.at==Vector2(-3,-18) and trail.walk_in,"The trail opens on foot at Katy's original cell")
 await position_at(trail.at+Vector2(0,4))
 await position_at(trail.at)
 check(Tour.area(game.model)=="tomato_road","Walking from the cabin loads the mountain path")
 if Tour.area(game.model)!="tomato_road":return
 check(game.model.terrain.submerged(Vector3(400,0,400)),"Low ground off the mountain uses the safe return")
 var pass_=game.model.get_meta("falan_links").filter(func(link):return link.get("floor")==ids[1])[0]
 check(road_connected(map_position(),pass_.at,.55,false),"The mountain path has a continuous dry route to the farm")
 if DisplayServer.get_name()!="headless":
  var factor:float=game.model.falan_scale
  await shot("Mountain Tomato Farm/path-overview",Vector3(212,220,192)*factor,Vector3(0,12,0)*factor,65)
 await position_at(pass_.at+Vector2(4,0))
 await position_at(pass_.at)
 check(Tour.area(game.model)=="tomato_farm","The mountain path opens into the farm on foot")
 if Tour.area(game.model)!="tomato_farm":return
 check(is_instance_valid(game.world.find_child("MountainTomatoBeds",true,false)) and is_instance_valid(game.world.find_child("TomatoStorehouse",true,false)),"The farm renders the crop beds and storehouse")
 check(game.model.falan_frontier_plan.any(func(row):return row[0]=="ghana_well" and Vector2(row[1].origin.x,row[1].origin.z)==Vector2(-15,-12)),"The well uses the original (25,26) cell")
 if DisplayServer.get_name()!="headless":
  var factor:float=game.model.falan_scale
  await shot("Mountain Tomato Farm/farm-overview",Vector3(74,78,81)*factor,Vector3(0,14,0)*factor,60)
  await shot("Mountain Tomato Farm/well-and-storehouse",Vector3(-29,30,7)*factor,Vector3(-5,16,-7)*factor,63)
 for cell in [Vector2(0,6),Vector2(12,6)]:
  var doors=game.model.get_meta("falan_links").filter(func(link):return link.get("floor")==ids[2] and link.at==cell)
  check(doors.size()==1 and doors[0].walk_in,"The farm preserves both storehouse doors")
  if doors.is_empty():return
  await position_at(cell+Vector2(0,4))
  await position_at(cell)
  check(game.model.falan_floor==ids[2],"Walking through the farm door enters the storehouse")
  if game.model.falan_floor!=ids[2]:return
  var exit=game.model.get_meta("falan_links").filter(func(link):return link.arrival==cell)[0]
  await position_at(exit.at+Vector2(0,-4))
  await position_at(exit.at)
  check(Tour.area(game.model)=="tomato_farm","The storehouse door returns to the farm")
  if Tour.area(game.model)!="tomato_farm":return
 var farm_exit=game.model.get_meta("falan_links").filter(func(link):return link.get("floor")==ids[0])[0]
 await position_at(farm_exit.at-Vector2(4,0))
 await position_at(farm_exit.at)
 check(Tour.area(game.model)=="tomato_road","The farm returns to the mountain path")
 if Tour.area(game.model)!="tomato_road":return
 var trail_exit=game.model.get_meta("falan_links").filter(func(link):return link.get("floor")==1155)[0]
 await position_at(trail_exit.at-Vector2(4,0))
 await position_at(trail_exit.at)
 check(game.model.falan_floor==1155,"The trail returns to the woodcutter's house")
 if game.model.falan_floor!=1155:return
 var cottage_exit=game.model.get_meta("falan_links").filter(func(link):return link.to=="freyja_return")[0]
 await position_at(cottage_exit.at-Vector2(0,4))
 await position_at(cottage_exit.at)
 check(Tour.area(game.model)=="east_gate","The house still returns to the East Gate road")

func check_west_laruka_road():
 var edge:float=Tour.Frontier.OUTER_EDGE.freyja
 await position_at(Tour.Frontier.to_city("freyja",Vector2(3,edge-1)))
 await position_at(Tour.Frontier.to_city("freyja",Vector2(3,edge+1)))
 check(Tour.area(game.model)=="freyja","West Gate opens on foot from Falan")
 if Tour.area(game.model)!="freyja":return
 check(road_connected(Vector2(3,165),Vector2(-39,420),.55),"A clear road rounds the inlet to the Western Lakes seam")
 if DisplayServer.get_name()!="headless":
  var scale_:float=game.model.falan_scale
  await shot("West Road to Laruka/west-inlet",Vector3(61,70,182)*scale_,Vector3(-64,6,232)*scale_,66)
 await position_at(Vector2(-39,419))
 await position_at(Vector2(-39,421))
 check(Tour.area(game.model)=="west_lakes","The road continues on foot into Western Lakes")
 if Tour.area(game.model)!="west_lakes":return
 var start=map_position()
 var ridges=game.world.find_child("ArchivedGateRidges",true,false)
 check(is_instance_valid(ridges) and ridges.mesh.get_surface_count()==1,"Western Lakes renders the archived mountain ridges")
 var village=Tour.Regions.site_links("west_lakes").filter(func(link):return link.site==2300)[0]
 check(road_connected(start,village.at,.55,false),"A clear road leads from the West Gate seam to Saint Laruka")
 check(game.world.find_child("LarukaOpenGate",true,false)!=null,"The open gate is visible from the road")
 var landing=Tour.Regions.LARUKA_GATE+Tour.Regions.LARUKA_TO_ROAD+Vector2(3,0)
 await position_at(landing+Vector2(3,1.5))
 await position_at(village.at+Vector2(0,1.5))
 check(Tour.area(game.model)=="laruka","Walking through Laruka's gate enters the village")
 if Tour.area(game.model)!="laruka":return
 var gate=game.model.get_meta("falan_links").filter(func(link):return link.to=="freyja_return")[0]
 check(gate.at.distance_to(map_position())>Tour.WALK_IN_RADIUS,"The village landing stays clear of the return trigger")
 check(game.world.find_child("LarukaOpenGate",true,false)!=null,"The same gate appears on the village side")
 await position_at(gate.at)
 check(Tour.area(game.model)=="west_lakes" and map_position().distance_to(landing)<.5,"The original gate returns to the road on foot")
 if DisplayServer.get_name()!="headless" and Tour.area(game.model)=="west_lakes":
  var scale_:float=game.model.falan_scale
  await shot("West Road to Laruka/lakes-road",Vector3(154,90,-88)*scale_,Vector3(30,6,35)*scale_,63)
  await shot("West Road to Laruka/laruka-approach",Vector3(-123,40,95)*scale_,Vector3(-171,8,113)*scale_,61)

func check_east_il_road():
 var edge:float=Tour.Frontier.OUTER_EDGE.east_gate
 await position_at(Vector2(-138,-273))
 game.camera_rig.yaw=0.0
 Input.action_press("move_forward")
 for i in 1200:
  await physics_frame
  if Tour.area(game.model)=="east_gate":break
 Input.action_release("move_forward")
 check(Tour.area(game.model)=="east_gate","East Gate opens on foot from Falan")
 if Tour.area(game.model)!="east_gate":return
 var archive=Tour.Regions.frame("east_gate")
 check((archive*map_position()).distance_to(Vector2(475,196)*3)<.35,"East Gate lands at archived Freyja cell (475,196)")
 check(game.player.facing.dot(Vector3.BACK)>.99 and cos(game.camera_rig.yaw)<-.99,"Kaz and the camera face outward on arrival")
 if DisplayServer.get_name()!="headless":
  game.camera_rig.update_camera(.2)
  var eye:Vector3=game.camera_rig.camera.global_position
  await shot("East Road to Il/archived-east-gate-landing",eye,eye+Vector3.BACK*8.0,63)
 Input.action_press("move_forward")
 for i in 18:await physics_frame
 Input.action_release("move_forward")
 check((archive*map_position()).x>475*3+1,"Forward continues east after the gate landing")
 await position_at(Vector2(3,Tour.Frontier.INNER_EDGE.east_gate+1))
 await position_at(Vector2(3,Tour.Frontier.INNER_EDGE.east_gate-1))
 check(Tour.area(game.model)=="city" and map_position().distance_to(Vector2(-138,-372))<.35,"The exterior return lands at the original city cell (277,88)")
 if Tour.area(game.model)!="city":return
 await position_at(Tour.Frontier.to_city("east_gate",Vector2(3,edge-1)))
 await position_at(Tour.Frontier.to_city("east_gate",Vector2(3,edge+1)))
 if Tour.area(game.model)!="east_gate":return
 var plot=game.world.find_child("WoodcutterCropRows",true,false)
 check(is_instance_valid(plot) and Entrances.Gates.EXTERIORS.east_gate.crops.size()==14,"The original 4×4 garden has thirteen crops and a pitchfork")
 var east_chart=game.forest_ui.enemy_minimap
 east_chart.refresh()
 check(east_chart.chart.pins.any(func(pin):return pin.label=="Tomato Plot"),"The East Gate map marks the tomato plot")
 if DisplayServer.get_name()!="headless":
  var scale_:float=game.model.falan_scale
  await shot("East Road to Il/woodcutter-field",Vector3(85,22,234)*scale_,Vector3(110,7,262)*scale_,61)
 var cabin=Tour.Regions.site_links("east_gate").filter(func(link):return link.site==1155)[0]
 check(Tour.Regions.frame("east_gate")*cabin.at==Vector2(1527,459),"The woodcutter's house uses the original Freyja door cell")
 await position_at(cabin.at-cabin.direction*4.0)
 await position_at(cabin.at)
 check(game.model.falan_floor==1155,"The woodcutter's house opens on foot")
 if game.model.falan_floor!=1155:return
 var exit=game.model.get_meta("falan_links").filter(func(link):return link.to=="freyja_return")[0]
 await position_at(exit.at+Vector2(0,-4))
 await position_at(exit.at)
 check(Tour.area(game.model)=="east_gate","Leaving the house returns to the East Gate road")
 if Tour.area(game.model)!="east_gate":return
 await position_at(Vector2(-108,410))
 await position_at(Vector2(-108,412))
 check(Tour.area(game.model)==Tour.Regions.canonical_area("east_coast"),"The road continues on foot into East Coast")
 if Tour.area(game.model)!=Tour.Regions.canonical_area("east_coast"):return
 var start=map_position()
 var ridges=game.world.find_child("ArchivedGateRidges",true,false)
 check(is_instance_valid(ridges) and ridges.mesh.get_surface_count()==1,"East Coast renders the archived cliffs")
 var village=Tour.Regions.site_links(Tour.Regions.canonical_area("east_coast")).filter(func(link):return link.site==2000)[0]
 check(road_connected(start,village.at,.55,false),"A clear road leads from East Gate to Il Village")
 var outside_gate=game.world.find_child("IlVillageTimberGate",true,false)
 check(is_instance_valid(outside_gate),"The timber gate and lookout are visible from the road")
 var landing=Tour.Regions.coast_to_gate(Tour.Regions.IL_GATE+Tour.Regions.IL_TO_ROAD+Vector2(3,0))
 await position_at(landing+Vector2(3,0))
 await position_at(village.at)
 check(Tour.area(game.model)=="east_gate","Walking through Il's gate stays in the connected landscape")
 check(game.world.find_child("IlVillageTimberGate",true,false)==outside_gate,"The same timber gate remains alive")
 await position_at(landing)
 check(Tour.area(game.model)=="east_gate" and map_position().distance_to(landing)<.5,"Il's gate returns along the existing road without travel")
 if DisplayServer.get_name()!="headless" and Tour.area(game.model)==Tour.Regions.canonical_area("east_coast"):
  var scale_:float=game.model.falan_scale
  await shot("East Road to Il/canal-crossing",Vector3(-310,24,-61)*scale_,Vector3(-268,6,-86)*scale_,59)
  await shot("East Road to Il/coastal-road",Vector3(-155,89,-36)*scale_,Vector3(-55,5,50)*scale_,63)
  await shot("East Road to Il/il-approach",Vector3(166,46,207)*scale_,Vector3(98,8,247)*scale_,58)

func check_west_south_gates():
 for gate in ["freyja","south_gate"]:
  var west=gate=="freyja"
  var edge:float=Tour.Frontier.OUTER_EDGE[gate]
  await position_at(Tour.Frontier.to_city(gate,Vector2(3,edge-30)))
  game.camera_rig.yaw=PI if west else -PI*.5
  Input.action_press("move_forward")
  for i in 280:
   await physics_frame
   if Tour.area(game.model)==gate:break
  Input.action_release("move_forward")
  check(Tour.area(game.model)==gate,"Kaz can physically walk through "+gate)
  if Tour.area(game.model)!=gate:return
  var archive:Transform2D=Tour.Regions.frame(gate)
  var cell=Vector2(374,195) if west else Vector2(424,259)
  check((archive*map_position()).distance_to(cell*3.0)<.4,"The original outside landing matches "+gate)
  check(game.player.facing.dot(Vector3.BACK)>.99 and cos(game.camera_rig.yaw)<-.99,"Kaz faces away from Falan at "+gate)
  game.camera_rig.yaw=0.0
  Input.action_press("move_forward")
  for i in 280:
   await physics_frame
   if Tour.area(game.model)=="city":break
  Input.action_release("move_forward")
  check(Tour.area(game.model)=="city","Kaz can walk back into Falan at "+gate)
  if Tour.area(game.model)!="city":return
  var city=Vector2(-138,378) if west else Vector2(303,0)
  check(map_position().distance_to(city)<.4,"The original city return matches "+gate)

func check_south_venoa_road():
 var edge:float=Tour.Frontier.OUTER_EDGE.south_gate
 await position_at(Tour.Frontier.to_city("south_gate",Vector2(3,edge-1)))
 await position_at(Tour.Frontier.to_city("south_gate",Vector2(3,edge+1)))
 check(Tour.area(game.model)=="south_gate","South Gate opens on foot from Falan")
 if Tour.area(game.model)!="south_gate":return
 await position_at(Vector2(54,446))
 await position_at(Vector2(54,448))
 check(Tour.area(game.model)=="south_lakes","The road continues on foot into Southern Lakes")
 if Tour.area(game.model)!="south_lakes":return
 var road_start=map_position()
 var ridges=game.world.find_child("ArchivedGateRidges",true,false)
 check(is_instance_valid(ridges) and ridges.mesh.get_surface_count()==1,"Southern Lakes renders the archived mountain range")
 var links=Tour.Regions.site_links("south_lakes")
 var cave=links.filter(func(link):return link.site==11002)[0]
 var village=links.filter(func(link):return link.site==2100)[0]
 check(road_connected(road_start,village.at,.55),"A clear road connects the South Gate seam to Venoa Village")
 if DisplayServer.get_name()!="headless":
  var scale_:float=game.model.falan_scale
  await shot("South Road to Venoa/mountain-pass",Vector3(141,72,-252)*scale_,Vector3(92,6,-173)*scale_,64)
  await shot("South Road to Venoa/venoa-approach",Vector3(-68,85,-37)*scale_,Vector3(-155,7,53)*scale_,64)
 await position_at(cave.at-cave.direction*4)
 await position_at(cave.at)
 check(game.model.falan_floor==11002,"Walking into Venoa Cave opens its village-side floor")
 if game.model.falan_floor!=11002:return
 for i in 4:await physics_frame
 check(game.model.falan_floor==11002,"The cave landing does not send Kaz straight back out")
 var cave_exit_link:Dictionary=game.model.get_meta("falan_links").filter(func(link):return link.get("exit_id")==11002)[0]
 await position_at(cave_exit_link.at+Vector2(0,-4))
 await position_at(cave_exit_link.at)
 check(Tour.area(game.model)=="south_lakes","Walking out of Venoa Cave returns to the road")
 if Tour.area(game.model)!="south_lakes":return
 await position_at(village.at+Vector2(4,-1.5))
 await position_at(village.at-Vector2(0,1.5))
 check(Tour.area(game.model)=="venoa","Walking through the original village gate enters Venoa")
 if Tour.area(game.model)!="venoa":return
 var gate:Dictionary=game.model.get_meta("falan_links").filter(func(link):return link.to=="freyja_return")[0]
 check(gate.at.distance_to(map_position())>Tour.WALK_IN_RADIUS,"The exit is beyond the village landing")
 await position_at(gate.at)
 check(Tour.area(game.model)=="south_lakes","Walking back through Venoa's gate returns to the road")
 await open_area("north_coast")
 var zombie=Tour.Regions.site_links("north_coast").filter(func(link):return link.site==410)[0]
 await position_at(zombie.at-zombie.direction*4)
 await position_at(zombie.at)
 check(game.model.falan_floor==15505,"Walking into the yellow diamond enters Zombie Cave")

func check_freyja_scale():
 var scale_:float=game.model.falan_scale
 check(is_equal_approx(scale_,1.3),"The saved city loads at 130 percent")
 var landings={"freyja":Vector2(374,195),"east_gate":Vector2(475,196),"south_gate":Vector2(424,259)}
 var returns={"freyja":Vector2(-138,378),"east_gate":Vector2(-138,-372),"south_gate":Vector2(303,0)}
 for gate in Tour.Frontier.FRAMES:
  var edge:float=Tour.Frontier.OUTER_EDGE[gate]
  var inside=Tour.Frontier.to_city(gate,Vector2(3,edge-1))
  var outside=Tour.Frontier.to_city(gate,Vector2(3,edge+1))
  await position_at(inside)
  await position_at(outside)
  check(Tour.area(game.model)==gate,"Walking out of Falan reaches "+gate)
  if Tour.area(game.model)!=gate:return
  var frame=Tour.Regions.frame(gate)
  check((frame*map_position()).distance_to(landings[gate]*3)<.4,"The gate lands on the original Freyja tile: "+gate)
  check(game.player.facing.dot(Vector3.BACK)>.99 and cos(game.camera_rig.yaw)<-.99,"Kaz and the camera face out: "+gate)
  var before_forward=map_position()
  Input.action_press("move_forward")
  for i in 16:await physics_frame
  Input.action_release("move_forward")
  check(map_position().y>before_forward.y+1.0,"Forward walks away from the city: "+gate)
  var ridges=game.world.find_child("ArchivedGateRidges",true,false)
  check(is_instance_valid(ridges) and ridges.mesh.get_surface_count()==1,"The archived cliff and shore forms render outside "+gate)
  if gate=="south_gate":
   if DisplayServer.get_name()!="headless" and "--south-exterior" in OS.get_cmdline_user_args():
    await shot("South Gate Exterior/south-overview",Vector3(-116,142,90)*scale_,Vector3(40,0,216)*scale_,66)
    await shot("South Gate Exterior/south-landing",Vector3(3,13,119)*scale_,Vector3(3,11,199)*scale_,66)
    await shot("South Gate Exterior/south-mountain-road",Vector3(173,63,266)*scale_,Vector3(126,9,353)*scale_,64)
  else:
   if DisplayServer.get_name()!="headless" and "--gate-exteriors" in OS.get_cmdline_user_args():
    var label="west" if gate=="freyja" else "east"
    var side=-1.0 if gate=="freyja" else 1.0
    await shot("Gate Exteriors/"+label+"-overview",Vector3(side*101,101,83)*scale_,Vector3(side*30,3,188)*scale_,65)
    await shot("Gate Exteriors/"+label+"-landing",Vector3(3,13,123)*scale_,Vector3(3,11,195)*scale_,64)
  var at=Vector2(-33,174) if gate=="freyja" else Vector2(3,190)
  await position_at(at)
  var ground:Vector3=game.model.world_point(at)
  var query=PhysicsRayQueryParameters3D.create(ground+Vector3.UP*3,ground-Vector3.UP*2,1)
  var hit=game.world.get_world_3d().direct_space_state.intersect_ray(query)
  check(not hit.is_empty() and absf(hit.position.y-ground.y)<.2,"Scaled terrain height matches physical collision at "+gate)
  var nav=game.army_runtime.navigation_data(game.model)
  check(is_equal_approx(nav.spacing,3.9) and is_equal_approx(nav.bounds_max.x,477*scale_),
   "Native navigation uses scaled terrain and bounds")
  await position_at(Vector2(3,Tour.Frontier.INNER_EDGE[gate]+1))
  var before_return=map_position()
  await position_at(Vector2(3,Tour.Frontier.INNER_EDGE[gate]-1))
  check(Tour.area(game.model)=="city","Walking through %s returns to Falan (%s to %s)" % [gate,before_return,map_position()])
  if Tour.area(game.model)!="city":return
  check(map_position().distance_to(returns[gate])<.4,"The gate returns to the original city tile: "+gate)
 var venture:Dictionary=get_meta("falan_venture")
 var east_edge:float=Tour.Frontier.EAST_TRAIL_EDGE
 Tour.travel(game,venture.falan_areas.east_gate,{"arrival":Vector2(east_edge+1,279),"yaw":0.0,"velocity":Vector3.ZERO})
 await position_at(Vector2(east_edge+1,279))
 await position_at(Vector2(east_edge-1,279))
 check(Tour.area(game.model)=="south_gate","The East and South roads still connect outside the city")
 if "--south-exterior" in OS.get_cmdline_user_args() and Tour.area(game.model)=="south_gate":
  var south_edge:float=Tour.Frontier.SOUTH_TRAIL_EDGE
  await position_at(Vector2(261,south_edge+2))
  await position_at(Vector2(261,south_edge-1))
  check(Tour.area(game.model)=="east_gate","The South Gate road also returns to East Gate")
 Tour.travel(game,venture,{"arrival":Vector2(3,163),"yaw":0.0,"velocity":Vector3.ZERO})
 await position_at(Vector2(3,163))
 if DisplayServer.get_name()!="headless":
  await shot("Freyja Scale/west-crossing",Vector3(5,12,168)*scale_,Vector3(3,7,105)*scale_,65)
 var hp:float=game.player.hp
 game.player.position=Vector3(-24,1,105)*scale_
 for i in 4:await physics_frame
 check(map_position().distance_to(Vector2(-24,105))<.2 and game.player.hp==hp and game.player.position.y>=2.0*scale_-.10,
  "Entering the scaled moat supports Kaz in place on the water")
 if "--gate-exteriors" in OS.get_cmdline_user_args() or "--south-exterior" in OS.get_cmdline_user_args():return
 await open_area("south_lakes")
 await site(11002,"interior")
 if game.model.falan_floor!=11002:return
 check_venoa_roof()
 check(is_equal_approx(game.world.map_features.global_basis.x.length(),scale_),"Venoa's cave floor shares the overworld scale")
 await cave_exit("south_lakes")
 await check_ruby_boss()

func approach_black_prayer():
 await open_area("sokia_coast")
 var sites=Tour.Regions.site_links("sokia_coast")
 var west=sites.filter(func(link):return link.site==3200)[0]
 var house=sites.filter(func(link):return link.site==3350)[0]
 check(road_connected(west.at,house.at,.55),"Kili's west trail reaches Fengnu's House on dry ground")
 await site(3200,"kili")
 await room(3208)
 var tavern=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(tavern) and tavern.get_children().any(func(npc):return npc.get_meta("npc_name")=="雷欧尼"),
  "Kili's tavern keeps the original silent quest NPC")
 await room(3200)
 var gate=game.model.get_meta("falan_links").filter(func(link):return link.get("area")=="sokia_coast")[0]
 await position_at(gate.at)
 await walk_through_entry()
 await site(15004,"interior")
 if game.model.falan_floor!=15003:return


func check_ruby_boss():
 await approach_black_prayer()
 if game.model.falan_floor!=15003:return

 check(game.world.find_child("BlueCGYellowDiamond",true,false)!=null,"The suspicious rock has the original yellow diamond")
 await room(Tour.Prayer.ENTRY)
 await check_black_prayer_floors()
 await room(Ruby.ROOM)
 if game.model.falan_floor!=Ruby.ROOM:return
 check_venoa_roof()
 var roof=game.world.find_child("SolidCaveCeiling",true,false)
 check(is_instance_valid(roof) and is_equal_approx(roof.global_basis.x.length(),1.3),
  "The original Ruby palace and solid ceiling retain the existing scale")
 var plan=Tour.Indoor.floor_info(Ruby.ROOM)
 var original:PackedByteArray=plan[2].hex_decode()
 check(Tour.Indoor.walk_mask(Ruby.ROOM,plan[0],original.duplicate(),game.model.seed_value)==original,
  "Ruby’s room uses the original walkable tiles without widening")
 var props=game.world.find_child("ArchivedRubyProps",true,false)
 check(is_instance_valid(props) and props.get_children().filter(func(prop):return prop.get_meta("blue_cg_serial")==17206).size()==3,
  "The three original barred panels are present")
 var caps=props.get_children().filter(func(prop):return prop.get_meta("blue_cg_serial")==15819)
 check(caps.size()==4 and caps.all(func(prop):return prop is MeshInstance3D and prop.position.y>6.0),"Original overhead stone caps use raised 3D geometry")
 var arches=props.get_children().filter(func(prop):return prop.get_meta("blue_cg_serial") in [17683,17684])
 check(arches.size()==6 and arches.all(func(prop):return prop is MeshInstance3D and prop.position.y>6.0),"Six source arch headers use raised solid geometry without isometric billboard tops")
 check(map_position().distance_to(Vector2(42,-57))<.5,"The last maze arrives at the original palace entrance (39,5)")
 if DisplayServer.get_name()!="headless":
  await shot("Original Ruby/ruby-barred-entry",game.model.world_point(Vector2(-3,29),5.5),
   game.model.world_point(Vector2(-3,17),3.2),64)
 var pose:Transform3D=game.player.global_transform
 pose.origin=game.model.world_point(Vector2(-3,21),.32)
 check(game.player.test_move(pose,game.model.world_point(Vector2(-3,15),.32)-pose.origin),"The original barred tiles block walking")
 var model_before=game.model
 await position_at(Vector2(-3,27))
 await position_at(Vector2(-3,21))
 check(game.model==model_before and map_position().distance_to(Vector2(-3,15))<.5,
  "The silent guard lets Kaz cross the bars without changing floors")
 game.tuning.invincible=true
 await position_at(Vector2(-3,-6))
 var runtime=game.army_runtime
 var actors:Array=game.model.enemies.values()
 var boss=actors.filter(func(row):return row.ruby_slot==0)
 var blades=actors.filter(func(row):return row.skin==1)
 check(boss.size()==1 and blades.size()==5 and actors.size()==10,"Ruby has five Bloody Blades and four ghosts")
 check(actors.all(func(row):return runtime.handles.has(row.id)),"The complete encounter uses native actors")
 check(Ruby.motions().variants.map(func(row):return int(row.id))==[100654,101600,101121],"The boss and escorts use original sprites")
 check(Ruby.motions().variants.all(func(row):return row.standing_height>=Ruby.KAZ_HEIGHT)
  and Ruby.STATS.range>=Ruby.KAZ_HEIGHT,"Ruby and her escorts are at least Kaz's height and attack reach")
 if boss.is_empty():return
 if DisplayServer.get_name()!="headless":
  await shot("ruby-original-party",game.model.world_point(Vector2(-3,9),7.2),game.model.world_point(Vector2(-3,-23),2.0),75)
  await shot("ruby-original-boss",game.model.world_point(Vector2(-3,-32),6.4),game.model.world_point(Vector2(-3,-42),2.2),70)
 boss=boss[0]
 await position_at(Vector2(-3,-24))
 check(game.dungeon_boss_nearby(),"Ruby activates the dungeon boss camera")
 var rig=game.camera_rig
 rig.yaw=0.0
 rig.pitch=.35
 rig.reset_follow()
 game.model.waves.dungeon_boss_id=0
 for step in 90:rig.update_camera(1.0/60.0)
 var normal_distance:float=rig.current_distance
 var normal_fov:float=rig.camera.fov
 game.model.waves.dungeon_boss_id=boss.id
 for step in 90:rig.update_camera(1.0/60.0)
 check(rig.current_distance>normal_distance+1.0 and rig.camera.fov>normal_fov+3.0,
  "The camera pulls back and shows more of the room during the fight")
 check(rig.camera.global_position.y<game.cave_camera_limit(),"The pulled-back camera remains below the ceiling")
 if DisplayServer.get_name()!="headless":
  await shot("Original Ruby/ruby-boss-camera",rig.camera.global_position,
   rig.camera.global_position-rig.camera.global_basis.z*20.0,rig.camera.fov)
 await room_locked_ruby()
 runtime.record_events=true
 for attempt in 3:
  runtime.damage_enemy(boss.id,100)
  if runtime.unit_state(runtime.handles[boss.id]).hp<boss.max_hp:break
 var point:Vector3=runtime.unit_state(runtime.handles[boss.id]).position
 await position_at(Vector2(point.x,point.z+5)/game.model.falan_scale)
 var heal=await zombie_event("status",Zombie.HEAL,boss.id,1800)
 check(not heal.is_empty(),"Ruby heals while her Blades are defending her")
 for row in blades.slice(0,3):runtime.damage_enemy(row.id,row.max_hp*2)
 point=runtime.unit_state(runtime.handles[boss.id]).position
 await position_at(Vector2(point.x,point.z+4)/game.model.falan_scale)
 var frost=await zombie_event("status",Ruby.FROST,boss.id,900)
 check(not frost.is_empty() and not (await zombie_event("status",Ruby.FROST_IMPACT,boss.id)).is_empty(),
  "Ruby switches to a telegraphed Ice Burst with two Blades left")
 for row in game.model.enemies.values().duplicate():
  for attempt in 3:
   if not game.model.enemies.has(row.id):break
   runtime.damage_enemy(row.id,row.max_hp*2)
   for i in 2:await physics_frame
 for i in 6:await physics_frame
 check(get_meta(Ruby.SLAIN,{}).size()==10,"The run records all ten defeated enemies")
 check(not game.dungeon_boss_nearby(),"The camera can return to exploration framing after victory")
 await room(3351)
 await room(3350)
 await room(3352)
 await room(3350)
 await cave_exit("sokia_coast")
 var point_out=Tour.Regions.frame("sokia_coast")*map_position()
 check(point_out.distance_to(Vector2(349,261)*3)<.5,"Fengnu's House returns to its archived position")

func check_black_prayer_floors():
 var prayer=Tour.Prayer
 check(game.model.falan_floor==prayer.ENTRY,"The suspicious rock leads to original map 16507")
 for id:int in prayer.FLOORS:
  await room(id)
  var warp=prayer.stairs(id,game.model.seed_value)
  check(game.model.falan_floor==id,"Every Black Prayer floor is playable")
  for i in 4:await physics_frame
  var actors:Array=game.model.enemies.values()
  check(actors.size()==Tour.Prayer.PATROL_COUNT,"The maze uses 96 native Ghost and Bloody Blade patrols")
  check(actors.all(func(row):return row.has("black_prayer_slot") and row.skin in [1,2] and row.level>=20 and row.level<=23 and game.army_runtime.handles.has(row.id)),"Maze population retains original species and reference levels")
  check(not preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model).ruby_boss,"Maze escorts never acquire Ruby's boss abilities")
  var stairs=game.world.find_children("HabaruStair_*","Node3D",true,false)
  check(stairs.size()==2 and stairs.all(func(node):return node.get_meta("blue_cg_serial") in [17974,17975]),"Both original maze stair types have solid 3D geometry")
  var floor_=game.world.find_child("ArchivedRoomFloor",true,false)
  check(floor_!=null and floor_.material_override.get_shader_parameter("base_texture")==Tour.Indoor.RoomArt.PrayerArt.Floor,"Every floor uses recovered Black Prayer stone")
  if floor_!=null:
   var paint_size:Vector2=Tour.Indoor.RoomArt.PrayerArt.Floor.get_size()
   var tile=prayer.Data.GROUND_TILE-1
   var uvs:PackedVector2Array=floor_.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
   check(Array(uvs).all(func(uv):return Vector2i((uv*paint_size/36.0).floor())==Vector2i(tile%32,tile/32)),"Generated ground UVs select native 9555 rather than entrance tiles")
  var rocks=game.world.find_child("BlackPrayerNativeRockScatter",true,false)
  check(rocks!=null and rocks.get_meta("rock_count",0)>0,"Native grey rock silhouettes replace old scenery")
  if id==prayer.FLOORS[0]:
   var dead:Dictionary=actors[0]
   game.army_runtime.damage_enemy(dead.id,dead.max_hp*2)
   for i in 5:await physics_frame
   check(get_meta(prayer.SLAIN,{}).has(dead.black_prayer_slot),"Maze kills persist by floor and slot")
   check(get_meta(Ruby.SLAIN,{}).is_empty(),"Maze kills cannot unlock Ruby's reward rooms")
   var seed_:int=game.model.seed_value
   var before=prayer.walk_mask(id,seed_)
   await position_at(prayer.point(warp[1])+Vector2.LEFT*4.0)
   await walk_habaru_threshold(prayer.point(warp[1]),Vector2.RIGHT)
   check(game.model.falan_floor==prayer.FLOORS[1],"Kaz walks down the recovered 3D stairs")
   await position_at(prayer.point(prayer.stairs(prayer.FLOORS[1],game.model.seed_value)[0])+Vector2.UP*4.0)
   await walk_habaru_threshold(prayer.point(prayer.stairs(prayer.FLOORS[1],game.model.seed_value)[0]),Vector2.DOWN)
   check(game.model.falan_floor==id,"Kaz walks back up the recovered 3D stairs")
   for i in 4:await physics_frame
   check(game.model.enemies.size()==Tour.Prayer.PATROL_COUNT-1 and game.model.enemies.values().all(func(row):return row.black_prayer_slot!=dead.black_prayer_slot),"Backtracking does not resurrect a defeated patrol")
   check(prayer.walk_mask(id,game.model.seed_value)==before,"Backtracking preserves the same maze")
  if id in [prayer.FLOORS[0],prayer.FLOORS[2],prayer.FLOORS.back()] and DisplayServer.get_name()!="headless":
   var at=prayer.point(prayer.room_center(Vector2i(0,3)))
   await position_at(at)
   await shot("black-prayer-floor-"+str(prayer.FLOORS.find(id)+1),game.model.world_point(at+Vector2(5,5),7.3),game.model.world_point(at+Vector2(0,-1),1.3),85)

func room_locked_ruby():
 var door=game.model.get_meta("falan_links").filter(func(link):return link.get("floor")==3351)[0]
 await position_at(door.at)
 await walk_through_entry()
 check(game.model.falan_floor==Ruby.ROOM,"The reward rooms stay locked while Ruby's party lives")

func check_forest_grave():
 check_imur_mazes()
 await open_area("ghana_north_road")
 await site(Grave.ENTRY,"interior")
 if game.model.falan_floor!=Grave.ROOM:return
 check(game.world.find_child("SolidCaveCeiling",true,false)==null,"Imur Forest is open to the sky")
 check_single_floor()
 check_imur_walls(Grave.ROOM)
 check(game.model.enemies.is_empty(),"The graveyard encounter waits until the player approaches")
 game.tuning.invincible=true
 var at:Vector2=Tour.Regions.Sites.GRAVE_FORMATION[0]
 await position_at(at+Vector2(0,18))
 var runtime=game.army_runtime
 var first:Array=game.model.enemies.values()
 check(first.size()==3 and first.all(func(row):return runtime.handles.has(row.id)),"The ghost and both soldiers spawn through the native army")
 check(Grave.motions().variants.map(func(row):return int(row.id))==[101532,101114,107911,101205],"The two rounds use the original actors")
 if first.size()!=3:return
 var ghost:Dictionary=first.filter(func(row):return row.skin==0)[0]
 var ghost_point:Vector3=runtime.unit_state(runtime.handles[ghost.id]).position
 await position_at(Vector2(ghost_point.x,ghost_point.z+2.2)/game.model.falan_scale)
 runtime.record_events=true
 var seal:Dictionary=await zombie_event("status",Grave.MAGIC_SEAL,ghost.id)
 check(not seal.is_empty() and game.player.spell_loadout.magic_seal_left>0,"The first round seals spell casting")
 var exit=game.model.get_meta("falan_links").filter(func(link):return link.get("exit_id")==Grave.ROOM)[0]
 await position_at(exit.at)
 await walk_through_entry()
 check(game.model.falan_floor==Grave.ROOM,"The graveyard exit stays locked before the fight is cleared")
 for row in first:runtime.damage_enemy(row.id,row.max_hp*2)
 for i in 12:await physics_frame
 var second=game.model.enemies.values().filter(func(row):return row.get("skin")==2)
 check(second.size()==1 and game.model.enemies.values().filter(func(row):return row.get("skin")==3).size()==2,
  "Parukes and the rebels appear for the second round")
 if second.is_empty():return
 var boss:Dictionary=second[0]
 var handle:int=runtime.handles[boss.id]
 var point:Vector3=runtime.unit_state(handle).position
 if DisplayServer.get_name()!="headless":
  for i in 40:await physics_frame
  await shot("parukes-graveyard",point+Vector3(3,5,12),point+Vector3.UP*1.6,58)
 point=runtime.unit_state(handle).position
 await position_at(Vector2(point.x,point.z+2.2)/game.model.falan_scale)
 runtime.record_events=true
 runtime.damage_enemy(boss.id,200)
 game.player.invuln=0
 game.tuning.invincible=false
 var heal:Dictionary=await zombie_event("status",Zombie.HEAL,boss.id)
 check(not heal.is_empty() and heal.get("amount",0)>0,"Parukes recovers health from damage dealt by Life Drain")
 game.tuning.invincible=true
 runtime.damage_enemy(boss.id,boss.max_hp*.6)
 var quake:Dictionary=await zombie_event("status",Grave.EARTH_WARNING,boss.id)
 check(not quake.is_empty(),"Earth Rage gives a warning in the second round")
 var impact:Dictionary=await zombie_event("status",Grave.EARTH_IMPACT,boss.id)
 check(not impact.is_empty() and runtime.handles.has(boss.id),"Earth Rage resolves without sacrificing Parukes")
 var rebels=game.model.enemies.values().filter(func(row):return row.skin==3)
 if rebels.size()==2:
  var old_ids=rebels.map(func(row):return row.id)
  runtime.damage_enemy(rebels[0].id,rebels[0].max_hp*2)
  for i in 450:
   await physics_frame
   if game.model.enemies.values().any(func(row):return row.skin==3 and row.id not in old_ids):break
  check(game.model.enemies.values().any(func(row):return row.skin==3 and row.id not in old_ids and runtime.handles.has(row.id)),
   "Parukes replaces a fallen rebel through the native army lifecycle")
 runtime.damage_enemy(boss.id,boss.max_hp*2)
 for i in 5:await physics_frame
 check(get_meta(Grave.SLAIN,{}).has(3),"Parukes's defeat is recorded for the current run")
 if is_instance_valid(game.team_upgrade_picker):
  var progression=game.model.team_progression
  check(game.choose_team_upgrade(progression.offer[0],progression.choice_level()),"Choosing the victory upgrade resumes the run")
 await cave_exit("ghana_north_road",Grave.ROOM)
 var world=Tour.Regions.frame("ghana_north_road")*map_position()
 check(world.distance_to(Vector2(715,34)*3)<.5,"The fight returns to the original Ghana grave")

func check_imur_mazes():
 var maze=Tour.Indoor.Imur
 var all_masks={}
 for id in maze.FLOORS:
  var size:Vector2i=Tour.Indoor.floor_info(id)[0]
  for seed_ in [17,29,73]:
   var mask:PackedByteArray=maze.walk_mask(size,id,seed_)
   check(not all_masks.has(mask.hex_encode()),"Maze layout varies by floor and run seed")
   all_masks[mask.hex_encode()]=true
   var queue:Array[Vector2i]=[maze.ENTRY]
   var seen={}
   seen[maze.ENTRY]=true
   var cursor=0
   while cursor<queue.size():
    var cell=queue[cursor]
    cursor+=1
    for direction:Vector2i in maze.DIRECTIONS:
     var next=cell+direction
     if not seen.has(next) and Tour.Indoor.open_cell(mask,size,next.x,next.y):
      seen[next]=true
      queue.append(next)
   check(seen.has(maze.EXIT),"Each generated maze has a route to the exit")
   for z in size.y:
    for x in size.x:
     if Tour.Indoor.open_cell(mask,size,x,z):
      check(seen.has(Vector2i(x,z)),"Generated side paths connect to the entrance")

func check_imur_walls(id:int):
 var floor_=Tour.Indoor.floor_info(id)
 var size:Vector2i=floor_[0]
 var origin:Vector2=floor_[1]
 var bits=Tour.Indoor.walk_mask(id,size,floor_[2].hex_decode(),game.model.seed_value)
 size.y+=Tour.Indoor.GRAVE_MAZE_SIZE.y
 var space=game.player.get_world_3d().direct_space_state
 for z in range(36,size.y-1):
  for x in range(1,size.x-1):
   if not Tour.Indoor.open_cell(bits,size,x,z):continue
   for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
    var point=origin+Vector2(x,z)*3.0
    var start=Vector3(point.x,1.2,point.y)
    var end=start+Vector3(direction.x,0,direction.y)*3.0
    var ray=PhysicsRayQueryParameters3D.create(start*game.model.falan_scale,end*game.model.falan_scale,1)
    var clear=space.intersect_ray(ray).is_empty()
    check(clear==Tour.Indoor.open_cell(bits,size,x+direction.x,z+direction.y),
     "Maze collision follows the seeded passage grid")

func check_ghana_north():
 await open_area("ghana_road")
 await site(3000,"ghana")
 if Tour.area(game.model)!="ghana":return
 var north=game.model.get_meta("falan_links").filter(func(link):return link.get("area")=="ghana_north_road")
 check(north.size()==1,"Ghana has one North Gate exit")
 if north.is_empty():return
 check(north[0].at==Vector2(-6,-72) and road_connected(Vector2(-6,78),north[0].at,.55,false),
  "Village streets connect both original gates")
 await cave_exit("ghana_north_road")
 if Tour.area(game.model)!="ghana_north_road":return
 var frame=Tour.Regions.frame("ghana_north_road")
 var at=map_position()
 check((frame*at).distance_to(Vector2(704,95)*3)<.5,"North Gate lands on the original Sokia tile")
 var guard:Vector2=frame.inverse()*(Vector2(707,58)*3)
 var graves:Vector2=frame.inverse()*(Vector2(715,34)*3)
 check(road_connected(at,guard,.55),"The dry trail reaches the guard")
 check(road_connected(guard,graves,.55),"The dry trail continues to the original graves")
 var sprites=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(sprites) and sprites.get_child_count()==2 and sprites.get_child(0) is Sprite3D,
  "The original guard and grave graphics are present as silent sprites")
 await position_at(guard)
 await walk_through_entry()
 check(Tour.area(game.model)=="ghana_north_road","Interacting with the guard does not start dialogue or travel")
 if DisplayServer.get_name()!="headless":
  await shot("ghana-north-road",Vector3(69,28,-16),Vector3(15,7,-49),64)
 await position_at(graves+Vector2(0,9))
 Input.action_press("move_forward")
 for i in 90:
  await physics_frame
  if map_position().y<=graves.y+1.2:break
 Input.action_release("move_forward")
 check(map_position().y<=graves.y+1.2 and game.player.position.y>2.0,
  "Walking the narrow last stretch reaches the graves above the water")
 await site(3000,"ghana")
 check(map_position().distance_to(Vector2(-6,-69))<.5,
  "The North Gate enters on the archived village landing")
 await cave_exit("ghana_road")

func check_ghana():
 await open_area("ghana_road")
 var regions=Tour.Regions
 var gate:Vector2=regions.frame("ghana_road").inverse()*(Vector2(704,148)*3)
 var sites=regions.site_links("ghana_road")
 check(sites.size()==1 and sites[0].at==gate,"The original south gate is reachable from the Ghana road")
 await site(3000,"ghana")
 if Tour.area(game.model)!="ghana":return
 var entry=Vector2(-6,78)
 check(map_position().distance_to(entry)<.5,"The road enters at the archived village landing")
 village_entries(9)
 for link in game.model.get_meta("falan_links"):
  if link.to=="freyja_door":
   check(road_connected(entry,link.at,.55,false),"A walkable street leads to map "+str(link.floor))
 var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(npcs) and npcs.get_child_count()>=8,"Ghana keeps its original street NPC sprites")
 if DisplayServer.get_name()!="headless":
  await shot("ghana-village",Vector3(-24,34,87),Vector3(1,9,28),64)
 for id in [3001,3008,3010,3012,3020,3021,3804,3805,3806]:
  await room(id)
  if game.model.falan_floor!=id:return
  if id==3001:
   await room(3002)
   await room(3001)
  elif id==3010:
   var nurses=game.world.find_child("OriginalFalanNPCs",true,false)
   check(is_instance_valid(nurses) and nurses.get_child_count()==2,"The hospital keeps both original nurses")
   if is_instance_valid(nurses):
    var nurse=nurses.get_child(0).global_position
    await position_at(Vector2(nurse.x,nurse.z)/game.model.falan_scale)
    await walk_through_entry()
    check(game.model.falan_floor==3010,"The original nurse stays silent")
   if DisplayServer.get_name()!="headless":
    await shot("ghana-hospital",Vector3(-13,3.4,0),Vector3(7,1.6,3),65)
  elif id==3012:
   for inner in [3013,3014,3099]:
    await room(inner)
    await room(3012)
  await room(3000)
  if Tour.area(game.model)!="ghana":return
  if id==3806:
   check(map_position().distance_to(Vector2(-42,42))<.5,"The west residence returns to its archived landing")
 await cave_exit("ghana_road")
 check(map_position().distance_to(gate)<.5,"The south gate returns to the original Sokia road tile")
 await site(3000,"ghana")

func check_kili_coast_road():
 game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 await open_area("sokia_coast")
 var regions=Tour.Regions
 var data=Entrances.UNDERSEA_MOUTHS
 var frame=regions.frame("sokia_coast")
 var path:Array=data.KILI_ROAD
 check(path.front()==Vector2i(240,265) and path.back()==Vector2i(274,294),"The route joins the original cave and Kili gate cells")
 await position_at(frame.inverse()*(Vector2(path[1])*3.0))
 for i in range(2,path.size()):
  var target=frame.inverse()*(Vector2(path[i])*3.0)
  for step in 75:
   if Tour.area(game.model)!="sokia_coast" or map_position().distance_to(target)<.22:break
   var direction=(target-map_position()).normalized()
   game.camera_rig.yaw=atan2(-direction.x,-direction.y)
   Input.action_press("move_forward")
   await physics_frame
  Input.action_release("move_forward")
  check(Tour.area(game.model)=="kili" or map_position().distance_to(target)<.30,"Kaz walks the original route cell "+str(path[i]))
  if errors:return
  if i in [18,39] and DisplayServer.get_name()!="headless":
   var point:Vector3=game.player.position
   await shot("Kili Coast Road/route-"+str(i),point+Vector3(24,25,27),point+Vector3.UP*2,65)
 if Tour.area(game.model)=="sokia_coast":
  Input.action_press("move_forward")
  for step in 12:await physics_frame
  Input.action_release("move_forward")
 check(Tour.area(game.model)=="kili","Walking the full road crosses into Kili without F")
 if Tour.area(game.model)!="kili":return
 check_coastal_village("kili")
 check(game.camera_rig.yaw>2.8 or game.camera_rig.yaw< -2.8,"The gate preserves the forward-facing camera")
 if DisplayServer.get_name()!="headless":
  var point:Vector3=game.player.position
  await shot("Kili Coast Road/kili-gate",point+Vector3(16,16,-23),point+Vector3(0,2,15),65)
  await shot("Kili Coast Road/kili-village",game.model.world_point(Vector2(-40,-18))+Vector3(90,125,92),game.model.world_point(Vector2(-40,-18)),60)
 await walk_habaru_threshold(regions.KILI_EAST_GATE,Vector2.RIGHT)
 check(Tour.area(game.model)=="sokia_coast","Kili's east columns open onto Sokia without F")
 if Tour.area(game.model)!="sokia_coast":return
 var east_gate:Vector2=regions.KILI_EAST_GATE+regions.KILI_TO_ROAD
 if DisplayServer.get_name()!="headless":
  var point:Vector3=game.model.world_point(east_gate)
  await shot("Kili Coast Road/kili-east-gate",point+Vector3(21,17,21),point+Vector3(-8,3,0),65)
 await walk_habaru_threshold(east_gate,Vector2.LEFT)
 check(Tour.area(game.model)=="kili","The east crossing preserves the same village on return")
 if Tour.area(game.model)!="kili":return
 await walk_habaru_threshold(regions.KILI_GATE,Vector2.UP)
 check(Tour.area(game.model)=="sokia_coast","The same gap returns to the coast without F")
 if Tour.area(game.model)=="sokia_coast":
  check((frame*map_position()).distance_to(Vector2(274,293)*3)<6,"The return lands on the original road beside the gate")
 await open_area("venoa")
 check_coastal_village("venoa")
 if DisplayServer.get_name()!="headless":
  await shot("Kili Coast Road/venoa-village",Vector3(87,125,100),Vector3(-15,7,-4),60)

func check_coastal_village(area:String):
 var source=Entrances.Villages.SOURCE
 var expected=source.BUILDINGS[area]
 var buildings=game.model.falan_frontier_plan.filter(func(row):return row[0]!="coastal_wall")
 check(buildings.size()==expected.size(),"Every original building footprint is present in "+area)
 for row in expected:
  check(buildings.any(func(b):return Vector2(b[1].origin.x,b[1].origin.z).is_equal_approx(row[1])),"Original building cell retained: "+str(row[4]))
 var details=game.world.find_child("FreyjaDestinationEntrances",true,false)
 check(details!=null and details.get_meta("coastal_village_scenery")==source.SCENERY[area].size(),"The full original village scenery is included")
 var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
 check(npcs!=null and npcs.get_child_count()>0,"Original 2D villagers remain")
 var water=game.world.find_child("FreyjaWater",true,false)
 check(water.material_override.get_shader_parameter("freyja_ground_index")==load("res://assets/maps/falan/"+area+"_ground_index.png"),"The village uses its own source water and ground grid")

func check_kili():
 await open_area("sokia_coast")
 var regions=Tour.Regions
 var frame=regions.frame("sokia_coast")
 var sites=regions.site_links("sokia_coast")
 var gates=sites.filter(func(link):return link.site==3200)
 check(gates.size()==2,"Kili has both original coastal entrances")
 if gates.size()!=2:return
 var cave=sites.filter(func(link):return link.site==15004)[0]
 check((frame*gates[0].at)==Vector2(274,294)*3 and road_connected(cave.at,gates[0].at),"The Sokia cave road reaches Kili's exact west entrance")
 check(road_connected(gates[0].at,gates[1].at),"The coastal road connects both Kili gates")
 await site(3200,"kili")
 if Tour.area(game.model)!="kili":return
 village_entries(10)
 check(Entrances.Villages.SOURCE.SCENERY.kili.filter(func(row):return row[1] in range(11188,11209)).size()>5,"Kili retains palms from the archived scenery")
 var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(npcs) and npcs.get_child_count()>=3,"Original street NPCs remain as silent 2D sprites")
 if DisplayServer.get_name()!="headless":
  await shot("kili-village",Vector3(-53,21,-86),Vector3(-53,7,-40),65)
 if "--coastal-kili" in OS.get_cmdline_user_args():await coastal_exterior_preview("kili")
 for id in [3201,3208,3210,3212,3220,3221,3801,3802,3803,3807]:
  await room(id)
  if game.model.falan_floor!=id:return
  if id==3201:
   await room(3202)
   await room(3201)
  elif id==3210:
   var nurses=game.world.find_child("OriginalFalanNPCs",true,false)
   check(is_instance_valid(nurses) and nurses.get_child_count()>=4,"The hospital keeps its original staff")
   if DisplayServer.get_name()!="headless":
    await shot("kili-hospital",Vector3(-13,6,1),Vector3(5,1.5,4),67)
  elif id==3212:
   await room(3213)
   await room(3212)
   await room(3214)
   await room(3299)
   await room(3214)
   await room(3212)
  await room(3200)
  if Tour.area(game.model)!="kili":return
 var exits=game.model.get_meta("falan_links").filter(func(link):return link.to=="freyja_outside")
 check(exits.size()==2,"The village offers both return gates")
 if exits.size()!=2:return
 await walk_habaru_threshold(exits[1].at,Vector2.RIGHT)
 check(Tour.area(game.model)=="sokia_coast" and (frame*map_position()).distance_to(Vector2(294,325)*3)<2,
  "East Gate returns to the original Sokia road")
 await walk_habaru_threshold(gates[1].at,Vector2.LEFT)
 check(Tour.area(game.model)=="kili","The East Gate reenters the same village")
 await walk_habaru_threshold(regions.KILI_GATE,Vector2.UP)
 check(Tour.area(game.model)=="sokia_coast" and (frame*map_position()).distance_to(Vector2(274,293)*3)<6,
  "West Gate returns to the original trailhead")

func check_dungeon_entrances():
 game.tuning.invincible=true
 var shots={
  "south_gate":[Vector2i(471,317),Vector2(1,.65),"venoa-falan-mouth"],
  "south_lakes":[Vector2i(442,349),Vector2(.35,1),"venoa-village-mouth"],
  "east_coast":[Vector2i(672,223),Vector2(-1,.20),"habaru-il-mouth"],
  "sokia_coast":[Vector2i(356,334),Vector2(-1,.15),"great-wind-west-mouth"],
  "north_coast":[Vector2i(541,39),Vector2(.40,1),"zombie-diamond-mouth"],
 }
 var count=0
 for area in Entrances.Archive.SCENERY:
  if Tour.Regions.GATE_FRAMES.has(area):
   Tour.travel(game,Tour.outdoor_layout(get_meta("falan_venture"),area),{"arrival":Vector2(0,28),"yaw":0.0,"velocity":Vector3.ZERO})
   for i in 4:await physics_frame
  else:
   await open_area(area)
  var cliff=game.world.find_child("ArchivedCliffForms",true,false)
  check(cliff is MeshInstance3D,"Archive rock forms render in "+area)
  var mouths=game.world.find_child("RecessedCaveMouths",true,false)
  var archive_mouths:Dictionary=Entrances.Archive.MOUTHS.get(area,{})
  check(is_instance_valid(mouths)==not archive_mouths.is_empty(),"Only natural cave mouths get openings in "+area)
  var frame=Tour.Regions.frame(area)
  for link in Tour.Regions.site_links(area):
   if link.kind not in ["cave","stairs","diamond"]:continue
   count+=1
   var at:Vector3=game.model.world_point(link.at)
   var query=PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.3,at+Vector3.UP*.15,1)
   var hit:Dictionary=game.world.get_world_3d().direct_space_state.intersect_ray(query)
   check(hit.is_empty(),"A player can reach the original warp tile at "+link.title)
  if DisplayServer.get_name()=="headless" or not shots.has(area):continue
  var capture:Array=shots[area]
  var at=frame.inverse()*(Vector2(capture[0])*3.0)
  var point:Vector3=game.model.world_point(at)
  var look:Vector2=frame.inverse().basis_xform(capture[1]).normalized()
  await position_at(at)
  await shot("Dungeon Entrances/"+capture[2],point+Vector3(look.x*14,6,look.y*14),point+Vector3.UP*3.8,68)
 check(count==23,"Every original outdoor dungeon entrance is covered")

func check_venoa_cave():
 game.tuning.invincible=true
 await open_area("south_gate")
 var entrance=Tour.Regions.site_links("south_gate").filter(func(link):return link.site==11000)[0]
 check(Tour.Regions.frame("south_gate")*entrance.at==Vector2(471,317)*3,"The Falan mouth occupies its archived outdoor cell")
 await site(11000,"interior")
 check(game.model.falan_floor==11000,"The Falan entrance opens on B1, not B2")
 if game.model.falan_floor!=11000:return
 await check_venoa_floor(32,2)
 await walk_habaru_link("floor",11001)
 await check_venoa_floor(40,0)
 await check_venoa_boss()
 await walk_habaru_link("floor",11002)
 await check_venoa_floor(32,1)
 await walk_habaru_link("exit_id",11002)
 check(Tour.area(game.model)=="south_lakes","The three-floor cave exits onto the village road")
 if Tour.area(game.model)!="south_lakes":return
 var links=Tour.Regions.site_links("south_lakes")
 var cave=links.filter(func(link):return link.site==11002)[0]
 var village=links.filter(func(link):return link.site==2100)[0]
 check((Tour.Regions.frame("south_lakes")*map_position()).distance_to(Vector2(442,349)*3)<.5,"The village-side exit uses the original Freyja warp")
 check(road_connected(cave.at,village.at,.55),"A dry road connects the cave exit to Venoa Village")
 await site(2100,"venoa")
 await leave_village("south_lakes")
 await site(11002,"interior")
 check(game.model.falan_floor==11002,"Reentry from the village returns to the final B1")
 await walk_habaru_link("floor",11001)
 check_venoa_pack(40)
 check(game.model.enemies.values().all(func(row):return row.skin!=Habaru.VENOA_BOSS_SKIN),"The defeated Great Bear stays down across floor changes")
 await walk_habaru_link("floor",11000)
 await check_venoa_floor(32,2)
 # The archived miner gate joins two disconnected pockets on this same map.
 await room(11000,0)
 await walk_habaru_link("floor",11022)
 await check_venoa_floor(0,0)
 await walk_habaru_link("floor",11002)
 await walk_habaru_link("floor",11022)
 await walk_habaru_link("floor",11000)
 await room(11000,1)
 await walk_habaru_link("exit_id",11000)
 check(Tour.area(game.model)=="south_gate","The miners' shortcut and the full cave both return to Falan on foot")

func check_venoa_floor(bears:int,npcs:int):
 var id:int=game.model.falan_floor
 var indoor=Tour.Indoor
 var info=indoor.floor_info(id)
 var bits:PackedByteArray=info[2].hex_decode()
 check(indoor.walk_mask(id,info[0],bits.duplicate(),game.model.seed_value)==bits,"Every Venoa tile retains archived collision on "+str(id))
 check_venoa_roof()
 check_venoa_pack(bears)
 var actors=game.world.find_child("OriginalFalanNPCs",true,false)
 check((actors.get_child_count() if is_instance_valid(actors) else 0)==npcs,"The original miners and sign retain their own floor: "+str(id))
 var stairs=indoor.RoomArt.Data.FREYJA_STAIRS[id]
 for row in stairs:
  var node=game.world.map_features.get_node_or_null("HabaruStair_%d_%d"%[row[0].x,row[0].y])
  check(node!=null and node.get_meta("blue_cg_serial")==row[1],"Each original Venoa stair is rendered once: "+str(row[0]))
 if DisplayServer.get_name()!="headless":
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"Venoa Restoration"))
  var entry:Vector3=game.player.position
  await shot("Venoa Restoration/floor-%d"%id,entry+Vector3(3,5.5,8),entry+Vector3(-1,2,-8),67)

func check_venoa_boss():
 check_archived_arena()
 var runtime=game.army_runtime
 var bosses=game.model.enemies.values().filter(func(row):return row.get("skin")==Habaru.VENOA_BOSS_SKIN)
 check(bosses.size()==1,"The deepest floor has one Great Bear alongside the patrols")
 if bosses.is_empty():return
 var boss:Dictionary=bosses[0]
 var variant:Dictionary=Habaru.motions().variants[Habaru.VENOA_BOSS_SKIN]
 check(variant.id==101010 and variant.standing_height>4.0 and boss.hp>800.0,"The boss uses the original bear at larger scale and boss health")
 check(runtime.handles.has(boss.id) and runtime.enemy_target(boss.id).local_combat_box().is_equal_approx(Dimensions.body(Habaru,Habaru.VENOA_BOSS_SKIN)),
  "The Great Bear uses the native combat lifecycle and enlarged hitbox")
 var at:Vector3=runtime.unit_state(runtime.handles[boss.id]).position
 await position_at(Tour.Indoor.safe_point(11001,Vector2(at.x,at.z+3)/game.model.falan_scale))
 if DisplayServer.get_name()!="headless":
  game.player.hide()
  await shot("Cave Interiors/venoa-great-bear",at+Vector3(1.1,3.25,10),at+Vector3.UP*1.9,62)
  game.player.show()
 game.player.invuln=0
 var normal_hp:float=game.player.hp
 var normal_max_hp:float=game.player.max_hp
 game.player.max_hp=5000
 game.player.hp=game.player.max_hp
 game.tuning.invincible=false
 runtime.record_events=true
 runtime.event_log.clear()
 var hp:float=game.player.hp
 for i in 140:
  await physics_frame
  if runtime.event_log.any(func(e):return e.kind=="external_damage" and e.source_id==boss.id and e.amount>0):break
 check(game.player.hp<hp and runtime.event_log.any(func(e):return e.kind=="external_damage" and e.source_id==boss.id and e.amount>0),
  "The Great Bear's original swing deals damage")
 runtime.record_events=false
 game.tuning.invincible=true
 game.player.max_hp=normal_max_hp
 game.player.hp=normal_hp
 runtime.damage_enemy(boss.id,boss.max_hp*2)
 for i in 8:await physics_frame
 check(not runtime.handles.has(boss.id) and get_meta(Habaru.VENOA_SLAIN,{}).has(boss.venoa_bear_slot),
  "Defeating the boss retires its native unit for this run")

func check_sokia_coast(venoa_exit:Vector2,village:Vector2):
 var regions=Tour.Regions
 var sites=regions.site_links("south_lakes")
 var mouth=sites.filter(func(link):return link.site==15005)
 check(mouth.size()==1,"The south road reaches the original Sokia cave entrance")
 if mouth.is_empty():return
 check(road_connected(venoa_exit,mouth[0].at) and road_connected(village,mouth[0].at),
  "The continuation shares a dry road with Venoa Village and the bear cave")
 await site(15005,"interior")
 if game.model.falan_floor!=15003:return
 check_venoa_roof()
 check_single_floor([Ruby.ROOM])
 var guards=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(guards) and guards.get_child_count()>=2,"The original guards remain as silent sprites")
 await cave_exit("sokia_coast")
 if Tour.area(game.model)!="sokia_coast":return
 var arrival=map_position()
 var frame=regions.frame("sokia_coast")
 check((frame*arrival).distance_to(Vector2(240,265)*3)<.5,"The cave exits at the original Sokia coordinates")
 var trailhead:Vector2=frame.inverse()*regions.Data.KILI_TRAILHEAD
 check(road_connected(arrival,trailhead),"The Sokia landing has a dry road to Kili's west trailhead")
 var ground=Vector3(trailhead.x,game.model.surface_height(trailhead.x,trailhead.y),trailhead.y)
 check(game.model.terrain.disk_clear(ground,.7),"Kili's trailhead is on walkable land")
 if DisplayServer.get_name()!="headless":
  await shot("sokia-coast",game.player.position+Vector3(-12,11,-10),ground+Vector3.UP,65)
 await site(15004,"interior")

 await cave_exit("south_lakes")
 check(map_position().distance_to(mouth[0].at)<.5,"The Sokia route returns to the same Freyja road")

func check_venoa_pack(count:int):
 var bears:Array=game.model.enemies.values().filter(func(row):return row.get("skin")!=Habaru.VENOA_BOSS_SKIN)
 var native_bears=bears.filter(func(row):
  return row.get("skin")==Habaru.VENOA_BEAR_SKIN and row.has("venoa_bear_slot") and game.army_runtime.handles.has(row.id))
 check(bears.size()==count and native_bears.size()==count,"The room has "+str(count)+" native Cave Bears")
 if bears.is_empty():return
 check(Habaru.motions().variants[Habaru.VENOA_BEAR_SKIN].id==101010 and game.army_runtime.enemy_target(bears[0].id).local_combat_box().is_equal_approx(Dimensions.body(Habaru,Habaru.VENOA_BEAR_SKIN)),
  "The Venoa bear uses the original sprite and fitted cave bear hitbox")

func check_archived_arena():
 var indoor=Tour.Indoor
 var id:int=game.model.falan_floor
 var arena:Rect2i=indoor.RoomArt.BossProps.ARENAS[id]
 var info=indoor.floor_info(id)
 var size:Vector2i=info[0]
 var original:PackedByteArray=info[2].hex_decode()
 var mask=indoor.walk_mask(id,size,original.duplicate(),game.model.seed_value)
 var matches=true
 for z in range(arena.position.y,arena.end.y):
  for x in range(arena.position.x,arena.end.x):
   if indoor.open_cell(mask,size,x,z)!=indoor.open_cell(original,size,x,z):matches=false
 var exact_habaru=id in Tour.Dungeons.HABARU_FLOORS+Tour.Dungeons.VENOA_FLOORS
 check(matches and ((mask==original)==exact_habaru),"The arena uses the expected archived walk grid")
 var props=game.world.find_child("ArchivedBossProps",true,false)
 var count=0
 if is_instance_valid(props):
  for child in props.get_children():count+=int(child.get_meta("archived_placements",1))
 var stairs=indoor.RoomArt.Data.FREYJA_STAIRS.get(id,[])
 for row in indoor.RoomArt.BossProps.PLACEMENTS[id]:
  if stairs.any(func(stair):return stair[0]==row[0] and stair[1]==row[1]):count+=1
 check(count==indoor.RoomArt.BossProps.PLACEMENTS[id].size(),
  "All recovered arena objects are present, with stairs represented once in 3D")

func check_kaz_clearance(from:Vector2,to:Vector2,message:String):
 var pose:Transform3D=game.player.global_transform
 pose.origin=game.model.world_point(from,.32)
 check(not game.player.test_move(pose,game.model.world_point(to,.32)-pose.origin),message)

func check_single_floor(annexes:Array=[]):
 var id:int=game.model.falan_floor
 var info=Tour.Indoor.floor_info(id)
 var size:Vector2i=info[0]
 var origin:Vector2=info[1]
 var mask=Tour.Indoor.walk_mask(id,size,info[2].hex_decode(),game.model.seed_value)
 if id==Grave.ROOM:size.y+=Tour.Indoor.GRAVE_MAZE_SIZE.y
 var start=Vector2i(((map_position()-origin)/3.0).round())
 var queue:Array[Vector2i]=[start]
 var reached={start:true}
 var cursor=0
 while cursor<queue.size():
  var cell=queue[cursor]
  cursor+=1
  for direction:Vector2i in Tour.Indoor.Imur.DIRECTIONS:
   var next=cell+direction
   if reached.has(next) or not Tour.Indoor.open_cell(mask,size,next.x,next.y):continue
   reached[next]=true
   queue.append(next)
 for link in game.model.get_meta("falan_links",[]):
  if link.to=="freyja_door":check(link.floor in annexes,"No stairs lead to another dungeon floor")
  var tile=Vector2i(((link.at-origin)/3.0).round())
  check(reached.has(tile),"All doors are reachable on the same floor")

func cave_exit(area:String,exit_id:int=-1):
 var exits=game.model.get_meta("falan_links").filter(func(link):return link.to=="freyja_outside" and link.area==area and (exit_id==-1 or link.get("exit_id")==exit_id))
 check(exits.size()==1,"The archived cave exit is available")
 if exits.is_empty():return
 await position_at(exits[0].at)
 await walk_through_entry()
 check(Tour.area(game.model)==Tour.Regions.canonical_area(area),"The cave exit returns to "+area)

func check_venoa_roof():
 var roof=game.world.find_child("SolidCaveCeiling",true,false)
 check(roof is MeshInstance3D,"This dungeon floor has a solid ceiling")
 if not roof is MeshInstance3D:return
 var size:Vector2i=Tour.Indoor.floor_info(game.model.falan_floor)[0]
 var bounds:AABB=roof.mesh.get_aabb()
 check(is_equal_approx(bounds.size.x,size.x*3.0) and is_equal_approx(bounds.size.z,size.y*3.0),"The roof covers the entire archived floor footprint")
 if Tour.Indoor.CAVE_ROCK.has(game.model.falan_floor):
  var walls=game.world.find_child("ArchivedCaveRockWalls",true,false)
  check(walls is MeshInstance3D and walls.mesh.get_surface_count()>0,"The cave has rendered stone around its original paths")
  check(bounds.position.y>=Tour.Indoor.CEILING_HEIGHT and bounds.size.y>.75,"Roof relief stays above the original headroom")
 var at=game.player.position
 var scale_:float=game.model.falan_scale
 var height:float=Tour.Indoor.CEILING_HEIGHT*scale_
 var probe=PhysicsRayQueryParameters3D.create(Vector3(at.x,height-1,at.z),Vector3(at.x,height+1,at.z),1)
 var hit=game.world.get_world_3d().direct_space_state.intersect_ray(probe)
 check(not hit.is_empty() and hit.collider.name=="SolidCaveCeilingCollision" and hit.position.y>10.9,"The rock ceiling has collision at roughly 11 m")
 var original_pitch:float=game.camera_rig.pitch
 game.camera_rig.pitch=1.15
 game.camera_rig.update_camera(.15)
 check(game.camera_rig.camera.global_position.y<height,"The active camera stays below the ceiling")
 game.camera_rig.pitch=original_pitch
 game.camera_rig.update_camera(.15)

func check_venoa():
 var regions=Tour.Regions
 var venture:Dictionary=get_meta("falan_venture")
 Tour.travel(game,venture.falan_areas.south_gate,{"arrival":Vector2(54,444),"yaw":PI,"velocity":Vector3.ZERO})
 await position_at(Vector2(54,444))
 await position_at(Vector2(54,450))
 check(Tour.area(game.model)=="south_lakes","Walking past the South Gate continues onto the southern road")
 if Tour.area(game.model)!="south_lakes":return
 var sites=regions.site_links("south_lakes").filter(func(link):return link.site==2100)
 check(sites.size()==1,"The original Venoa entrance is on the south road")
 if sites.is_empty():return
 var at=map_position()
 check(road_connected(at,sites[0].at),"A dry mapped road links the South Gate to Venoa")
 await site(2100,"venoa")
 if Tour.area(game.model)!="venoa":return
 village_entries(6)
 var villagers=game.world.find_child("OriginalFalanNPCs",true,false)
 check(is_instance_valid(villagers) and villagers.get_child_count()>=12,"Venoa's original static NPC sprites are present")
 if DisplayServer.get_name()!="headless":
  await shot("venoa-village",Vector3(22,67,66),Vector3(-15,6,-2),63)
 if "--coastal-venoa" in OS.get_cmdline_user_args():await coastal_exterior_preview("venoa")
 await room(2101)
 await room(2100)
 await room(2101,1)
 await room(2100,2)
 await room(2110)
 await room(2111)
 await room(2110)
 await room(2100)
 await room(2120)
 await room(2100)
 await room(2121)
 await room(2100)
 await room(2112)
 if DisplayServer.get_name()!="headless":
  await shot("venoa-chief-house",Vector3(12,19,25),Vector3(-6,0,1),59)
 await room(2198)
 await room(2113)
 await room(2198)
 await room(2199)
 check(game.world.find_child("ArchiveCrescent",true,false)!=null,"The original teleport room monuments render")
 await room(2198)
 await room(2112)
 await room(2100)
 await walk_habaru_threshold(regions.VENOA_GATE,Vector2.RIGHT)
 check(Tour.area(game.model)=="south_lakes","Venoa's original gate returns to the road without F")
 check((regions.frame("south_lakes")*map_position()).distance_to(Vector2(331,481)*3)<1.0,
  "Returning from Venoa lands at its original outbound warp (331,481)")

func check_ceiling():
 var roof=game.world.find_child("HabaruRockCeiling",true,false)
 check(roof is MeshInstance3D and roof.mesh.get_aabb().position.y>=Tour.Indoor.CEILING_HEIGHT,"A rock ceiling covers the archived cave")
 if not roof is MeshInstance3D:return
 check(game.world.find_child("HabaruCeilingCollision",true,false) is StaticBody3D,"The closed ceiling has collision")
 check(roof.material_override.get_shader_parameter("canopy_cutaway")==null,"The ceiling never uses a cutaway")
 var pitch:float=game.camera_rig.pitch
 game.camera_rig.pitch=1.15
 game.camera_rig.update_camera(.15)
 check(game.camera_rig.camera.global_position.y<Tour.Indoor.CEILING_HEIGHT*game.model.falan_scale,"The normal camera stays below the ceiling even when pitched high")
 game.camera_rig.pitch=pitch

func road_connected(from:Vector2,to:Vector2,clearance:float=0.0,road_only:bool=true)->bool:
 if Entrances.Sokia.owns(Tour.area(game.model)):road_only=false
 var terrain=game.model.terrain
 var image:Image=terrain.mask_texture().get_image()
 var origin:Vector2=terrain.mask_origin()
 var start=Vector2i(((from-origin)/3.0).round())
 var goal=Vector2i(((to-origin)/3.0).round())
 var queue:Array[Vector2i]=[start]
 var visited={start:true}
 var bounds=Rect2i(Vector2i.ZERO,image.get_size())
 var index=0
 while index<queue.size():
  var at=queue[index]
  index+=1
  if at==goal:return true
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next:Vector2i=at+step
   if visited.has(next) or not bounds.has_point(next):continue
   var tile=image.get_pixelv(next)
   if tile.r>.5 or (tile.g<.56 if road_only else tile.b>.98):continue
   if clearance>0.0:
    var p=origin+Vector2(next)*3.0
    var at_world=Vector3(p.x,game.model.surface_height(p.x,p.y)+.15,p.y)
    if not terrain.disk_clear(at_world,clearance) or game.model.scenery_obstacles.values().any(func(box):return box.grow(clearance).has_point(at_world)):continue
   visited[next]=true
   queue.append(next)
 return false

func open_area(name_:String):
 var regions=Tour.Regions
 Tour.travel(game,regions.layout(name_),{"arrival":regions.entry_point(name_),"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame

func village_world(at:Vector3,village:String)->Vector3:
 var placement=Tour.Regions.village_transform(village)
 var p=placement*Vector2(at.x,at.z)
 return Vector3(p.x,at.y,p.y)*game.model.falan_scale

func site(id:int,area:String):
 if area in ["il_village","alyut"]:
  var before=game.model
  var placement=Tour.Regions.village_transform(area)
  await position_at(placement*Tour.Regions.entry_point(area))
  check(game.model==before and Tour.area(game.model)==Tour.Regions.canonical_area(area),"The village shares its surrounding outdoor map")
  return
 var links=Tour.Regions.site_links(Tour.area(game.model)).filter(func(l):return l.site==id)
 check(not links.is_empty(),"Outdoor road leads to village "+area)
 if links.is_empty():return
 await position_at(links[0].at)
 if Tour.area(game.model)!=area:await walk_through_entry()
 check(Tour.area(game.model)==area,"The village loads from the saved road")

func leave_village(area:String):
 if Tour.Regions.CONNECTED_VILLAGES.has(Tour.area(game.model)):
  var village:String=Tour.Regions.CONNECTED_VILLAGES[Tour.area(game.model)]
  var gate=Tour.Regions.IL_GATE+Vector2(6,0) if village=="il_village" else Tour.Regions.ALYUT_SOUTH_GATE+Vector2(0,6)
  var before=game.model
  await position_at(Tour.Regions.village_transform(village)*gate)
  check(game.model==before and Tour.area(game.model)==Tour.Regions.canonical_area(area),"Leaving the village retains the same outdoor map")
  return
 var links=game.model.get_meta("falan_links").filter(func(l):return l.to=="freyja_return")
 check(links.size()==1,"The village retains its original outdoor return")
 if links.is_empty():return
 var inside=Tour.area(game.model)
 await position_at(links[0].at)
 if Tour.area(game.model)==inside:await walk_through_entry()
 check(Tour.area(game.model)==Tour.Regions.canonical_area(area),"The village returns to the original branch")

func village_entries(expected:int):
 var links=game.model.get_meta("falan_links").filter(func(l):return l.to=="freyja_door")
 check(links.size()==expected,"All original building entrances are available")
 for link in links:
  var at:Vector2=link.at
  var pos=Vector3(at.x,game.model.surface_height(at.x,at.y)+.15,at.y)
  check(game.model.terrain.disk_clear(pos,.55),"Village entrance has dry access for map "+str(link.floor))
  check(not game.model.scenery_obstacles.values().any(func(box):return box.grow(.55).has_point(pos+Vector3.UP*.4)),"The building does not block entrance "+str(link.floor))

func room(id:int,index:int=0):
 var links=game.model.get_meta("falan_links").filter(func(l):return l.get("floor")==id)
 check(links.size()>index,"A live door leads to map "+str(id))
 if links.size()<=index:return
 var at:Vector2=links[index].at
 var coastal="--coastal-kili" in OS.get_cmdline_user_args() or "--coastal-venoa" in OS.get_cmdline_user_args() or "--kili-houses" in OS.get_cmdline_user_args()
 if coastal:check(links[index].get("walk_in",false),"Original room link opens without F: "+str(id))
 var hp:float=game.player.hp
 if coastal:
  var direction=Vector2.ZERO
  for candidate in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
   var approach=at-candidate*3.8
   var p=Vector3(approach.x,0,approach.y)
   if game.model.terrain.disk_clear(p,.65) and not game.model.scenery_obstacles.values().any(func(box):return box.grow(.65).has_point(p)):
    direction=candidate
    break
  check(direction!=Vector2.ZERO,"Room has a walkable approach: "+str(id))
  if direction!=Vector2.ZERO:await walk_habaru_threshold(at,direction)
  for i in 12:await physics_frame
 else:
  var before=game.model
  await position_at(at)
  if game.model==before:await walk_through_entry()
 var village=Tour.Regions.village_area(id)
 check(Tour.area(game.model)==("interior" if village.is_empty() else Tour.Regions.canonical_area(village)) and (not village.is_empty() or game.model.falan_floor==id),"Original door enters or returns to map "+str(id))
 check(game.player.hp==hp,"Door preserves run health")
 if game.model.falan_floor==id:
  check(game.world.find_child("ArchivedRoomFloor",true,false)!=null,"Archived floor renders for "+str(id))
  if coastal:await check_coastal_room(id)
 print("FREYJA_ROOM ",id)

func check_coastal_room(id:int):
 var source=Tour.Indoor.RoomArt.Coastal.Data.ROOMS[id]
 var houses={3801:[Vector2(12,16),Vector2(56,86),92],3802:[Vector2(3,9),Vector2(69,89),65],3803:[Vector2(10,16),Vector2(38,58),70],3807:[Vector2(2,11),Vector2(37,70),92]}
 if houses.has(id):
  var expected:Array=houses[id]
  var exits=game.model.get_meta("falan_links").filter(func(link):return link.get("floor")==3200)
  check(exits.size()==1 and exits[0].at==(expected[0]-Vector2(10,10))*3,"Recovered house uses its original exit tile: "+str(id))
  check(exits.size()==1 and exits[0].arrival==(expected[1]-Vector2(75,75))*3,"House returns to its original Kili tile: "+str(id))
  check(source.size()==expected[2],"Every recovered wall and furnishing is included: "+str(id))
 var props=game.world.find_child("ArchivedCoastalFurnishings",true,false)
 check(props!=null and props.get_parent().get_meta("coastal_source_objects",0)==source.size(),"All original objects are placed in room "+str(id))
 check(game.world.find_child("ArchivedRoomWalls",true,false)==null,"Original wall objects replace generic walls")
 var npcs=game.world.find_child("OriginalFalanNPCs",true,false)
 var original:Array=Tour.VillageNPCs.AREAS.get(str(id),[])
 check((npcs.get_child_count() if npcs else 0)==original.size(),"Original room NPC count retained: "+str(id))
 for node in props.get_children():
  var serial=node.get_meta("source_graphic")
  check(node.multimesh.instance_count==source.filter(func(row):return row[3]==serial).size(),"Original count retained for graphic "+str(serial))
 if DisplayServer.get_name()!="headless" and id in [3201,3208,3210,3214,3299,2110,2112,2121,2199,3801,3802,3803,3807]:
  var info=Tour.Indoor.floor_info(id)
  var center:Vector2=info[1]+Vector2(info[0]-Vector2i.ONE)*1.5
  var point:Vector3=game.model.world_point(center)
  var distance=maxf(info[0].x,info[0].y)*2.3*game.model.falan_scale
  var folder="Kili Original Houses" if id in [3801,3802,3803,3807] else "Coastal Village Rooms"
  await shot(folder+"/room-"+str(id),point+Vector3(-distance*.45,distance*.82,distance*.60),point,58)

func coastal_exterior_preview(area:String):
 check_coastal_village(area)
 for row in Entrances.Villages.SOURCE.BUILDINGS[area]:
  var node=game.world.find_child("BlueCGVillageBuilding_"+str(row[4]),true,false)
  check(node is MeshInstance3D and node.mesh.get_surface_count()==(2 if row[4] in Entrances.Villages.Buildings.KILI_GRAPHICS else 1),"Source-specific village facade renders: "+str(row[4]))
 if DisplayServer.get_name()=="headless":return
 var center=game.model.world_point(Vector2(-40,-18) if area=="kili" else Vector2(-15,-4))
 await shot("Coastal Village Rooms/"+area+"-exterior",center+Vector3(-105,135,105),center,58)
 var serial=11294 if area=="kili" else 11284
 var building=game.world.find_child("BlueCGVillageBuilding_"+str(serial),true,false)
 var p:Vector3=building.global_position
 await shot("Coastal Village Rooms/"+area+"-building",p+Vector3(-32,33,37),p+Vector3.UP*3,60)

func walk_through_entry(shift:bool=false):
 var at=map_position()
 var available:Array=game.model.get_meta("falan_links",[]).duplicate()
 available.sort_custom(func(a,b):return at.distance_squared_to(a.at)<at.distance_squared_to(b.at))
 if available.is_empty() or at.distance_squared_to(available[0].at)>36.0:return
 var link:Dictionary=available[0]
 var before:Vector2=link.at-link.get("direction",Vector2.DOWN)*4.0
 if link.get("crossing",false):
  for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
   var approach:Vector2=link.at-direction*4.0
   if not Tour.Regions.crossings(Tour.area(game.model),approach,link.at).is_empty():
    before=approach;break
 var modifier=InputEventKey.new();modifier.keycode=KEY_SHIFT;modifier.physical_keycode=KEY_SHIFT;modifier.pressed=shift
 Input.parse_input_event(modifier);Input.flush_buffered_events()
 game.player.position=game.model.world_point(link.at,.15);game.player.velocity=Vector3.ZERO
 game.falan_crossing_position=before
 Tour.cross_on_foot(game)
 modifier=modifier.duplicate();modifier.pressed=false;Input.parse_input_event(modifier);Input.flush_buffered_events()
 for i in 6:await process_frame
 for i in 4:await physics_frame

func map_position()->Vector2:
 return Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale

func position_at(p:Vector2):
 game.player.position=game.model.world_point(p,.15)
 game.player.velocity=Vector3.ZERO
 if game.model.falan_floor==Habaru.ROOM and not game.habaru_dialogue_seen and not get_meta("habaru_slain",{}).has(0) and p.distance_to(Tour.Regions.Sites.HABARU_FORMATION[0])<=15:
  var return_position:Vector3=game.player.position
  game.player.position=game.model.world_point(Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,7),.15)
  var talk=InputEventKey.new();talk.physical_keycode=KEY_F;talk.pressed=true
  Input.parse_input_event(talk);Input.flush_buffered_events()
  talk=talk.duplicate();talk.pressed=false;Input.parse_input_event(talk);Input.flush_buffered_events()
  await finish_boss_dialogue()
  game.player.position=return_position
 for i in 4:await physics_frame

func finish_boss_dialogue():
 for i in 4:
  if not is_instance_valid(game.get("dialogue")):return
  var event=InputEventKey.new()
  event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=true
  Input.parse_input_event(event);Input.flush_buffered_events()
  await process_frame
  event=event.duplicate();event.pressed=false
  Input.parse_input_event(event);Input.flush_buffered_events()
  await process_frame
func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 game.ui.hide()
 game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 camera.global_position=eye
 camera.look_at(target)
 camera.fov=fov
 camera.reset_physics_interpolation()
 if refresh_army:game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)
 game.set_process(true)
 game.ui.show()

func check_entry_controls():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"Pet F Only"))
 game.tuning.invincible=true
 var doors:Array=game.model.get_meta("falan_links").filter(func(link):return link.get("door",false) and link.to=="interior")
 check(not doors.is_empty(),"Falan retains its building entrances")
 if doors.is_empty():return
 var door:Dictionary=doors[0]
 check(door.get("walk_in",false),"Former F-only Falan building supports walking in")
 game.player.position=game.model.world_point(door.at,.15);game.player.velocity=Vector3.ZERO;game.falan_crossing_position=door.at
 var army=game.army_runtime
 game.settings.forest_pet_loadout=[army.Pets.key(0)];army.queue_hounds()
 for i in 90:await physics_frame
 check(army.handles.has(army.HOUND_ID),"Pet arrives beside the entrance")
 var serial:int=army.hound_order_serial
 var f=InputEventKey.new();f.keycode=KEY_F;f.physical_keycode=KEY_F;f.pressed=true
 Input.parse_input_event(f);Input.flush_buffered_events()
 for i in 4:await physics_frame
 f=f.duplicate();f.pressed=false;Input.parse_input_event(f);Input.flush_buffered_events()
 check(Tour.area(game.model)=="city" and not game.transitioning,"F at an entrance never changes areas")
 check(army.hound_order==army.HoundOrder.HOLD and army.hound_order_serial==serial+1,"F at an entrance commands pet defense")
 f=f.duplicate();f.pressed=true;f.shift_pressed=true;Input.parse_input_event(f);Input.flush_buffered_events()
 for i in 4:await physics_frame
 f=f.duplicate();f.pressed=false;Input.parse_input_event(f);Input.flush_buffered_events()
 check(Tour.area(game.model)=="city" and not game.transitioning,"Shift+F no longer enters a doorway")
 var labels=game.world.find_children("*","Label3D",true,false)
 check(labels.all(func(label):return not label.text.begins_with("F  ·") and not "Shift+F" in label.text),"Entrance labels contain no F interaction prompt")
 if DisplayServer.get_name()!="headless":
  var center=game.model.world_point(door.at)
  await shot("Pet F Only/entrance-pet-defense",center+Vector3(20,24,26),center,65)
 game.player.position=game.model.world_point(door.at,.15);game.falan_crossing_position=door.at+Vector2(0,4)
 check(Tour.cross_on_foot(game),"Walking across the same doorstep starts entry")
 for i in 10:await physics_frame
 check(Tour.area(game.model)=="interior" and game.model.falan_floor==door.floor,"Walking loads the original building")
 var exits:Array=game.model.get_meta("falan_links").filter(func(link):return link.get("exit",false))
 check(not exits.is_empty() and exits.all(func(link):return link.get("walk_in",false)),"Building exits support walking out")
 if not exits.is_empty():
  game.player.position=game.model.world_point(exits[0].at,.15);game.falan_crossing_position=exits[0].at+Vector2(0,4)
  check(Tour.cross_on_foot(game),"Walking across the exit starts departure")
  for i in 10:await physics_frame
  check(Tour.area(game.model)=="city","Walking out returns to Falan")
 await check_alyut_west_night()

func walk_connected_gate(at:Vector2,direction:Vector2,village:String):
 await position_at(at-direction*5)
 var model_before=game.model
 var world_before=game.world.map_features
 var army_before=game.army_runtime
 var handles=army_before.handles.duplicate()
 var yaw=atan2(-direction.x,-direction.y)
 game.camera_rig.yaw=yaw
 Input.action_press("move_forward")
 for i in 160:
  await physics_frame
  check(game.model==model_before and game.world.map_features==world_before and game.army_runtime==army_before,"Village gates preserve the world and native army in both directions")
  if (map_position()-at).dot(direction)>5:break
 Input.action_release("move_forward")
 check((map_position()-at).dot(direction)>3,"The original gate is physically walkable: "+village)
 check(is_equal_approx(game.camera_rig.yaw,yaw),"Village entry never resets the camera")
 check(handles.keys().all(func(id):return army_before.handles.get(id)==handles[id]),"Existing native monster handles survive village crossings")

func check_alyut_coast_gates():
 var regions=Tour.Regions
 check(Tour.area(game.model)=="north_coast" and game.model.has_meta("joined_village"),"Alyut shares the North Coast landscape")
 if Tour.area(game.model)!="north_coast":return
 var placement=regions.village_transform("alyut")
 for gate in [[regions.ALYUT_SOUTH_GATE,Vector2.DOWN],[regions.ALYUT_NORTH_GATE,Vector2.UP]]:
  for sign_ in [1,-1]:
   await walk_connected_gate(placement*gate[0],placement.basis_xform(gate[1])*sign_,"alyut")
 await walk_connected_gate(placement*regions.ALYUT_NORTH_GATE,Vector2.UP,"alyut")
 check(Tour.area(game.model)=="north_coast","The north gate opens onto its own coast road")

