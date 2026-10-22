extends "res://scripts/rogue_equipment_combat_tests.gd"
func run():
 Input.use_accumulated_input=false;game.smoke_test=true;game.settings.volume=0.0
 game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
 game.player.smoke_mode=true;game.start_mode("defense");pause_fixture_director();await frames(3)
 var run_=game.encounters
 check(run_.has_method("gate_alive"),"Expanded map exposes a buildable gate")
 if not run_.has_method("gate_alive"):finish();return
 await construction_rules()
 await passage_rules()
 await combat_rules()
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
 game.reset_player_at(Vector3(8,.06,180));await frames(35);r.money=10
 check(r.build_candidate()>=0,"Side-wall footprint is an eligible nearby build position")
 r.update_build_input(3.1)
 check(not r.gate_alive() and r.money==10 and not gate.can_complete_build(),"Initial wall cannot be created around its builder")
 game.reset_player_at(Vector3(0,.06,182));await frames(35)
 var wall_occupant=fixture(Vector3.ZERO);wall_occupant.global_position=Vector3(13,.06,180);await frames(2)
 r.update_build_input(.1)
 check(not r.gate_alive() and r.money==10,"Initial wall occupancy defers payment for other actors too")
 wall_occupant.collision_layer=8;await frames(2)
 check(not gate.can_complete_build(),"Friendly bodies also block new solid wall creation")
 wall_occupant.queue_free();await frames(2);r.gate_state.progress=0
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
func passage_rules():
 var p=game.player;var rig=game.camera_rig
 p.select_character(9);game.reset_player_at(Vector3(0,.06,182));await frames(35)
 rig.set_process(false);rig.camera.global_position=Vector3(0,3,190);rig.camera.look_at(Vector3(0,1,174))
 var target=fixture(Vector3(0,0,-5));await frames(2);p.set_auto_attack(true)
 check(p.auto_aim_target()==target,"J acquires visible enemy through transparent panel")
 p.set_auto_attack(false);game.camera_rig.yaw=0;aim_world(target.position+Vector3.UP)
 tap("light_attack");await frames(35)
 check(target.hp<10000,"Real Magic Swordsman melee contacts pass through panel")
 var before=target.hp;tap("heavy_attack");await frames(65)
 check(target.hp<before,"Real long-range wave passes through panel")
 p.active_ability.cancel();p.active_ability.reset_run();p.position=Vector3(10,.06,182);p.active_ability.player.pos=p.position
 target.position=Vector3(10,.06,177);target.hp=10000
 rig.camera.global_position=Vector3(10,3,190);rig.camera.look_at(Vector3(10,1,174));await frames(2);p.set_auto_attack(true)
 check(p.auto_aim_target()==null,"Solid side wall blocks J sight")
 p.set_auto_attack(false);aim_world(target.position+Vector3.UP);tap("heavy_attack");await frames(65)
 check(target.hp==10000,"Same wave is stopped by solid side wall")
 p.active_ability.cancel();target.queue_free();await frames(2);rig.set_process(true)
 p.position=Vector3(0,.06,180)
 check(game.encounters.gate_state.cannon.can_complete_build(),"Friendly player occupancy never blocks completion")
 game.reset_player_at(Vector3(0,.06,182));await frames(35)
