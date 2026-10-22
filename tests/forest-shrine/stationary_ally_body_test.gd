extends SceneTree
var checks=0
var failures=0
var cfg="user://stationary-ally-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func settle(unit):
 unit.global_position=Vector3(0,.15,70);unit.velocity=Vector3.DOWN*2
 for i in 8:unit.move_and_slide()
 unit.velocity=Vector3.ZERO;unit.jump_buffer=0;unit.ai_move=Vector3.ZERO
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false)
 for guard in game.gate_defenders.units.values():guard.set_physics_process(false)
 var unit=game.explorer_helpers.pool.filter(func(u):return u.kit_id==10)[0]
 unit.set_physics_process(false);unit.state="acting";unit.opening=false;unit.think_left=100;unit.ai_target=null;unit.auto_attack_enabled=false
 var optimized=unit.active_ability;optimized.cancel();optimized.active=true
 var native=load("res://scripts/rogue_roster_combat.gd").new();native.hero=unit;native.game=game;native.class_id="ranger";native.roster=optimized.roster;native.player=optimized.player.duplicate(true)
 settle(unit)
 native.move_input=Vector3.ZERO
 var start=Time.get_ticks_usec()
 for i in 1200:native._move_body(1.0/60)
 var baseline_us=Time.get_ticks_usec()-start;var reference=unit.global_position
 check(unit.is_on_floor(),"Native stationary body settles on the real terrain")
 settle(unit);optimized.move_input=Vector3.ZERO
 start=Time.get_ticks_usec()
 for i in 1200:optimized._move_body(1.0/60)
 var optimized_us=Time.get_ticks_usec()-start
 check(unit.global_position.distance_to(reference)<.0001 and unit.is_on_floor(),"Stationary support reuse retains the native position and floor state")
 check(optimized_us<baseline_us*.65,"Stationary allies avoid repeated full body casts on unchanged ground")
 optimized.player.cooldowns.drink=5
 for i in 60:unit._physics_process(1.0/60)
 check(absf(optimized.player.cooldowns.drink-4)<.035,"Stationary combat timers still run at their native rate")
 unit.ai_move=Vector3.RIGHT;var origin=unit.global_position
 for i in 30:unit._physics_process(1.0/60)
 check(unit.global_position.x>origin.x+1,"Movement immediately leaves the stationary support cache")
 unit.ai_move=Vector3.ZERO;unit.velocity=Vector3.ZERO;unit.global_position=Vector3(0,8,70)
 for i in 20:unit._physics_process(1.0/60)
 check(unit.global_position.y<7,"Teleporting off the floor restores native gravity immediately")
 print("STATIONARY_BODY_TIMING native_us=",baseline_us," optimized_us=",optimized_us)
 native.free();game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("STATIONARY_ALLY_BODY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
