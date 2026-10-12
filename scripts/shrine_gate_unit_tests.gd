extends Node
var game: Node
var checks=0
var failures=0
class ShrineStub extends RefCounted:
 var ids: Dictionary={}
 func handles(actor)->bool:return ids.has(actor.encounter_id)
class Owner extends Node:
 var game: Node
 var generation=10
 var wave=1
 var phase="spawning"
 var gate_position=Vector3(0,0,180)
 var health=5000
 var contacts=0
 var roster: Dictionary={}
 var shrine=ShrineStub.new()
 func _running()->bool:return game.playing and not game.paused
 func gate_alive()->bool:return health>0
 func owns(actor)->bool:return is_instance_valid(actor) and actor.get_meta("siege_generation",-1)==generation and roster.get(actor.encounter_id)==actor
 func apply_gate_contact(actor)->bool:
  if not owns(actor) or actor.dead:return false
  health-=20;contacts+=1;return true
func check(value: bool,label: String):
 checks+=1
 if not value:failures+=1;push_error(label)
func run():
 game.smoke_test=true;game.settings.volume=0.0;game.tuning.freeze_ai=true
 game.start_mode("defense");game.encounters.set_physics_process(false);game.player.set_physics_process(false)
 check(ResourceLoader.exists("res://scripts/gate_attack_clock.gd") and ResourceLoader.exists("res://scripts/fire_siege_gate.gd"),"Separate gate clock/controller exist")
 if failures:finish();return
 var Clock=load("res://scripts/gate_attack_clock.gd");var clock=Clock.new()
 check(not clock.advance(1.24,true),"Gate first contact waits 1.25 seconds")
 check(clock.advance(.01,true),"Gate first contact occurs at interval")
 check(not clock.advance(100,true,true),"Pause cannot accumulate hits")
 check(clock.advance(100,true) and not clock.advance(0,true),"Long update emits one contact without replay")
 clock.reset();clock.advance(.8,true);clock.advance(.1,false)
 check(not clock.advance(1.24,true) and clock.advance(.01,true),"Status cancellation needs a fresh full interval")
 var owner=Owner.new();owner.game=game;game.add_child(owner)
 var controller=load("res://scripts/fire_siege_gate.gd").new();controller.configure(owner)
 check(controller.slots.size()==8,"Exactly eight legal attack positions")
 var actors: Array=[]
 for i in range(300):
  var enemy=Ninja.new();enemy.game=game;enemy.defense_lane=1;enemy.encounter_id="gate_unit_%d" % i;enemy.set_meta("siege_generation",10)
  enemy.position=Vector3((i%10)*1.2,.15,110-floori(i/10.0)*1.2)
  game.add_child(enemy);enemy.set_physics_process(false);owner.roster[enemy.encounter_id]=enemy;actors.append(enemy)
  check(controller.admit(enemy) and controller.admit(enemy),"Admission idempotent %d" % i)
 controller.tick(0)
 check(controller.waiting_count()==292,"Remaining 292 actors wait outside eight slots")
 var distinct: Dictionary={};var legal=true
 for enemy in actors:
  var target=controller.assignment(enemy)
  legal=legal and not target.is_empty() and controller.legal(target.position)
  if target.is_empty():continue
  check(not distinct.has(target.position),"Distinct attack/wait position");distinct[target.position]=true
 check(legal,"All 300 positions are valid terrain within bounds")
 for i in range(8):actors[i].position=controller.assignment(actors[i]).position+Vector3.UP*.15
 controller.tick(1.24);check(owner.contacts==0 and controller.attackers()==8,"All eight wait a full first interval")
 controller.tick(.01);check(owner.contacts==8 and owner.health==4840,"Eight once-only twenty-damage contacts")
 var saved=owner.health;actors[0].stun=1;actors[1].frozen_left=1;actors[2].impact_pause=1
 controller.tick(1.25);check(owner.health==saved-100,"Stun/freeze/impact pause suppress individual contacts")
 actors[0].stun=0;actors[1].frozen_left=0;actors[2].impact_pause=0
 saved=owner.health;controller.tick(1.24);check(owner.health==saved,"Recovery cannot replay the canceled first interval")
 controller.tick(.01);check(owner.health==saved-160,"Recovered contacts resume independently")
 actors[0].position+=Vector3(5,0,0);controller.tick(.01)
 check(not controller.assignment(actors[0]).attacking,"Displacement releases its contact position")
 actors[1].dead=true;controller.tick(.2)
 check(not controller.handles(actors[1]) and controller.attackers()<=8,"Death releases weak identity and slot")
 var inside=actors[2];inside.position.z=185;controller.tick(.2)
 check(not controller.handles(inside) and not controller.admit(inside),"Already-inside actors retain normal defense behavior")
 owner.shrine.ids[actors[3].encounter_id]=true;controller.tick(.2)
 check(not controller.handles(actors[3]),"Shrine assignments cannot be reclaimed")
 owner.generation+=1;controller.tick(1.25)
 check(controller.records.is_empty(),"Retired generation clears all pending strikes")
 controller.configure(owner);owner.health=0
 check(not controller.intercepts(actors[4]),"Broken gate stops interception")
 owner.health=5000;owner.generation=10;owner.shrine.ids.clear();controller.configure(owner)
 var old_bounds=game.world.playable_bounds;game.world.playable_bounds=Rect2(1000,1000,1,1);controller.configure(owner)
 var before=actors[4].position;check(controller.admit(actors[4]),"Zero-clearance fixture admits without teleport")
 controller.tick(100);check(controller.slots.is_empty() and controller.assignment(actors[4]).position==before and actors[4].position==before,"No legal slots safely hold current position")
 game.world.playable_bounds=old_bounds;controller.clear()
 for actor in actors:actor.queue_free()
 owner.queue_free();await get_tree().process_frame
 finish()
func finish():
 game.show_main_menu();game.sound_library.cancel();game.music.stop()
 print("SHRINE_GATE_UNIT_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
