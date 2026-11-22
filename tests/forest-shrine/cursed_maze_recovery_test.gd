extends "res://tests/forest-shrine/original_maps_test.gd"
const Decree=Winter.Decree
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Cursed=preload("res://scripts/forest/crowd/cursed_maze_sprites.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Cursed Maze/"

func _initialize():
 create_timer(600).timeout.connect(func():printerr("CURSED_MAZE_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 data_checks()
 if "--data-only" in OS.get_cmdline_user_args():await finish();return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW))
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/cursed-maze-recovery.cfg";root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false
 game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true
 set_meta(Winter.SLAIN,{})
 var reviewed=[]
 for number in range(1,61):
  var id=Decree.floor_id(number);var previous=Original.SHALENA_NORTH if number==1 else Decree.floor_id(number-1)
  var entry=Original.links(previous).filter(func(l):return l.get("floor")==id)[0]
  Tour.travel(game,Original.layout(id),{"arrival":entry.arrival,"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  check(game.model.falan_floor==id,"Previous source stair reaches floor "+str(number))
  var rows=Decree.encounters(id,game.model.seed_value)
  var expected={};var seen={};var types={};var bosses=[];var maze=Decree.maze(id,game.model.seed_value)
  for row in rows:expected[Vector2i(id,row[5])]=row
  check(game.model.enemies.size()==rows.size(),"Every source-roster creature has a live spawn on floor "+str(number))
  check(Original.state(id).raw==Original.Art.raw_map(Original.path_for(id)),"All three original map planes retained on floor "+str(number))
  for enemy:Dictionary in game.model.enemies.values():
   var row:Array=expected.get(enemy.frostpass_slot,[])
   check(not row.is_empty(),"Spawn retains a stable encounter slot")
   if row.is_empty():continue
   var skin=Cursed.KEYS.find(row[1]);var kind=Roles.SLIME if skin>=0 else Roles.GATEKEEPER_HOUND
   if skin<0:skin=Pets.skin(row[1])
   var handle:int=game.army_runtime.handles.get(enemy.id,0)
   check(enemy.variant==kind and enemy.skin==skin and handle!=0,"Creature uses its original prepared art and native owner: "+row[2])
   if handle!=0:check(game.army_runtime.unit_state(handle).pose_row==skin,"Native pose row matches "+row[2])
   check(enemy.enemy_name==row[2] and enemy.level==row[3],"Creature name/level matches floor roster")
   var region:int=maze.regions[row[0]]
   var approach=game.model.world_point(Original.point(id,maze.approaches[region]))
   check(game.army_runtime.native.can_reach(approach,enemy.pos,enemy.footprint),"Creature is reachable from its original stair chamber: %d %s"%[number,row[2]])
   seen[enemy.frostpass_slot]=true;types[row[1]]=true
   if enemy.get("boss",false):bosses.append(enemy)
  check(seen.size()==expected.size(),"No duplicate or missing encounter slots")
  var guardian=number%10==0
  var next=51011 if number==60 else Decree.floor_id(number+1)
  var exits=Original.links(id).filter(func(l):return l.get("floor")==next)
  check(not exits.is_empty(),"Source path continues from floor "+str(number))
  check(bosses.size()==(2 if number==60 else 1 if guardian else 0),"Correct guardian count on floor "+str(number))
  if not guardian:check(types.size()==(10 if number>50 else 2),"Complete reference monster roster appears on floor "+str(number))
  var count_=game.model.enemies.size()
  game.model.waves.tick_holy_decree();game.army_runtime.import_arrivals()
  check(game.model.enemies.size()==count_,"Repeated population does not duplicate enemies")
  if guardian or number in [1,11,21,31,41,51]:await photograph(number,bosses)
  if number==31:check_new_creature_combat()
  if guardian:
   var gate=Original.links(id).filter(func(l):return l.get("decree_guardians",false))[0]
   var before=game.model
   check(not Decree.cleared(get_meta(Winter.SLAIN,{}),id,game.model.seed_value),"Living guardian seals the next floor")
   Tour.enter_link(game,"interior",gate,gate.at)
   check(game.model==before,"Normal travel cannot bypass a living guardian")
   for boss in bosses:
    var handle:int=game.army_runtime.handles.get(boss.id,0)
    game.army_runtime.apply_hit(handle,{"amount":boss.max_hp*4,"direction":Vector3.FORWARD})
    game.army_runtime.dispatch_events()
    check(get_meta(Winter.SLAIN,{}).has(boss.frostpass_slot),"Native boss death records stable progress: "+boss.enemy_name)
    if number==60 and boss==bosses[0]:check(not Decree.cleared(get_meta(Winter.SLAIN,{}),id,game.model.seed_value),"One living Twin King keeps the final seal closed")
   check(Decree.cleared(get_meta(Winter.SLAIN,{}),id,game.model.seed_value),"All guardian deaths unlock the floor")
   Tour.travel(game,Original.layout(id),{"arrival":entry.arrival,"yaw":0.0,"velocity":Vector3.ZERO})
   for i in 4:await physics_frame
   check(not game.model.enemies.values().any(func(e):return e.get("boss",false)),"Defeated guardians do not respawn on return")
  reviewed.append({"floor":number,"source":Original.source_id(id),"creatures":rows.size(),"species":types.size(),"bosses":bosses.size()})
  print("CURSED_FLOOR ",number," creatures=",rows.size()," species=",types.size())
 await traverse_original_maze()
 check(get_meta(Decree.COMPLETE,false),"Defeating both kings and using the final seal completes the native exploration branch")
 var report=FileAccess.open(REVIEW+"floors.json",FileAccess.WRITE);report.store_string(JSON.stringify(reviewed,"  "));report.close()
 print("CURSED_MAZE_RESULT floors=60 checks=",checks," failures=",failures)
 await finish()

func data_checks():
 super.data_checks()
 var dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
 for skin in range(2,Cursed.KEYS.size()):
  var original=dimensions.companion_body(Pets.skin(Cursed.KEYS[skin]))
  var recovered=dimensions.body(Cursed,skin)
  check(recovered.position.is_equal_approx(original.position) and recovered.size.is_equal_approx(original.size),"Guardian retains its original fitted body after joining the casting bank")

func region_at(id:int,point:Vector2)->int:
 var row=Original.state(id)
 return Decree.maze(id,0).regions.get(Vector2i(((point-row.origin)/3.0).round()),-1)

func walk_gate(link:Dictionary):
 var before=game.model
 check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(link.at,.15),.5),"Native movement connects the current chamber to its chosen source stair")
 game.player.position=game.model.world_point(link.at,.15);game.player.velocity=Vector3.ZERO
 game.falan_crossing_position=link.at+Vector2(4,0)
 check(Tour.cross_on_foot(game),"Original stair accepts on-foot entry")
 for i in 4:await physics_frame
 check(game.model!=before and game.model.falan_floor==link.floor,"Original stair loads its exact destination")

func traverse_original_maze():
 var first=Decree.floor_id(1);var last=Decree.floor_id(60)
 var entry=Original.links(Original.SHALENA_NORTH).filter(func(l):return l.get("floor")==first)[0]
 var seal=Original.links(last).filter(func(l):return l.get("decree_guardians",false))[0]
 var start=Vector2i(first,region_at(first,entry.arrival));var goal=Vector2i(last,region_at(last,seal.at))
 var queue=[start];var parents={start:start};var stairs={}
 for current:Vector2i in queue:
  if current==goal:break
  for link in Original.links(current.x):
   var target:int=link.get("floor",0)
   if Decree.floor_number(target)==0 or region_at(current.x,link.at)!=current.y:continue
   var next=Vector2i(target,region_at(target,link.arrival))
   check(next.y>=0,"Original destination is on recorded open ground")
   if next.y<0 or parents.has(next):continue
   parents[next]=current;stairs[next]=link;queue.append(next)
 check(parents.has(goal),"The exact original component/stair graph reaches the Twin Kings with its required backtracking")
 if not parents.has(goal):return
 var route=[];var cursor=goal
 while cursor!=start:route.push_front(stairs[cursor]);cursor=parents[cursor]
 Tour.travel(game,Original.layout(first),{"arrival":entry.arrival,"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 var visited={first:true};var actual=[]
 for link in route:
  actual.append({"from":Original.source_id(game.model.falan_floor),"at":str(link.at),"to":Original.source_id(link.floor),"arrival":str(link.arrival)})
  await walk_gate(link);visited[game.model.falan_floor]=true
  var pos=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  check(region_at(game.model.falan_floor,pos)==region_at(link.floor,link.arrival),"Original stair arrives in the correct separate chamber")
 check(visited.size()==60,"On-foot route visits every original floor")
 await walk_gate(seal)
 var file=FileAccess.open(REVIEW+"original-route.json",FileAccess.WRITE);file.store_string(JSON.stringify(actual,"  "));file.close()
 print("CURSED_ORIGINAL_ROUTE stairs=",route.size()+1," floors=",visited.size())

func check_new_creature_combat():
 var probe=ClassDB.instantiate("GoemonCrowdRuntime");probe.configure(64,2000)
 check(probe.configure_kits(preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model)),"Recovered creature contact tables configure the existing native owner")
 probe.set_navigation(game.army_runtime.navigation_data(game.model))
 var at:Vector3=game.model.enemies.values()[0].pos
 for skin in Cursed.KEYS.size():
  for direction in 8:
   var yaw=direction*TAU/8;var target=at+Vector3(sin(yaw),0,cos(yaw))*1.6
   var targets:Dictionary=game.army_runtime.external_targets()
   targets.positions[0]=target;targets.targetable[0]=1
   targets.minimum[0]+=target-game.player.position;targets.maximum[0]+=target-game.player.position
   probe.set_targets(targets)
   var handle:int=probe.spawn(6000+skin*8+direction,0,Roles.SLIME,at,3000,.5)
   check(probe.set_pet_skin(handle,skin),"Recovered creature selects its native attack skin")
   probe.set_pose(handle,at,yaw);probe.set_guard(handle,at,14)
   var hits=[]
   for tick in 1200:
    probe.step(1.0/60)
    hits.append_array(probe.take_events().filter(func(e):return e.kind=="external_damage"))
    if hits.size()>=2:break
   check(hits.size()>=2 and hits.all(func(hit):return is_equal_approx(hit.amount,Cursed.STATS.damage)),"Repeated exact native contacts: %s facing %d"%[Cursed.KEYS[skin],direction])
   probe.despawn(handle);probe.take_events()

func photograph(number:int,bosses:Array):
 if DisplayServer.get_name()=="headless":return
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(REVIEW+"play-%02d.png"%number)
 game.camera_rig.set_process(false)
 var ceilings=[]
 for node:MeshInstance3D in game.world.find_children("*Ceiling*","MeshInstance3D",true,false):
  if node.visible:node.hide();ceilings.append(node)
 var focus=game.player.position
 if not bosses.is_empty():
  focus=Vector3.ZERO
  for boss in bosses:focus+=boss.pos
  focus/=bosses.size()
 else:
  var enemies=game.model.enemies.values()
  focus=enemies[enemies.size()/2].pos
 game.camera_rig.camera.global_position=focus+Vector3(20,24,26);game.camera_rig.camera.look_at(focus+Vector3.UP*2)
 game.crowd.army.presentation.draw_effects()
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(REVIEW+"encounter-%02d.png"%number)
 for node in ceilings:node.show()
 game.camera_rig.set_process(true)
