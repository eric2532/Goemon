extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Boss Speed and Sand Beam/"
var samples=[]
var intervals=[]
var focused=0
var stepped=0
var last_frame=0
var evidence={}
var home_point=Vector3(0,.1,140)
const INPUTS=["scripts/attack_chain.gd","scripts/recovered_ed_beam.gd","scripts/forest/forest_tower_arrows.gd","scripts/forest/forest_waves.gd","scripts/forest/forest_enemy_roles.gd","scripts/forest/dark_lumina_kit.gd","scripts/player.gd","scripts/recovered_enemy_combat.gd","scripts/recovered_enemy_model.gd","scripts/forest/skullpion_effects.gd","scripts/forest/skullpion_visual.gd","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib"]

func advance(count:int):
 for i in count:
  var start=Time.get_ticks_usec()
  game.player._physics_process(1.0/60)
  samples.append(Time.get_ticks_usec()-start)
  evidence.walk_peak=maxf(evidence.get("walk_peak",0),Vector2(game.player.velocity.x,game.player.velocity.z).length())
  game.camera_rig.update_camera(1.0/60)
  await physics_frame
  stepped+=1
  if root.has_focus():focused+=1
  var now=Time.get_ticks_usec()
  if last_frame>0:intervals.append((now-last_frame)/1000.0)
  last_frame=now

func park(point:Vector3):
 var p=game.player;p.cancel_charge();p.position=point;p.velocity=Vector3.ZERO;p.smoke_move=Vector2.ZERO
 p.jump_buffer=0;p.jump_windup=0;p.jumps_used=0;p.coyote=0;p.reset_wall_jump()
 await advance(12)

func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 var camera=game.camera_rig.camera;var previous=camera.global_transform
 if label_ in ["sand-blast","sand-range"]:
  camera.global_position=game.player.position+Vector3(210,150,100)
  camera.look_at(game.player.position+Vector3(0,5,-95))
 await frames(2)
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png(OUT+label_+".png")
 camera.global_transform=previous

func attack_step(seconds:float):
 var p=game.player
 p.active_ability.tick(seconds);p.model.animate(seconds,0,p.is_on_floor(),p.velocity.y,0,false,0,false)

func range_and_aim():
 var p=game.player;var combat=p.active_ability;var skull=p.model.skull
 var targets=[]
 var home=p.position
 p.position.y+=40
 for offset in [Vector3(0,0,-200),Vector3(24,0,-200),Vector3(40,0,-200),Vector3(0,0,-290),Vector3(200,0,0)]:
  var row=game.model.waves.spawn_enemy(0,p.position+offset);row.hp=10000;row.max_hp=10000;row.pos.y=p.position.y;targets.append(row)
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
 p.ai_controlled=true;p.ai_aim=p.position+Vector3(0,5,-200)
 combat.start_skull_attack(103);combat.state.sand_held=true;attack_step(.47)
 print("BEAM_RANGE_TRACE ",p.position," end=",combat.skull_sand_path()," targets=",targets.map(func(row):return [row.pos,row.hp]))
 check(targets[0].hp<10000 and targets[1].hp<10000,"Longer, thicker beam pierces both fitted targets 200 metres ahead")
 await capture("sand-range")
 check(targets[2].hp==10000 and targets[3].hp==10000,"Thick beam retains finite side and end limits")
 check(is_equal_approx(skull.sand.global_basis.z.length(),250.0/160) and is_equal_approx(skull.sand.global_basis.x.length(),28.8/40),"Prepared dust mesh doubles its reach and width with a crossed vertical section")
 p.ai_aim=p.position+Vector3(200,5,0);attack_step(.2)
 check(targets[4].hp<10000,"Held dust follows a changed aim at the next Ed-style pulse")
 var hp=targets[4].hp;p.cancel_charge();attack_step(1)
 check(targets[4].hp==hp,"Cancelling a steered beam cannot deliver delayed hits")
 p.ai_controlled=false;p.position=home;p.velocity=Vector3.ZERO
 for row in targets:game.actors[row.id].take_hit(100000,Vector3.FORWARD,false,{"tower":true})

