extends SceneTree
var game
var checks=0
var failures=0
const ORIGIN=Vector3(0,.1,70)
var config_path="user://ninja-three-hit-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: Ninja refresh timeout");quit(1))
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
func swing(c,stage: int=0):
 c.player.cooldowns.cutlass=0;c.player.attack=null;c.hit_stop=0
 c.combo=stage;c.combo_timer=1;c.attack();c.primary_held=false
 var a=c.player.attack
 if a==null:check(false,"Fixture creates a real primary swing");return
 c.tick(a.duration+.01,false)
func reset_target():
 await prepare(5)
 var c=game.player.active_ability
 c.player.cooldowns.flintlock=2.8
 return target(Vector3(0,0,-2.6))
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
 await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=true;game.tuning.critical_chance=0;game.character_tuning={}
 var e=await reset_target();var c=game.player.active_ability
 for stage in 3:
  var hp=e.hp;swing(c,stage)
  check(e.hp<hp,"A real basic attack connects (%d)"%(stage+1))
  check(c.player.cooldowns.flintlock==0 if stage==2 else c.player.cooldowns.flintlock>1,"Shadow Cut refreshes on exactly the third landed swing (%d)"%(stage+1))
 if "--visual" in OS.get_cmdline_user_args():
  game.model.update_vision(game.player.position);game.world.update_fog();c._animate(0,0)
  game.camera_rig.camera.position=game.player.position+Vector3(3.7,2.6,-5.5)
  game.camera_rig.camera.look_at(game.player.position+Vector3.UP*1.35)
  await frames(3);await RenderingServer.frame_post_draw
  var folder="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/ninja-three-hit-refresh-20261017"
  check(root.get_texture().get_image().save_png(folder+"/third-hit-refresh.png")==OK,"Native third-hit cooldown refresh capture")
 c.hit_stop=0;c.action("flintlock")
 check(c.player.roll>0 and c.player.dashAttack!=null,"Refreshed right-click can actually cast Shadow Cut")
 # Crowds cannot refresh in a single cleave.
 e=await reset_target();c=game.player.active_ability
 var second=target(Vector3(.2,0,-2.6));var third=target(Vector3(-.2,0,-2.6))
 swing(c)
 check(e.hp<10000 and second.hp<10000 and third.hp<10000,"Crowd fixture hits three enemies with one swing")
 check(c.player.ninjaHits==1 and c.player.cooldowns.flintlock>1,"One multi-target swing earns only one refresh hit")
 swing(c,1);swing(c,2)
 check(c.player.cooldowns.flintlock==0 and c.player.ninjaHits==0,"Three multi-target swings produce exactly one refresh")
 # Misses preserve partial progress and never earn a hit themselves.
 e=await reset_target();c=game.player.active_ability;swing(c);swing(c,1)
 var enemy=game.actors[e.id];var pos: Vector3=enemy.position
 enemy.position+=Vector3.BACK*30;e.pos=enemy.position;enemy._sync_fitted_pose()
 swing(c,2)
 check(c.player.ninjaHits==2 and c.player.cooldowns.flintlock>0,"A missed third swing neither refreshes nor discards the two confirmed hits")
 enemy.position=pos;e.pos=pos;enemy._sync_fitted_pose();swing(c)
 check(c.player.cooldowns.flintlock==0,"The next landed swing after a miss completes the three-hit refresh")
 # An already-ready cooldown cannot bank a future automatic reset.
 e=await reset_target();c=game.player.active_ability;c.player.cooldowns.flintlock=0
 for i in 3:swing(c,i)
 check(c.player.ninjaHits==0,"Every third hit consumes its cycle even if right-click is already ready")
 c.player.cooldowns.flintlock=2.8;swing(c)
 check(c.player.ninjaHits==1 and c.player.cooldowns.flintlock>0,"A new cooldown requires another three landed attacks")
 # Projectiles and socket splash can arrive while a new basic attack is armed.
 e=await reset_target();c=game.player.active_ability;c.attack();c.primary_held=false
 var snapshot: Dictionary=c.living()[0]
 for i in 3:
  c._projectile_damage=true;c._damage_origin=c.player.pos+Vector3.UP
  c.hit(snapshot,1,"cutlass");c._projectile_damage=false
  c.hit(snapshot,1,"cutlass",false,Vector3.ZERO,"fire")
  c.hit(snapshot,1,"flintlock")
 check(c.player.ninjaHits==0 and c.player.cooldowns.flintlock>0,"Projectiles, elemental follow-ups and secondary hits do not advance the basic-hit counter")
 # Fog and walls reject contacts before counting them.
 for mode in ["fog","cover"]:
  e=await reset_target();c=game.player.active_ability
  var wall: StaticBody3D
  if mode=="fog":game.model.visible_cells.clear()
  else:
   wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
   var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,6,.2);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=game.player.position+Vector3(0,1,-.6);await frames()
  for i in 3:swing(c,i)
  check(e.hp==10000 and c.player.ninjaHits==0 and c.player.cooldowns.flintlock>0,"Rejected "+mode+" hits never grant a refresh")
  if is_instance_valid(wall):wall.queue_free();await frames()
 # Dash hits themselves cannot reset Shadow Cut in a crowd.
 e=await reset_target();c=game.player.active_ability;c.player.cooldowns.flintlock=0
 c.action("flintlock");var dash: Dictionary=c.player.dashAttack
 for offset in [-.2,0,.2]:target(Vector3(offset,0,-3.5))
 c.Actions.resolve_dash_segment(c,c.player.pos,c.player.pos+Vector3.FORWARD*5)
 check(dash.hits.size()>=3 and c.player.ninjaHits==0 and c.player.cooldowns.flintlock>0,"Shadow Cut can hit a crowd without resetting its own cooldown")
 # The immortal dummy confirms contact without losing HP.
 await prepare(5);c=game.player.active_ability
 var dummy=game.training_dummy;game.player.position=dummy.home+Vector3(0,.1,2);c.player.pos=game.player.position;c.aim=dummy.home
 game.enemies.append(dummy);game.model.update_vision(game.player.position);c.player.cooldowns.flintlock=2.8
 for i in 3:swing(c,i)
 check(dummy.hp==dummy.max_hp and c.player.cooldowns.flintlock==0,"Three real hits on the infinite-health dummy refresh right-click")
 # Lifecycle resets cannot carry a partial cycle to a new run or fighter.
 e=await reset_target();c=game.player.active_ability;swing(c);swing(c,1)
 c.cancel(true);check(c.player.ninjaHits==2,"Ordinary interruption preserves partial hit progress")
 c.cancel();check(c.player.ninjaHits==0,"Full cancellation clears partial hit progress")
 swing(c);c.reset_run();check(c.player.ninjaHits==0,"Restart clears partial hit progress")
 swing(c);game.player.select_character(7);game.player.select_character(5);c=game.player.active_ability
 check(c.player.ninjaHits==0,"Switching away and back clears partial hit progress")
 await prepare(11);c=game.player.active_ability;e=target(Vector3(0,0,-2.6));c.player.cooldowns.flintlock=2.8
 for i in 3:swing(c,i)
 check(e.hp<10000 and c.player.cooldowns.flintlock>0,"Explorer's landed combo does not gain Ninja's cooldown mechanic")
 c.cancel()
 game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames(3);await create_timer(.35).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("NINJA_THREE_HIT_REFRESH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
