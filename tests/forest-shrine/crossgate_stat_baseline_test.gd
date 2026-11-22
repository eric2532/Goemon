extends "res://tests/forest-shrine/weapon_equipment_test.gd"

const Balance=preload("res://scripts/character_balance.gd")
const RESET_OUT="res://build/Other Files/Asset Toolkit/Character Stat Reset/"

func expanded_contact_case():
 var p=game.player
 p.ai_controlled=true;p.ai_aim=home+Vector3.FORWARD*20;p.position=home
 var kit=p.active_ability
 var profile:Dictionary=game.character_tuning.get_or_add(Balance.key_for(p.character_id),{})
 game.army_runtime.clear();game.model.enemies.clear();await frames()
 var probe=spawn(Vector3.FORWARD*8)
 var half_depth=probe.combat_bounds().end.z-probe.global_position.z
 var distance=p.melee_strike_reach()/Hero.CROSSGATE_MELEE_REACH*1.125+half_depth
 game.army_runtime.clear();game.model.enemies.clear();await frames()
 var target=spawn(Vector3.FORWARD*distance)
 var before:float=target.hp
 profile.melee_reach=1.0/Hero.CROSSGATE_MELEE_REACH
 kit.cancel();p.attack_chain.reset();kit.start_attack()
 kit.tick(kit.duration/p.attack_speed_multiplier()+.01)
 check(target.hp==before,"A native target between the old and new reach is outside the old envelope")
 profile.erase("melee_reach")
 kit.cancel();p.attack_chain.reset();kit.start_attack()
 var pattern:Dictionary=p.model.normal_attack_pattern()
 var rate=p.attack_speed_multiplier()
 kit.tick((float(pattern.contacts[0])-.001)/rate)
 check(target.hp==before,"Faster melee still waits for its original animation contact")
 kit.tick(.002/rate)
 check(is_equal_approx(before-target.hp,Skills.basic_damage(pattern)),"The faster first cut reaches the newly reachable native target exactly once")
 if DisplayServer.get_name()!="headless":
  p.model.show_pose(5,kit.elapsed,true)
  game.camera_rig.set_process(false)
  game.camera_rig.camera.global_position=home+Vector3(0,12,20)
  game.camera_rig.camera.look_at(home+Vector3(0,2,-4))
  game.army_runtime.flush_presentation();game.forest_ui.sync()
  await frames();await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(RESET_OUT+"melee-expanded-contact.png")==OK,"Captured the expanded melee contact in rendered gameplay")
 kit.tick(float(pattern.duration)/rate)
 check(is_equal_approx(before-target.hp,Skills.basic_damage(pattern)*pattern.contacts.size()),"The full expanded swing preserves damage per source contact")
 kit.cancel();p.ai_controlled=false

