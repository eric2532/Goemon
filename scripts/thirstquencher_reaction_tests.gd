extends "res://scripts/independent_enemy_tests.gd"
const SoldierCombat=preload("res://scripts/forest/forest_thirstquencher_combat.gd")
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
func run():
 await setup()
 for role in [0,1,3]:
  var fixture=spawn(role);var actor=fixture.actor;var data:Dictionary=fixture.data
  data.stun=0;SoldierCombat.begin(data);actor.take_hit(5,Vector3.RIGHT,false,{"tower":true,"tower_feedback":false})
  check(not SoldierCombat.active(data),"A hit interrupts the original soldier attack (%d)"%role)
  check(is_equal_approx(float(data.get("soldier_hurt_left",0)),16.0/30),"Hurt plays its full16sourceframes (%d)"%role)
  check(data.stun>=16.0/30,"Hurt animation and combat interruption share their duration (%d)"%role)
  actor._physics_process(0);game.crowd._process(0)
  check(Soldier.frame_state(game.crowd._formations[data.id].parts[0]).clip=="Source__801b02a8","A hit immediately submits the native hurt pose (%d)"%role)
  actor.freeze_for(1);var held=float(data.get("soldier_hurt_tick",0));game.model.waves.tick_enemy(data,.25,game.player.position)
  check(is_equal_approx(float(data.get("soldier_hurt_tick",0)),held),"Freezing holds the hurt clock (%d)"%role)
  data.frozen=0;data.erase("frozen_pose");actor.frozen_left=0;game.model.waves.tick_enemy(data,.1,game.player.position)
  check(absf(float(data.get("soldier_hurt_tick",0))-held-3)<.00001,"Thawing resumes the source hurt clock (%d)"%role)
  var start=actor.position;data.hp=1;actor.hp=1;actor.take_hit(2,Vector3.RIGHT,false,{"tower":true,"tower_feedback":false})
  check(actor.dead and actor.collision_layer==0,"A dead soldier releases native hurt contact (%d)"%role)
  check(absf(actor.position.y-start.y-36*.01*Soldier.SCALE)<.001,"Death begins with the original source root raise (%d)"%role)
  var peak=actor.position.y
  for i in 15:
   actor._physics_process(.05);peak=maxf(peak,actor.position.y)
  var ground:float=game.model.surface_height(actor.position.x,actor.position.z)
  check(peak>start.y+1.5 and actor.position.distance_to(start)>2,"Death performs the original upward/backward arc (%d)"%role)
  check(actor.position.y>=ground-.001,"The falling corpse respects the actual Kai floor (%d)"%role)
  check(Soldier.frame_state(data,.2).clip=="Source__801b09d0","Death uses the recovered source motion (%d)"%role)
  await remove_enemy(actor,data)
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 5:await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("THIRSTQUENCHER_REACTION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
