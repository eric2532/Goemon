extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const OUT="res://build/Other Files/Asset Toolkit/Lancelot Normal Overlay/"
const Roster=preload("res://scripts/rogue_roster.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Shot=preload("res://scripts/recovered_enemy_projectile.gd")
const STEP=1.0/60
var kit:Node
var pool:Node
var arrow_slots:Array
var releases:Array=[]
var clock=0.0
var timings:Array=[]

func advance():
 var started=Time.get_ticks_usec()
 clock+=STEP*game.player.attack_speed_multiplier()
 kit.tick_timers(STEP);kit.tick(STEP)
 game.player.model.animate(STEP,0,true,0,0,false,0,false)
 for arrow in arrow_slots:
  if arrow.pool_live:arrow._physics_process(STEP)
 game.army_runtime.presentation_dirty=true;game.army_runtime.flush_presentation()
 timings.append((Time.get_ticks_usec()-started)/1000.0)

func start_volley():
 kit.cancel();kit.clear_cooldowns();fresh();releases.clear();clock=0
 game.player.position=ORIGIN;game.player.velocity=Vector3.DOWN*5
 for i in 20:game.player._physics_process(STEP)
 tap("equip")
 check(kit.is_attacking() and kit.clip=="6","亂射 begins with its original charge")

func run():
 create_timer(120).timeout.connect(func():printerr("LANCELOT_OVERLAY_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 await setup_fixture()
 game.set_process(false);game.explorer_helpers.set_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 for node in [game,game.player,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true;game.camera_focused=false;game._sync_camera_mouse()
 game.ui.hide();game.forest_ui.hide();game.music.stop()
 game.training_dummy.position=ORIGIN+Vector3(0,0,-8);game.training_dummy.home=game.training_dummy.position
 game.player.select_character(Roster.LANCELOT_ID);kit=game.player.active_ability
 pool=Pool.service(game)
 arrow_slots=pool.all[pool.key_for(game.player,Shot,"crossgate_arrow")]
 pool.launched.connect(func(arrow):
  arrow.set_physics_process(false)
  releases.append({"action":arrow.attack_ticket.action,"at":clock,"damage":arrow.damage,"skill_damage":arrow.attack_ticket.get("skill_damage",1.0),"critical_chance":arrow.attack_ticket.critical_chance}))
 game.camera_rig.camera.position=ORIGIN+Vector3(6,5,9)
 game.camera_rig.camera.look_at(game.training_dummy.position+Vector3.UP*1.3)
 var created=pool.created;var misses=pool.misses
 for repeated in [false,true]:
  start_volley();tap("light_attack")
  var pending=kit.bow_primary_ticket
  check(pending.action=="crossgate_bow" and kit.ticket.action=="lancelot_random_shot","Normal input keeps its own ticket without replacing 亂射")
  for i in 20:tap("heavy_attack")
  check(is_same(pending,kit.bow_primary_ticket) and releases.is_empty(),"Right clicks leave the pending normal request and bow windup alone")
  var captured=false
  for i in 600:
   if repeated:tap("light_attack")
   advance()
   if not repeated and i<120 and DisplayServer.get_name()!="headless":
    await physics_frame
    if i%4==0:
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(OUT+"sequence-%03d.png"%i)
   if not captured and releases.any(func(row):return row.action=="crossgate_bow"):
    captured=true
    check(kit.marker==2 and game.player.model.current_frame==11,"Both arrow kinds release on original bow frame 11")
    if DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw
     check(root.get_texture().get_image().save_png(OUT+"normal-during-volley.png")==OK,"Capture the shared bow release with normal and skill arrows")
   if not kit.is_attacking():break
  var normal=releases.filter(func(row):return row.action=="crossgate_bow")
  var volley=releases.filter(func(row):return row.action=="lancelot_random_shot")
  check(volley.size()==12,"Normal attacks preserve all twelve 亂射 arrows")
  check(normal.size()>=2 if repeated else normal.size()==1,"Normal clicks add independent arrows during 亂射")
  for i in range(1,normal.size()):check(normal[i].at-normal[i-1].at>=.986-STEP,"Repeated normal arrows retain the ordinary bow cadence")
  check(releases.all(func(row):return row.damage==250),"Both arrow kinds retain their base damage")
  for i in 120:advance()
  check(pool.created==created and pool.misses==misses,"Overlapping volleys use the prepared arrow slots")
 start_volley();game.player.set_auto_attack(true)
 check(game.player.auto_attack_running(),"Existing auto-attack can run during 亂射")
 for i in 600:
  advance()
  if not kit.state.has("barrage_left"):break
 game.player.set_auto_attack(false)
 check(releases.filter(func(row):return row.action=="lancelot_random_shot").size()==12 and releases.filter(func(row):return row.action=="crossgate_bow").size()>=2,"Auto-attack adds normal arrows without losing volley arrows")
 for i in 120:advance()
 # A normal click after the final volley arrow must survive into a normal windup.
 start_volley()
 for i in 600:
  advance()
  if releases.size()==12:break
 tap("light_attack")
 check(not kit.bow_primary_ticket.is_empty(),"A late click queues after the last volley release")
 for i in 120:advance()
 check(releases.filter(func(row):return row.action=="crossgate_bow").size()==1,"The late click becomes exactly one ordinary attack after 亂射")
 game.settings.skill_balance={"lancelot/random-shot":{"damage":3.0,"count":32}}
 kit.prepare_projectiles()
 var warm_nodes=get_node_count();var warm_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 created=pool.created
 for repetition in 6:
  start_volley()
  for i in 1200:
   tap("light_attack");advance()
   if not kit.is_attacking():break
  check(releases.filter(func(row):return row.action=="lancelot_random_shot").size()==32,"Overlapping attacks preserve the configured 32-arrow volley")
  check(releases.all(func(row):return row.skill_damage==(3.0 if row.action=="lancelot_random_shot" else 1.0)),"Normal arrows keep their own tuning instead of inheriting 亂射 damage")
  for i in 120:advance()
 check(pool.created==created and pool.misses==misses,"Six overlapping maximum volleys reuse their prepared slots")
 check(get_node_count()<=warm_nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=warm_resources,"Repeated overlapping volleys retain no nodes or resources after warmup")
 game.settings.skill_balance={}
 for interruption in ["dodge","hit","skin","character","focus","death"]:
  start_volley();tap("light_attack")
  match interruption:
   "dodge":game.player.dodge_cooldown=0;tap("dodge")
   "hit":kit.hit()
   "skin":game.select_crossgate_skin(Roster.LANCELOT_ID,105206 if game.player.model.variant_skin==106125 else 106125)
   "character":game.player.select_character(1);game.player.select_character(Roster.LANCELOT_ID);kit=game.player.active_ability
   "focus":kit._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
   "death":kit.die()
  for i in 100:advance()
  check(kit.bow_primary_ticket.is_empty() and releases.is_empty(),interruption+" clears both pending normal and skill arrows")
 timings.sort()
 print("LANCELOT_NORMAL_OVERLAY_RESULT checks=%d failures=%d step_p95_ms=%.3f step_max_ms=%.3f"%[checks,failures,timings[int(timings.size()*.95)],timings[-1]])
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
