extends "res://tests/forest-shrine/dark_lumina_3_controls_test.gd"
const QUEUE_OUT=OUT+"Queued Elements/"
const Shot=preload("res://scripts/dark_lumina_3_projectile.gd")
var caster:Node
var shots=[]
var fx:Node
var peak_wings=0
var peak_wind_voices=0
var peak_fire=0

func advance(count:int):
 for i in count:
  await super.advance(1)
  peak_wings=maxi(peak_wings,fx.effects.filter(func(e):return e.kind in ["finale-wind","finale-wind_outer"]).size())
  peak_wind_voices=maxi(peak_wind_voices,fx.voices.filter(func(v):return v.playing and v.get_meta("finale_loop","")=="wind_loop").size())
  var live_fire=0
  for entries in Pool.service(game).all.values():
   for shot in entries:
    if shot.pool_live and shot.get_script()==Shot and shot.kind==3:live_fire+=1
  peak_fire=maxi(peak_fire,live_fire)

func reset_cast():
 fresh();Pool.service(game).release_owner(game.player);fx.clear();shots.clear()
 peak_wings=0;peak_wind_voices=0

func primary()->Array:return shots.filter(func(s):return not s.secondary)

func finish_cast(move:int,count:int):
 await advance(ceili(Finale.moves[move].size()*count*2.0/caster.CAST_RATE)+45)

func view(label_:String):
 if not visual:return
 var camera=game.camera_rig.camera;var previous=camera.global_transform
 camera.global_position=ORIGIN+Vector3(65,115,130);camera.look_at(ORIGIN+Vector3(0,10,-25))
 fx.draw_effects();RenderingServer.force_draw()
 root.get_texture().get_image().save_png(QUEUE_OUT+label_+".png")
 camera.global_transform=previous

func verify_volleys(move:int,count:int):
 var expected=[0,88,6,32][move]
 var main=primary()
 check(main.size()==expected*count,"%s produces %d complete sequential volleys (%d shots)"%[Finale.NAMES[move],count,main.size()])
 for cycle in count:
  var volley=main.filter(func(s):return s.cycle==cycle)
  check(volley.size()==expected,"Every release belongs to the correct volley %d"%(cycle+1))
 check(main.all(func(s):return is_equal_approx(s.damage,65*Finale.DAMAGE[move]*(.5 if move==1 else 1)*game.player.damage_multiplier())),"Every queued projectile keeps its original damage")
 check(not caster.is_attacking(),"The complete queue finishes")
 if move==1:
  check(peak_wings==4 and peak_wind_voices<=1,"Wind repeats keep two mirrored wings and at most one sustain voice")
  check(not fx.effects.any(func(e):return e.get("owner_id",0)==caster.get_instance_id()),"Wind releases its owned effects after the final volley")
 else:
  var distances=main.map(func(s):return Vector2(s.point.x-s.target.x,s.point.z-s.target.z).length())
  check(distances.all(func(d):return d<=Finale.FALL_SPREAD[move-2]+.01),"Every falling shot stays inside the widened scatter radius")

