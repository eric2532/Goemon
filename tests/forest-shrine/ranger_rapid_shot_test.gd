extends SceneTree
## Real input, universal equipment, native contacts and overlapping pooled volleys.
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
const OUTPUT="res://build/Other Files/Asset Toolkit/Ranger Rapid Shot/"
const ORIGIN=Vector3(0,12,76)
var game
var checks=0
var failures=0
var cfg="user://ranger-rapid-shot-%d.cfg"%OS.get_process_id()
var visual=false
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func press(action:String,down:bool=true):
 var event=InputEventAction.new();event.action=action;event.pressed=down
 if down:game.player._unhandled_input(event)
 else:game.player._input(event)
func aim_at(point:Vector3):
 var p=game.player;p.position=ORIGIN;p.velocity=Vector3.ZERO;p.facing=(point-ORIGIN).normalized()
 game.camera_rig.camera.position=ORIGIN+Vector3(0,1.05,8)
 game.camera_rig.camera.look_at(point)
func tick(c,n:int):
 for i in n:
  c.player.pos=game.player.position
  if c.spell_owner==null:c.tick(1.0/60)
  else:game.player.spell_loadout.tick(1.0/60)
  c.fx.tick(1.0/60)
func fresh(character:int=10):
 var p=game.player;p.cancel_charge();p.select_character(character);p.set_physics_process(false)
 p.set_auto_attack(false);p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.attack_chain.reset()
 p.progression.reset(false);p.clear_powerups();p.end_surge();p.hp=p.max_hp
 p.run_upgrades={"damage":0,"vitality":0,"tempo":0};p.buildings_broken=0;p.scale=Vector3.ONE
 aim_at(ORIGIN+Vector3(0,1.05,-60))
 if p.is_rogue_character():p.active_ability.reset_run();p.active_ability.set_process(false)
func assert_fan(c):
 check(c.projectiles.size()==10,"One input releases exactly ten simultaneous arrows")
 if c.projectiles.size()!=10:return
 var rays=c.projectiles.map(func(pr):return pr.aimDirection)
 check(is_equal_approx(rays[0].signed_angle_to(rays[9],Vector3.UP),4*Actions.RANGER_FAN_STEP),"Ten rays fill the existing symmetric 55-degree fan")
 for i in 10:
  var pr=c.projectiles[i]
  check(pr.kind=="arrow" and pr.hits.is_empty() and pr.life>0 and pr.damage==25,"Arrow %d starts clean with ordinary fan damage"%i)
  if i>0:check(is_equal_approx(rays[i-1].signed_angle_to(rays[i],Vector3.UP),4*Actions.RANGER_FAN_STEP/9),"Fan spacing is even")
 check(c.projectiles.all(func(pr):return pr.ticket==c.projectiles[0].ticket),"Volley shares one attack ticket")
