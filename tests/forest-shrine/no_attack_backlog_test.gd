extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://no-attack-backlog-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func event(action:String,down:bool)->InputEventAction:
 var e=InputEventAction.new();e.action=action;e.pressed=down;return e
func tap(action:String):
 game.player._unhandled_input(event(action,true));game.player._input(event(action,false))
func frames(n:int=3):
 for i in n:await process_frame
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 var p=game.player
 for id in range(1,13):
  p.select_character(id);p.cancel_charge();p.attack_left=0;p.quick_attacks.cancel();p.attack_chain.reset();p.impact_pause=0
  if p.active_ability!=null:p.active_ability.cancel()
  tap("light_attack")
  for i in 100:tap("heavy_attack");tap("light_attack")
  if id==1:
   check(p.quick_attacks.pending.is_empty(),"Goemon ignores busy clicks instead of storing a backlog")
   p.attack_left=0;p.quick_attacks.tick()
   check(not p.quick_attacks.active,"Goemon has no delayed extra action after the current attack")
  elif id==2:
   check(not p.musashi.heavy_queued,"Edo ignores a busy heavy press")
   for i in 100:tap("sky_strike")
   check(p.musashi.meteor_pending==0,"Edo cannot bank a queue of meteor casts")
   p.musashi.cancel();tap("sky_strike")
   for i in 100:tap("sky_strike")
   check(p.musashi.is_casting_meteors() and p.musashi.meteor_pending==0,"A fresh meteor press starts once and busy repeats are ignored")
  else:
   var c=p.active_ability
   check(c.attack_buffer==0 and not c.primary_held,"%s release drops unstarted primary input"%c.class_id)
   check(c.player.secondaryBuffer==null,"%s release drops unstarted secondary input"%c.class_id)
   if c.player.attack!=null:
    c.hit_stop=0;c.tick(c.player.attack.duration+.1)
   check(c.player.attack==null and c.attack_buffer==0,"%s stops when its current attack finishes"%c.class_id)
  p.cancel_charge();p.attack_left=0;p.quick_attacks.cancel();p.attack_chain.reset();p.impact_pause=0
 # Native automatic and held attacks remain intentional, not a click backlog.
 p.select_character(5);var ninja=p.active_ability;ninja.reset_run()
 ninja.input(event("light_attack",true));var first=ninja.player.attack
 ninja.tick(first.duration+.01)
 check(ninja.player.attack!=null,"Holding primary still repeats attacks")
 ninja.release_input(event("light_attack",false));ninja.hit_stop=0
 if ninja.player.attack!=null:ninja.tick(ninja.player.attack.duration+.1)
 check(ninja.player.attack==null,"Releasing a held attack stops after its current swing")
 ninja.action("cutlass");ninja.attack_buffer=.17;ninja.release_input(event("light_attack",false))
 check(ninja.attack_buffer==0,"Even a late released press cannot persist through recovery")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("NO_ATTACK_BACKLOG_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
