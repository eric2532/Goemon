extends "res://scripts/rogue_equipment_combat_tests.gd"
func run():
 Input.use_accumulated_input=false;game.smoke_test=true;game.settings.volume=0.0
 game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
 game.player.smoke_mode=true;game.start_mode("defense");pause_fixture_director();await frames(3)
 var run_=game.encounters
 check(run_.has_method("gate_alive"),"Expanded map exposes a buildable gate")
 if not run_.has_method("gate_alive"):finish();return
 await construction_rules()
 finish()
func finish():
 game.show_main_menu();game.sound_library.cancel();game.music.stop();stop_audio(game)
 print("SHRINE_GATE_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
func construction_rules():
 var r=game.encounters;var p=game.player
 check(not r.gate_alive() and r.gate_hp==0 and not r.gate_state.is_empty(),"Gate starts unbuilt")
 check(r.gate_position==Vector3(0,0,180),"Gate sits five metres before starting point")
 var gate=r.gate_state.cannon
 game.reset_player_at(Vector3(0,.06,182));await frames(35)
 r.money=9.0;r.update_build_input(3.1)
 check(not r.gate_alive() and r.money==9,"Insufficient gold cannot complete")
 r.money=10.0;r.update_build_input(1.5)
 check(r.gate_state.progress>.45 and not r.gate_alive(),"Half construction takes 1.5 seconds")
 p.velocity.x=3;r.update_build_input(.4)
 check(r.gate_state.progress<.5,"Moving interrupts and decays work")
 p.velocity=Vector3.ZERO;r.update_build_input(3)
 check(r.gate_alive() and r.gate_hp==5000 and r.money==0,"Three seconds buys 5000 HP for exactly 10 gold")
 r.update_build_input(3)
 check(r.money==0 and r.cannons.is_empty(),"Repeat completion never charges or adds upkeep")
 await frames(2)
 var space=game.get_world_3d().direct_space_state
 var front=Vector3(0,2,177);var rear=Vector3(0,2,183)
 check(space.intersect_ray(PhysicsRayQueryParameters3D.create(front,rear,1)).is_empty(),"Player shots and sight pass through panel")
 check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(front,rear,16)).is_empty(),"Enemy-only panel collision blocks the opening")
 check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(10,2,177),Vector3(10,2,183),1)).is_empty(),"Side walls remain solid terrain")
 var pose=p.global_transform;pose.origin=Vector3(0,.06,182)
 check(not p.test_move(pose,Vector3(0,0,-5)),"Real hero capsule passes through door")
 var enemy=fixture(Vector3.ZERO);enemy.global_position=Vector3(0,.06,178);enemy.collision_mask=17
 check(enemy.test_move(enemy.global_transform,Vector3(0,0,5)),"Real enemy capsule is blocked")
 enemy.queue_free();await frames(2)
 check(gate.panel_mesh.material_override.albedo_color.a>=.25 and gate.panel_mesh.material_override.albedo_color.a<=.35,"Panel stays approximately thirty percent opaque")
 check(gate.panel_mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Panel casts no opaque shadow")
 for point in [Vector3(-18,.1,175),Vector3(18,.1,175),Vector3(-12,.1,168),Vector3(12,.1,168)]:
  game.reset_player_at(point+Vector3(0,0,2));await frames(30)
  check(r.nearest_site()>=0,"Mine/tower work pad remains accessible at %s" % point)
 r.gate_hp=1234;r.wave=1;r.interrupt_inputs()
 check(r.gate_hp==1234 and r.gate_alive(),"Damage persists across wave/input retirement")
 gate.break_gate();r.gate_state.level=0;r.gate_hp=0;r.gate_state.progress=0
 var wall_count=gate.walls.get_child_count();r.money=10
 game.reset_player_at(Vector3(0,.06,182));await frames(30)
 enemy=fixture(Vector3.ZERO);enemy.global_position=Vector3(0,.1,180);await frames(2)
 r.update_build_input(3.1)
 check(not r.gate_alive() and r.money==10 and not gate.can_complete_build(),"Occupied enemy opening defers purchase")
 enemy.queue_free();await frames(2)
 r.update_build_input(.1)
 check(r.gate_alive() and r.money==0 and r.gate_hp==5000,"Cleared opening rebuilds once for ten gold")
 check(gate.walls.get_child_count()==wall_count,"Rebuilding reuses side walls")
 game.paused=true;var money=r.money;var hp=r.gate_hp;r.update_build_input(100)
 check(r.money==money and r.gate_hp==hp,"Pause suspends construction transactions")
 game.paused=false
