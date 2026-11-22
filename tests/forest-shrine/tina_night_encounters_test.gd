extends "res://tests/forest-shrine/original_maps_test.gd"
const Creatures=preload("res://scripts/forest/crowd/shalena_sprites.gd")
const Clock=preload("res://scripts/forest/forest_explorer_clock.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/Tina Recovery/Night Encounters/"

func run():
 root.size=Vector2i(1280,800)
 check(not Creatures.owns(51005) and Creatures.owns(4201),"Only the original night village gets hostile patrols")
 check(Creatures.Data.ZONES.size()==56 and Creatures.Data.SPECIES.size()==16,"Pinned road and night-village memberships are complete")
 var rng=RandomNumberGenerator.new();rng.seed=17
 var bag=Creatures.refill([0,0,1,2],rng);bag.sort()
 check(bag==[0,0,1,2],"Shuffle bags retain weighted outcomes without replacement")
 for floor_ in [4201,Original.SHALENA_SOUTH,Original.SHALENA_NORTH]:
  var posts=Creatures.posts(floor_,19)
  check(not posts.is_empty() and posts.size()<=192,"Bounded original-map patrol preparation "+str(floor_))
  check(posts==Creatures.posts(floor_,19),"Revisiting retains deterministic slots "+str(floor_))
  for row in posts:
   var post:Vector4i=row[0];var cell=Vector2i(((Vector2(post.x,post.y)-Original.state(floor_).origin)/3).round())+Original.crop(floor_).position
   check(Creatures.zone_at(floor_,cell)==post.w,"Patrol uses its most local source region")
   check(Creatures.Data.ZONES[post.w][2].any(func(member):return member[0]==post.z and row[1]>=member[1] and row[1]<=member[2]),"Species and level belong to that original encounter")
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/tina-night-enemies-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.set_process(false)
 game.explorer_clock.load_hour(12)
 await visit(51005,Vector2i(47,35))
 check(game.model.waves.patrol_posts.is_empty() and game.model.enemies.is_empty(),"Daytime village stays peaceful")
 game.explorer_clock.load_hour(17.9999);game.explorer_clock.tick(game,.21)
 for i in 10:await physics_frame
 check(game.model.falan_floor==4201,"Actual dusk transition activates the native night layout")
 await populate()
 check_attacks()
 await check_live_attack()
 var killed_slot=-1
 if not game.model.enemies.is_empty():
  var row:Dictionary=game.model.enemies.values()[0];killed_slot=row.source_patrol_slot
  game.army_runtime.apply_hit(game.army_runtime.handles[row.id],{"amount":row.max_hp*2,"direction":Vector3.FORWARD})
  game.army_runtime.dispatch_events()
  check(not game.army_runtime.handles.has(row.id),"Enemy deaths retire the shared native handle")
  game.army_runtime.sync_compatibility()
  var player_at=game.player.position
  var post:Vector4i=game.model.waves.patrol_posts[killed_slot]
  game.player.position=game.model.world_point(Vector2(post.x,post.y))
  for i in game.model.waves.patrol_posts.size()+1:game.model.waves.tick(12,game.player.position)
  check(not game.model.enemies.values().any(func(enemy):return enemy.get("source_patrol_slot")==killed_slot),"A defeated patrol cannot respawn on the player")
  game.player.position=player_at
  for i in game.model.waves.patrol_posts.size()+1:game.model.waves.tick(12,game.player.position)
  game.army_runtime.import_arrivals()
  check(game.model.enemies.values().filter(func(enemy):return enemy.get("source_patrol_slot")==killed_slot).size()==1,"Wild encounters replenish once the player leaves, without duplicates")
 game.explorer_clock.load_hour(5.9999);game.explorer_clock.tick(game,.21)
 for i in 10:await physics_frame
 check(game.model.falan_floor==51005 and game.model.enemies.is_empty(),"Dawn removes night enemies with the normal map transition")
 game.explorer_clock.load_hour(0);await visit(4201,Vector2i(47,35));await populate()
 check(game.model.enemies.values().filter(func(row):return row.get("source_patrol_slot")==killed_slot).size()==1,"A new night repopulates its original patrol once")
 if DisplayServer.get_name()!="headless":await capture_enemies("tina-night-enemies")
 for floor_ in [Original.SHALENA_SOUTH,Original.SHALENA_NORTH]:
  game.explorer_clock.load_hour(12)
  await visit(floor_,Vector2i(570,300) if floor_==Original.SHALENA_SOUTH else Vector2i(120,140))
  await populate()
  if DisplayServer.get_name()!="headless":await capture_enemies("shalena-south" if floor_==Original.SHALENA_SOUTH else "shalena-north")
 check(Clock.CYCLE_SECONDS==1440,"Encounter population preserves the 24-minute world cycle")
 if DisplayServer.get_name()!="headless":await lineup()
 finish()

func visit(floor_:int,cell:Vector2i):
 game.transitioning=true
 await Tour.travel(game,Original.layout(floor_),{"arrival":Original.source_point(floor_,cell),"yaw":0.0})
 check(game.model.falan_floor==floor_,"Explorer enters encounter map "+str(floor_))
 for i in 4:await physics_frame

func populate():
 var waves=game.model.waves
 check(waves.patrol_source==Creatures and not waves.patrol_posts.is_empty(),"Source encounters use the existing world patrol owner")
 if game.model.enemies.is_empty():
  waves.tick(12,game.player.position)
  check(game.model.enemies.values().any(func(row):return (row.pos-game.player.position).length()/game.model.falan_scale<40),"Arrival populates a nearby clearing first instead of the far side of the map")
 for i in waves.patrol_posts.size()+1:waves.tick(12,game.player.position)
 game.army_runtime.finish_integration();game.army_runtime.import_arrivals()
 check(not game.model.enemies.is_empty(),"Recovered map has live hostile enemies")
 var skins={}
 for row:Dictionary in game.model.enemies.values():
  skins[row.skin]=true
  var handle:int=game.army_runtime.handles.get(row.id,0)
  check(handle!=0 and game.army_runtime.unit_state(handle).pose_row==row.skin,"Original appearance is wired to native combat")
  check(row.enemy_name==Creatures.Data.SPECIES[row.skin].name and row.has("source_patrol_slot"),"Original identity and stable patrol slot are retained")
  check(waves.navigation.move_clear(row.pos/game.model.falan_scale,row.footprint*waves.patrol_fits[row.skin]*Roles.MAP_ENEMY_SCALE),"Actual enemy clears recovered scenery")
 var count_=game.model.enemies.size()
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 4:waves.tick(12,game.player.position)
 check(count_==game.model.enemies.size(),"Repeated population cannot duplicate a living patrol")
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Settled patrol ticks do not construct extra nodes or resources")
 print("TINA_POPULATION floor=",game.model.falan_floor," enemies=",count_," skins=",skins.keys())
 if game.model.falan_floor==4201:check(skins.has(2) and skins.has(3) and skins.has(13),"Night village contains blood skeletons, spirits and pirates")

func check_attacks():
 var probe=ClassDB.instantiate("GoemonCrowdRuntime");probe.configure(64,2000)
 check(probe.configure_kits(preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model)),"All recovered contacts configure the same native combat owner")
 probe.set_navigation(game.army_runtime.navigation_data(game.model))
 var at:Vector3=game.model.enemies.values()[0].pos;var target=at
 for direction in [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT]:
  var point=at+direction*1.6;point.y=game.model.world_height(point.x,point.z)
  if probe.can_reach(at,point,.55):target=point;break
 check(at!=target,"Attack review has reachable footing")
 var targets:Dictionary=game.army_runtime.external_targets()
 targets.positions[0]=target;targets.targetable[0]=1
 targets.minimum[0]+=target-game.player.position;targets.maximum[0]+=target-game.player.position
 probe.set_targets(targets)
 for skin in Creatures.Data.SPECIES.size():
  var handle:int=probe.spawn(skin+1,0,Roles.SLIME,at,3000,.5)
  check(probe.set_pet_skin(handle,skin),"Native attack selects the original species "+str(skin))
  probe.set_pose(handle,at,atan2(target.x-at.x,target.z-at.z));probe.set_guard(handle,at,14)
  var hits=[]
  for tick in 1200:
   probe.step(1.0/60)
   hits.append_array(probe.take_events().filter(func(event):return event.kind=="external_damage"))
   if hits.size()>=2:break
  check(hits.size()>=2 and hits.all(func(hit):return is_equal_approx(hit.amount,30)),"Repeated original contacts deal exact native damage: "+Creatures.Data.SPECIES[skin].name)
  probe.despawn(handle);probe.take_events()
 check(probe.snapshot().handles.is_empty(),"Repeated species reuse leaves no native units alive")

