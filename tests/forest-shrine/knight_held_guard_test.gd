extends SceneTree
const ORIGIN=Vector3(0,.1,70)
var game
var checks=0
var failures=0
var config_path="user://knight-held-guard-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: Knight guard timeout");quit(1))
 run.call_deferred()
func check(ok: bool,note: String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func frames(n=3):
 for i in n:await physics_frame
func setup_fighter(id: int=7,origin: Vector3=ORIGIN):
 for actor in game.actors.values():
  if is_instance_valid(actor):actor.queue_free()
 game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 game.player.select_character(id);game.player.position=origin;game.player.velocity=Vector3.ZERO
 game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO;game.player.facing=Vector3.FORWARD
 game.player.hp=game.player.max_hp;game.player.invuln=0;game.player.attack_chain.reset()
 var c=game.player.active_ability;c.reset_run()
 for i in 20:c._move_body(1.0/60)
 c.player.pos=game.player.position;c.player.angle=PI;c.aim=c.player.pos+Vector3.FORWARD*30
 game.camera_rig.yaw=0;game.camera_rig.camera.global_position=game.player.position+Vector3(0,2.4,10)
 game.camera_rig.camera.look_at(game.player.position+Vector3(0,1.1,-15));game.model.update_vision(game.player.position)
 await frames()
 return c
func target(offset: Vector3):
 var data=game.model.waves.spawn_enemy(0,game.player.position+offset);data.hp=10000;data.max_hp=10000;data.stun=100
 game.sync_enemies();var actor=game.actors[data.id];actor.set_physics_process(false);actor._sync_fitted_pose();game.model.update_vision(game.player.position)
 return data
func hold(c,down: bool,action: String="heavy_attack"):
 var event=InputEventAction.new();event.action=action;event.pressed=down
 c.input(event)
func run():
 var original=load("res://scripts/forest/forest_map_document.gd").new();original.load_original();set_meta("forest_custom_layout",original.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
 await frames();game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=false;game.tuning.enemy_damage=1;game.tuning.critical_chance=0;game.character_tuning={}
 var c=await setup_fighter();hold(c,true)
 for i in 600:c.tick(1.0/60)
 check(c.player.blocking and c.player.guardTime>0,"Knight can hold guard continuously for ten seconds")
 hold(c,false);check(not c.player.blocking,"Releasing right-click immediately lowers the guard")
 c.player.cooldowns.flintlock=0;hold(c,true)
 var e=target(Vector3(0,0,-3.5));var hp=game.player.hp
 game.player.take_hit(18,Vector3.BACK)
 check(game.player.hp==hp and c.player.blocking and c.player.attack==null,"A frontal block protects HP and keeps the held shield raised")
 var losses=[]
 for i in 36:
  var before=e.hp;c.tick(1.0/60)
  if e.hp<before:losses.append(before-e.hp)
 check(losses.size()==3,"A blocked hit produces exactly three shield damage pulses ("+str(losses)+")")
 var hit_actor=game.actors[e.id]
 check(not hit_actor.bar.visible,"Enemy health bars remain hidden after taking damage")
 check(c.player.guardCounter!=null,"Burst owns its own lifetime while guard stays raised")
 for i in 12:c.tick(1.0/60)
 check(c.player.guardCounter==null and c.player.blocking,"Three shields finish without lowering the held guard")
 var first_hp=e.hp;game.player.take_hit(18,Vector3.BACK)
 var burst=c.player.guardCounter
 for i in 8:game.player.take_hit(18,Vector3.BACK)
 check(c.player.guardCounter==burst,"A crowd cannot stack overlapping shield bursts")
 hold(c,false)
 for i in 48:c.tick(1.0/60)
 check(first_hp-e.hp==240*burst.ticket.damage_multiplier,"Released shields finish all three hits after the guard is lowered")
 hold(c,true);hold(c,true,"weapon_chain");hold(c,false)
 check(c.player.blocking and c.secondary_held,"Keyboard 3 keeps guarding when right-click is released")
 hold(c,false,"weapon_chain")
 check(not c.player.blocking and not c.secondary_held,"Guard lowers when the final held input is released")
 hold(c,true)
 check(c.player.blocking and c.player.cooldowns.flintlock==0,"Guard can be raised again immediately")
 game.player.invuln=0;hp=game.player.hp;game.player.take_hit(18,Vector3.FORWARD)
 check(game.player.hp==hp-18 and c.player.guardCounter==null,"An attack from behind bypasses the frontal shield")
 c=await setup_fighter();hold(c,true)
 var middle=target(Vector3(0,0,-4));var wide=target(Vector3(4.5,0,-4))
 var outside=target(Vector3(12,0,-4));var rear=target(Vector3(0,0,4))
 game.player.take_hit(18,Vector3.BACK)
 var saved_ticket=c._ticket;var saved_resolution=c._resolution_ticket
 var saved_origin=c._damage_origin;var saved_projectile=c._projectile_damage
 for i in 48:c.tick(1.0/60)
 check(middle.hp==9760 and wide.hp==9760,"All three projected faces damage multiple enemies across their width")
 check(outside.hp==10000 and rear.hp==10000,"Shield counter cannot damage enemies outside the face or behind Knight")
 check(c._ticket==saved_ticket and c._resolution_ticket==saved_resolution and c._damage_origin==saved_origin and c._projectile_damage==saved_projectile,"Counter restores combat hit attribution and origin")
 game.player.take_hit(18,Vector3.BACK);c.cancel()
 check(c.player.guardCounter==null and not c.player.blocking,"Cancel clears held guard and pending shield damage")
 c=await setup_fighter();hold(c,true)
 var blocked=target(Vector3(0,0,-5))
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.position=game.player.position+Vector3(0,3,-2.5)
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(15,8,.5);shape.shape=box;wall.add_child(shape);game.add_child(wall)
 await frames();game.player.take_hit(18,Vector3.BACK)
 for i in 48:c.tick(1.0/60)
 check(blocked.hp==10000,"Solid cover blocks projected shield damage")
 wall.queue_free();await frames()
 # Exercise the actual game event-to-player damage path for both melee and archers.
 c=await setup_fighter(5)
 for variant in [0,1]:
  c=await setup_fighter(5)
  for actor in game.actors.values():actor.queue_free()
  game.actors.clear();game.enemies.clear();game.model.enemies.clear()
  var enemy=game.model.waves.spawn_enemy(variant,game.player.position+Vector3(0,0,3 if variant==0 else 10))
  enemy.retaliation=100
  enemy.road_path=game.model.waves.routes.guidance(enemy.pos);game.player.invuln=0;hp=game.player.hp
  for i in 240:
   game._physics_process(1.0/60);c.tick_timers(1.0/60)
   if game.player.hp<hp:break
  check(game.player.hp<hp,"Actual enemy %s attack damages player HP"%("melee" if variant==0 else "archer"))
 var raised=load("res://scripts/forest/forest_map_document.gd").new();raised.load_ramparts()
 game.preview_forest_map(raised.data,false);game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
 for variant in [0,1]:
  c=await setup_fighter(5,Vector3(-96,18.1,185))
  var elevated=game.model.waves.spawn_enemy(variant,game.player.position+Vector3(0,0,3 if variant==0 else 10))
  elevated.retaliation=100;elevated.road_path=game.model.waves.routes.guidance(elevated.pos);game.player.invuln=0;hp=game.player.hp
  for i in 240:
   game._physics_process(1.0/60);c.tick_timers(1.0/60)
   if game.player.hp<hp:break
  check(game.player.hp<hp,"Elevated enemy %s attack damages player HP on a wall"%("melee" if variant==0 else "archer"))
 # Restore the flat fixture for the visual shield capture.
 game.preview_forest_map(original.data,false);game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
 if "--visual" in OS.get_cmdline_user_args():
  c=await setup_fighter();hold(c,true);target(Vector3(0,0,-4));target(Vector3(4,0,-5))
  game.camera_rig.camera.global_position=game.player.position+Vector3(16,12,15)
  game.camera_rig.camera.look_at(game.player.position+Vector3(0,2,-2))
  game.player.take_hit(18,Vector3.BACK)
  c.tick(.06);c._animate(0,.016);await frames();await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/knight-held-guard-20261017/shield-pulse.png")==OK,"Native shield preview captured")
 c.cancel();game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames();await create_timer(.35).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("KNIGHT_HELD_GUARD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
