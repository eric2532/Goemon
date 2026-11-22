extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/Enemy Fly Away/"
func picture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REVIEW+name_+".png")==OK,"Captured "+name_)
func run():
 create_timer(180).timeout.connect(func():printerr("FLY_AWAY_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(REVIEW+"frames");root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 for node in [game,game.player,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 game.player.select_character(34);fresh();home.y=game.model.surface_height(home.x,home.z)+.05
 game.player.position=home+Vector3(0,0,4);game.training_dummy.position=home+Vector3.DOWN*1000
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 game.settings.forest_pet_loadout=[];game.army_runtime.refresh_kits();game.model.update_vision(home)
 game.camera_rig.camera.global_position=home+Vector3(5,12,22);game.camera_rig.camera.look_at(home+Vector3(3,1,-2))
 if DisplayServer.get_name()!="headless":DisplayServer.window_move_to_foreground()
 var army=game.army_runtime;var fx=game.crowd.army.presentation
 army.clear();game.model.enemies.clear();fx.clear();army.record_events=true
 for critical in [false,true]:
  var enemy=spawn(Vector3.ZERO,100);var handle:int=enemy.handle;var kills:int=game.kills
  army.apply_hit(handle,{"amount":100,"critical":critical,"direction":Vector3.RIGHT})
  army.flush_presentation()
  check(enemy.dead and not army.valid(handle) and game.kills==kills+1,"Lethal contact removes combat and awards exactly one kill")
  check(fx.corpses.size()==1 and fx.corpses[0].has("flight_origin")==critical,"Only the critical exact-health kill launches")
  if critical:
   fx.tick(.4)
   check(fx.corpses[0].position.distance_to(home+Vector3(5,3.4,0))<.15,"Body follows a five-metre midpoint arc")
   check(fx.voices.any(func(v):return v.stream==fx.FLY_SOUND),"Launch uses the recovered sound through the existing voice pool")
   await picture("critical-midflight")
  fx.tick(2);army.sync_compatibility();await frames(2)
  check(fx.corpses.is_empty(),"Both normal and flying deaths release their corpse slots")
 # The player-facing facade must pass its rolled critical into native combat.
 var enemy=spawn(Vector3.ZERO,100);game.update_character_tuning(34,"critical_chance",100)
 enemy.take_hit(100,Vector3.RIGHT,false,game.player.attack_chain.make_ticket("kazi_sword"));army.flush_presentation()
 check(fx.corpses.size()==1 and fx.corpses[0].has("flight_origin"),"Cross Gate player's critical reaches the native death owner")
 fx.tick(2);army.sync_compatibility();await frames(2);game.update_character_tuning(34,"critical_chance",0)
 # Active multi-hit sequences keep the body at contact until their final release.
 enemy=spawn(Vector3.ZERO,100);enemy.retain_sequence();var kills:int=game.kills
 army.apply_hit(enemy.handle,{"amount":125,"direction":Vector3.RIGHT});army.flush_presentation()
 var corpse:Dictionary=fx.corpses[0]
 for i in 90:fx.tick(DT)
 check(fx.corpse_held(corpse) and corpse.age==0 and not corpse.flight_started and corpse.position.distance_to(home)<.15,"Combo holds the corpse and delays flight/audio")
 enemy.release_sequence();fx.tick(.2)
 check(corpse.flight_started and corpse.position.x>home.x+2,"Flight starts on sequence release")
 await picture("overkill-launch")
 fx.tick(1);army.sync_compatibility();await frames(2)
 check(fx.corpses.is_empty() and game.kills==kills+1 and not is_instance_valid(enemy),"Combo release cleans flight and facade without another reward")
 # Every recovered enemy sprite family reuses the same corpse/flight owner.
 var kits=load("res://scripts/forest/crowd/army_kit_data.gd")
 for family in ["slime","zombie","grave","captain","ruby_boss","falan_frontier","habaru","undersea"]:
  var sprites=load("res://scripts/forest/crowd/"+family+"_sprites.gd")
  var kit:Dictionary=kits.from_model(game.model,1.0,game);kit.cave_sprites=sprites
  game.crowd.army.configure_profiles(kit)
  enemy=spawn(Vector3.ZERO,100)
  army.apply_hit(enemy.handle,{"amount":125,"direction":Vector3.RIGHT});army.flush_presentation();fx.tick(.4)
  check(fx.corpses.size()==1 and fx.corpses[0].position.x>home.x+4.9,family+" uses the shared flight")
  if family in ["habaru","undersea"]:await picture(family+"-flight")
  fx.tick(1);army.sync_compatibility();await frames(2)
 game.crowd.army.configure_profiles(kits.from_model(game.model,1.0,game))
 # Reuse the existing bounded batches under simultaneous and repeated deaths.
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var samples:Array[int]=[]
 for cycle in 3:
  for i in 150:
   var body=spawn(Vector3((i%15)*.12,0,-(i/15)*.12),100)
   army.apply_hit(body.handle,{"amount":150,"direction":Vector3.RIGHT})
  army.flush_presentation()
  check(fx.corpses.size()==fx.corpse_capacity,"Mass deaths respect the existing corpse cap")
  for i in 55:
   var begin=Time.get_ticks_usec();fx.tick(DT);samples.append(Time.get_ticks_usec()-begin)
   if cycle==0 and DisplayServer.get_name()!="headless":await picture("frames/%03d"%i)
  army.sync_compatibility();await frames(3)
  check(fx.corpses.is_empty(),"Repeated mass flights all expire")
 print("FLY_REUSE nodes=",get_node_count()-nodes," resources=",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated deaths retain no additional nodes/resources")
 samples.sort();print("FLY_PRESENT_US p95=",samples[floori(samples.size()*.95)]," max=",samples.back())
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("FLY_AWAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
