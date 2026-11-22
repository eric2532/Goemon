extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Qi=preload("res://scripts/qigong_combat.gd")
const Metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
const TICK=1.0/60.0
const HP=60000.0
const REPORT="res://build/Other Files/Asset Toolkit/Uru/Spirit Shockwave/"
var launches:Array=[]
var samples:Array=[]
var player:Hero
var pool:Node

func key(number:int):
 var event=InputEventKey.new();event.physical_keycode=KEY_1+number-1;event.pressed=true
 player._unhandled_input(event)
 event.pressed=false;player._input(event)

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REPORT+name_+".png")==OK,"Captured "+name_)

func floor_point(point:Vector3)->Vector3:
 return Vector3(point.x,game.model.surface_height(point.x,point.z)+.1,point.z)

func spawn(point:Vector3)->Dictionary:
 var variant=preload("res://scripts/forest/forest_enemy_roles.gd").SLIME if "--crossgate-pet-test" in OS.get_cmdline_user_args() else 0
 var row=game.model.waves.spawn_enemy(variant,floor_point(point))
 row.hp=HP;row.max_hp=HP
 return row

func advance_cast(controller:Node,count:int):
 for i in count:
  var started=Time.get_ticks_usec()
  player.spell_loadout.tick(TICK)
  for shot in pool.all[controller.pool_key]:
   if shot.pool_live:shot._physics_process(TICK)
  if not controller.spirit_targets.is_empty():samples.append((Time.get_ticks_usec()-started)/1000.0)

