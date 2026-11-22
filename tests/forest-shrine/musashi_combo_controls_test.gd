extends "res://tests/forest-shrine/musashi_techniques_test.gd"
## Player-only buffering and phase exits against real Wind Meadow collision.
const REVIEW="res://build/Other Files/Asset Toolkit/Musashi Combo Controls/"
var results={}
func advance(count:int):
 await driver.advance(count,func(delta):
  var started=Time.get_ticks_usec()
  p._physics_process(delta)
  if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(delta)
  times.append((Time.get_ticks_usec()-started)/1000.0))
func number(value:int):
 p.spell_loadout.number_input(value,true);p.spell_loadout.number_input(value,false)
func finish():
 c.cancel();game.sound_library.cancel();game.queue_free();driver.queue_free();current_scene=null
 for i in 4:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MUSASHI_COMBO_CONTROLS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func run():
 create_timer(150,true,false,true).timeout.connect(func():printerr("MUSASHI_COMBO_CONTROLS_TIMEOUT");quit(1))
 set_meta("forest_painterly_preview",true)
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
 check(p.is_on_floor(),"Fixture starts on real Wind Meadow ground")
 # Skills and mouse presses share a single expiring slot, without starting early.
 number(1);await advance(8);number(2)
 check(c.combo_skill=="crosswise" and c.buffered_action=="start_combo","Hotbar accepts the next combo during the current cut")
 number(3)
 check(c.buffered_args==["desperado"],"Latest command replaces the pending command")
 await advance(9)
 check(c.combo_skill=="crosswise" and c.mode=="fusion","Next skill cannot truncate the active sword window")
 await advance(2)
 check(c.combo_skill=="desperado" and c.elapsed<.04 and c.buffered_action.is_empty(),"Latest combo starts once at the recovery boundary")
 await advance(3)
 check(c.elapsed>.04,"Consumed input does not restart the next skill")
 plant();number(1);number(2);await advance(17)
 check(c.combo_skill=="crosswise" and c.buffered_action=="start_combo","An early skill press survives beyond the old 200 ms limit")
 await advance(2)
 check(c.combo_skill=="tenderize" and c.buffered_action.is_empty(),"An early skill press executes once at the existing recovery boundary")
 plant();c.start_attack(true);number(2);await advance(20)
 check(c.mode=="lumina" and not c.buffered_action.is_empty(),"The next skill is still buffered after 333 ms")
 await advance(6)
 check(c.mode=="lumina" and c.buffered_action.is_empty(),"An input older than 400 ms expires before recovery")
 await advance(30)
 check(not c.is_attacking(),"Expired input cannot fire after the animation ends")
 plant();tap("light_attack");await advance(8);tap("light_attack");await advance(11)
 check(c.mode=="fusion" and c.combo==1 and c.buffered_action.is_empty(),"Ordinary light attacks use the same recovery buffer")
 await advance(50)
 check(not c.is_attacking(),"One buffered press produces exactly one follow-up")
 # Movement is planted through the complete cut, then exits the automatic combo.
 plant();number(3);p.smoke_move=Vector2.RIGHT
 await advance(17)
 check(Vector2(p.position.x-origin.x,p.position.z-origin.z).length()<.1 and c.combo_skill=="desperado","Movement cannot slide the planted windup or active swing: %s %s %.3f"%[p.position,c.mode,c.elapsed])
 await advance(6)
 check(not c.is_attacking() and c.combo_skill.is_empty() and p.position.x>origin.x+.1,"Movement exits after the cut and discards remaining combo phases")
 results.movement_exit_source_tick=9
 # A buffered command wins over held movement at this boundary.
 plant();number(1);await advance(8);number(2);p.smoke_move=Vector2.RIGHT;await advance(11)
 check(c.combo_skill=="tenderize" and c.mode=="fusion","A fresh skill command takes priority over movement")
 # Reassigned slots must reach the same native controller.
 plant();p.spell_loadout.equip(13,"special_4","musashi/desperado")
 tap("light_attack");await advance(8);number(4);await advance(11)
 check(c.combo_skill=="desperado" and p.spell_loadout.current==null,"Reassigned combo uses the native buffer and visible body")
 p.spell_loadout.equip(13,"special_4","")
 plant();p.spell_loadout.equip(13,"special_4","musashi/counter")
 tap("light_attack");await advance(8);number(4);await advance(11)
 check(c.mode=="counter" and p.spell_loadout.current==null,"A reassigned Lumina skill starts on the visible native owner only at recovery")
 p.spell_loadout.equip(13,"special_4","")
 for number_ in [4,5]:
  plant();tap("light_attack");await advance(8);number(number_);await advance(11)
  check(c.mode==("rotation" if number_==4 else "counter"),"Numbered Lumina skill buffers through Fusion: %d"%number_)
 plant();c.start_rotation();p.smoke_move=Vector2.RIGHT;await advance(37)
 check(c.mode=="rotation" and Vector2(p.position.x-origin.x,p.position.z-origin.z).length()<.1,"Rotation retains all windup and spin ticks: %s %s %d"%[p.position,c.mode,c.rotation_ticks])
 await advance(7)
 check(not c.is_attacking() and p.position.x>origin.x+.1,"Rotation releases movement at spin recovery")
 # Airborne finishers retain their motion owner and exit only after landing.
 plant();c.combo=2;c.combo_timer=1;c.primary_attack();p.smoke_move=Vector2.RIGHT
 await advance(14);number(2);await advance(12)
 check(c.controls_motion() and not p.is_on_floor(),"Movement cannot cancel an airborne finisher")
 await advance(14)
 check(c.buffered_action.is_empty(),"A skill buffered too early in flight expires")
 for i in 120:
  if not c.is_attacking():break
  await advance(1)
 check(not c.is_attacking() and p.is_on_floor(),"Finisher completes physical landing before releasing movement")
 plant();c.combo=2;c.combo_timer=1;c.primary_attack()
 for i in 120:
  if c.finisher_phase=="land":break
  await advance(1)
 number(2)
 check(c.finisher_phase=="land" and not c.buffered_action.is_empty(),"A fresh landing input waits through the first landing pose")
 await advance(3)
 check(c.combo_skill=="tenderize" and c.mode=="fusion","A fresh buffered skill exits landing recovery")
 plant();number(2)
 for i in 180:
  if c.mode=="tenderize_end" and c.elapsed>=.4:break
  await advance(1)
 number(1)
 for i in 30:
  if c.combo_skill=="crosswise":break
  await advance(1)
 check(c.combo_skill=="crosswise" and p.is_on_floor(),"Tenderize finishes its contact and returns to ground before the next skill")
 # Cancellation must clear both intent and remaining automatic phases.
 for kind in ["focus","hit","pause","switch"]:
  plant();number(1);await advance(8);number(2)
  check(not c.buffered_action.is_empty(),"Fixture queues input before interruption: "+kind)
  if kind=="focus":c.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
  elif kind=="hit":c.hit()
  elif kind=="pause":game.show_pause();game.resume()
  else:p.select_character(1);p.select_character(13)
  check(c.buffered_action.is_empty() and c.buffer_left==0 and not c.is_attacking(),"Interruption clears the buffered action: "+kind)
  await advance(35)
  check(not c.is_attacking(),"Interruption cannot replay a stale skill: "+kind)
 # Native allies keep their original automatic sequences and independent state.
 plant();p.ai_controlled=true;c.start_combo("desperado")
 check(not c.responsive_controls() and not c.buffer_action("start_combo",["tenderize"]),"Player experiment does not change AI input or combo scheduling")
 p.ai_controlled=false;c.cancel()
 # Actual native contacts remain identical when only recovery is skipped.
 var row=game.model.waves.spawn_enemy(0,origin+Vector3.FORWARD*3);row.hp=100000;row.max_hp=100000
 game.model.update_vision(origin);game.sync_enemies();enemy=game.actors[row.id]
 plant();var hp=enemy.hp;c.start_attack(false);await advance(40);var full_damage=hp-enemy.hp
 plant();hp=enemy.hp;c.start_attack(false);p.smoke_move=Vector2.RIGHT;await advance(40)
 check(full_damage>0 and is_equal_approx(hp-enemy.hp,full_damage),"Movement exit preserves the exact native damage of the full swing")
 results.full_swing_damage=full_damage;results.movement_exit_damage=hp-enemy.hp
 # Warm the existing audio/effect pools, then repeatedly replace pending actions.
 for round_ in 2:
  plant();number(1);await advance(8);number(2);number(3);await advance(180)
 await advance(50);plant();await process_frame;await process_frame
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 times.clear()
 for round_ in 8:
  plant();number(1);await advance(8);number(2);number(3);await advance(180)
 await advance(50);plant();await process_frame;await process_frame
 results.retained_nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes
 results.retained_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 check(results.retained_nodes<=0 and results.retained_resources<=0,"Repeated buffered combos retain no additional nodes or resources")
 times.sort();results.step_p95_ms=times[int(times.size()*.95)];results.step_max_ms=times.back()
 if DisplayServer.get_name()!="headless":
  plant();number(1);await advance(8);number(2)
  game.camera_rig.camera.global_position=origin+Vector3(12,8,12);game.camera_rig.camera.look_at(origin+Vector3.UP*2)
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(REVIEW+"buffered-cut.png")==OK,"Captured Musashi's committed sword pose")
  await advance(11)
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(REVIEW+"next-skill.png")==OK,"Captured the buffered skill transition")
 var report=FileAccess.open(REVIEW+("headless" if DisplayServer.get_name()=="headless" else "desktop")+".json",FileAccess.WRITE)
 report.store_string(JSON.stringify(results,"  "));report.close()
 print("MUSASHI_COMBO_CONTROLS_PROFILE ",JSON.stringify(results))
 await finish()