func run():
 create_timer(180).timeout.connect(func():printerr("FAIL: Skullpion controls timeout");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var hashes={}
 for path in INPUTS:hashes[path]=FileAccess.get_sha256("res://"+path)
 var map=preload("res://scripts/forest/forest_map_document.gd").new();map.load_wind_meadow()
 await setup_fixture(map.data)
 home_point.y=game.model.surface_height(home_point.x,home_point.z)+.1
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 var p=game.player;p.select_character(27);fresh();p.set_scarf_equipped(false)
 game.settings.jump_styles={};p.jump_style.prepare();game.settings.spell_loadouts={};p.spell_loadout.prepare()
 game.tuning.invincible=true
 var combat=p.active_ability;var skull=p.model.skull
 await park(home_point)
 game.training_dummy.position=p.position+Vector3(0,0,-30);game.training_dummy.home=game.training_dummy.position
 game.model.update_vision(game.training_dummy.position)
 p.facing=Vector3.FORWARD;p.model.rotation.y=0
 p.auto_attack_enabled=true;p.auto_lock_target=game.training_dummy;p.auto_lock_refresh=100
 combat.start_skull_attack(103);p.auto_attack_enabled=false
 check(combat.action==103,"LMB selects the original sand blast")
 attack_step(.46);check(p.attack_left<=p.attack_duration,"Faster preparation keeps the attack countdown within its real duration")
 check(contacts.is_empty() and not skull.sand.visible,"Sand windup is five times faster without early damage")
 attack_step(.01);check(contacts.size()==1 and skull.sand.visible,"Sand release shows its prepared plume and deals one directional hit")
 await capture("sand-blast")
 attack_step(1.8);check(contacts.size()==9,"Sand uses Ed’s 0.2-second piercing pulses without per-frame duplicate hits")
 check(not skull.sand.visible,"Finite sand cast stops at the active animation end")
 attack_step(1);check(not combat.is_attacking(),"Sand returns to idle")
 check(is_equal_approx(p.movement_multiplier(),5) and is_equal_approx(preload("res://scripts/forest/forest_enemy_roles.gd").stats(4).speed,7.5),"Player and native Skullpion ground speeds are five times their previous values")
 var kit=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model)
 check(is_equal_approx(kit.skullpion[0],game.model.balance.boss_speed*game.model.balance.enemy_speed_mult*5),"Saved boss-speed settings also feed the fivefold speed into the native kit")
 var event=InputEventAction.new();event.action="light_attack";event.pressed=true;p._unhandled_input(event)
 attack_step(4)
 check(combat.is_attacking() and skull.sand.visible,"Holding primary sustains the dust beam beyond the finite cast")
 event.pressed=false;p._input(event)
 var released_hits=contacts.size();attack_step(1)
 check(not combat.is_attacking() and not skull.sand.visible and contacts.size()==released_hits,"Primary release clears the beam immediately and prevents stale hits")
 p.spell_loadout.number_input(4,true);attack_step(.5)
 check(combat.is_attacking() and skull.sand.visible,"Numbered sand slot supports held beam input")
 p.spell_loadout.number_input(4,false)
 check(not combat.is_attacking(),"Releasing numbered slot stops the beam")
 var row=game.model.waves.spawn_enemy(0,p.position+Vector3(0,0,-32));row.hp=10000;row.max_hp=10000
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
 var victim=game.actors[row.id];var hp=victim.hp
 combat.start_skull_attack(103);p.facing=Vector3.FORWARD;attack_step(4.7)
 check(victim.hp<hp,"Sand damages a native army opponent through existing hit ownership")
 for offset in [Vector3(30,0,0),Vector3(0,0,30)]:
  game.training_dummy.position=p.position+offset;game.model.update_vision(game.training_dummy.position);contacts.clear()
  combat.start_skull_attack(103);p.facing=Vector3.FORWARD;p.model.rotation.y=0;attack_step(4.2)
  check(contacts.is_empty(),"Sand rejects targets beside or behind the mouth");combat.cancel()
 game.training_dummy.position=p.position+Vector3(0,0,-30);game.model.update_vision(game.training_dummy.position)
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(12,12,2)
 wall.add_child(shape);game.add_child(wall);wall.position=p.position+Vector3(0,4,-24);await physics_frame
 contacts.clear();combat.start_skull_attack(103);p.facing=Vector3.FORWARD;p.model.rotation.y=0;attack_step(4.2)
 check(contacts.is_empty(),"Solid cover blocks sand damage");combat.cancel();wall.queue_free();await physics_frame
 await range_and_aim()
 game.tower_arrows.launch({"id":98765,"from":p.position,"to":p.position})
 check(game.tower_arrows.visuals[98765].basis.is_finite(),"An overlapping fast boss and tower arrow retain a finite launch orientation")
 contacts.clear();p.attack_chain.reset();tap("equip")
 check(combat.action==102 and is_equal_approx(p.attack_duration,1.1),"E tail sweep takes 1.1 seconds instead of 3.3")
 attack_step(.16);check(contacts.is_empty(),"Tail retains its proportionally shortened windup")
 attack_step(.01);check(contacts.size()==1,"First tail hit advances from 0.5 seconds to 0.167 seconds")
 attack_step(.53);check(absf(absf(p.model.body.rotation.y)-PI)<.001,"The visible tail turn runs at the same threefold speed")
 await capture("tail-sweep")
 attack_step(.4);check(contacts.size()==6 and not combat.is_attacking(),"Fast tail preserves all six contacts and finishes at 1.1 seconds")
 combat.start_skull_attack(103);attack_step(2.5);p.cancel_charge()
 check(not skull.sand.visible and skull.voices.all(func(voice):return not voice.playing),"Cancellation clears the reused sand and audio")
 var nodes=skull.find_children("*","",true,false).size()
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 12:
  combat.start_skull_attack(103);attack_step(4.7)
  combat.start_skull_attack(102);attack_step(1.1)
 await advance(70)
 check(skull.find_children("*","",true,false).size()==nodes,"Repeated sand and tail casts reuse all boss presentation nodes")
 evidence.repeat_resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 check(evidence.repeat_resource_delta<=2,"Repeated casts leave no growing resource ownership")
 await park(home_point);p.smoke_move=Vector2(1,0);evidence.walk_peak=0;var walk_start=p.position
 await advance(60);p.smoke_move=Vector2.ZERO
 check(evidence.walk_peak>=p.combat_tuning("walk_speed")*5*.95,"Actual Skullpion walking reaches the faster ground speed")
 await park(home_point);tap("jump");await advance(6)
 check(p.velocity.y>100 and p.position.y>home_point.y+8,"Space launches the heavy boss promptly")
 var apex=p.position.y;var descending=false;var landing_frame=0
 for i in 80:
  await advance(1);apex=maxf(apex,p.position.y)
  if p.velocity.y< -100:descending=true
  if p.is_on_floor():landing_frame=i+7;break
 check(apex-home_point.y>35 and descending and landing_frame>0 and landing_frame<65,"Leap clears tall castle roofs and falls fast within about one second")
 evidence.leap={"height":apex-home_point.y,"seconds":landing_frame/60.0}
 p.wall_jump_normal=Vector3.BACK;p.perform_wall_jump()
 check(p.velocity.y>=160 and p.wall_jump_recovery>0,"Wall jumps keep the fast launch and existing push-off recovery")
 await park(home_point);contacts.clear();game.training_dummy.position=p.position+Vector3(0,0,-30);game.model.update_vision(game.training_dummy.position)
 tap("heavy_attack");check(combat.action==104 and p.velocity.y>=160,"RMB jump stomp uses the fast launch")
 await advance(15);check(contacts.is_empty(),"Jump stomp cannot deal its landing hit while airborne")
 await capture("jump-stomp")
 await advance(60);check(contacts.size()==1 and not combat.is_attacking(),"Jump stomp hits once on physical landing and recovers promptly")
 p.select_character(29)
 check(is_equal_approx(p.movement_multiplier(),6) and is_equal_approx(preload("res://scripts/forest/forest_enemy_roles.gd").stats(17).speed,21.6),"Player and native Dark Lumina 2 ground speeds are five times their previous values")
 await park(home_point);p.smoke_move=Vector2(1,0);evidence.walk_peak=0;walk_start=p.position
 await advance(60);p.smoke_move=Vector2.ZERO
 print("DL2_WALK_TRACE ",walk_start," end=",p.position," velocity=",p.velocity," floor=",p.is_on_floor()," speed=",p.combat_tuning("walk_speed")," active=",p.active_ability.mode)
 check(evidence.walk_peak>=p.combat_tuning("walk_speed")*6*.95,"Actual Dark Lumina 2 walking reaches the faster ground speed")
 p.select_character(27);combat=p.active_ability;skull=p.model.skull
 # Cross the actual castle colliders with the full 30 x 25 x 40 body.
 check(not game.enemy_objectives.is_empty(),"Castle crossing uses a real enemy stronghold")
 if not game.enemy_objectives.is_empty():
  var castle=game.enemy_objectives[0]
  var boxes=preload("res://scripts/forest/forest_enemy_castle.gd").boxes(castle.data())
  var bounds:AABB=boxes[0]
  for box in boxes:bounds=bounds.merge(box)
  bounds.position+=castle.global_position
  var start=Vector3(bounds.get_center().x,0,bounds.end.z+26)
  start.y=game.model.surface_height(start.x,start.z)+.1
  await park(start);p.smoke_move=Vector2(0,-1);tap("jump")
  await advance(6)
  var landed_on_castle=false
  var cleared_castle=false
  evidence.castle_trace=[]
  for i in 60:
   await advance(1)
   evidence.castle_trace.append([i+7,p.position.x,p.position.y,p.position.z,p.velocity.y,p.velocity.z,p.is_on_floor()])
   if i==21:await capture("castle-leap")
   if not p.is_on_floor() and p.position.z+20<bounds.position.z-.05:cleared_castle=true
   if p.is_on_floor() and not cleared_castle:landed_on_castle=true
  p.smoke_move=Vector2.ZERO
  print("CASTLE_LEAP bounds=",bounds," start=",start," end=",p.position)
  check(cleared_castle and not landed_on_castle,"One fast leap carries the entire boss over the castle without landing on its walls")
  await advance(30)
  check(p.is_on_floor(),"Heavy fall lands on physical ground beyond the castle")
 p.spell_loadout.equip(27,"equip","goemon/surge");tap("equip")
 check(combat.mode!="attack","An equipped E spell still overrides the native tail key")
 p.cancel_charge();p.spell_loadout.equip(27,"equip","")
 p.jump_style.equip(27,"double");await park(home_point);tap("jump");await advance(4)
 check(p.velocity.y<30,"An explicitly equipped jump style retains its own motion")
 p.jump_style.equip(27,"");p.select_character(1);await park(home_point);tap("jump");await advance(5)
 check(p.velocity.y<30 and p.body_shape.shape is CapsuleShape3D,"Other fighters keep their jump physics and collision")
 intervals.sort();evidence.stepped_frames=stepped;evidence.focused_frames=focused
 evidence.frame_interval_ms={"p50":intervals[intervals.size()/2],"p95":intervals[int(intervals.size()*.95)],"max":intervals.back()}
 samples.sort();evidence.hero_step_usec_p95=samples[int(samples.size()*.95)]
 evidence.source_hashes=hashes
 check(INPUTS.all(func(path):return hashes[path]==FileAccess.get_sha256("res://"+path)),"Verification source stays unchanged during the run")
 evidence.checks=checks;evidence.failures=failures;evidence.renderer=RenderingServer.get_video_adapter_name()
 FileAccess.open(OUT+("headless-results.json" if DisplayServer.get_name()=="headless" else "desktop-results.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKULLPION_CONTROLS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
