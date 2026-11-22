extends "res://scripts/recovered_goemon_pipe_hitbox_tests.gd"
## Keep the exact pipe contacts and one impact beat while retiring redundant queries.
func run():
 create_timer(120).timeout.connect(func():printerr("GOEMON_CROWD_COMBAT_TIMEOUT");quit(1))
 var doc=load("res://scripts/forest/forest_map_document.gd").new();check(doc.load_wind_meadow()=="","Use Wind Meadow")
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false);game.explorer_helpers.set_process(false)
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 raw_motion=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_goemon/motion.json"))
 var p=game.player;var dummy=game.training_dummy;var combat=p.original_pipe_combat
 var collider:CollisionShape3D=dummy.get_children().filter(func(c):return c is CollisionShape3D)[0]
 collider.shape.radius=.08;collider.shape.height=.16;collider.position=Vector3.ZERO;dummy.contact_shape.center=Vector3.ZERO
 for stage in [1,2,3,1]:
  reset_strike(stage);dummy.impact_pause=0
  check(combat.excluded_rids==[p.get_rid()],"Every new stage or repeated attack resets physics exclusions")
  var frame_=4 if stage==1 else (5 if stage==2 else 7)
  pose_fixture(stage,frame_);await target_at(raw_pipe_point(stage,frame_,Vector3(23,-3,78)))
  p.strike()
  check(contacts==[stage] and is_equal_approx(p.attack_duration,RecoveredGoemonCombatProfile.duration(stage)),"Stage %d preserves exact tip contact and authored duration"%stage)
  check(combat.excluded_rids.has(dummy.get_rid()),"Confirmed victim is excluded before later physics queries")
  p.strike()
  check(combat.query.exclude.has(dummy.get_rid()) and contacts==[stage],"Later substeps exclude the victim without duplicate damage")
  check(is_equal_approx(p.impact_pause,.045 if stage==3 else .025),"First contact retains the original short player impact beat")
  p.impact_pause=0;game.confirm_impact(dummy,dummy.position,Vector3.FORWARD,stage-1,false)
  check(p.impact_pause==0 and is_equal_approx(dummy.impact_pause,[.035,.06,.095][stage-1]),"A later contact retains victim recoil without restarting the player pause")
  p.impact_pause=.12;game.confirm_impact(dummy,dummy.position,Vector3.FORWARD,stage-1,false)
  check(is_equal_approx(p.impact_pause,.12),"Later outgoing contacts preserve a longer incoming-hit pause")
 reset_strike();pose_fixture(1,4)
 var tip=raw_pipe_point(1,4,Vector3(23,-3,78));await target_at(tip)
 var wall=StaticBody3D.new();wall.collision_layer=1
 var blocker=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,8,.18);blocker.shape=box;wall.add_child(blocker);game.add_child(wall)
 wall.position=(p.global_position+Vector3.UP*1.1).lerp(tip,.5);wall.look_at(tip)
 await physics_frame;await physics_frame;p.strike()
 check(contacts.is_empty() and not combat.excluded_rids.has(dummy.get_rid()),"Blocked targets are neither damaged nor excluded")
 wall.free();await physics_frame;p.strike()
 check(contacts==[1],"A target still receives its exact contact when cover is removed during the swing")
 for action in ["borrowed_skill","heavy"]:
  p.attack_ticket=p.attack_chain.make_ticket(action);p.impact_pause=0
  game.confirm_impact(dummy,dummy.position,Vector3.FORWARD,0,false)
  p.impact_pause=0;game.confirm_impact(dummy,dummy.position,Vector3.FORWARD,0,false)
  check(is_equal_approx(p.impact_pause,.025),"Non-pipe skill tickets retain their existing feedback rules: "+action)
 await allied_reuse()
 game.queue_free();current_scene=null;paused=false;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_CROWD_COMBAT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
func allied_reuse():
 var runtime=game.army_runtime;var owner=game.explorer_helpers.legendary_heroes
 game.training_dummy.collision_layer=0;game.training_dummy.position=Vector3(0,-100,0)
 runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-2));row.hp=1000000;row.max_hp=1000000
 runtime.import_arrivals();var target=game.actors[row.id]
 var driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 for i in 5:check(owner.reinforce(1,ORIGIN+Vector3((i-2)*.05,0,0)),"Allocate allied Goemon through the existing native owner")
 await driver.advance(4,func(dt):owner.tick(dt))
 var bodies=owner.bodies.duplicate();var expected=0.0
 for body in bodies:expected+=74*body.damage_multiplier()
 var warm_nodes=0;var warm_resources=0.0
 for repeat_index in 4:
  if repeat_index>0:
   owner.clear()
   for i in 5:check(owner.reinforce(1,ORIGIN+Vector3((i-2)*.05,0,0)),"Reuse native Goemon bodies")
  if repeat_index==3:warm_nodes=get_node_count();warm_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  var before=target.hp
  for body in bodies:body.press("light_attack")
  await driver.advance(110,func(dt):owner.tick(dt))
  check(is_equal_approx(before-target.hp,expected),"Five simultaneous native Goemons preserve every stage's damage on use %d"%repeat_index)
  for body in bodies:
   check(not body.has_offensive_action() and body.struck_targets.size()==1 and body.original_pipe_combat.excluded_rids==[body.get_rid(),target.get_rid()],"Each ally finishes with its own independent per-stage contact/exclusion state")
  await driver.advance(30,func(dt):
   runtime.presentation_delta+=dt;runtime.presentation_dirty=true;runtime.flush_presentation())
  print("GOEMON_CROWD_REUSE_SAMPLE repeat=",repeat_index," nodes=",get_node_count()," resources=",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)," memory=",OS.get_static_memory_usage())
  check(game.player.impact_pause==.025,"Allied impacts do not restart or change the player's pause")
 var node_delta=get_node_count()-warm_nodes;var resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-warm_resources
 check(node_delta<=0 and resource_delta<=0,"Repeated simultaneous allied attacks retain no extra nodes or resources (%d nodes, %d resources)"%[node_delta,resource_delta])
 check(owner.bodies.size()==5 and owner.bodies==bodies,"Repeated allied attacks reuse the same five native-owned bodies")
 owner.clear();driver.queue_free()
