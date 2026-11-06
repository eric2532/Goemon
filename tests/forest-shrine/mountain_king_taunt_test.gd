extends "res://tests/forest-shrine/mountain_king_test.gd"
const REVIEW="res://build/Other Files/Mountain King Slam/Taunt/"
func press_four():
 var event=InputEventKey.new();event.physical_keycode=KEY_4;event.pressed=true
 game.player._unhandled_input(event)
 game.player.spell_loadout.number_input(4,false)
func capture_taunt(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 game.camera_rig.camera.global_position=home+Vector3(18,14,-30)
 game.camera_rig.camera.look_at(home+Vector3(0,6,0))
 game.player.model.pose(game.player.active_ability.clip,game.player.active_ability.elapsed)
 RenderingServer.force_draw();await process_frame
 check(root.get_texture().get_image().save_png(REVIEW+label_+".png")==OK,"Captured "+label_)
func check_pursuit():
 var p=game.player;var kit=p.active_ability;var owner=game.army_runtime
 var saved_home=home;var found=false
 owner.integration_tick(1.0/60)
 for candidate in [Vector3(-150,0,150),Vector3(-150,0,-100),Vector3(130,0,130),Vector3(130,0,-130)]:
  candidate.y=game.model.surface_height(candidate.x,candidate.z)+.1
  var reachable=true
  for offset in [-3,0,3]:
   var point=candidate+Vector3(36,0,offset);point.y=game.model.surface_height(point.x,point.z)+.1
   reachable=reachable and owner.native.can_reach(point,candidate,.7)
  if reachable:home=candidate;found=true;break
 check(found,"Pursuit fixture has three real walkable routes outside the castle walls")
 if not found:return
 kit.cancel();fresh();await advance(6)
 var victims=[];var distances=[]
 for offset in [-3,0,3]:
  var point=home+Vector3(36,0,offset);point.y=game.model.surface_height(point.x,point.z)+.1
  var row=game.model.waves.spawn_enemy(0,point);row.hp=10000;row.max_hp=10000
  victims.append(row.id)
 owner.integration_tick(1.0/60)
 for id in victims:
  var state=owner.unit_state(owner.handles[id]);distances.append(state.position.distance_to(p.position))
  check(state.external_kind!=0,"Distant soldier initially follows normal castle targeting")
 press_four()
 for i in 120:
  owner.integration_tick(1.0/60);await advance(1)
  if DisplayServer.get_name()!="headless":await physics_frame
 for i in victims.size():
  var state=owner.unit_state(owner.handles[victims[i]])
  check(state.external_kind==0 and state.position.distance_to(p.position)<distances[i]-2,"Taunted native soldier selects and moves toward Mountain King (target=%s, distance=%s→%s)"%[state.external_kind,distances[i],state.position.distance_to(p.position)])
 if DisplayServer.get_name()!="headless":
  game.camera_rig.camera.global_position=home+Vector3(20,30,-45);game.camera_rig.camera.look_at(home+Vector3(12,2,0))
  RenderingServer.force_draw();await process_frame
  check(root.get_texture().get_image().save_png(REVIEW+"native-pursuit.png")==OK,"Captured actual native enemy pursuit")
 kit.cancel()
 for id in victims:owner.despawn(owner.handles[id])
 owner.integration_tick(1.0/60)
 home=saved_home;fresh();await advance(6)
func run():
 create_timer(180).timeout.connect(func():printerr("MOUNTAIN_TAUNT_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(REVIEW)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data);game.tuning.invincible=true;game.set_process(false)
 home.y=game.model.surface_height(home.x,home.z)+.1
 game.camera_rig.set_process_unhandled_input(false)
 var p=game.player;p.select_character(33);fresh();await advance(6)
 var kit=p.active_ability;var pool=Pool.service(game)
 game.forest_ui.sync()
 check(p.spell_loadout.numbered_slots[3]==["Taunt · War Cry","special_4"],"Fourth slot exposes the native taunt")
 check("4  Taunt · War Cry" in game.forest_ui.spell_summary.text,"HUD teaches the fourth key")
 check(game.forest_ui.helper_portraits[3].visible and game.forest_ui.helper_portraits[3].texture==game.forest_ui.helper_portraits[2].texture,"Taunt reuses the exact Avatar icon artwork")
 check(game.forest_ui.helper_portraits[3].material==game.forest_ui.TAUNT_ICON_MATERIAL and game.forest_ui.helper_portraits[2].material==null,"Only the taunt icon receives the red material")
 var hp=game.training_dummy.hp;var created=pool.created;var misses=pool.misses
 p.set_auto_attack(true);await advance(1)
 check(kit.mode=="attack","Auto attack is active before fourth-key interruption")
 press_four()
 p.set_auto_attack(false)
 check(kit.mode=="taunt" and kit.clip=="Stand - 3","Real fourth-key event starts original challenge gesture")
 check(is_equal_approx(kit.duration,p.model.animation_player.get_animation("Stand - 3").length),"Gesture retains authored timing")
 check(game.last_sound_voice.stream==SoundLibrary.original_for(33,"wc_warcry"),"Taunt plays original Mountain King war cry")
 check(kit.ground_attack_velocity()==Vector3.ZERO,"Gesture keeps authored feet planted")
 check(game.army_runtime.external_targets().taunting[0] and kit.taunt_left==8,"Shout publishes eight seconds of player taunt priority")
 await advance(45);await capture_taunt("normal-taunt")
 var elapsed=kit.elapsed;press_four();tap("light_attack")
 check(kit.mode=="taunt" and kit.elapsed==elapsed and not kit.queued,"Busy presses neither restart nor queue attacks")
 await advance(160)
 check(not kit.is_attacking() and kit.clip.is_empty(),"Gesture ends through shared action lifecycle")
 check(game.training_dummy.hp==hp and contacts.is_empty(),"Taunt never damages nearby targets")
 check(game.army_runtime.external_targets().taunting[0],"Taunt priority outlasts the gesture")
 kit.tick_timers(8)
 check(not game.army_runtime.external_targets().taunting[0],"Player taunt priority expires")
 press_four();await advance(10);tap("dodge")
 check(kit.mode.is_empty(),"Evade interrupts taunt")
 await advance(60);press_four();kit.hit()
 check(kit.mode.is_empty(),"Hit response interrupts taunt")
 check(kit.taunt_left>0,"Interrupting the gesture preserves the active taunt")
 kit.start_avatar();await advance(30);press_four()
 check(kit.mode=="taunt" and kit.clip=="Alternate Stand - 3" and kit.demon,"Avatar reuses its matching original gesture")
 await advance(45);await capture_taunt("avatar-taunt")
 kit.cancel(true)
 check(kit.demon and kit.mode.is_empty(),"Interrupting Avatar taunt preserves the form")
 kit.end_avatar();fresh();await advance(6)
 # Setup costs stay outside the repeated action measurement.
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 12:
  press_four();await advance(200)
 check(pool.created==created and pool.misses==misses,"Repeated taunts allocate no projectile leases")
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated taunts retain no additional nodes or resources")
 await check_pursuit()
 p.position=home+Vector3.UP*8;p.velocity=Vector3.UP;p.move_and_slide();press_four()
 check(kit.mode.is_empty(),"Airborne taunt cannot replace jump animation")
 fresh();await advance(6)
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
 check(mirrors.cast(),"Five native-owned Mountain Kings prepare the same kit")
 await physics_frame;await physics_frame
 created=pool.created;misses=pool.misses
 for body in mirrors.bodies:
  body.position=home;body.velocity=Vector3.DOWN*20
  for i in 3:body.move_and_slide()
  body.set_auto_attack(false);body.active_ability.start_attack();body.press("special_4");body.release()
  check(body.active_ability.mode=="taunt","Allied Mountain King uses the same taunt input (floor=%s, active=%s, hp=%s, mode=%s, dodge=%s)"%[body.is_on_floor(),body.active_ability.active,body.hp,body.active_ability.mode,body.dodge_time])
  check(game.army_runtime.unit_state(body.native_handle).buff_left==8,"Allied taunt reaches the native status owner")
 for i in 210:
  mirrors.tick(1.0/60);await advance(1)
 check(mirrors.bodies.all(func(body):return body.active_ability.mode.is_empty()),"Simultaneous allied gestures complete (modes=%s, paused=%s)"%[str(mirrors.bodies.map(func(body):return body.active_ability.mode)),game.paused])
 check(pool.created==created and pool.misses==misses,"Simultaneous taunts reuse prepared resources")
 mirrors.clear();mirrors.dispose()
 press_four();p.select_character(1)
 check(not kit.active and kit.mode.is_empty() and kit.taunt_left==0,"Switching fighters clears the gesture and taunt priority")
 p.select_character(33);fresh();await advance(6)
 p.spell_loadout.equip(33,"special_4","goemon/dash");press_four()
 check(kit.mode.is_empty() and p.forward_dash.active,"Existing fourth-slot assignment overrides native taunt (mode=%s, dash=%s, paused=%s, floor=%s)"%[kit.mode,p.forward_dash.active,game.paused,p.is_on_floor()])
 p.spell_loadout.equip(33,"special_4","")
 kit.cancel();fresh();await advance(6);press_four()
 check(kit.mode=="taunt","Removing override restores fourth-slot taunt (mode=%s, paused=%s, floor=%s)"%[kit.mode,game.paused,p.is_on_floor()])
 kit.die();check(kit.mode=="dead" and kit.taunt_left==0,"Defeat cancels the gesture and taunt priority")
 steps.sort()
 var report={"checks":checks,"failures":failures,"manual_step_p95_ms":steps[int(steps.size()*.95)],"manual_step_max_ms":steps[-1],"pool_misses":pool.misses}
 FileAccess.open(REVIEW+"result-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MOUNTAIN_TAUNT_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