func check_live_attack():
 for i in 16:await physics_frame
 var row:Dictionary=game.model.enemies.values()[0];var at:Vector3=row.pos;var target=at
 for direction in [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT]:
  var candidate=at+direction*1.6;candidate.y=game.model.world_height(candidate.x,candidate.z)
  if game.army_runtime.native.can_reach(at,candidate,.55):target=candidate;break
 var saved=game.player.position;var hp=game.player.hp
 game.player.position=target;game.player.velocity=Vector3.ZERO;game.tuning.invincible=false
 var samples=[];var previous=Time.get_ticks_usec()
 for i in 240:
  await physics_frame
  var now=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
  if game.player.hp<hp:break
 check(game.player.hp<hp,"A live night enemy reaches the actual player damage path")
 print("TINA_LIVE_DAMAGE hp_before=",hp," hp_after=",game.player.hp)
 game.tuning.invincible=true;game.player.hp=hp;game.player.position=saved;game.player.velocity=Vector3.ZERO
 if DisplayServer.get_name()!="headless":
  samples.clear();previous=Time.get_ticks_usec()
  for i in 120:
   await process_frame
   var now=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
  samples.sort();print("TINA_RENDERED_FRAME_INTERVAL p95_ms=",samples[floori(samples.size()*.95)]," max_ms=",samples[-1]," samples=",samples.size())
  var report=FileAccess.open(REVIEW+"frame-intervals.json",FileAccess.WRITE);report.store_string(JSON.stringify(samples))

