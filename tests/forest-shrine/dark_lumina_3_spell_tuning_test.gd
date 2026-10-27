extends "res://tests/forest-shrine/dark_lumina_3_controls_test.gd"
const TUNING_OUT=OUT+"Spell Tuning/"
const TUNING_STAGE=Vector3(0,.1,110)
var released=[]
func fresh(surge:bool=false):
 super.fresh(surge);game.player.position=TUNING_STAGE
func snap(label_:String):
 if not visual:return
 game.crowd.army.presentation.draw_effects()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(TUNING_OUT+label_+".png")
func run():
 visual=DisplayServer.get_name()!="headless"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TUNING_OUT))
 create_timer(180).timeout.connect(func():printerr("FINALE_TUNING_TIMEOUT");quit(1))
 await setup_fixture()
 root.title="Goemon · Dark Lumina wings, spells and flight"
 root.set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.set_process(false);game.model.phase="wave";game.tuning.invincible=true
 var p=game.player;p.select_character(30);fresh();var c=p.active_ability
 var presentation=game.crowd.army.presentation;var pool=Pool.service(game)
 var prepared=pool.created;var misses=pool.misses
 game.ui.hide();game.training_dummy.hide()
 game.camera_rig.camera.position=TUNING_STAGE+Vector3(26,20,40);game.camera_rig.camera.look_at(TUNING_STAGE+Vector3(0,4,-8))
 for i in 6:check(Finale.DAMAGE[i]>=[1.0,.15,.7,.2,1.5,.8][i]*5,"Spell %d deals at least five times its previous damage"%i)
 check(Finale.DAMAGE[5]==8,"Each of five Sky clones deals ten times its previous damage")
 c.start_move(1);await advance(50)
 var wings=presentation.effects.filter(func(e):return e.kind in ["finale-wind","finale-wind_outer"])
 check(wings.size()==4 and wings.filter(func(e):return e.mirrored).size()==2,"Wind has two mirrored wings with both recovered layers")
 await snap("wind-two-wings")
 c.cancel();check(not presentation.effects.any(func(e):return e.kind in ["finale-wind","finale-wind_outer"]),"Cancel removes both wings")
 p.position=ORIGIN+Vector3(0,0,50)
 var row=game.model.waves.spawn_enemy(0,p.position+Vector3(0,0,-8));row.hp=100000;row.max_hp=100000
 game.army_runtime.import_arrivals();var victim=game.army_runtime.enemy_target(row.id)
 # The isolated floor is flat; remove the original map's native wall constraints.
 game.army_runtime.native.set_navigation({})
 c.start_move(1);c.area(p.position+p.facing*5*Finale.SCALE,Finale.WIND_AREA,0,true)
 var before=victim.position
 for i in 6:game.army_runtime.native.step(1.0/60)
 var state=game.army_runtime.unit_state(victim.handle)
 check(state.position.z<before.z-.3,"Playable Wind pushes a real native target away from the caster: %s -> %s"%[before,state.position])
 check(state.hp==100000,"Wind area pushes while the visible gusts own damage")
 c.cancel();game.army_runtime.despawn(victim.handle)
 pool.launched.connect(func(shot):
  if shot.get_script()==preload("res://scripts/dark_lumina_3_projectile.gd"):
   shot.set_physics_process(false)
   released.append({"kind":shot.kind,"secondary":shot.secondary,"point":shot.position,"damage":shot.damage,"up":shot.basis.y,"forward":shot.basis.z,"cross":shot.cross_slash}))
 for move in [2,3]:
  fresh();c.start_move(move);var target=c.aim;released.clear();await advance(68)
  await snap("water-scattered" if move==2 else "fire-scattered")
  await advance(110)
  var primary=released.filter(func(s):return not s.secondary)
  check(primary.size()==(6 if move==2 else 32),"Enlarged falling spell retains every release: %d"%move)
  var spread=0.0
  for shot in primary:spread=maxf(spread,Vector2(shot.point.x-target.x,shot.point.z-target.z).length())
  check(spread>18 and spread<=Finale.FALL_SPREAD[move-2],"Falling spell %d scatters beyond its old eighteen-metre radius"%move)
  check(primary.all(func(shot):return is_equal_approx(shot.damage,65*Finale.DAMAGE[move])),"Falling spell %d uses shared damage exactly once"%move)
  c.cancel();await advance(240)
 fresh();c.start_move(5);await advance(57)
 var clones=presentation.effects.filter(func(e):return e.kind=="finale-sky_copy")
 check(clones.size()==5,"Sky prepares five standing clones")
 var material=Finale.meshes.sky_copy.surface_get_material(0)
 check(material.get_shader_parameter("effect_pose_start")==0 and material.get_shader_parameter("effect_pose_count")==2,"Waiting and flying clones use the recovered upright pose")
 await snap("sky-five-standing-clones")
 released.clear();await advance(73)
 check(released.filter(func(s):return s.kind==5).size()==5,"Sky sends every standing clone into the attack")
 check(released.all(func(s):return s.up.dot(Vector3.UP)>.999),"Launched clones stay upright along their flight path")
 await snap("sky-clones-launched")
 c.cancel();await advance(180)
 fresh();c.start_move(0);released.clear();await advance(100)
 check(released.any(func(s):return s.cross),"Shared Sword releases its cross slashes")
 check(released.all(func(s):return s.forward.dot(p.facing)>.999),"Shared Sword waves point along travel")
 check(not Finale.meshes.sword_cross.surface_get_material(0).get_shader_parameter("billboard"),"Camera facing cannot overwrite the slash angle")
 var normals=Finale.meshes.sword_cross.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
 check(normals.size()>0 and absf(normals[0].dot(Vector3.BACK))<.001,"The crescent curves along travel in a diagonal cut plane")
 await snap("sword-correct-angle")
 c.cancel();await advance(180)
 fresh();c.start_move(4);check(not p.can_fly(),"Earth keeps its physical takeoff and landing")
 for i in 140:
  await advance(1)
  if c.marker>40:break
 await advance(12);await snap("earth-expanded");await advance(140)
 check(not c.is_attacking() and p.model.body.visible,"Earth lands and releases its larger area")
 fresh();check(p.can_fly(),"Dark Lumina has flight without equipment")
 check(is_equal_approx(p.movement_multiplier(),1.6),"Ground floating is sixty percent faster")
 p.position=ORIGIN+Vector3(0,5,45)
 p.smoke_move=Vector2(0,-1);Input.action_press("jump");Input.action_press("sprint")
 await advance(45)
 check(p.flying and p.position.y>ORIGIN.y+8 and p.velocity.y>24,"Space gives powered flight faster than Ben's boosted rise: %s v=%s"%[p.position,p.velocity])
 check(Vector2(p.velocity.x,p.velocity.z).length()>36,"Shift flight outruns Ben's boosted travel: %s"%p.velocity)
 await snap("faster-flight")
 Input.action_release("jump");await advance(55)
 check(p.velocity.y<0,"Releasing Space descends")
 Input.action_release("sprint");p.smoke_move=Vector2.ZERO
 await advance(360)
 check(pool.created==prepared and pool.misses==misses,"Repeated enlarged skills reuse all prepared leases")
 check(not pool.all.values().any(func(nodes):return nodes.any(func(s):return s.pool_live and s.get_script()==preload("res://scripts/dark_lumina_3_projectile.gd"))),"All enlarged hazards retire")
 p.select_character(1);check(not p.can_fly(),"Changing fighter removes innate finale flight")
 p.select_character(3);var rogue=p.active_ability;rogue.player.vel=Vector3.ZERO
 rogue.receive_knockback(Vector3.FORWARD);check(is_equal_approx(rogue.player.vel.z,-7),"Shared knockback retains ordinary strength")
 rogue.receive_knockback(Vector3.FORWARD,17);check(is_equal_approx(rogue.player.vel.z,-24),"Wind's extra impulse reaches the Rogue movement owner")
 step_times.sort();frame_times.sort()
 var report={"checks":checks,"failures":failures,"pool_before":prepared,"pool_after":pool.created,"pool_misses":pool.misses-misses,"manual_step_p95_ms":step_times[floori(step_times.size()*.95)]}
 if visual:report.frame_median_ms=frame_times[frame_times.size()/2];report.frame_p95_ms=frame_times[floori(frame_times.size()*.95)];report.frame_max_ms=frame_times[-1]
 FileAccess.open(TUNING_OUT+("rendered-results.json" if visual else "headless-results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FINALE_TUNING_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
