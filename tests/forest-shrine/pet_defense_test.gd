extends "res://tests/forest-shrine/gatekeeper_hound_test.gd"
const DEFENSE_OUT="res://build/Other Files/Pet Defense/"
func run():
 create_timer(180).timeout.connect(func():quit(1))
 var model=load("res://scripts/forest/forest_model.gd").new()
 model.reset(42,{"enemy_health_mult":1.0,"enemy_speed_mult":1.0,"enemy_size_mult":3.0},{},false)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null);runtime.configure_kits(Kit.from_model(model))
 verify_guard(runtime,Roles.stats(ROLE));verify_combat_recall(runtime,Roles.stats(ROLE));verify_orders(runtime,Roles.stats(ROLE))
 runtime.clear();runtime.free();model=null
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.player.select_character(preload("res://scripts/rogue_roster.gd").KAZI_ID)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.player.position=Vector3(-120,0,125);game.player.position.y=game.model.surface_height(-120,125)
 game.player.hp=100000;game.player.max_hp=100000
 var army=game.army_runtime
 game.settings.forest_pet_loadout=Pets.sanitized([Pets.key(0),Pets.key(21),Pets.key(41),Pets.key(61),Pets.key(81)])
 army.queue_hounds()
 for i in 90:army.integration_tick(1.0/60);army.flush_presentation()
 var pets:Array[int]=[]
 for skin in [0,21,41,61,81]:
  if army.handles.has(army.HOUND_ID-skin):pets.append(army.handles[army.HOUND_ID-skin])
 check(pets.size()==5,"Five mixed pet families arrive in the native owner")
 var point:Vector3=game.player.position+Vector3(0,0,-2);point.y=game.model.surface_height(point.x,point.z)
 var enemy:int=army.spawn(90001,0,12,point,100000,.7)
 var times=[];var hits=0;var acquired={};var warmed_nodes=0;var warmed_resources=0
 for cycle in 3:
  for i in 240:
   var start=Time.get_ticks_usec();army.integration_tick(1.0/60);army.flush_presentation();times.append((Time.get_ticks_usec()-start)/1000.0)
   for pet in pets:
    if army.unit_state(pet).target_id==90001:acquired[pet]=true
   if i%4==0:
    game.crowd.present_army(army.render_snapshot(),[]);await frames(1)
  if cycle==0:
   warmed_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));warmed_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
  check(acquired.size()==5,"All five pets automatically engage a nearby enemy, cycle %d"%cycle)
  check(army.unit_state(enemy).hp<100000-hits,"Repeated native contacts damage the enemy, cycle %d"%cycle)
  hits=int(100000-army.unit_state(enemy).hp)
  game.issue_hound_order(army.HoundOrder.RETURN);army.integration_tick(1.0/60)
  check(pets.all(func(h):return army.unit_state(h).target_id==0),"Return interrupts all five pets, including repeated recalls")
  check(army.external_targets().hound_order_serial==cycle+1,"Each return order reaches native pets once")
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=warmed_nodes+2 and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=warmed_resources+2,"Repeated five-pet defense and recalls retain no extra nodes or resources after warmup")
 times.sort();print("PET_DEFENSE_STEP p95_ms=",times[int(times.size()*.95)]," max_ms=",times[-1])
 for i in 360:army.integration_tick(1.0/60);army.flush_presentation()
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 var camera=game.camera_rig.camera;camera.global_position=point+Vector3(-4,20,30);camera.look_at(point+Vector3.UP)
 game.crowd.present_army(army.render_snapshot(),[]);game.forest_ui.sync()
 if DisplayServer.get_name()!="headless":
  await frames(3);await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(DEFENSE_OUT+"mixed-pets-defending.png")==OK,"Captured mixed pets defending after recall")
 army.despawn(enemy)
 for i in 120:army.integration_tick(1.0/60)
 check(pets.all(func(h):return army.unit_state(h).target_id==0),"Dead targets release every pet")
 await verify_hold_position(army,pets)
 await verify_scattered_targets(army,pets)
 game.queue_free();current_scene=null;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_DEFENSE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

