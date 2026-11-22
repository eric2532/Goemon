extends "res://tests/forest-shrine/weapon_equipment_test.gd"

const FIST_OUT="res://build/Other Files/Asset Toolkit/Cross Gate Fist Feel/"
const Balance=preload("res://scripts/character_balance.gd")
var fist_rows=[]

func fist_contact_case(character:int,skin:int):
 var p=game.player;var kit=p.active_ability
 kit.cancel();p.attack_chain.reset();p.position=home;p.ai_controlled=true;p.ai_aim=home+Vector3.FORWARD*20
 game.army_runtime.clear();game.model.enemies.clear()
 var probe=spawn(Vector3.FORWARD*2)
 var half_depth=probe.combat_bounds().end.z-probe.global_position.z
 var reach=p.melee_strike_reach()
 var prior_reach=reach/Hero.CROSSGATE_FIST_REACH
 game.army_runtime.clear();game.model.enemies.clear()
 var target=spawn(Vector3.FORWARD*((reach+prior_reach)*.5+half_depth))
 var before:float=target.hp
 var profile:Dictionary=game.character_tuning.get_or_add(Balance.key_for(character),{})
 profile.melee_reach=1.0/Hero.CROSSGATE_FIST_REACH
 profile.attack_speed=1.0/Hero.CROSSGATE_FIST_SPEED
 kit.start_attack()
 var pattern:Dictionary=p.model.normal_attack_pattern().duplicate(true)
 var old_rate=p.attack_speed_multiplier()
 kit.tick(float(pattern.duration)/old_rate+.001)
 check(target.hp==before,"Previous fist reach misses the boundary target %d/%d"%[character,skin])
 profile.erase("melee_reach");profile.erase("attack_speed")
 kit.cancel();p.attack_chain.reset();kit.start_attack()
 var rate=p.attack_speed_multiplier()
 check(is_equal_approx(rate,old_rate*1.25),"Fist playback is 25 percent faster %d/%d"%[character,skin])
 kit.tick((float(pattern.contacts[0])-.001)/rate)
 check(target.hp==before,"Fist cannot damage before its visible contact %d/%d"%[character,skin])
 kit.tick(.002/rate)
 check(is_equal_approx(before-target.hp,Skills.basic_damage(pattern)),"First fist contact reaches the new boundary exactly once %d/%d"%[character,skin])
 kit.tick((float(pattern.duration)-kit.elapsed-.001)/rate)
 check(kit.is_attacking(),"Fist preserves the last recovery frame %d/%d"%[character,skin])
 kit.tick(.002/rate)
 check(not kit.is_attacking() and is_equal_approx(before-target.hp,Skills.basic_damage(pattern)*pattern.contacts.size()),"Fist recovers sooner with unchanged contact count/damage %d/%d"%[character,skin])
 check(p.model.normal_attack_pattern()==pattern,"Runtime tuning preserves source frames and markers %d/%d"%[character,skin])
 check(is_equal_approx(game.world.attack_range.radius(p),reach),"Fist outline matches actual expanded reach %d/%d"%[character,skin])
 fist_rows.append({"character":character,"skin":skin,"old_reach":prior_reach,"reach":reach,"old_contact_seconds":float(pattern.contacts[0])/old_rate,"contact_seconds":float(pattern.contacts[0])/rate,"old_cycle_seconds":float(pattern.duration)/old_rate,"cycle_seconds":float(pattern.duration)/rate})
 kit.cancel();p.ai_controlled=false

func native_fists(character:int):
 var p=game.player
 game.army_runtime.clear();game.model.enemies.clear();await frames()
 var target=spawn(Vector3.FORWARD*1.6)
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 5:check(mirrors.reinforce(character,home),"Fist copy enters the native lifecycle")
 for body in mirrors.bodies:
  check(body.model.current_weapon()=="unarmed" and is_equal_approx(body.attack_speed_multiplier(),1.5),"Native copy inherits fist selection and tempo")
 var profile:Dictionary=game.character_tuning[Balance.key_for(character)]
 var pool=Pool.service(game);var misses=pool.misses
 for previous in [true,false]:
  if previous:
   profile.melee_reach=1.0/1.25;profile.attack_speed=1.0/1.25
  else:profile.erase("melee_reach");profile.erase("attack_speed")
  var samples=[];var nodes=0;var resources=0
  for cycle in 10:
   var expected=0.0;var before:float=target.hp
   for body in mirrors.bodies:
    body.position=home;body.ai_target=target;body.ai_aim=target.global_position
    body.attack_chain.reset();body.active_ability.cancel();body.active_ability.start_attack()
    var pattern:Dictionary=body.model.normal_attack_pattern()
    expected+=Skills.basic_damage(pattern)*pattern.contacts.size()*body.damage_multiplier()
   for tick in 120:
    var start=Time.get_ticks_usec()
    for body in mirrors.bodies:
     body.active_ability.tick(DT);body.model.animate(DT,0,true,0,0,false,0,false)
    game.crowd.army.presentation.tick(DT)
    if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(DT)
    if cycle>=2:samples.append((Time.get_ticks_usec()-start)/1000.0)
   check(is_equal_approx(before-target.hp,expected),"Five simultaneous fist attacks preserve exact damage")
   if cycle==1:
    await frames(3);nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  await frames(3)
  check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.misses==misses,"Repeated native fists retain no warmed nodes/resources or pool misses")
  print("FIST_COPY_MS character=",character," previous=",previous," ",preload("res://tests/forest-shrine/army_benchmark_metrics.gd").summary(samples))
 mirrors.dispose();await frames()

