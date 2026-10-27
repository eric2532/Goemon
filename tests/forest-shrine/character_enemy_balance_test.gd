extends "res://tests/forest-shrine/jump_styles_test.gd"
const Balance=preload("res://scripts/character_balance.gd")
const Core=preload("res://scripts/forest/core_balance.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
func control(name_:String):return game.menu.find_child(name_,true,false)
func settle():
 for i in 4:await process_frame
func capture_menu(label_:String):
 if DisplayServer.get_name()=="headless":return
 await settle();RenderingServer.force_draw();await process_frame
 root.get_texture().get_image().save_png("res://build/Other Files/Character and Enemy Balance/"+label_+".png")
func run():
 DirAccess.make_dir_recursive_absolute("res://build/Other Files/Character and Enemy Balance")
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
 root.add_child(game);current_scene=game;await settle()
 game.set_process_input(false);game.set_process_unhandled_input(false)
 hero=game.player;hero.set_process_input(false);hero.set_process_unhandled_input(false)
 game.set_physics_process(false);hero.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.spell_loadouts={};game.settings.jump_styles={};game.tuning.invincible=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();driver.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(driver)
 root.title="Goemon Character and Enemy Balance Verification";root.grab_focus()
 game.show_settings(false);await settle();await capture_menu("settings")
 check(control("EnemyBalanceButton")!=null,"Settings exposes Enemy Balance beside Character Balance")
 for id in Balance.Roster.PLAYABLE_IDS:
  game.show_character_balance(false,id);await settle()
  check(control("BalanceCharacter").item_count==Balance.Roster.PLAYABLE_IDS.size() and control("Balance_jump_height")!=null,"Fighter %d has jump height in the balance editor"%id)
  control("Balance_jump_height").value=2.0
  check(game.balance_value(id,"jump_height")==2.0,"Fighter %d saves independent jump height"%id)
  game.reset_character_tuning(id)
 game.show_character_balance(false,28);await capture_menu("character-balance")
 var before=game.balance_value(23,"max_hp")
 var snapshot=game.model.balance.duplicate(true)
 for type in Core.TYPES:
  game.show_enemy_balance(false,type);await settle()
  check(control("BalanceEnemy").item_count==10,"Enemy %d is selectable with every AI type"%type)
  control("Enemy_hp").value=1234+type
  control("Enemy_damage").value=37+type
  control("Enemy_speed").value=12+type
  check(game.core_balance.enemy_profiles[str(type)]=={"hp":1234.0+type,"damage":37.0+type,"speed":12.0+type},"Enemy %d saves health, damage and movement"%type)
 check(game.model.balance==snapshot,"Editing AI settings preserves the current run snapshot")
 check(game.balance_value(23,"max_hp")==before,"AI enemy edits do not change playable Vambee")
 game.update_character_tuning(23,"max_hp",444)
 check(game.core_balance.enemy_profiles["6"].hp==1240,"Playable Vambee edits do not change AI Vambee")
 game.update_character_tuning(28,"jump_height",1.75)
 game.save_settings();game.character_tuning.clear();game.core_balance=Core.defaults();game.load_settings()
 check(game.balance_value(28,"jump_height")==1.75 and game.core_balance.enemy_profiles.size()==10,"Player and enemy profiles survive saving and reloading")
 game.update_enemy_tuning(6,"hp",NAN);game.update_enemy_tuning(999,"hp",100)
 check(game.core_balance.enemy_profiles["6"].hp==1240 and not game.core_balance.enemy_profiles.has("999"),"Invalid enemy values and types are rejected")
 var malformed=Core.sanitized({"enemy_profiles":{"6":{"hp":INF,"damage":-100,"speed":"bad"},"999":{"hp":5}}})
 check(malformed.enemy_profiles=={"6":{"damage":0.0}},"Saved enemy profiles reject invalid data and bound numeric values")
 game.reset_enemy_tuning(6)
 check(not game.core_balance.enemy_profiles.has("6") and game.core_balance.enemy_profiles.size()==9,"Reset changes only the selected enemy")
 game.show_enemy_balance(false,18);await capture_menu("enemy-balance")
 var escape=InputEventAction.new();escape.action="pause";escape.pressed=true
 game._input(escape);await settle()
 check(control("EnemyBalanceButton")!=null,"Escape returns Enemy Balance to Settings")
 game.resume();game.start_wave();game.model.waves.spawn_clock=100000
 check(game.model.balance.enemy_profiles==game.core_balance.enemy_profiles,"The next wave applies AI profiles")
 var payload=Kits.from_model(game.model)
 for type in Core.TYPES:
  var stats=game.model.waves.role_stats(type)
  var base=Core.EnemyBalance.base_stats(game.core_balance,type)
  check(is_equal_approx(stats.hp,base.hp*(1 if type==4 else game.core_balance.enemy_health_mult)) and is_equal_approx(stats.speed,base.speed*game.core_balance.enemy_speed_mult) and is_equal_approx(stats.damage,base.damage*game.core_balance.enemy_damage_mult),"Enemy %d uses per-type values and existing shared multipliers"%type)
  var index=payload.soldier_kinds.find(type)
  if index>=0:check(is_equal_approx(payload.soldier_profiles[index*6+2],stats.damage) and is_equal_approx(payload.soldier_profiles[index*6+1],stats.speed),"Enemy %d reaches native army damage and movement profiles"%type)
  else:check(is_equal_approx(payload.skullpion[0],stats.speed) and is_equal_approx(payload.skullpion[1],stats.damage),"Skullpion reaches its existing native kit")
 var enemy=game.model.waves.spawn_enemy(18,Vector3(60,0,100));game.army_runtime.import_arrivals()
 check(is_equal_approx(game.army_runtime.unit_state(game.army_runtime.handles[enemy.id]).hp,enemy.max_hp),"Edited enemy health reaches a spawned native unit")
 game.core_balance.enemy_profiles["18"].hp=99
 check(game.model.balance.enemy_profiles["18"].hp==1252,"Saved edits cannot mutate an active wave's profile")
 game.update_character_tuning(8,"jump_height",2.0)
 var ally_payload=Kits.from_model(game.model,1.0,game)
 check(is_equal_approx(ally_payload.dragoon[10],game.balance_value(8,"jump_speed")*sqrt(2.0)),"Native Dragoon receives its character's jump-height multiplier")
 game.reset_character_tuning(8)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 runtime.configure_kits(payload);runtime.set_navigation(1,{"width":0})
 for i in 12:
  runtime.spawn(100+i,0,0,Vector3(i*24,0,0),3702,.4)
  runtime.spawn(-100-i,1,12,Vector3(i*24,0,-1.5),100000,.4)
 var contacts={}
 for tick in 240:
  runtime.step(1.0/60,{})
  for event in runtime.take_events():
   if event.kind=="damage":
    check(is_equal_approx(event.amount,74.0),"Simultaneous native strike uses the edited damage")
    contacts[event.source_id]=int(contacts.get(event.source_id,0))+1
 check(contacts.size()==12 and contacts.values().all(func(count):return count==4),"Twelve AI soldiers repeat two attack cycles without lost or duplicate contacts")
 runtime.free()
 game.reset_character_tuning(28)
 origin.y=game.world.height_at(origin.x,origin.z)+.1
 var floor_body=StaticBody3D.new();floor_body.collision_layer=1
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(200,1,200)
 floor_body.add_child(shape);game.add_child(floor_body);floor_body.position=origin-Vector3.UP*.6
 await physics_frame;await physics_frame
 for row in [[1,""],[5,""],[13,""],[19,""],[27,""],[29,""],[28,""],[1,"musashi"],[1,"sonic"],[1,"ranger"]]:
  game.update_character_tuning(row[0],"jump_height",1.0)
  var original=await apex(row[0],row[1],45)
  game.update_character_tuning(row[0],"jump_height",2.0)
  var higher=await apex(row[0],row[1],45)
  check(original>.1 and higher>original*1.7 and higher<original*2.3,"%d / %s actual jump height scales near 2x (%.3f / %.3f)"%[row[0],row[1],original,higher])
  game.reset_character_tuning(row[0])
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await settle()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CHARACTER_ENEMY_BALANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