func verify_scattered_targets(army,pets:Array[int]):
 game.model.waves.crossgate_pet_test=true
 game.crowd.army.meshes[Roles.SLIME]=preload("res://scripts/forest/crowd/slime_sprites.gd").make_mesh()
 army.refresh_kits();army.order_hounds(army.HoundOrder.DEFEND)
 var home=Vector3(-120,0,125);home.y=game.model.surface_height(home.x,home.z)
 game.player.position=home
 for i in pets.size():
  var post=home+Vector3((i-2)*3.5,0,-4);post.y=game.model.surface_height(post.x,post.z)
  army.native.set_pose(pets[i],post,0)
 var lone=home+Vector3(0,0,-8);lone.y=game.model.surface_height(lone.x,lone.z)
 var previous=[army.spawn(94999,0,12,lone,1000000,.7)]
 for tick in 60:army.integration_tick(1.0/60)
 check(pets.all(func(h):return army.unit_state(h).target_id==94999),"All regular pet families can still share a lone enemy")
 var warmed_nodes=0;var warmed_resources=0;var times=[]
 for cycle in 3:
  var replacements=[]
  for i in 5:
   var post=home+Vector3((i-2)*6,0,-12);post.y=game.model.surface_height(post.x,post.z)
   var handle:int=army.spawn(95000+cycle*5+i,0,Roles.SLIME,post,1000000,Roles.SLIME_RADIUS)
   army.apply_hit(handle,{"element":"stun","status_seconds":60.0,"provoke":false});replacements.append(handle)
  for handle in previous:army.despawn(handle)
  army.integration_tick(1.0/60)
  var chosen={}
  for h in pets:chosen[army.unit_state(h).target_id]=true
  check(not chosen.has(0) and chosen.size()>=3,"Regular mixed pets spread across nearby targets immediately, cycle %d"%cycle)
  for tick in 300:
   var start=Time.get_ticks_usec();army.integration_tick(1.0/60);army.flush_presentation();times.append(Time.get_ticks_usec()-start)
   if tick%6==0:await frames(1)
  check(replacements.filter(func(h):return army.unit_state(h).hp<1000000).size()>=3,"Hound, mantis, lizard and bees damage different enemies, cycle %d"%cycle)
  if cycle==0:
   warmed_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));warmed_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
  previous=replacements
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=warmed_nodes+2 and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=warmed_resources+2,"Repeated regular-pet retargeting retains prepared nodes and resources")
 var camera=game.camera_rig.camera;camera.global_position=home+Vector3(18,24,28);camera.look_at(home+Vector3(0,0,-10))
 game.crowd.present_army(army.render_snapshot(),[]);game.forest_ui.sync()
 if DisplayServer.get_name()!="headless":
  await frames(3);await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(DEFENSE_OUT+"mixed-pets-scattered-targets.png")==OK,"Captured regular pets attacking different slimes")
 for h in previous:army.despawn(h)
 times.sort();print("REGULAR_PET_SPREAD_STEP_US p95=",times[int(times.size()*.95)]," max=",times[-1])

