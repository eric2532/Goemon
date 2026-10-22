extends SceneTree
var game
var checks=0
var failures=0
const ORIGIN=Vector3(0,.1,70)
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: Ninja gameplay timeout");quit(1))
 run.call_deferred()
func check(ok: bool,message: String):
 checks+=1
 print("PASS: " if ok else "FAIL: ",message)
 if not ok:failures+=1
func frames(n: int=2):
 for i in n:await physics_frame
func press(down: bool):
 var event=InputEventAction.new();event.action="light_attack";event.pressed=down
 Input.parse_input_event(event);Input.flush_buffered_events()
func fresh(hero_id: int=11):
 press(false)
 for actor in game.actors.values():
  if is_instance_valid(actor):actor.queue_free()
 game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 await frames()
 game.player.select_character(hero_id);game.player.set_auto_attack(false)
 game.player.position=ORIGIN;game.player.velocity=Vector3.ZERO
 game.player.attack_chain.reset();game.player.active_ability.reset_run()
 game.player.active_ability.player.pos=ORIGIN
 game.camera_rig.yaw=0
 game.camera_rig.camera.global_position=ORIGIN+Vector3(0,2.4,10)
 game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1.1,-15))
 game.model.update_vision(ORIGIN)
 for i in range(20):game.player.active_ability._move_body(1.0/60)
 game.player.active_ability.player.pos=game.player.global_position
func target(offset: Vector3,variant: int=0):
 var id=9000+game.model.enemies.size()
 var data={"id":id,"variant":variant,"pos":ORIGIN+offset,"hp":10000.0,"max_hp":10000.0,"velocity":Vector3.ZERO,"stun":100.0,"attack":false,"clock":0.0,"facing":0.0,"action":"walk","action_left":0.0,"attack_progress":0.0,"walk_phase":0.0}
 game.model.enemies[id]=data;game.sync_enemies()
 var actor=game.actors[id];actor.set_physics_process(false);actor._sync_fitted_pose()
 game.model.update_vision(ORIGIN)
 return data
func prepare(id: int):
 if id>=3:await fresh(id)
 else:
  await fresh(7);game.player.select_character(id);game.player.position=ORIGIN
 game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
 game.player.dodge_time=0;game.player.jump_buffer=0;game.player.jump_windup=0
 game.camera_rig.pitch=ActionCamera.CROSSHAIR_DEFAULT_PITCH
 if id>=3:
  var c=game.player.active_ability
  for i in range(20):c._move_body(1.0/60)
  c.player.pos=game.player.position;c.aim=game.player.position+Vector3.FORWARD*30
 else:
  for i in range(20):game.player._physics_process(1.0/60)
var config_path="user://ninja-authored-gameplay-%d.cfg"%OS.get_process_id()
var output=ProjectSettings.globalize_path("res://build/Other Files/ninja-authored-poses-20261017")
func shot(label_: String):
 if not "--visual" in OS.get_cmdline_user_args():return
 var crowd_visible=game.crowd.visible
 var previous_camera=game.camera_rig.camera.global_transform
 game.crowd.visible=false
 game.camera_rig.camera.position=game.player.position+Vector3(3.7,2.6,-5.5)
 game.camera_rig.camera.look_at(game.player.position+Vector3.UP*1.35)
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/game-"+label_+".png")==OK,"Native gameplay capture "+label_)
 game.crowd.visible=crowd_visible
 game.camera_rig.camera.global_transform=previous_camera
func run():
 # These movement fixtures use flat ground, independent of raised-route map presets.
 var map_doc=load("res://scripts/forest/forest_map_document.gd").new();map_doc.load_original();set_meta("forest_custom_layout",map_doc.data)
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
 await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=true;game.tuning.critical_chance=0;game.character_tuning={}
 await prepare(5);var c=game.player.active_ability;var actor=c.visual_actor
 c._animate(0,0)
 check(actor.cosplay_rig.ninja_motion.last_clip=="idle","Actual Forest gameplay displays the authored idle")
 game.model.update_vision(game.player.position);game.world.update_fog();await shot("idle")
 var start: Vector3=game.player.position;var e=target(Vector3(0,0,-3.5))
 c.action("flintlock");var dash: Dictionary=c.player.dashAttack
 check(is_equal_approx(c.player.rollDuration,.14) and c.player.rollSpeed==81 and dash.damage==76,"RMB runs three times faster with the same damage")
 c._animate(0,0);await shot("slash-start")
 for i in 3:c.physics_step(1.0/60)
 check(actor.cosplay_rig.ninja_motion.last_clip=="slash","Actual RMB timer drives the authored cut")
 check(e.hp<10000,"The authored dash still damages enemies along its path")
 check(not dash.get("magicBrush",{}).is_empty(),"RMB trail follows the authored blade instead of a detached slash")
 await shot("slash-middle")
 for i in 6:c.physics_step(1.0/60)
 await shot("slash-finish")
 var extra_ticks=0
 while c.player.roll>0 and extra_ticks<30:
  c.physics_step(1.0/60);extra_ticks+=1
 check(c.player.roll<=0 and c.player.dashAttack==null,"Dash gameplay ends on its faster timer")
 check(actor.cosplay_rig.ninja_motion.last_clip=="recovery","Game displays an interruptible return from the authored finish (clip=%s, roll=%s, shot=%s, pos=%s)"%[actor.cosplay_rig.ninja_motion.last_clip,c.player.roll,c.player.shot,game.player.position])
 check(extra_ticks<=12,"Only confirmed-hit impact pause delays the dash clock")
 check(game.player.position.distance_to(start)>6 and game.player.position.distance_to(start)<12,"Dash physics retains forward travel (start=%s, end=%s, distance=%s)"%[start,game.player.position,game.player.position.distance_to(start)])
 for i in 24:c.physics_step(1.0/60)
 check(actor.cosplay_rig.ninja_motion.last_clip=="idle","Game returns to the user's new idle (clip=%s, floor=%s, pos=%s)"%[actor.cosplay_rig.ninja_motion.last_clip,game.player.is_on_floor(),game.player.position])
 await shot("recovered")
 # Running still uses the existing locomotion rather than freezing at idle.
 game.player.smoke_move=Vector2(0,-1)
 for i in 20:c.physics_step(1.0/60)
 check(actor.locomotion.stride_speed>2.2 and actor.cosplay_rig.ninja_motion.last_clip=="","Run remains responsive with its existing animation")
 await shot("run")
 game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames(3);await create_timer(.35).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("NINJA_AUTHORED_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