func fist_picture(character:int):
 if DisplayServer.get_name()=="headless":return
 var p=game.player;var kit=p.active_ability
 p.position=home;p.ai_controlled=true;p.ai_aim=home+Vector3.FORWARD*20
 game.army_runtime.clear();game.model.enemies.clear();await frames()
 var probe=spawn(Vector3.FORWARD*2)
 var half_depth=probe.combat_bounds().end.z-probe.global_position.z
 var reach=p.melee_strike_reach()
 game.army_runtime.clear();game.model.enemies.clear();await frames()
 var target=spawn(Vector3.FORWARD*(reach*.9+half_depth))
 var hp_before:float=target.hp
 game.camera_rig.camera.global_position=home+Vector3(8,5,13);game.camera_rig.camera.look_at(home+Vector3(0,1,-1))
 kit.cancel();p.attack_chain.reset();kit.start_attack()
 var contact=float(p.model.normal_attack_pattern().contacts[0])
 var captured=false
 while kit.is_attacking():
  kit.tick(DT);p.model.animate(DT,0,true,0,0,false,0,false)
  await process_frame
  if not captured and kit.elapsed>=contact:
   captured=true
   check(target.hp<hp_before,"Rendered fist reaches a native enemy beyond its previous range")
   game.army_runtime.flush_presentation()
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(FIST_OUT+"contact-%d.png"%character)==OK,"Captured the moving fist contact")
 p.ai_controlled=false

func run():
 create_timer(900).timeout.connect(func():printerr("FIST_FEEL_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(FIST_OUT);root.size=Vector2i(1280,800);root.gui_disable_input=true
 cfg="user://crossgate-fist-feel-%d.cfg"%OS.get_process_id()
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 for node in [game,game.player,game.camera_rig]:node.set_process_input(false);node.set_process_unhandled_input(false)
 game.settings.forest_pet_loadout=[];game.settings.gear_loadouts={};game.settings.disable_character_cooldowns=false
 game.begin_arena();game.choose_rogue_character(34);await frames(3);game.equipment_hub.enter_map();await frames(3)
 game.clear_menu();game.forest_ui.hide();game.playing=true;game.paused=false;paused=false
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;game.model.update_vision(home)
 game.army_runtime.refresh_kits()
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 var p=game.player;var unsupported=0
 for character in Gear.Roster.CROSSGATE:
  p.select_character(character);game.update_character_tuning(character,"critical_chance",0)
  var copied=false
  for skin_key in Gear.catalog()[str(character)]:
   var skin=int(skin_key);choose_skin(character,skin)
   var choices:Dictionary=Gear.allowed(character,game.settings)
   if not choices.has("unarmed"):unsupported+=1;continue
   equip_weapon(character,"unarmed")
   for direction in 8:
    var pattern:Dictionary=p.model.normal_attack_pattern(Vector3.FORWARD.rotated(Vector3.UP,direction*PI/4))
    check(pattern.contacts.all(func(at):return at>=0 and at<pattern.duration),"Fist source contacts remain valid within every facing")
   fist_contact_case(character,skin)
   p.powerups.range=1;p.powerups.attack_speed=1;p.attack_speed_stacks=20
   check(is_equal_approx(p.melee_range_multiplier(),1.5625*1.5) and p.attack_speed_multiplier()==3.0,"Fists retain range upgrades and the final 3x speed cap")
   p.powerups.range=0;p.powerups.attack_speed=0;p.attack_speed_stacks=0
   if not copied:
    await native_fists(character);await fist_picture(character);copied=true
   var other=choices.keys().filter(func(weapon):return weapon!="unarmed")
   if not other.is_empty():
    equip_weapon(character,other[0])
    var rate=1.0 if other[0] in ["bow","kunai"] else 1.2
    check(is_equal_approx(p.attack_speed_multiplier(),rate) and is_equal_approx(p.melee_range_multiplier(),1.25),"Switching away removes only the fist bonuses")
    check(is_equal_approx(game.world.attack_range.radius(p),p.melee_strike_reach()),"Switching weapons refreshes the range outline")
   await frames()
  print("FIST_CHARACTER id=",character," cases=",fist_rows.size()," failures=",failures)
 var report=FileAccess.open(FIST_OUT+"timings.json",FileAccess.WRITE);report.store_string(JSON.stringify(fist_rows,"  "));report.close()
 print("FIST_FEEL_RESULT checks=%d failures=%d supported_appearances=%d unsupported_appearances=%d"%[checks,failures,fist_rows.size(),unsupported])
 game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
