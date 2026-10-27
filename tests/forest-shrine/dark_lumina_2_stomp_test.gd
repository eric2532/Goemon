extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const OUT="res://build/Other Files/Asset Toolkit/Dark Lumina 2/Jump Stomp/"
var home=Vector3(0,.1,140)
var watched:Node
var waves=[]
var last_marker=0
var last_air_frame=-1
var tick_count=0
var focused=0
var cpu=[]
func fresh(surge:bool=false):
 if game.player.active_ability!=null:game.player.active_ability.cancel()
 game.player.spell_loadout.cancel()
 super.fresh(surge)
 game.player.position=home
 game.training_dummy.home=home+Vector3(0,0,-5);game.training_dummy.position=game.training_dummy.home
 game.model.update_vision(home)
 watched=null;waves.clear();last_marker=0;last_air_frame=-1
func advance(count:int):
 for i in count:
  var start=Time.get_ticks_usec();var p=game.player
  p._physics_process(1.0/60);game.crowd.army.presentation.tick(1.0/60)
  if not p.is_on_floor():last_air_frame=tick_count
  if watched!=null and watched.marker>last_marker:
   waves.append({"frame":tick_count,"floor":p.is_on_floor(),"height":p.position.y,"marker":watched.marker,"since_air":tick_count-last_air_frame})
   last_marker=watched.marker
  cpu.append((Time.get_ticks_usec()-start)/1000.0)
  tick_count+=1
  if DisplayServer.get_name()!="headless" and root.has_focus():focused+=1
  game.camera_rig.camera.global_position=home+Vector3(42,28,45);game.camera_rig.camera.look_at(home+Vector3(0,5,0))
  await physics_frame
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.player.model.show();await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Rendered "+label_)
func finish_cast():
 for i in 230:
  await advance(1)
  if waves.size()==2 and waves[1].frame==tick_count-1:
   await advance(12);await capture("energy-waves-%d"%game.player.character_id)
  if not watched.is_attacking():break
 print("STOMP_CONTACTS ",waves)
 check(waves.size()==2 and waves.all(func(row):return row.floor and absf(row.height-home.y)<.3),"Both original energy waves require physical ground contact")
 check(waves.size()>0 and waves[0].since_air<=3,"First energy wave follows landing within three physics frames")
 check(not watched.is_attacking(),"Stomp completes and releases the combat owner")
func run():
 create_timer(180).timeout.connect(func():printerr("DL2_STOMP_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var map=preload("res://scripts/forest/forest_map_document.gd").new();map.load_wind_meadow();await setup_fixture(map.data)
 home.y=game.model.surface_height(home.x,home.z)+.1
 game.set_process(false);game.army_runtime.set_physics_process(false)
 game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
 game.tuning.invincible=true
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_title("Goemon · DL2 jump stomp (DEBUG)")
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 var p=game.player;p.select_character(Dark.PLAYER);fresh();await advance(4)
 for i in 90:
  if p.is_on_floor():break
  await advance(1)
 check(p.is_on_floor(),"Grounded stomp fixture settles the newly selected boss capsule")
 tap("heavy_attack");watched=p.active_ability
 check(watched.action==Dark.SLAM,"RMB starts jump stomp")
 check(is_equal_approx(Dark.SHOCK_RADIUS,72),"Energy-wave reach doubles while retaining the triple-size body")
 var high=p.position.y
 for i in 65:await advance(1);high=maxf(high,p.position.y)
 check(high>home.y+30,"Grounded stomp retains the full boss leap")
 await capture("grounded-stomp");await finish_cast()
 for key in ["heavy_attack","surge"]:
  fresh();await advance(4);tap("jump");await advance(18)
  check(not p.is_on_floor() and p.velocity.y>0,"Space jump is rising before aerial "+key)
  p.velocity.x=30;p.velocity.z=20;tap(key);watched=p.active_ability
  check(watched.action==Dark.SLAM and watched.jump_started and watched.pose_tick==38 and p.velocity.y<=-Dark.LEAP_SPEED,"Airborne "+key+" enters the original descending pose immediately")
  check(is_zero_approx(p.velocity.x) and is_zero_approx(p.velocity.z),"Aerial stomp stops horizontal travel")
  await advance(1)
  check(waves.is_empty() and p.velocity.y<0,"Aerial stomp cannot relaunch or emit waves in midair")
  await capture("aerial-stomp");await finish_cast()
 fresh();await advance(4);tap("jump");await advance(18);tap("surge");watched=p.active_ability
 p.active_ability.cancel();await advance(120)
 check(waves.is_empty() and not p.active_ability.is_attacking(),"Cancelling airborne stomp leaves no delayed energy wave")
 p.select_character(1);fresh();await advance(4)
 check(p.spell_loadout.equip(1,"equip","dark-lumina-2/shockwave"),"Stomp uses the existing stable shared skill")
 p.position.y+=12;p.velocity=Vector3(10,20,0);p.move_and_slide()
 check(not p.is_on_floor(),"Borrowed skill wearer starts airborne")
 tap("equip");watched=p.spell_loadout.current.controller
 check(watched.action==Dark.SLAM and p.velocity.y<=-Dark.LEAP_SPEED,"Borrowed stomp begins descent without another leap")
 await finish_cast()
 check(p.character_id==1 and p.spell_loadout.current==null,"Borrowed stomp restores the receiving fighter")
 p.spell_loadout.equip(1,"equip","");p.select_character(29);fresh();await advance(4)
 var presentation=game.crowd.army.presentation
 presentation.clear()
 for repeat in 4:
  for i in 12:
   presentation.dark_cue(home+Vector3((i%4-1.5)*20,0,-floori(i/4.0)*20),8)
   presentation.dark_cue(home+Vector3((i%4-1.5)*20,0,-floori(i/4.0)*20),9)
  presentation.tick(.1)
  check(presentation.batches["dark-stomp_wave"].multimesh.visible_instance_count==24,"Twelve simultaneous stomps retain both recovered ground waves")
  check(presentation.batches["dark-shock_dome"].multimesh.visible_instance_count<=0 and presentation.batches["dark-shock_ring"].multimesh.visible_instance_count<=0,"Stomp never substitutes the unrelated dome meshes")
  if repeat==0:await capture("simultaneous-waves")
  presentation.tick(2)
 var nodes=presentation.get_child_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 20:
  for i in 12:presentation.dark_cue(home,8);presentation.dark_cue(home,9)
  presentation.tick(.1);presentation.tick(2)
 check(presentation.effects.is_empty() and presentation.get_child_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated waves retire with stable prepared nodes and resources")
 cpu.sort()
 var result={"checks":checks,"failures":failures,"stepped_frames":tick_count,"focused_frames":focused,"manual_step_cpu_p95_ms":cpu[int(cpu.size()*.95)],"presentation_nodes":nodes,"note":"Isolated player/shared skill and repeated simultaneous effect checks; CPU step is not gameplay FPS"}
 FileAccess.open(OUT+"gameplay-results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("DARK_LUMINA_STOMP_RESULT ",result)
 game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