func run():
 visual="--visual" in OS.get_cmdline_user_args()
 create_timer(180).timeout.connect(func():printerr("Rapid Shot test timed out");quit(1))
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;game.smoke_test=true;root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.set_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 game.tuning.critical_chance=0;game.character_tuning={};game.settings.spell_loadouts={}
 if visual:DisplayServer.window_move_to_foreground();root.grab_focus()
 fresh();var p=game.player;var c=p.active_ability
 check(Catalog.all().has("ranger/rapid-shot") and Catalog.defaults(10).sky_strike=="ranger/rapid-shot","Rapid Shot is universal and Ranger's default T")
 press("sky_strike");assert_fan(c)
 check(c.player.rangerShots==0 and c.player.cooldowns.flintlock==0,"Rapid Shot leaves primary rhythm and original fan cooldown alone")
 press("sky_strike");check(c.projectiles.size()==10,"Extra presses cannot bypass the quarter-second interval")
 tick(c,16);check(c.player.rangerFlightSerial==20,"Holding T repeats without Rain")
 press("sky_strike",false);tick(c,60)
 check(c.player.rangerFlightSerial==20 and c.projectiles.is_empty(),"Release stops firing and arrows expire")
 press("sky_strike");press("sky_strike",false)
 check(c.projectiles.size()==10,"A later tap fires again")
 fresh();c=p.active_ability;press("light_attack");press("sky_strike")
 check(c.projectiles.size()==10 and c.player.attack==null,"Rapid Shot starts immediately during a primary draw")
 c.primary_held=true;tick(c,32)
 check(c.player.rangerFlightSerial==30 and c.player.rangerShots==0,"Held primary cannot starve held Rapid Shot")
 press("sky_strike",false);press("light_attack",false)
 c.cancel();c.player.cooldowns.rapid_shot=0;press("surge");press("surge",false);press("sky_strike");press("sky_strike",false)
 check(c.projectiles.size()==10 and c.projectiles.all(func(pr):return pr.power and pr.damage==38),"Rain powers all ten Rapid Shot arrows")
 fresh();c=p.active_ability;press("sky_strike");p.interrupt_attack_for_movement();var serial=c.player.rangerFlightSerial;tick(c,30)
 check(not c.rapid_shot_held and c.player.rangerFlightSerial==serial,"Dodge interruption stops the native held skill")
 fresh();c=p.active_ability;press("sky_strike");c._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);tick(c,30)
 check(not c.rapid_shot_held and c.projectiles.is_empty(),"Focus loss cancels native repeat and presentation")
 # Every receiving body uses the same real equipment/input route.
 for character in Catalog.Roster.PLAYABLE_IDS:
  game.settings.spell_loadouts={};fresh(character);var loadout=p.spell_loadout
  loadout.retired_cooldowns.clear()
  check(loadout.equip(character,"equip","ranger/rapid-shot"),"Fighter %d equips Rapid Shot"%character)
  var instance=loadout.instances.get("%d:ranger/rapid-shot"%character)
  var controller=instance.controller;controller.set_process(false)
  var weapon=p.weapon_slot
  press("equip");check(controller.projectiles.size()==10,"Fighter %d casts all ten arrows"%character)
  check(p.weapon_slot==weapon,"Fighter %d keeps their weapon"%character)
  tick(controller,16);check(controller.player.rangerFlightSerial==20,"Fighter %d repeats while held"%character)
  press("equip",false);tick(controller,30)
  check(controller.player.rangerFlightSerial==20,"Fighter %d stops on release"%character)
  press("equip");p.interrupt_attack_for_movement();serial=controller.player.rangerFlightSerial;tick(controller,30)
  check(not controller.rapid_shot_held and controller.player.rangerFlightSerial==serial,"Fighter %d cancels held fire on interruption"%character)
  loadout.equip(character,"equip","");await process_frame
 game.settings.spell_loadouts={};fresh(1)
 var loadout=p.spell_loadout;loadout.retired_cooldowns.clear()
 loadout.equip(1,"equip","ranger/rapid-shot");loadout.equip(1,"surge","ranger/rapid-shot")
 var shared=loadout.instances["1:ranger/rapid-shot"].controller;shared.set_process(false)
 press("equip");press("surge");press("equip",false);tick(shared,16)
 check(shared.rapid_shot_held and shared.player.rangerFlightSerial==20,"A second assigned key keeps the shared volley held")
 press("surge",false);tick(shared,30)
 check(not shared.rapid_shot_held and shared.player.rangerFlightSerial==20,"The last assigned key stops shared repetition")
 press("equip");press("equip",false);tick(shared,1);press("equip");tick(shared,16);press("equip",false)
 check(shared.player.rangerFlightSerial==40,"Holding again during recovery fires as soon as the interval ends")
 tick(shared,30)
 press("equip");press("equip",false)
 var remaining=float(shared.player.cooldowns.rapid_shot)
 loadout.equip(1,"equip","edo/volley");loadout.equip(1,"surge","");loadout.equip(1,"equip","ranger/rapid-shot")
 var restored=loadout.instances["1:ranger/rapid-shot"].controller
 press("equip");press("equip",false)
 check(restored.projectiles.is_empty() and is_equal_approx(restored.player.cooldowns.rapid_shot,remaining),"Re-equipping cannot bypass Rapid Shot cooldown")
 loadout.equip(1,"equip","")
 game.settings.spell_loadouts={};fresh();c=p.active_ability
 p.spell_loadout.equip(10,"equip","ranger/rapid-shot");press("surge");press("surge",false);press("equip");press("equip",false)
 var borrowed=p.spell_loadout.instances["10:ranger/rapid-shot"].controller
 check(borrowed.projectiles.all(func(pr):return pr.power),"Native Rain also powers Ranger's equipped copy")
 p.spell_loadout.equip(10,"equip","");await process_frame
 await contacts()
 await pooling()
 if visual:await profile()
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("RANGER_RAPID_SHOT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func contacts():
 fresh();var p=game.player;var c=p.active_ability
 aim_at(Vector3(0,1.1,70))
 var data=game.model.waves.spawn_enemy(4,Vector3(0,0,70));data.hp=10000;data.max_hp=10000;game.sync_enemies()
 var target=game.actors[data.id];target.set_physics_process(false);target._sync_fitted_pose()
 game.model.visible_cells[game.model.cell_of(target.position)]=true
 press("sky_strike");press("sky_strike",false)
 var damaged=0
 for pr in c.projectiles:
  var hp=target.hp
  c.resolve_projectile_segment(pr,pr.mesh.position,pr.mesh.position+pr.vel.normalized()*18)
  if target.hp<hp:damaged+=1
  var after=target.hp
  c.resolve_projectile_segment(pr,pr.mesh.position,pr.mesh.position+pr.vel.normalized()*18)
  check(target.hp==after,"One arrow cannot damage the same native victim twice")
 check(damaged==10,"All ten fan rays damage a fitted native target")
 check(target.hp<10000,"Rapid Shot damage reaches native HP")
 c.cancel();c.player.cooldowns.rapid_shot=0
 var wall=StaticBody3D.new();wall.collision_layer=1
 # The close giant makes the reticle aim down: cover the actual downward path.
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(40,.2,40);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=ORIGIN+Vector3.UP*.5
 await physics_frame;await process_frame
 var hp=target.hp;press("sky_strike");press("sky_strike",false);tick(c,30)
 check(target.hp==hp and c.projectiles.is_empty(),"Solid cover stops all ten arrows before native contact")
 wall.free()
 game.army_runtime.despawn(target.handle)
 await physics_frame;await process_frame
func pooling():
 fresh();var c=game.player.active_ability
 var prepared={}
 for pool in c.fx.idle_arrows.values():
  for mesh in pool:prepared[mesh.get_instance_id()]=true
 var reused=true;var clean=true;var max_live=0
 press("sky_strike")
 for i in 360:
  tick(c,1);max_live=maxi(max_live,c.projectiles.size())
  for pr in c.projectiles:
   reused=reused and prepared.has(pr.mesh.get_instance_id())
   clean=clean and pr.hits.is_empty() and not pr.power and pr.damage==25
  if i%30==0:await process_frame
 press("sky_strike",false);tick(c,90)
 check(max_live>=20 and max_live<=30,"Repeated volleys overlap with at most thirty live arrows")
 check(reused,"Six seconds of held fire uses only prepared arrow nodes")
 check(clean and c.projectiles.is_empty(),"Recycled arrows reset damage, hit history, power and lifetime")
func profile():
 game.resume()
 fresh();var c=game.player.active_ability
 var results=[]
 for count in [5,10]:
  c.cancel();c.player.cooldowns.rapid_shot=0
  for warm in 90:
   if warm%15==0:c.begin_cast("rapid-shot");Actions.fire_ranger_fan(c,PI,false,"flintlock",c.aim,false,count)
   c.tick(1.0/60);c.fx.tick(1.0/60);await process_frame
  var samples=[];var cpu=[];var casts=[];var focused=0;var previous=Time.get_ticks_usec()
  var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  for i in 180:
   await process_frame
   var now=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
   var start=Time.get_ticks_usec()
   if i%15==0:
    c.begin_cast("rapid-shot");Actions.fire_ranger_fan(c,PI,false,"flintlock",c.aim,false,count)
    casts.append((Time.get_ticks_usec()-start)/1000.0)
   c.tick(1.0/60);c.fx.tick(1.0/60);cpu.append((Time.get_ticks_usec()-start)/1000.0)
   if root.has_focus():focused+=1
  samples.sort();cpu.sort();casts.sort()
  results.append({"arrows":count,"frames":180,"focused":focused,"frame_p95_ms":samples[171],"frame_max_ms":samples.back(),"skill_cpu_p95_ms":cpu[171],"cast_max_ms":casts.back(),"node_delta":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources})
 var report={"renderer":RenderingServer.get_video_adapter_name(),"resolution":str(root.size),"scope":"Five versus ten-arrow fan, same quarter-second cadence and paused world. One skill step per rendered frame. Not a full-army benchmark.","samples":results}
 var file=FileAccess.open(OUTPUT+"profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
 c.cancel();c.player.cooldowns.rapid_shot=0
 game.resume()
 aim_at(ORIGIN+Vector3(0,1.05,-60));press("sky_strike");press("sky_strike",false);tick(c,7);c._present_projectiles();c._animate(0,0)
 check(c.projectiles.size()==10 and not game.paused,"Rendered capture contains one live ten-arrow cast")
 var camera=game.camera_rig.camera;camera.position=ORIGIN+Vector3(13,15,13);camera.look_at(ORIGIN+Vector3(0,0,-7))
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUTPUT+"rapid-shot.png")==OK,"Capture ten-arrow fan through the desktop renderer")
