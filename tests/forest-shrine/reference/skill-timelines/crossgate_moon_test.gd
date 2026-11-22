extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Qi=preload("res://scripts/qigong_combat.gd")
const Metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
const OUT="res://build/Other Files/Asset Toolkit/Kaz Moon/White Sparks/"
const HP=60000.0
const TICK=1.0/60.0
var shots:Array=[]
var samples:Array=[]
var player:Hero
var pool:Node

func press_one():
 player.spell_loadout.number_input(1,true)
 player.spell_loadout.number_input(1,false)

func cast_steps(count:int):
 for i in count:player._physics_process(TICK)

func flight_steps(count:int):
 for i in count:
  var start=Time.get_ticks_usec()
  var active=false
  for shot in shots:
   if shot.pool_live:
    active=true;shot._physics_process(TICK)
  if active:samples.append((Time.get_ticks_usec()-start)/1000.0)

func cues_after(order:int,kind:String)->Array:
 return game.voices.filter(func(voice):return voice.get_meta("kind","")==kind and voice.get_meta("order",0)>order)

func waves_glide_on_floor()->bool:
 var live=shots.filter(func(shot):return shot.pool_live)
 return not live.is_empty() and live.all(func(shot):
  var tip:Vector3=shot.visual.global_position
  var floor_hit=AttackChain.world_ray(shot,tip+Vector3.UP*.5,tip-Vector3.UP*.5,1,[],false)
  var basis:Basis=shot.visual.global_basis
  var normal:Vector3=shot.ground_normal
  return not floor_hit.is_empty() and absf(tip.y-floor_hit.position.y-Qi.Moon.GROUND_CLEARANCE)<.01 and basis.y.normalized().dot(normal)>.999 and basis.z.normalized().dot(shot.velocity.slide(normal).normalized())>.999)

func capture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+filename+".png")==OK,"Captured "+filename)

func profile_volley():
 var viewport=root.get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(viewport,true)
 var frame_ms:Array=[]
 var gpu_ms:Array=[]
 var last=Time.get_ticks_usec()
 for i in 72:
  await RenderingServer.frame_post_draw
  var now=Time.get_ticks_usec()
  if i>=12:
   frame_ms.append((now-last)/1000.0)
   gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
  last=now
 print("MOON_VOLLEY_FRAME_MS ",Metrics.summary(frame_ms))
 print("MOON_VOLLEY_GPU_MS ",Metrics.summary(gpu_ms) if gpu_ms.max()>0 else "unavailable")
 RenderingServer.viewport_set_measure_render_time(viewport,false)

