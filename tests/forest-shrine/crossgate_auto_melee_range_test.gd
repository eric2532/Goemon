extends "res://tests/forest-shrine/weapon_equipment_test.gd"
const AUTO_OUT="res://build/Other Files/Asset Toolkit/Auto Melee Range/"

func auto_target(distance_:float)->Ninja:
 var p=game.player;var army=game.army_runtime
 p.active_ability.cancel(true);p.attack_chain.reset();p.position=home;p.impact_pause=0
 army.clear();game.model.enemies.clear();army.refresh_kits()
 var target=spawn(Vector3.FORWARD*distance_)
 p.auto_attack_enabled=true;p.auto_lock_target=target;p.auto_lock_refresh=100;p.auto_lock_had_target=true
 return target

func range_case(character:int,weapon:String,multiplier:float):
 var p=game.player;var kit=p.active_ability
 p.accessory_bonuses.range=multiplier
 var reach=p.melee_strike_reach()
 var target=auto_target(reach+8);var hp_:float=target.hp
 check(not p.auto_attack_running(),"J waits outside melee reach %d/%s/x%.0f"%[character,weapon,multiplier])
 for i in 90:kit.tick(DT)
 check(not kit.is_attacking() and target.hp==hp_,"Distant targets cause no automatic swing or damage")
 kit.cancel(true);p.auto_lock_target=null;p.auto_lock_had_target=false
 check(not p.auto_attack_running(),"J waits without a target")
 kit.start_attack()
 check(kit.is_attacking(),"A manual melee attack can still swing without a target")
 target=auto_target(reach*.55);hp_=target.hp
 check(p.auto_attack_running(),"J resumes inside equipped melee reach")
 kit.tick(DT)
 check(kit.is_attacking() and target.hp==hp_,"Automatic melee keeps its source windup")
 var pattern:Dictionary=p.model.normal_attack_pattern()
 kit.advance_attack(float(pattern.duration)/p.attack_speed_multiplier()+.001)
 check(target.hp<hp_,"In-range automatic melee hits a real native enemy")
 kit.cancel(true);p.auto_attack_enabled=false

func run():
 create_timer(600).timeout.connect(func():printerr("AUTO_MELEE_RANGE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(AUTO_OUT);root.size=Vector2i(1280,800);root.gui_disable_input=true
 cfg="user://crossgate-auto-melee-%d.cfg"%OS.get_process_id()
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 for node in [game,game.player,game.camera_rig]:node.set_process_input(false);node.set_process_unhandled_input(false)
 game.settings.forest_pet_loadout=[];game.settings.gear_loadouts={};game.settings.disable_character_cooldowns=false
 game.begin_arena();game.choose_rogue_character(34);await frames(3);game.equipment_hub.enter_map();await frames(3)
 game.clear_menu();game.forest_ui.hide();game.playing=true;game.paused=false;paused=false
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;game.model.update_vision(home)
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 var p=game.player
 game.camera_rig.camera.global_position=home+Vector3(0,8,18);game.camera_rig.camera.look_at(home+Vector3(0,1,-5));game.camera_rig.camera.make_current()
 Pool.service(game).launched.connect(func(shot):shot.set_physics_process(false);shot.retire())
 for character in Gear.Roster.CROSSGATE:
  p.select_character(character);game.update_character_tuning(character,"critical_chance",0)
  if character==Gear.Roster.MAZE_ID:choose_skin(character,0)
  for weapon in Gear.allowed(character,game.settings):
   equip_weapon(character,weapon)
   if weapon in ["bow","kunai"]:
    auto_target(30)
    check(p.auto_attack_running(),"Ranged J attacks retain their current range")
    p.auto_attack_enabled=false
   else:
    for multiplier in [1.0,2.0,6.0]:range_case(character,weapon,multiplier)
  print("AUTO_MELEE_CHARACTER id=",character," checks=",checks," failures=",failures)
 p.select_character(34);p.accessory_bonuses.erase("range")
 auto_target(40);p.accessory_bonuses.primary="fire"
 check(p.auto_attack_running(),"The Fire basic-attack replacement remains ranged")
 p.accessory_bonuses.erase("primary")
 var target=auto_target(p.melee_strike_reach()*.55)
 var event=InputEventKey.new();event.keycode=KEY_J;event.physical_keycode=KEY_J;event.pressed=true
 p._unhandled_input(event)
 check(not p.auto_attack_enabled and not p.auto_attack_running(),"Physical J toggles automatic melee off")
 p._unhandled_input(event)
 check(p.auto_attack_enabled and p.auto_attack_running(),"Physical J toggles in-range automatic melee on")
 p.position.y+=100
 check(not p.auto_attack_running(),"A target far below cannot trigger automatic melee")
 p.position=home
 target=auto_target(p.melee_strike_reach()*.9)
 var wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new()
 box.size=Vector3(10,10,.2);shape.shape=box;wall.add_child(shape);game.add_child(wall)
 var origin=home+Vector3.UP*1.1*p.growth_multiplier()
 wall.position=origin.lerp(AttackChain.contact_point(target,origin,target.global_position),.5)
 await physics_frame;await frames(3)
 check(not p.auto_attack_running(),"Solid cover still blocks automatic melee")
 wall.free();await physics_frame;await frames(3)
 check(p.auto_attack_running(),"Removing cover permits automatic melee again")
 game.paused=true;check(not p.auto_attack_running(),"Pause still suspends automatic melee");game.paused=false
 p.defend_held=true;check(not p.auto_attack_running(),"Guard still suspends automatic melee");p.defend_held=false
 p.active_ability.tick(DT);p.model.animate(DT,0,true,0,0,false,0,false)
 if DisplayServer.get_name()!="headless":
  await frames(3);await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(AUTO_OUT+"in-range.png")==OK,"Captured an in-range automatic swing")
 p.active_ability.cancel(true);auto_target(p.melee_strike_reach()+4)
 p.active_ability.tick(DT);p.model.animate(DT,0,false,0,0,false,0,false)
 if DisplayServer.get_name()!="headless":
  await frames(3);await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(AUTO_OUT+"out-of-range.png")==OK,"Captured J waiting outside reach")
 print("AUTO_MELEE_RANGE_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
