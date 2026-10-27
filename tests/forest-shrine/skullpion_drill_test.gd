extends "res://tests/forest-shrine/skullpion_controls_test.gd"
const DRILL_OUT="res://build/Other Files/Asset Toolkit/Skullpion Drill/"

func target(offset:Vector3):
 var point=game.player.position+offset;point.y=game.model.surface_height(point.x,point.z)+offset.y
 var row=game.model.waves.spawn_enemy(0,point);row.hp=10000;row.max_hp=10000
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets();game.model.update_vision(point)
 return game.actors[row.id]

func begin_drill():
 game.player.cancel_charge();game.player.attack_chain.reset();tap("surge")

func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.crowd.army.present(game.army_runtime.render_snapshot(),[])
 var camera=game.camera_rig.camera;var previous=camera.global_transform
 camera.global_position=game.player.position+Vector3(80,55,90)
 camera.look_at(game.player.position+Vector3(0,8,15))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(DRILL_OUT+label_+".png")
 camera.global_transform=previous

func run():
 create_timer(120).timeout.connect(func():printerr("FAIL: Skullpion drill timeout");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DRILL_OUT))
 var hashes={}
 for path in INPUTS:hashes[path]=FileAccess.get_sha256("res://"+path)
 var map=preload("res://scripts/forest/forest_map_document.gd").new();map.load_wind_meadow()
 await setup_fixture(map.data)
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 var p=game.player;p.select_character(27);fresh();p.set_scarf_equipped(false)
 game.settings.jump_styles={};p.jump_style.prepare();game.settings.spell_loadouts={};p.spell_loadout.prepare()
 game.tuning.invincible=true
 home_point.y=game.model.surface_height(home_point.x,home_point.z)+.1
 await park(home_point)
 game.training_dummy.position=Vector3(900,0,900)
 var combat=p.active_ability;var skull=p.model.skull
 var near=target(Vector3(0,0,35));var far=target(Vector3(-65,0,0))
 var nearby=target(Vector3(10,0,35));var airborne=target(Vector3(0,20,35))
 begin_drill()
 check(combat.action==105 and is_equal_approx(p.attack_duration,.467),"Unassigned R starts Poison Drill with a 0.467-second duration")
 attack_step(.14);await capture("tail-drilling")
 attack_step(.04)
 check(near.hp==10000 and not skull.drill.visible,"Drill keeps a short readable windup without an early hit")
 attack_step(.011)
 check(is_equal_approx(near.hp,9941.5) and far.hp==10000,"First hit arrives at 0.19 seconds on the nearest enemy, even behind the player")
 check(nearby.hp<10000 and airborne.hp==10000,"Original ground area hits nearby enemies without reaching airborne enemies")
 check(is_equal_approx(game.army_runtime.unit_state(near.handle).slow_factor,.55),"Drill poison retains the native 55-percent movement slow")
 check(skull.drill.visible and skull.drill.global_position.distance_to(near.global_position)<3,"Prepared drill emerges from the ground at its victim")
 check(p.model.current_clip=="801ae08c" and is_equal_approx(combat.pose_tick,57.3),"Tail drilling pose uses the same tenfold contact clock")
 check(skull.body.find_child("Part_16",true,false).global_position.y<p.position.y,"The original tail has entered the ground before the first emergence")
 attack_step(.03);await capture("first-emergence")
 attack_step(.15)
 check(is_equal_approx(near.hp,9824.5) and combat.marker==3,"All three original strikes land by 0.37 seconds, once per marker")
 attack_step(.1)
 check(not combat.is_attacking() and not skull.drill.visible,"Drill returns to idle and clears its effect in under half a second")
 begin_drill();attack_step(.191)
 near.take_hit(100000,Vector3.FORWARD,false,{"tower":true})
 nearby.take_hit(100000,Vector3.FORWARD,false,{"tower":true})
 attack_step(.09)
 check(near.dead and nearby.dead and far.hp<10000 and combat.aim.distance_to(far.global_position)<3,"A later strike retargets the next living ground enemy")
 p.cancel_charge();var hp=far.hp;attack_step(1)
 check(far.hp==hp and not skull.drill.visible and skull.voices.all(func(voice):return not voice.playing),"Cancelling after a strike clears audio/effects and prevents delayed damage")
 begin_drill();attack_step(.1);p.cancel_charge();attack_step(.5)
 check(far.hp==hp,"Cancelling during windup prevents every strike")
 var blocked=target(Vector3(0,0,35))
 var wall=StaticBody3D.new();wall.collision_layer=1
 var collider=CollisionShape3D.new();collider.shape=BoxShape3D.new();collider.shape.size=Vector3(12,12,2)
 wall.add_child(collider);game.add_child(wall);wall.position=p.position+Vector3(0,4,25);await physics_frame
 begin_drill();attack_step(.191)
 check(blocked.hp==10000 and far.hp<hp,"Solid cover excludes the closer blocked enemy")
 p.cancel_charge();wall.queue_free();await physics_frame
 far.take_hit(100000,Vector3.FORWARD,false,{"tower":true});blocked.take_hit(100000,Vector3.FORWARD,false,{"tower":true})
 begin_drill();attack_step(.2)
 check(not combat.aim.is_finite() and not skull.drill.visible,"No eligible ground target produces no stale or misplaced drill")
 attack_step(.3);check(not combat.is_attacking(),"A missed drill still finishes promptly")
 var distant=target(Vector3(150,0,0))
 begin_drill();attack_step(.5)
 check(distant.hp==10000,"Drill cannot acquire an enemy beyond its existing 125-metre reach")
 var repeat_target=target(Vector3(0,0,35))
 begin_drill();attack_step(.5);await advance(60)
 var nodes=skull.find_children("*","",true,false).size()
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var drill_id=skull.drill.get_instance_id();var cast_samples=[]
 for i in 12:
  begin_drill()
  for j in 30:
   var start=Time.get_ticks_usec();attack_step(1.0/60);cast_samples.append(Time.get_ticks_usec()-start)
   await physics_frame
 await advance(60)
 evidence.repeat_resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 check(skull.drill.get_instance_id()==drill_id and skull.find_children("*","",true,false).size()==nodes,"Repeated casts reuse the original drill, particles and sound voices")
 check(evidence.repeat_resource_delta<=2,"Repeated casts leave no growing resource ownership")
 check(repeat_target.hp<8000,"Repeated native army hits continue working after pool reuse")
 p.spell_loadout.equip(27,"surge","goemon/surge");tap("surge")
 check(not combat.is_attacking(),"An equipped R spell keeps priority over the native drill")
 p.cancel_charge();p.spell_loadout.equip(27,"surge","")
 await park(home_point);tap("jump");await advance(4);tap("surge")
 check(not p.is_on_floor() and not combat.is_attacking(),"Ground drilling cannot start in midair")
 await park(home_point);begin_drill();p.select_character(1);combat.tick(.5)
 check(not combat.is_attacking() and not skull.drill.visible,"Switching fighters cancels the pending drill")
 cast_samples.sort();evidence.attack_step_usec_p95=cast_samples[int(cast_samples.size()*.95)]
 evidence.source_hashes=hashes
 check(INPUTS.all(func(path):return hashes[path]==FileAccess.get_sha256("res://"+path)),"Verification source stays unchanged during the run")
 evidence.checks=checks;evidence.failures=failures;evidence.renderer=RenderingServer.get_video_adapter_name()
 FileAccess.open(DRILL_OUT+("headless-results.json" if DisplayServer.get_name()=="headless" else "desktop-results.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKULLPION_DRILL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
