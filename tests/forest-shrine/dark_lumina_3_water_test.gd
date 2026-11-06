extends "res://tests/forest-shrine/dark_lumina_3_controls_test.gd"
const WATER_OUT=OUT+"Water Contact/"
const Shot=preload("res://scripts/dark_lumina_3_projectile.gd")
var records=[]
var fx:Node
var peak_water=0

func key(number:int):
 game.player.spell_loadout.number_input(number,true);game.player.spell_loadout.number_input(number,false)

func check(ok:bool,label_:String):
 super.check(ok,label_)
 if not ok:print("WATER_FIXTURE_STATE ",{"playing":game.playing,"paused":game.paused,"transitioning":game.transitioning,"phase":game.model.phase,"hp":game.player.hp,"fighter":game.player.character_id,"live_water":live_water().size()})

func advance(count:int):
 for i in count:
  await super.advance(1)
  peak_water=maxi(peak_water,live_water().size())

func live_water()->Array:
 var result=[]
 for entries in Pool.service(game).all.values():
  for shot in entries:
   if shot.pool_live and shot.get_script()==Shot and shot.kind==2:result.append(shot)
 return result

func reset_water():
 fresh();Pool.service(game).release_owner(game.player);fx.clear();records.clear()

func view(label_:String):
 if not visual:return
 fx.draw_effects();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(WATER_OUT+label_+".png")==OK,"Rendered "+label_)

