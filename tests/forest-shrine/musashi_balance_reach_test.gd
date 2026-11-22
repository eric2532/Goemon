extends "res://tests/forest-shrine/musashi_techniques_test.gd"
## Actual settings UI, source-clock movement, painted reach and native contacts.
const REVIEW="res://build/Other Files/Asset Toolkit/Musashi Balance Reach/"
const RangeIndicator=preload("res://scripts/forest/player_attack_range.gd")
var report={}
func advance(count:int):
 await driver.advance(count,func(delta):
  var started=Time.get_ticks_usec()
  p._physics_process(delta)
  if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(delta)
  times.append((Time.get_ticks_usec()-started)/1000.0))
func place_enemy(point:Vector3):
 game.army_runtime.set_pose(enemy.handle,point,0)
 game.army_runtime.sync_targets()
func run():
 create_timer(120,true,false,true).timeout.connect(func():printerr("MUSASHI_BALANCE_REACH_TIMEOUT");quit(1))
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
 root.add_child(game);current_scene=game
 for i in 6:await process_frame
 game.start_wave();game.tuning.freeze_ai=true;game.tuning.invincible=true;game.tuning.critical_chance=0;game.character_tuning={}
 for node in [game,game.army_runtime]:node.set_process(false);node.set_physics_process(false)
 game.camera_rig.process_mode=Node.PROCESS_MODE_DISABLED;game.music.stop()
 p=game.player;p.select_character(13);p.set_physics_process(false);c=p.active_ability
 origin=Vector3(-60,game.model.surface_height(-60,60)+.05,60)
 driver=preload("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 plant();await advance(4)
 check(p.is_on_floor(),"Movement fixture starts on Wind Meadow ground")
 game.show_character_balance(false,13);await process_frame
 var control=game.menu.find_child("Balance_walk_speed",true,false)
 check(control!=null,"Musashi exposes the existing Run speed control")
 control.value=10.2;game.resume();plant();p.smoke_move=Vector2.RIGHT
 await advance(110)
 var baseline=Vector2(p.velocity.x,p.velocity.z).length()
 check(absf(baseline-5.94*p.character_size_multiplier())<.01,"Default Run speed preserves Musashi's recovered maximum pace")
 game.show_character_balance(false,13);await process_frame
 control=game.menu.find_child("Balance_walk_speed",true,false);control.value=20.4;game.resume()
 await advance(4)
 var faster=Vector2(p.velocity.x,p.velocity.z).length()
 check(absf(faster-baseline*2)<.01,"Editing the real Run speed control doubles live movement")
 report.default_speed=baseline;report.doubled_speed=faster
 game.character_tuning.clear();game.load_settings()
 check(is_equal_approx(game.balance_value(13,"walk_speed"),20.4),"Musashi's edited speed survives save and reload")
 p.select_character(1);p.select_character(13);plant();await advance(4)
 check(is_equal_approx(p.combat_tuning("walk_speed"),20.4),"Edited speed survives character reselection")
 game.reset_character_tuning(13);plant();await advance(4)
 var row=game.model.waves.spawn_enemy(0,origin+Vector3.FORWARD*3);row.hp=100000;row.max_hp=100000
 game.model.update_vision(origin);game.sync_enemies();enemy=game.actors[row.id]
 check(enemy.handle!=0,"Sword contact uses a real native enemy")
 var indicator=RangeIndicator.new();var base_radius=indicator.radius(p)
 p.attack_heavy=true
 check(is_equal_approx(indicator.radius(p),base_radius) and base_radius>=c.blade_reach(true),"Ground outline covers both basic swords regardless of previous attack")
 for reach in [1.0,4.0]:
  game.update_character_tuning(13,"melee_reach",reach)
  for heavy in [false,true]:
   plant();await advance(4);c.start_attack(heavy)
   var key=c.action_key
   var at=(4.0 if not heavy else 11.0)/30.0
   var raw=p.model.sword_trail.pose_segment(key,at,p.model.rig_visual.global_transform)
   var pair=c.blade_segment(key,at)
   check(Vector2(pair[0].x-origin.x,pair[0].z-origin.z).length()>=c.blade_reach(heavy)-.001,"Painted blade reaches configured extent: %.0f / %s"%[reach,heavy])
   check(Vector2(pair[0].x-origin.x,pair[0].z-origin.z).length()+.25*p.contact_size_multiplier()<=indicator.radius(p)+.001,"Ground outline encloses traced blade: %.0f / %s"%[reach,heavy])
   var trail=p.model.sword_trail;trail.clear();trail.begin_action(key)
   for i in 3:trail.source_tick(raw,.03672,true,origin,c.blade_reach(heavy))
   check(trail.samples.back().outer.is_equal_approx(raw[0]) and trail.samples.back().wave_outer.is_equal_approx(pair[0]),"Original trail stays on source blade; painted wave follows contact reach")
   var hit_position=Vector3(pair[0].x,origin.y,pair[0].z)
   place_enemy(hit_position)
   var hp=enemy.hp
   c.elapsed=at;c.strike()
   check(enemy.hp<hp,"Native victim touching the painted blade is hit: %.0f / %s"%[reach,heavy])
   var once=enemy.hp;c.strike()
   check(enemy.hp==once,"Repeated contact samples never damage a victim twice")
   c.cancel();await advance(2)
   if DisplayServer.get_name()!="headless":
    game.world.sync(0)
    game.camera_rig.camera.global_position=origin+Vector3(16,22,28)*reach
    game.camera_rig.camera.look_at(origin+Vector3.UP*2)
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(REVIEW+"range-%.0f-%s.png"%[reach,heavy])==OK,"Captured range outline")
 # A target inside the old broad cone but away from this blade pose must miss.
 game.reset_character_tuning(13);plant();await advance(4);c.start_attack(false)
 place_enemy(origin+Vector3.FORWARD*3);var hp=enemy.hp
 c.elapsed=2.0/30.0;c.strike()
 check(enemy.hp==hp,"An enemy in the old cone is not hit before the blade reaches it")
 c.elapsed=4.0/30.0;c.strike()
 check(enemy.hp<hp,"The same target is hit when the source blade sweeps through it")
 game.update_character_tuning(13,"melee_reach",4.0)
 plant();await advance(4);c.start_attack(true)
 var far_pair=c.blade_segment(c.action_key,11.0/30.0)
 place_enemy(Vector3(far_pair[0].x,origin.y,far_pair[0].z));hp=enemy.hp
 var wall=StaticBody3D.new();wall.collision_layer=1
 var collider=CollisionShape3D.new();collider.shape=BoxShape3D.new();collider.shape.size=Vector3(8,12,.3)
 wall.add_child(collider);game.add_child(wall);wall.position=origin.lerp(enemy.position,.5)+Vector3.UP*4
 await physics_frame;await physics_frame
 c.elapsed=11.0/30.0;c.strike()
 check(enemy.hp==hp,"A wall still blocks an extended blade contact")
 wall.queue_free();await process_frame
 c.cancel();c.start_attack(true)
 place_enemy(origin+Vector3.FORWARD*(c.blade_reach(true)+10));hp=enemy.hp
 c.elapsed=11.0/30.0;c.strike()
 check(enemy.hp==hp,"A victim outside the configured reach remains unharmed")
 game.reset_character_tuning(13)
 # Reuse checks exercise prepared geometry without loading new assets.
 for cycle in 2:
  plant();c.start_attack(false);await advance(42)
 c.cancel();await advance(90)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 times.clear()
 for cycle in 12:
  plant();c.start_attack(false);await advance(42)
 c.cancel();await advance(90)
 report.retained_nodes=get_node_count()-nodes;report.retained_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated attacks retain no nodes or resources")
 check(c.contact_segments.is_empty(),"Cancellation clears cached contact samples")
 times.sort();report.step_p95_ms=times[int(times.size()*.95)];report.step_max_ms=times.back()
 report.checks=checks;report.failures=failures
 FileAccess.open(REVIEW+"result-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MUSASHI_BALANCE_REACH_RESULT ",JSON.stringify(report))
 game.queue_free();driver.queue_free();current_scene=null
 for i in 4:await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