func capture_enemies(name_:String):
 DisplayServer.window_move_to_foreground()
 var row:Dictionary=game.model.enemies.values()[0]
 var at:Vector3=row.pos
 game.camera_rig.set_process(false);game.camera_rig.camera.global_position=at+Vector3(-15,19,22);game.camera_rig.camera.look_at(at+Vector3.UP*2)
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(REVIEW+name_+".png")

func lineup():
 DisplayServer.window_move_to_foreground()
 game.ui.hide();game.forest_ui.hide()
 root.size=Vector2i(1440,1000)
 game.camera_rig.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera_rig.camera.size=42*game.model.falan_scale
 var stage=Node3D.new();game.world.add_child(stage)
 stage.position=Vector3(2500,0,2500)*game.model.falan_scale;stage.scale=Vector3.ONE*game.model.falan_scale
 var batch=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.use_custom_data=true
 batch.multimesh.mesh=Creatures.make_mesh();stage.add_child(batch);batch.set_instance_shader_parameter("use_world_pet_sizes",true)
 batch.multimesh.instance_count=16;batch.custom_aabb=AABB(Vector3(-30,-5,-30),Vector3(60,40,60))
 for skin in 16:
  var at=Vector3((skin%4-1.5)*9,0,(skin/4-1.5)*11)
  batch.multimesh.set_instance_transform(skin,Transform3D(Basis.IDENTITY,at))
  var label=Label3D.new();label.text=Creatures.Data.SPECIES[skin].name;label.font=preload("res://scripts/forest/preparation_skin.gd").FONT
  label.font_size=32;label.pixel_size=.025;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=at+Vector3(0,-.4,0);stage.add_child(label)
 for action in [0,2]:
  for skin in 16:batch.multimesh.set_instance_custom_data(skin,Color(skin,action,.65,0))
  game.camera_rig.camera.global_position=stage.to_global(Vector3(-3,50,48));game.camera_rig.camera.look_at(stage.to_global(Vector3(0,1,0)))
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(REVIEW+("species-idle.png" if action==0 else "species-attack.png"))
 stage.queue_free()