func pet_key(code:int,pressed:bool=true,echo:bool=false,shift:bool=false):
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;event.echo=echo;event.shift_pressed=shift;game._input(event)
func verify_hold_position(army,pets:Array[int]):
 var origin:Vector3=game.player.position;var posts=[];var enemies=[]
 for i in pets.size():
  var point=origin+Vector3((i-2)*6,0,-8);point.y=game.model.surface_height(point.x,point.z)
  army.native.set_pose(pets[i],point,0);posts.append(point)
  var target=point+Vector3(0,0,-1.5);target.y=game.model.surface_height(target.x,target.z)
  enemies.append(army.spawn(91000+i,0,12,target,100000,.7))
 var far_point=origin+Vector3(0,0,12);far_point.y=game.model.surface_height(far_point.x,far_point.z)
 var distant:int=army.spawn(92000,0,12,far_point,100000,.7)
 var serial:int=army.hound_order_serial
 game.paused=true;pet_key(KEY_F);game.paused=false
 check(army.hound_order_serial==serial,"Pause blocks F")
 pet_key(KEY_F,false);pet_key(KEY_F,true,true);pet_key(KEY_F,true,false,true)
 check(army.hound_order_serial==serial,"Release, key-repeat and Shift+F do not issue pet orders")
 var times=[];var drift=0.0;var hold_nodes=0;var hold_resources=0
 for cycle in 3:
  pet_key(KEY_F);army.integration_tick(1.0/60)
  check(army.hound_order==army.HoundOrder.HOLD and army.hound_order_serial==serial+cycle+1,"Physical F orders defend in place, including repeated presses")
  pet_key(KEY_F,false);army.integration_tick(1.0/60)
  check(army.hound_order==army.HoundOrder.HOLD and army.hound_order_serial==serial+cycle+1,"Releasing F keeps defense active without issuing another order")
  game.forest_ui.sync()
  check(game.forest_ui.hound_stance==1 and game.forest_ui.hound_stance_labels[1].text=="› F Defend" and game.forest_ui.hound_stance_labels[1].get_combined_minimum_size().x<=70,"Released F shows a readable selected Defend label")
  game.player.position=origin+Vector3(40,0,0);game.player.position.y=game.model.surface_height(game.player.position.x,game.player.position.z)
  for i in 180:
   var start=Time.get_ticks_usec();army.integration_tick(1.0/60);army.flush_presentation();times.append((Time.get_ticks_usec()-start)/1000.0)
   for j in pets.size():drift=maxf(drift,army.unit_state(pets[j]).position.distance_to(posts[j]))
   if i%6==0:game.crowd.present_army(army.render_snapshot(),[]);await frames(1)
  if cycle==0:
   hold_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));hold_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
  check(enemies.all(func(h):return army.unit_state(h).hp<100000) and drift<.01,"All five pets strike from their original positions while the player moves away")
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=hold_nodes+2 and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=hold_resources+2,"Repeated hold-position attacks retain no extra nodes or resources after warmup")
 check(army.unit_state(distant).hp==100000,"Defending pets never chase the distant attacker")
 times.sort();print("PET_HOLD_STEP p95_ms=",times[int(times.size()*.95)]," max_ms=",times[-1]," drift=",drift)
 var camera=game.camera_rig.camera;camera.global_position=origin+Vector3(-4,24,32);camera.look_at(origin+Vector3(0,0,-8))
 game.crowd.present_army(army.render_snapshot(),[]);game.forest_ui.sync()
 if DisplayServer.get_name()!="headless":
  await frames(3);await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png("res://build/Other Files/Pet Hold/five-pets-holding.png")==OK,"Captured five pets defending their separate positions")
 for h in enemies:army.despawn(h)
 for i in 180:army.integration_tick(1.0/60)
 check(pets.all(func(h):return army.unit_state(h).target_id==0) and pets.all(func(h):return army.unit_state(h).position.distance_to(posts[pets.find(h)])<.01),"After kills pets stay planted without roaming or following")
 camera.look_at(camera.global_position+Vector3.UP+Vector3.FORWARD*.1)
 tap("heavy_attack")
 for i in 120:army.integration_tick(1.0/60)
 check(pets.any(func(h):return army.unit_state(h).position.distance_to(posts[pets.find(h)])>1),"Empty right click releases hold to hunt")
 pet_key(KEY_F);army.integration_tick(1.0/60)
 var stopped=pets.map(func(h):return army.unit_state(h).position)
 army.despawn(distant)
 for i in 60:army.integration_tick(1.0/60)
 check(pets.all(func(h):return army.unit_state(h).position.distance_to(stopped[pets.find(h)])<.01),"F stops the moving hunt at the new positions")
 pet_key(KEY_Z)
 for i in 120:army.integration_tick(1.0/60)
 check(pets.any(func(h):return army.unit_state(h).position.distance_to(stopped[pets.find(h)])>1),"Z releases hold and recalls the pack")