func run():
 DirAccess.make_dir_recursive_absolute(REPORT)
 create_timer(120).timeout.connect(func():quit(1))
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 player=game.player
 for node in [game,player,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.set_process(false)
 player.select_character(35);fresh()
 game.settings.disable_character_cooldowns=false
 var home=floor_point(Vector3(-150,0,150))
 player.position=home;player._physics_process(TICK)
 game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*100;game.training_dummy.collision_layer=0
 game.camera_rig.camera.global_position=home+Vector3(6,5,11)
 game.camera_rig.camera.look_at(home+Vector3(0,2,-4))
 var army=game.army_runtime
 army.set_physics_process(false);army.set_process(false)
 var swarm=[]
 for i in 120:swarm.append(spawn(home+Vector3((i%12-5.5)*1.7,0,-9-i/12*1.7)))
 var blocked=spawn(home+Vector3(12,0,1))
 var wall=StaticBody3D.new()
 var collider=CollisionShape3D.new()
 var box=BoxShape3D.new();box.size=Vector3(.5,15,6)
 collider.shape=box;wall.add_child(collider);game.add_child(wall)
 wall.global_position=home+Vector3(6,3,1)
 var long_range=spawn(home+Vector3.FORWARD*166)
 var beyond=spawn(home+Vector3.FORWARD*201)
 await physics_frame;await physics_frame
 army.import_arrivals();army.integration_tick(TICK)
 game.crowd.present_army(army.render_snapshot(),[])
 var bar=player.spell_loadout
 var instance=bar.instances["35:"+Qi.SPIRIT_ID]
 var skill=instance.controller
 pool=game.get_node("CharacterProjectiles")
 pool.launched.connect(func(shot):
  if shot is Qi.Spirit:
   shot.set_physics_process(false);launches.append(shot.target))
 var origin=player.global_position+Vector3.UP*skill.caster_height()*.5
 var targets=swarm.map(func(row):return game.actors[row.id])
 var long_target=game.actors[long_range.id]
 targets.append(long_target)
 var eligible=targets.filter(func(target):return game.forest_enemy_visible(target) and AttackChain.clear_line(player,origin,AttackChain.aim_point(target,origin)))
 check(eligible.size()>96 and long_target in eligible,"The fixture has more targets than the pool and a clear target beyond Fire's range")
 check(game.forest_ui.loadout_buttons[0].visible and bar.numbered_slots[0][0]=="※高感應電流","Uru's actual first slot uses the level-11 name")
 key(1)
 check(bar.current==instance and skill.charge_fx.visible and game.last_sound_voice.get_meta("kind")=="cg_spirit_charge" and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_MAGIC_CAST,"Key 1 opens with Spirit Shockwave's charge control and recovered cue 259")
 key(6)
 check(bar.current==instance and bar.instances["35:uru/recovery"].controller.cast_left>0,"Manual healing starts without interrupting the offensive cast")
 advance_cast(skill,32)
 check(launches.is_empty() and skill.charge_fx.frame==10,"The barrage waits for the original staff cast marker")
 advance_cast(skill,1)
 check(not launches.is_empty() and launches.size()<=Qi.SPIRIT_BATCH and not skill.charge_fx.visible and player.model.current_frame==11,"The first batch leaves on source tick 33 with staff frame 11")
 var flying=pool.all[skill.pool_key].filter(func(shot):return shot.pool_live and shot.impact_age<0)
 check(flying.any(func(shot):return shot.rings[1].position.cross(shot.velocity.normalized()).length()>.1 and shot.rings.all(func(ring):return ring.frame<8)),"Child rings fan off the flight line using the native action-zero sprites")
 await capture("03 Spirit ring spread")
 for i in 20:player.spell_loadout.tick(TICK)
 check(pool.idle[skill.pool_key].is_empty() and not skill.spirit_targets.is_empty(),"A saturated pool holds the remaining targets for later shots")
 advance_cast(skill,10)
 var contacts=pool.all[skill.pool_key].filter(func(shot):return shot.pool_live and shot.impact_age>=0)
 check(not contacts.is_empty() and contacts.all(func(shot):return shot.burst.texture in Qi.Spirit.IMPACTS and shot.burst.hframes==7),"Normal contact uses one of the shared seven-frame Cross Gate sparks")
 await capture("04 Spirit normal impact")
 advance_cast(skill,240)
 check(launches.size()==eligible.size() and eligible.all(func(target):return launches.count(target)==1),"One barrage locks every eligible enemy exactly once beyond the pool size")
 check(eligible.all(func(target):return is_equal_approx(HP-target.hp,5000.0)),"Every eligible enemy takes exactly 5,000 native damage")
 check(game.actors[blocked.id].hp==HP and game.actors[beyond.id].hp==HP,"Solid cover and the outer range both block hits")
 check(game.voices.any(func(voice):return voice.get_meta("kind","")=="cg_spirit_hit" and voice.stream==SoundLibrary.original_for(35,"cg_spirit_hit")),"Contact uses the recovered 255 cue")
 check(skill.spirit_targets.is_empty() and pool.all[skill.pool_key].all(func(shot):return not shot.pool_live and shot.target==null),"All leases and queued targets retire")
 var created:int=pool.created
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 2:
  skill.clear_cooldowns();player.attack_chain.reset();bar.magic_result={};bar.magic_combo_steps=0
  key(1);advance_cast(skill,285)
 check(pool.created==created and pool.misses==0 and nodes==Performance.get_monitor(Performance.OBJECT_NODE_COUNT) and resources==Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"Two repeated large barrages reuse their prepared nodes and resources")
 check(eligible.all(func(target):return is_equal_approx(HP-target.hp,15000.0)),"Repeated casts deliver one hit per enemy per cast")
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(player,0)
 var allies=[]
 for i in 5:
  check(mirrors.reinforce(35,home+Vector3(i-2,0,0)),"Native Uru ally joins the barrage")
  var body=mirrors.bodies[i]
  allies.append(body.spell_loadout.instances["35:"+Qi.SPIRIT_ID].controller)
  body.perform(2,targets[0].global_position)
 var launched_before=launches.size()
 var ally_samples=[]
 for i in 480:
  var started=Time.get_ticks_usec()
  for skill_ in allies:
   skill_.hero.spell_loadout.tick(TICK)
   for shot in pool.all[skill_.pool_key]:
    if shot.pool_live:shot._physics_process(TICK)
  if i>=32 and i<250:ally_samples.append((Time.get_ticks_usec()-started)/1000.0)
 check(launches.size()>launched_before+120 and pool.misses==0 and allies.all(func(c):return c.spirit_targets.is_empty()),"Five simultaneous allies drain their queues through fixed-size pools")
 mirrors.dispose()
 var shot=pool.launch(player,Qi.Spirit,Qi.SPIRIT_ID,{"position":origin,"target":long_target,
  "velocity":origin.direction_to(AttackChain.aim_point(long_target,origin))*Qi.Spirit.TRAVEL_SPEED,"flight_life":2.0})
 var batch=shot.ghosts.multimesh
 check(batch.visible_instance_count==0 and batch.instance_count==48,"A fresh lease starts with an empty 48-stamp batch")
 shot._physics_process(TICK)
 var first=batch.get_instance_transform(0)
 var stamp=batch.get_instance_custom_data(0)
 var rendered=DisplayServer.get_name()!="headless"
 check(batch.visible_instance_count==4 and shot.last_stamp==1,"The first update stamps four ring positions")
 if rendered:
  check(stamp.g==1.0 and (first.origin+shot.ghosts.global_position).is_equal_approx(origin),"The render batch stores the original world position before the shot moves")
 for i in 4:shot._physics_process(TICK)
 check(batch.visible_instance_count==20 and shot.last_stamp==5,"Five updates stamp twenty ring positions")
 if rendered:
  check(batch.get_instance_transform(0).is_equal_approx(first) and batch.get_instance_custom_data(0)==stamp,"Earlier ring poses stay fixed as new ones are stamped")
 await capture("05 Spirit translucent afterimages")
 shot.end_flight()
 for i in 11:shot._physics_process(TICK)
 check(shot.pool_live and shot.ghost_tick-shot.last_stamp==11 and not shot.burst.visible,"Afterimages outlive a missed shot through update 11")
 shot._physics_process(TICK)
 check(not shot.pool_live and not shot.ghosts.is_visible_in_tree(),"The final stamps expire on update 12")
 var recycled=pool.launch(player,Qi.Spirit,Qi.SPIRIT_ID,{"position":origin,"target":long_target,
  "velocity":Vector3.FORWARD*Qi.Spirit.TRAVEL_SPEED,"flight_life":2.0})
 check(recycled==shot and recycled.ghosts.multimesh.visible_instance_count==0 and recycled.ghost_tick==0,"Reusing the lease clears its afterimage history")
 recycled.retire()
 print("SPIRIT_STEP_MS ",Metrics.summary(samples)," ALLIES_STEP_MS ",Metrics.summary(ally_samples))
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SPIRIT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