func run():
 create_timer(240).timeout.connect(func():printerr("LUMINA_WATER_TIMEOUT");quit(1))
 visual=DisplayServer.get_name()!="headless"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WATER_OUT))
 var map=preload("res://scripts/forest/forest_map_document.gd").new();map.load_wind_meadow();await setup_fixture(map.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.tuning.invincible=true;game.model.phase="wave"
 game.army_runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 game.training_dummy.position=Vector3(0,-1000,0)
 var p=game.player;p.select_character(30);fresh();fx=game.crowd.army.presentation
 game.set_process_input(false);game.set_process_unhandled_input(false)
 p.set_process_input(false);p.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.ui.hide();game.forest_ui.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 root.title="Goemon · Water bubble splits"
 if visual:root.set_flag(Window.FLAG_NO_FOCUS,true)
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  shot.set_physics_process(false)
  if shot.get_script()==Shot and shot.kind==2:records.append({"secondary":shot.secondary,"velocity":shot.velocity,"damage":shot.damage,"ticket":shot.attack_ticket.duplicate(true)}))
 var home=Vector3(0,game.model.surface_height(0,140)+.1,140)
 game.camera_rig.camera.global_position=home+Vector3(32,24,44);game.camera_rig.camera.look_at(home+Vector3.UP*8)
 # Lifetime cleanup must never pretend an airborne bubble made contact.
 for secondary in [false,true]:
  reset_water();p.position=home
  var shot=pool.launch(p,Shot,"finale2",{"kind":2,"secondary":secondary,"position":home+Vector3.UP*14,"velocity":Vector3.ZERO,"lifetime":.1})
  await view("secondary-airborne" if secondary else "parent-airborne")
  await advance(4)
  check(shot.pool_live and fx.effects.is_empty(),"An untouched bubble stays intact before expiry")
  await advance(4)
  check(not shot.pool_live and records.size()==1 and fx.effects.is_empty(),"Expired %s bubbles retire silently without a pop or split"%("secondary" if secondary else "primary"))
  await view("secondary-expired" if secondary else "parent-expired")
 # Ground contact still releases exactly five children and the recovered pop.
 reset_water();p.position=home
 var ticket=p.attack_chain.begin("dark_lumina_3_2")
 var shot=pool.launch(p,Shot,"finale2",{"kind":2,"position":home+Vector3.UP*4,"velocity":Vector3.DOWN*Finale.SHOT_SPEED[2],"lifetime":4.5,"damage":100.0,"attack_ticket":ticket.duplicate(true)})
 await view("falling-bubble")
 for tick in 90:
  await advance(1)
  if not shot.pool_live:break
 var children=records.filter(func(s):return s.secondary)
 check(not shot.pool_live and children.size()==5,"Ground contact pops the parent into exactly five bubbles")
 check(fx.effects.filter(func(e):return e.kind=="finale-water").size()==1,"The parent plays its recovered pop animation once")
 check(children.all(func(s):return s.damage==50.0 and s.ticket==ticket),"Children keep half damage and the original attack ticket")
 for i in children.size():check(children[i].velocity.is_equal_approx(Vector3(sin(i*TAU/5),0,cos(i*TAU/5))*8*Finale.SCALE),"Child %d travels in the five-way ring"%i)
 await advance(12);await view("five-bubbles-ground")
 await advance(130)
 check(records.size()==6 and live_water().is_empty(),"All five children retire without another generation")
 # A secondary bubble pops only on its own ground contact.
 reset_water();p.position=home
 var child=pool.launch(p,Shot,"finale2",{"kind":2,"secondary":true,"position":home+Vector3.UP*4,"velocity":Vector3.DOWN*Finale.SHOT_SPEED[2],"lifetime":2.0})
 for tick in 90:
  await advance(1)
  if not child.pool_live:break
 check(not child.pool_live and records.size()==1 and fx.effects.filter(func(e):return e.kind=="finale-water_secondary").size()==1,"Secondary contact visibly pops once and never splits")
 await advance(5);await view("secondary-contact-pop")
 var reused=pool.launch(p,Shot,"finale2",{"kind":2,"position":home+Vector3.UP*12})
 check(not reused.secondary and reused.age==0 and reused.hit_targets.is_empty(),"Reuse resets child state, age and hit history")
 pool.release_owner(p);await advance(180)
 reset_water();p.position=home;contacts.clear()
 # Float the target above the ramp so scenery cannot intercept this contact check.
 game.training_dummy.position=home+Vector3(0,10,-14);game.model.update_vision(home);game.sync_training_dummy()
 var contact_shot=pool.launch(p,Shot,"finale2",{"kind":2,"position":home+Vector3.UP*12,"velocity":Vector3.FORWARD*Finale.SHOT_SPEED[2],"damage":100.0,"attack_ticket":p.attack_chain.begin("dark_lumina_3_2")})
 for tick in 60:
  contact_shot._physics_process(1.0/60)
  if not contact_shot.pool_live:break
 check(not contact_shot.pool_live and contacts.size()==1 and records.filter(func(s):return s.secondary).size()==5,"Enemy contact hits once, pops the parent and releases five children (contacts=%d)"%contacts.size())
 game.training_dummy.position=Vector3(0,-1000,0);pool.release_owner(p);await advance(180)
 # Numbered and borrowed Water retain all six primary releases.
 for borrowed in [false,true]:
  if borrowed:p.select_character(1);p.spell_loadout.equip(1,"equip","dark-lumina-3/water")
  reset_water();key(1 if borrowed else 2);await advance(420)
  var parents=records.filter(func(s):return not s.secondary).size();var spawned=records.filter(func(s):return s.secondary).size()
  check(parents==6 and spawned>0 and spawned<=30 and spawned%5==0,"%s Water keeps six releases and five-child contact bursts (parents=%d children=%d)"%["Borrowed" if borrowed else "Dark Lumina",parents,spawned])
  check(live_water().is_empty(),"The full volley retires")
  if borrowed:p.spell_loadout.equip(1,"equip","")
 p.select_character(30);reset_water();await advance(240)
 var prepared=pool.created;var misses=pool.misses
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 # Repeated ground volleys exercise splits; airborne timeouts must produce none.
 for repeat in 2:
  reset_water();p.powerups.attack_speed=20;p.attack_speed_stacks=p.MAX_ATTACK_SPEED_STACKS;p.position=home+Vector3.UP*(300 if repeat==1 else 0)
  for chain in 3:
   for i in 3:key(2)
   while p.active_ability.is_attacking():await advance(1)
  await advance(480)
  var parents=records.filter(func(s):return not s.secondary).size();var spawned=records.filter(func(s):return s.secondary).size()
  check(parents==54 and (spawned==0 if repeat==1 else spawned>0 and spawned<=270 and spawned%5==0),"Nine accelerated %s volleys split only on contact (parents=%d children=%d)"%["airborne" if repeat==1 else "ground",parents,spawned])
  check(live_water().is_empty(),"Repeated Water fully retires")
 check(pool.created==prepared and pool.misses==misses,"Repeated Water uses prepared leases without combat-time allocation")
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated Water retains no nodes or resources")
 step_times.sort();frame_times.sort()
 var report={"checks":checks,"failures":failures,"peak_water":peak_water,"pool_before":prepared,"pool_after":pool.created,"pool_misses":pool.misses-misses,"node_delta":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"step_p95_ms":step_times[int(step_times.size()*.95)]}
 if visual:report.frame_p95_ms=frame_times[int(frame_times.size()*.95)];report.frame_max_ms=frame_times[-1]
 FileAccess.open(WATER_OUT+("desktop" if visual else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LUMINA_WATER_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