func run():
 create_timer(240).timeout.connect(func():printerr("STAT_BASELINE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(RESET_OUT)
 cfg="user://crossgate-stat-baseline-%d.cfg"%OS.get_process_id()
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg
 root.add_child(game);current_scene=game;await frames()
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player
 game.character_tuning.goemon={"max_hp":321.0,"damage_mult":1.25}
 var settings=game.settings.duplicate(true);var core=game.core_balance.duplicate(true)
 var baseline=game.tuning.duplicate(true)
 var rows=[]
 for id in Gear.Roster.CROSSGATE:
  p.select_character(id)
  game.update_character_tuning(id,"max_hp",2000)
  game.update_character_tuning(id,"damage_mult",3)
  game.update_character_tuning(id,"critical_chance",100)
  game.reset_character_tuning(id)
  check(p.max_hp==1000 and p.damage_multiplier()==1 and p.magic_damage_multiplier()==1,"Fighter %d resets live health and both damage channels"%id)
  for key in ["critical_chance","dodge_chance","counter_chance"]:
   check(p.combat_tuning(key)==5,"Fighter %d starts with 5%% %s"%[id,key])
  for key in ["walk_speed","sprint_speed","jump_speed","second_jump_speed"]:
   check(p.combat_tuning(key)==PrototypeTuning.DEFAULTS[key],"Fighter %d retains original %s"%[id,key])
  check(p.combat_tuning("attack_speed")==1 and p.combat_tuning("melee_reach")==1 and p.combat_tuning("jump_height")==1,"Fighter %d keeps saved tuning separate from the melee trial and jump scale"%id)
  game.show_character_balance(false,id);await frames()
  check(game.menu.find_child("Balance_max_hp",true,false).value==1000,"Fighter %d displays its shared HP default"%id)
  check(not game.character_tuning.has(Balance.key_for(id)),"Reset clears only the selected profile")
 check(game.settings==settings and game.core_balance==core and game.tuning==baseline and game.character_tuning.goemon=={"max_hp":321.0,"damage_mult":1.25},"Reset preserves equipment, skills, preferences, enemies and hidden character balance")
 game.character_tuning.clear();game.load_settings()
 for id in Gear.Roster.CROSSGATE:check(game.balance_value(id,"max_hp")==1000 and game.balance_value(id,"damage_mult")==1,"Fighter %d keeps the baseline after save/reload"%id)
 check(game.character_tuning.goemon=={"max_hp":321.0,"damage_mult":1.25},"Hidden saved profile survives reload")
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false
 game.begin_arena();game.choose_rogue_character(34);await frames()
 game.equipment_hub.enter_map();await frames()
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05;p.position=home
 game.model.update_vision(home);game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 for id in Gear.Roster.CROSSGATE:
  if id==Gear.Roster.MAZE_ID:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE
  p.select_character(id)
  for weapon in Gear.allowed(id,game.settings):
   equip_weapon(id,weapon)
   var pattern:Dictionary=p.model.normal_attack_pattern()
   var melee=weapon not in ["bow","kunai"]
   var speed=Hero.CROSSGATE_MELEE_SPEED if melee else 1.0
   if weapon=="unarmed":speed*=Hero.CROSSGATE_FIST_SPEED
   check(is_equal_approx(p.attack_speed_multiplier(),speed),"Fighter %d %s applies melee tempo only to melee weapons"%[id,weapon])
   var reach_factor=Hero.CROSSGATE_MELEE_REACH*(Hero.CROSSGATE_FIST_REACH if weapon=="unarmed" else 1.0)
   check(is_equal_approx(p.melee_range_multiplier(),reach_factor),"Melee and fist reach factors apply before existing upgrades")
   if melee:
    var reach=p.melee_strike_reach()
    var profile:Dictionary=game.character_tuning.get_or_add(Balance.key_for(id),{})
    profile.melee_reach=.8
    check(is_equal_approx(p.melee_strike_reach()*1.25,reach),"Actual weapon envelope expands by 25 percent")
    profile.erase("melee_reach")
    check(is_equal_approx(game.world.attack_range.radius(p),reach),"The ground outline matches the expanded melee reach")
   check(p.model.current_weapon()==("sword" if weapon=="three-weapon" else weapon),"The selected appearance applies its requested weapon mechanics")
   check(pattern.duration>0 and not pattern.contacts.is_empty(),"Fighter %d %s exposes its source attack cycle"%[id,weapon])
   for direction in 8:
    var directional:Dictionary=p.model.normal_attack_pattern(Vector3.FORWARD.rotated(Vector3.UP,direction*PI/4))
    check(is_equal_approx(Skills.basic_damage(directional),50),"Fighter %d %s direction %d starts at 50 damage per contact"%[id,weapon,direction])
   rows.append({"character":Gear.Roster.name_for(id),"id":id,"skin":Gear.Roster.selected_skin(id,game.settings),"weapon":weapon,"cycle_seconds":pattern.duration,"contacts":pattern.contacts.size(),"projectiles":pattern.projectiles,"base_damage_per_contact":Skills.basic_damage(pattern),"nominal_damage_per_second":Skills.basic_damage(pattern)*pattern.contacts.size()*int(pattern.projectiles)/float(pattern.duration)})
   attack_case(id,weapon)
   check(is_equal_approx(p.active_ability.ticket.normal_attack_damage,Skills.basic_damage(p.model.normal_attack_pattern())),"Normal attack snapshots its receiving weapon's damage")
   var previous=p.active_ability.ticket.normal_attack_damage
   game.model.team_progression.stat_ranks.attack_speed=1
   check(is_equal_approx(p.attack_speed_multiplier(),speed*1.1) and p.active_ability.ticket.normal_attack_damage==previous,"Attack-speed upgrades stack with melee tempo without reducing saved per-hit damage")
   game.model.team_progression.stat_ranks.attack_speed=0
 var report=FileAccess.open(RESET_OUT+"weapon-cycles.json",FileAccess.WRITE)
 report.store_string(JSON.stringify(rows," "));report.close()
 game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").DEFAULT
 p.select_character(34);equip_weapon(34,"sword")
 await expanded_contact_case()
 game.army_runtime.clear();game.model.enemies.clear();await frames()
 var target=spawn(Vector3(0,0,-1.6))
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 9:check(mirrors.reinforce(34,home),"Simultaneous attacker uses the existing native army")
 var warm_nodes=0;var warm_resources=0;var pool_misses=pool.misses
 var mirror_profile:Dictionary=game.character_tuning[Balance.key_for(34)]
 for previous in [true,false]:
  if previous:
   mirror_profile.melee_reach=1.0/Hero.CROSSGATE_MELEE_REACH
   mirror_profile.attack_speed=1.0/Hero.CROSSGATE_MELEE_SPEED
  else:
   mirror_profile.erase("melee_reach");mirror_profile.erase("attack_speed")
  var attack_costs=[]
  for cycle in 10:
   var before:float=target.hp
   for body in mirrors.bodies:
    body.ai_target=target;body.ai_aim=target.global_position;body.attack_chain.reset()
    body.active_ability.cancel();body.active_ability.start_attack()
   for tick in 40:
    var started=Time.get_ticks_usec()
    for body in mirrors.bodies:body.active_ability.tick(DT)
    game.crowd.army.presentation.tick(DT)
    game.native_ink_feedback.tick(DT)
    if cycle>=2:attack_costs.append((Time.get_ticks_usec()-started)/1000.0)
   check(is_equal_approx(before-target.hp,900),"Nine simultaneous native sword cycles deal exactly 9 × 2 × 50 damage")
   if cycle==1:
    await frames();warm_nodes=get_node_count();warm_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  print("BASIC_ATTACK_REUSE previous=",previous," nodes=",warm_nodes,"/",get_node_count()," resources=",warm_resources,"/",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
  print("BASIC_ATTACK_NINE_COPY_MS previous=",previous," ",preload("res://tests/forest-shrine/army_benchmark_metrics.gd").summary(attack_costs))
  check(get_node_count()<=warm_nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=warm_resources and pool.misses==pool_misses,"Repeated simultaneous attacks retain no warmed nodes/resources or pool misses")
 mirrors.dispose();await frames()
 for id in Gear.Roster.CROSSGATE:game.reset_character_tuning(id)
 game.select_kaz_skin(preload("res://scripts/kaz_skins.gd").DEFAULT)
 game.forest_ui.hide()
 game.show_character_balance(false,Gear.Roster.KAZI_ID);await frames()
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(RESET_OUT+"baseline.png")==OK,"Captured shared baseline settings")
  root.size=Vector2i(960,640);await frames();await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(RESET_OUT+"baseline-small.png")==OK,"Captured smaller baseline settings")
 game.queue_free();paused=false;await frames()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("STAT_BASELINE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