func run():
 create_timer(300).timeout.connect(func():printerr("LUMINA_QUEUE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QUEUE_OUT))
 visual=DisplayServer.get_name()!="headless"
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false);game.tuning.invincible=true;game.model.phase="wave"
 game.ui.hide();game.forest_ui.hide();game.training_dummy.position=Vector3(0,-1000,0)
 var owner=game.army_runtime;owner.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear();owner.set_navigation(9433,{"width":0})
 var p=game.player;p.select_character(30);fresh();caster=p.active_ability;fx=game.crowd.army.presentation
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;root.title="Goemon · Three queued elemental volleys"
 if visual:root.set_flag(Window.FLAG_NO_FOCUS,true)
 game.camera_rig.camera.position=ORIGIN+Vector3(65,115,130);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,10,-25))
 var pool=Pool.service(game);var prepared=pool.created;var misses=pool.misses
 pool.launched.connect(func(shot):
  shot.set_physics_process(false)
  if shot.get_script()==Shot:shots.append({"kind":shot.kind,"secondary":shot.secondary,"point":shot.position,"target":caster.aim,"damage":shot.damage,"cycle":caster.marker/Finale.moves[caster.move].size(),"direction":shot.velocity.normalized()}))
 check(Finale.FALL_SPREAD==[97.2,64.8],"Water and Fire scatter radii are twenty percent wider")
 var native=Finale.native()
 check(is_equal_approx(native.finale_ranges[0],97.2) and is_equal_approx(native.finale_ranges[1],64.8),"Native enemies receive the same widened spread")
 var cases=[1,3,7] if visual else [1,2,3,7]
 for move in [1,2,3]:
  for presses in cases:
   reset_cast();seed(572+move);key(move);await advance(6)
   var ticket=caster.ticket.duplicate(true)
   if presses==3:await advance(40)
   for i in presses-1:
    var elapsed=caster.elapsed;var marker=caster.marker
    key(move)
    if i<2 and presses!=3:check(is_zero_approx(caster.elapsed) and caster.marker==0,"Early press restarts the %s gesture"%Finale.NAMES[move])
    else:check(is_equal_approx(caster.elapsed,elapsed) and caster.marker==marker,"Late or over-cap press never truncates the active volley")
   check(caster.ticket==ticket,"Queued spells retain their original damage ticket")
   if presses==3:
    await advance(65);await view("%s-queued-spread"%Finale.NAMES[move].to_lower())
   await finish_cast(move,mini(presses,3));verify_volleys(move,mini(presses,3))
   if presses==7 and move in [2,3]:
    var old_radius=81.0 if move==2 else 54.0
    check(primary().any(func(s):return Vector2(s.point.x-s.target.x,s.point.z-s.target.z).length()>old_radius),"Seeded %s releases visibly reach beyond the old spread"%Finale.NAMES[move])
  reset_cast();key(move)
  var echo=InputEventKey.new();echo.keycode=KEY_1+move-1;echo.physical_keycode=echo.keycode;echo.pressed=true;echo.echo=true
  for i in 5:Input.parse_input_event(echo.duplicate());Input.flush_buffered_events()
  check(is_equal_approx(caster.duration,Finale.moves[move].size()/30.0),"Held-key repeat does not add casts")
  key(move);key(move);await advance(6);caster.interrupt_for_dodge();caster.tick(20)
  check(primary().is_empty() and not caster.is_attacking(),"Evade discards every unreleased queued volley")
  reset_cast();key(move);await advance(50);key(move);key(move)
  var fired=primary().size();click();caster.cancel();caster.tick(20)
  check(primary().size()==fired,"Switching attacks discards remaining volleys after release")
 # Equipped versions use the same controller and queue, without a loadout reset.
 p.select_character(1)
 for move in [1,2,3]:
  p.spell_loadout.equip(1,"equip","dark-lumina-3/"+Finale.NAMES[move].to_lower());reset_cast()
  key(1);caster=p.spell_loadout.current.controller;await advance(6)
  for i in 5:key(1)
  await finish_cast(move,3);verify_volleys(move,3)
  p.spell_loadout.equip(1,"equip","")
 p.select_character(30);caster=p.active_ability;reset_cast();await advance(480)
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 # Consecutive queues at maximum pickup speed overlap falling and lingering Fire.
 for repeat in 2:
  reset_cast();p.powerups.attack_speed=20;p.attack_speed_stacks=p.MAX_ATTACK_SPEED_STACKS;p.position=ORIGIN+Vector3.UP*300
  for chain in 3:
   for i in 3:key(3)
   while caster.is_attacking():await advance(1)
  check(primary().size()==288,"Consecutive accelerated airborne Fire queues keep all nine volleys")
  await advance(480)
  check(not pool.all.values().any(func(entries):return entries.any(func(s):return s.pool_live and s.get_script()==Shot)),"All queued falling and lingering hazards retire naturally")
 check(pool.created==prepared and pool.misses==misses,"Repeated queued spells stay within their prepared projectile pools")
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated queues retain no nodes or resources")
 step_times.sort();frame_times.sort()
 var report={"checks":checks,"failures":failures,"cases":cases,"pool_before":prepared,"pool_after":pool.created,"pool_misses":pool.misses-misses,"peak_fire":peak_fire,"node_delta":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"step_p95_ms":step_times[int(step_times.size()*.95)]}
 if visual:report.frame_p95_ms=frame_times[int(frame_times.size()*.95)];report.frame_max_ms=frame_times[-1]
 FileAccess.open(QUEUE_OUT+("desktop" if visual else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LUMINA_QUEUE_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