func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 create_timer(100).timeout.connect(func():quit(1))
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 doc.load_wind_meadow()
 await setup_fixture(doc.data)
 player=game.player
 for node in [game,player,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.set_process(false)
 player.select_character(34);fresh()
 game.settings.disable_character_cooldowns=false
 var home=Vector3(-150,0,150)
 home.y=game.model.surface_height(home.x,home.z)+.1
 player.position=home;cast_steps(5)
 game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*100
 game.training_dummy.collision_layer=0
 game.camera_rig.camera.global_position=home+Vector3(5,5,11)
 game.camera_rig.camera.look_at(home+Vector3(0,1,-3))
 var army=game.army_runtime
 army.set_physics_process(false);army.set_process(false)
 var rows=[]
 var variant=preload("res://scripts/forest/forest_enemy_roles.gd").SLIME if "--crossgate-pet-test" in OS.get_cmdline_user_args() else 0
 for i in 7:
  var point=home+Vector3((i-3)*8.0,0,-9.0-i)
  point.y=game.model.surface_height(point.x,point.z)+.1
  var row=game.model.waves.spawn_enemy(variant,point,-1,i)
  row.hp=HP;row.max_hp=HP;rows.append(row)
 army.import_arrivals();army.integration_tick(TICK)
 var targets=rows.map(func(row):return game.actors[row.id])
 game.crowd.present_army(army.render_snapshot(),[])
 await physics_frame
 pool=game.get_node("CharacterProjectiles")
 pool.launched.connect(func(shot):
  if shot.get_script()==Qi.Moon:
   shot.set_physics_process(false);shots.append(shot))
 var bar=player.spell_loadout
 check(bar.spell_for(34,"equip")==Qi.MOON_ID and bar.numbered_slots[0][0]=="※鴻雁追月 · Lv. 11","Kaz starts with level 11 追月 on key 1")
 check(bar.Catalog.all().has(Qi.ID),"Qi Orbs remains available to saved assignments")
 var library:SoundLibrary=game.sound_library
 library.select_character(34)
 library.mutes.qigong_charge=true
 library.mutes.coin_hit=true
 var order:int=game.voice_idx
 press_one()
 if bar.current==null:
  check(false,"Slot 1 starts in battle (phase=%s, playing=%s, paused=%s, transitioning=%s, HP=%s, hold=%s, queued=%s)"%[game.model.phase,game.playing,game.paused,game.transitioning,player.hp,player.combat_hold_left,bar.magic_queue.size()])
  quit(1);return
 var skill=bar.current.controller
 var charge=cues_after(order,"cg_moon_charge")
 check(skill.charge_fx.frame==0 and skill.charge_fx.visible and charge.size()==1 and charge[0].stream==SoundLibrary.CROSSGATE_FLASH,"Moon plays its original charge while Qi Blast charge is muted")
 cast_steps(26)
 check(skill.charge_fx.frame==8 and skill.charge_fx.visible and shots.is_empty(),"Nine charge frames hold for three updates each")
 await capture("01-charge")
 cast_steps(1)
 check(not skill.charge_fx.visible and shots.is_empty(),"Charge ends before the sword marker")
 cast_steps(12)
 check(cues_after(order,"swing").is_empty(),"First sword cue waits until tick 40")
 cast_steps(1)
 check(cues_after(order,"swing").size()==1 and shots.is_empty(),"First sword cue plays at tick 40")
 cast_steps(14)
 check(cues_after(order,"swing").size()==2 and cues_after(order,"cg_moon_release").is_empty() and shots.is_empty(),"Second sword cue plays one update before the volley")
 cast_steps(1)
 var release=cues_after(order,"cg_moon_release")
 check(shots.size()==6 and shots.all(func(shot):return shot.visible and shot.age==0),"All six waves are visible together on tick 55")
 check(release.size()==1 and release[0].stream==SoundLibrary.original_for(34,"cg_moon_release"),"Exactly one original 268 cue plays on the release tick")
 if shots.size()!=6:quit(1);return
 var locks=shots.map(func(shot):return shot.target)
 check(locks.all(func(target):return target in targets) and locks.all(func(target):return locks.count(target)==1),"Six waves lock distinct native enemies")
 var visuals=shots.map(func(shot):return shot.visual)
 var emitters=shots.map(func(shot):return shot.sparks)
 var bounds=Qi.Moon.shock_mesh.get_aabb()
 check(is_zero_approx(bounds.end.z) and is_zero_approx(bounds.position.y) and bounds.size.y*Qi.Moon.VISUAL_SCALE.y>2.0,"The shared mesh has a ground-level nose and a raised crest")
 check(shots.all(func(shot):return shot.visual.is_visible_in_tree() and shot.visual.mesh==Qi.Moon.shock_mesh and shot.visual.material_override==Qi.Moon.shock_material and shot.visual.scale.is_equal_approx(Qi.Moon.VISUAL_SCALE)),"Each wave uses the shared folded mesh and silver slash material at the shared base length")
 check(shots.all(func(shot):
  return shot.sparks.emitting and not shot.sparks.local_coords and shot.sparks.mesh==Qi.Moon.spark_mesh and (shot.sparks.global_position-shot.global_position).dot(shot.velocity)<0.0
 ),"Each wave leaves world-space sparks behind its leading tip")
 var facing=player.facing.slide(Vector3.UP).normalized()
 check(shots.all(func(shot):
  var rear:Vector3=shot.visual.to_global(Vector3(0,0,-78.0*shot.visual_growth))
  return (shot.first_from-player.global_position).dot(facing)>.9 and (rear-player.global_position).dot(facing)>0.0
 ),"The muzzle and the visible wave tails are in front of Kaz on release")
 var launch_headings=shots.map(func(shot):return shot.velocity)
 check(launch_headings.all(func(heading):return launch_headings.count(heading)==1),"Six different headings fan out from the front muzzle")
 check(waves_glide_on_floor(),"All six leading tips glide at Kojiro's floor clearance on release")
 check(shots.all(func(shot):return (shot.position-shot.first_from).slide(Vector3.UP).length()>Qi.Moon.SPEED*TICK*1.99),"Projectiles advance twice along the floor on release")
 check(shots.all(func(shot):return shot.velocity.normalized().is_equal_approx((shot.target.global_position-shot.first_from).slide(Vector3.UP).normalized())),"Waves steer toward the targets on the ground plane")
 check(shots.all(func(shot):return is_equal_approx(shot.damage,3000.0) and is_equal_approx(shot.hit_radius,31*Qi.Moon.VISUAL_SCALE.x)),"Each wave carries 3,000 base damage with a radius matching its fixed crest width")
 await capture("02-release")
 for i in 12:
  flight_steps(1)
  if DisplayServer.get_name()!="headless":await process_frame
 await capture("03-flight")
 if DisplayServer.get_name()!="headless":
  var camera:Camera3D=game.camera_rig.camera
  var original_view=camera.global_transform
  camera.global_position=home+Vector3(9,13,6)
  camera.look_at(home+Vector3(0,1.5,-6))
  flight_steps(2)
  check(waves_glide_on_floor(),"The slash tips stay on the floor as the camera orbits")
  await capture("04-ground-glide")
  flight_steps(8)
  await capture("05-approach")
  camera.global_transform=original_view
  flight_steps(38)
 else:flight_steps(48)
 cast_steps(15)
 var impact=cues_after(order,"cg_moon_hit")
 check(not impact.is_empty() and impact.all(func(voice):return voice.stream==SoundLibrary.QIGONG_IMPACT),"Moon plays original cue 255 while Qi Blast impact is muted")
 library.mutes.erase("qigong_charge")
 library.mutes.erase("coin_hit")
 library.mutes.cg_moon_hit=true
 library.mutes.cg_moon_charge=true
 check(library.playback_for(34,"cg_moon_hit",null).muted and not library.playback_for(34,"qigong_hit",null).muted
  and library.playback_for(34,"cg_moon_charge",null).muted and not library.playback_for(34,"qigong_charge",null).muted,
  "Muting Moon's own controls leaves both Qi Blast controls enabled")
 library.mutes.erase("cg_moon_hit")
 library.mutes.erase("cg_moon_charge")
 var hits=targets.filter(func(enemy):return is_equal_approx(HP-enemy.hp,3000.0))
 check(hits.size()==6 and hits.all(func(enemy):return enemy in locks),"Each lock takes one native hit after the wave reaches it")
 check(shots.all(func(shot):return not shot.pool_live and shot.target==null and not shot.visual.is_visible_in_tree() and not shot.sparks.emitting),"Contact hides the slash, stops its emitter and clears each target")
 check(not skill.is_attacking() and skill.cooldown>0,"The attack finishes while the five-second cooldown runs")
 var created:int=pool.created
 for i in 4:
  shots.clear();skill.clear_cooldowns();player.attack_chain.reset()
  press_one();cast_steps(70);flight_steps(150)
 check(pool.created==created and pool.misses==0 and shots.size()==6 and shots.all(func(shot):return shot.visual in visuals and shot.sparks in emitters),"Four repeat volleys reuse the prepared meshes and emitters")
 shots.clear();skill.clear_cooldowns();press_one();cast_steps(40)
 bar.interrupt();cast_steps(32)
 check(shots.is_empty() and not skill.charge_fx.visible,"Evade interruption clears an unreleased volley")

 var before=targets.map(func(enemy):return enemy.hp)
 shots.clear();skill.clear_cooldowns();press_one();cast_steps(70)
 var wall=StaticBody3D.new()
 var shape=CollisionShape3D.new()
 var box=BoxShape3D.new();box.size=Vector3(30,12,.5)
 shape.shape=box;wall.add_child(shape);game.add_child(wall)
 wall.global_position=home+Vector3(0,3,-3)
 await physics_frame;await physics_frame
 flight_steps(120)
 check(targets.map(func(enemy):return enemy.hp)==before and shots.all(func(shot):return not shot.pool_live),"Solid cover added after launch stops waves before damage")
 wall.free()
 shots.clear()
 var deck=StaticBody3D.new()
 var deck_shape=CollisionShape3D.new()
 var deck_box=BoxShape3D.new();deck_box.size=Vector3(8,.4,12)
 deck_shape.shape=deck_box;deck.add_child(deck_shape);game.add_child(deck)
 deck.global_position=home+Vector3(-6,2,5)
 deck.rotation.x=.24
 await physics_frame;await physics_frame
 var deck_wave=pool.launch(player,Qi.Moon,Qi.MOON_ID,{"position":deck.global_position+Vector3.UP*.4,
  "velocity":Vector3.FORWARD*Qi.Moon.SPEED,"flight_life":1.0})
 var launch_y:float=deck_wave.global_position.y
 flight_steps(6)
 check(deck_wave.pool_live and deck_wave.global_position.y>launch_y+.4 and waves_glide_on_floor(),"A wave climbs an inclined deck with its tip at floor clearance")
 deck_wave.retire();deck.free()
 shots.clear()
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(player,0)
 for i in 5:
  check(mirrors.reinforce(34,home+Vector3(i-2,0,0)),"Native Kaz ally allocated")
  mirrors.bodies[i].perform(2,targets[0].global_position)
 for i in 55:
  for body in mirrors.bodies:
   body.step(TICK,{"position":body.position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO})
 check(shots.size()==30 and pool.misses==0,"Five simultaneous native allies release thirty prepared waves")
 if DisplayServer.get_name()!="headless":await profile_volley()
 var total_before=targets.reduce(func(sum,enemy):return sum+enemy.hp,0.0)
 flight_steps(100)
 var total_after=targets.reduce(func(sum,enemy):return sum+enemy.hp,0.0)
 check(is_equal_approx(total_before-total_after,30*3000.0),"Thirty allied waves apply 90,000 total damage to native enemies")
 mirrors.dispose()
 check(shots.all(func(shot):return not shot.pool_live and shot.target==null),"Ally retirement clears its leases")
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MOON_FLIGHT_STEP_MS ",Metrics.summary(samples))
 print("MOON_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
