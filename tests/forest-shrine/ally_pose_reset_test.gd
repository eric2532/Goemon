extends SceneTree
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
var game
var cfg="user://ally-pose-%d.cfg"%OS.get_process_id()
func motion_sample(unit,population:int,kind:String)->Vector3:
 var combat=unit.active_ability
 combat.reset_run();unit.attack_chain.reset();unit.global_position=Vector3(0,.15,70);unit.velocity=Vector3.ZERO
 # Teleporting does not clear CharacterBody's previous floor state. Settle each
 # trial before jumping so both populations start from the same grounded body.
 for i in 8:
  unit.velocity=Vector3.DOWN*2;unit.move_and_slide()
 unit.velocity=Vector3.ZERO
 assert(unit.is_on_floor(),"Movement comparison must start grounded")
 unit.state="acting";unit.opening=false;unit.think_left=100;unit.ai_target=null;unit.auto_attack_enabled=false
 unit.ai_move=Vector3.RIGHT if kind=="walk" else Vector3.ZERO;unit.ai_aim=unit.global_position+Vector3(0,1,-10)
 combat.player.pos=unit.global_position;combat.aim=unit.ai_aim;combat.player.angle=PI
 unit.jump_buffer=.15 if kind=="jump" else 0.0;unit.coyote=.13;unit.jumps_used=0
 if kind=="dash":combat.action("flintlock")
 var peak=unit.global_position.y
 for i in 60:
  game.explorer_helpers.living_count=population;unit._physics_process(1.0/60);peak=maxf(peak,unit.global_position.y)
 return Vector3(unit.global_position.x,peak,unit.global_position.z)
func _initialize():run.call_deferred()
func run():
 var d=load("res://scripts/forest/forest_map_document.gd").new();d.load_original();set_meta("forest_custom_layout",d.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 for i in 3:await process_frame
 var h=game.explorer_helpers;GuardFixture.deploy(h,3);var u=h.active_units(3)[0];var c=u.active_ability
 c.visual_left=0;c._animate(0,0)
 var arm=u.model.actor.joints.Arm_L.node
 var idle=arm.transform
 c.player.blocking=true;c.player.guardStyle="knight";c.visual_left=0;c._animate(.016,0)
 var guarded=arm.transform
 print("POSE_GUARDED_CHANGED ",not guarded.is_equal_approx(idle))
 c.visual_left=.25;c.cancel()
 print("POSE_RESET ",arm.transform.is_equal_approx(idle))
 var failed=not arm.transform.is_equal_approx(idle) or guarded.is_equal_approx(idle)
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false)
 for actor in game.gate_defenders.units.values():actor.set_physics_process(false)
 GuardFixture.deploy(h,1)
 var ranger=h.active_units(1)[0];ranger.set_physics_process(false);ranger.state="acting";ranger.opening=false
 ranger.active_ability.cancel();ranger.active_ability.player.cooldowns.drink=5.0
 for i in 60:
  h.living_count=48;ranger._physics_process(1.0/60)
 var timed=absf(ranger.active_ability.player.cooldowns.drink-4.0)<.035
 var grounded=ranger.global_position.y>-.1
 print("BUDGETED_TIMER_CONSERVED ",timed," BODY_ON_TERRAIN ",grounded)
 failed=failed or not timed or not grounded
 var small_walk=motion_sample(ranger,1,"walk");var army_walk=motion_sample(ranger,48,"walk")
 var small_jump=motion_sample(ranger,1,"jump");var army_jump=motion_sample(ranger,48,"jump")
 GuardFixture.deploy(h,2);var ninja=h.active_units(2)[0];ninja.set_physics_process(false)
 var small_dash=motion_sample(ninja,1,"dash");var army_dash=motion_sample(ninja,48,"dash")
 var walk_ok=small_walk.distance_to(army_walk)<.05;var jump_ok=small_jump.distance_to(army_jump)<.1;var dash_ok=small_dash.distance_to(army_dash)<.1
 print("WALK_CONSERVED ",walk_ok," ",small_walk," / ",army_walk," JUMP_CONSERVED ",jump_ok," ",small_jump," / ",army_jump," DASH_CONSERVED ",dash_ok," ",small_dash," / ",army_dash)
 failed=failed or not walk_ok or not jump_ok or not dash_ok
 game.sound_library.cancel();game.music.stop()
 for k in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for v in game.find_children("*",k,true,false):v.stop()
 OS.delay_msec(120);game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("ALLY_POSE_RESET_RESULT checks=7 failures=",1 if failed else 0);quit(1 if failed else 0)