func combat_rules():
 var r=game.encounters;var p=game.player
 check(r.has_method("gate_blocking") and r.has_method("apply_gate_contact"),"Gate contacts and priority are integrated")
 if not r.has_method("apply_gate_contact"):return
 r.wave=0;r.update_start_input(0,false);r.update_start_input(3,true);r._spawn_due(300)
 var actors=game.enemies.filter(func(e):return is_instance_valid(e) and not e.dead and r.owns(e))
 for e in actors:e.set_physics_process(false)
 r.phase="clearance";r.pending=0;r.gate.tick(0)
 check(actors.size()==300 and r.alive_count==300,"Full real wave remains alive at the gate")
 check(r.gate.records.size()==300 and r.gate.waiting_count()==292,"Eight slots with 292 waiting raiders")
 var waiting={};var unique=true
 for e in actors:
  var a=r.gate.assignment(e)
  if not a.attacking:
   unique=unique and not waiting.has(a.position);waiting[a.position]=true
  check((e.collision_mask&16)!=0,"Only owned entrance raiders receive door collision")
 check(unique,"All waiting targets are distinct")
 var hero_hp=p.hp;var shrine_hp=r.base_hp;var money=r.money
 for i in range(8):actors[i].position=r.gate.assignment(actors[i]).position+Vector3.UP*.06
 r.gate.tick(1.24);check(r.gate_hp==5000,"Real gate waits 1.25 seconds")
 var damage=0.0
 for i in range(8):damage+=20*actors[i].defense_damage_multiplier*game.tuning.enemy_damage
 r.gate.tick(.01)
 check(is_equal_approx(r.gate_hp,5000-damage),"Real damage includes archetype and tuning multipliers")
 check(p.hp==hero_hp and r.base_hp==shrine_hp and r.alive_count==300 and r.money==money,"Gate arrival grants no damage, kills or rewards elsewhere")
 var e=actors[0];var point=e.position
 game.tuning.freeze_ai=false;p.position=point+Vector3(0,0,1);p.invuln=0
 e.state="strike";e.timer=.3;e.attack_hit=false;e.attack_kind="dash";e._physics_process(.1)
 check(p.hp==hero_hp and e.attack_hit and e.position.z<180,"Gate pose cannot execute player damage against nearby hero")
 p.position=Vector3(0,.06,210);e.position=Vector3(0,.06,175);e.grounded_cached=true;e.walk_clock=.14;e.walk_start=e.position;e.walk_end=Vector3(0,.06,185);e.walk_age=0;e.walk_span=.15
 e._physics_process(2)
 check(e.position.z<180,"Cached optimized approach cannot tunnel through door on long frame")
 e.defense_waypoint=game.world.lanes[1].size()-1
 r.breach(e);r.lane_direction(e)
 check(not r.shrine.handles(e) and not r.can_breach(e),"Both shrine-arrival paths honor gate priority")
 e.position=Vector3(0,.06,160);e.walk_clock=0;e.apply_defense_slow(.35,3);e._physics_process(.1)
 check(is_equal_approx(Vector2(e.velocity.x,e.velocity.z).length(),r.defense_speed(e)*.35),"Ice slows the gate approach without altering attacks")
 e.defense_traits.slow_factor=1.0
 game.tuning.freeze_ai=true
 for i in range(8):actors[i].position=r.gate.assignment(actors[i]).position+Vector3.UP*.06
 var hp=r.gate_hp;e.stun=.1;r.gate.tick(1.25);var after=r.gate_hp;e.stun=0;r.gate.tick(1.24)
 check(r.gate_hp==after,"Stunned slot needs a fresh interval")
 r.gate.tick(.01);check(r.gate_hp<after and hp>after,"Fresh gate contact resumes after stun")
 for status in ["frozen_left","impact_pause"]:
  e.set(status,.1);r.gate.tick(1.25);after=r.gate_hp;e.set(status,0);r.gate.tick(1.24)
  check(r.gate_hp==after,"%s cancels real gate windup" % status)
  r.gate.tick(.01);check(r.gate_hp<after,"%s recovery needs fresh interval" % status)
 game.paused=true;hp=r.gate_hp;r.tick(100);game.paused=false
 check(r.gate_hp==hp,"Pause cannot accumulate actual gate damage")
 p.hp=0;r.hero_died();r.gate.tick(1.25)
 check(r.gate_hp<hp and r.hero_dead,"Enemy gate attacks continue while hero is down")
 r._restore_hero();r.runtime.hero_dead=false
 var living=r.alive_count;r.gate_hp=1;r.gate.tick(1.25)
 check(r.gate_hp==0 and not r.gate_alive() and r.gate_state.cannon.panel.collision_layer==0,"Zero health opens the door once")
 check(r.alive_count==living and r.gate.records.is_empty() and e.collision_mask==1,"Breaking the door preserves lives and restores prior masks")
 check(not r.gate_blocking(e),"Surviving raiders resume ordinary route after destruction")
 e.position=game.world.base_position+Vector3(0,.06,-7);r.breach(e);r.shrine.tick(0)
 e.position=r.shrine.assignment(e).position+Vector3.UP*.06
 r.shrine.tick(2.49);check(r.base_hp==shrine_hp,"Shrine keeps its slower first interval")
 r.shrine.tick(.01);check(r.base_hp==shrine_hp-1,"Survivors continue attacking shrine after gate breaks")
 var inside=actors[1];inside.position=Vector3(0,.06,190);var inside_point=inside.position;var shrine_point=e.position
 game.reset_player_at(Vector3(0,.06,182));await frames(35);r.money=10;r.update_build_input(3.1)
 check(r.gate_alive() and r.gate_hp==5000 and r.money==0,"Mid-wave rebuilding costs ten gold and restores HP")
 check(inside.position==inside_point and not r.gate.handles(inside) and r.shrine.handles(e) and e.position==shrine_point,"Rebuild preserves inside actors and shrine assignments")
 check(r.gate.handles(actors[2]),"Rebuild reacquires entrance-side actors")
 r.record_defeat(actors[2]);check(r.gate.handles(actors[2]),"Living actor cannot be retired as a kill")
 actors[2].dead=true;r.record_defeat(actors[2]);r.record_defeat(actors[2])
 check(not r.gate.handles(actors[2]) and r.alive_count==living-1,"Death releases membership and counts once")
 var practice=fixture(Vector3.ZERO);check(practice.collision_mask==1 and not r.gate_blocking(practice),"Practice actors retain their collision and targeting scope");practice.queue_free()
 p.select_character(10);check(r.gate_alive(),"Character switching preserves gate")
 r.retire_wave_effects();check(r.gate.records.is_empty() and actors[3].collision_mask==1 and r.gate_alive(),"Wave retirement clears clocks and masks while keeping gate health")
 var old_generation=r.generation;r.begin();await frames(2)
 check(r.generation!=old_generation and not r.gate_alive() and not r.apply_gate_contact(actors[3]),"Restart removes barrier and rejects retired actors")
 var original_world=game.world
 var custom=preload("res://scripts/map_builder_world.gd").new()
 var document=preload("res://scripts/map_document.gd").new();document.reset_blank();custom.map_data=document.data.duplicate(true)
 game.add_child(custom);game.world=custom;r.begin()
 check(r.gate_state.is_empty(),"Custom maps receive no automatic gate")
 game.world=original_world;custom.queue_free()
