extends SceneTree
const Crowd=preload("res://scripts/forest/forest_enemy_crowd.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
class Model extends RefCounted:
 var enemies={}
 var terrain=preload("res://scripts/forest/forest_ramparts.gd").new()
 var navigation_revision=0
class Game extends Node3D:
 var model=Model.new()
 var playing=true
 var paused=false
 var transitioning=false
 var enemies=[]
 func forest_enemy_visible(_actor):return true
class Actor extends Node3D:
 var forest_id=0
 var variant=0
 var model=Node3D.new()
 var name_tag:Node3D
 var dead=false
 var distance_asleep=false
 var soldier_corpse_pitch=deg_to_rad(67.5)
 var render_full=true
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var game=Game.new();root.add_child(game)
 var crowd=Crowd.new();crowd.game=game;game.add_child(crowd);crowd.set_process(false)
 for role in [0,1,3]:
  var shapes=Contact.shapes(role,true)
  check(shapes.size()==1 and shapes[0].bounds.is_equal_approx(Soldier.hurt_bounds()),"Soldier uses its original single oriented hurt box: "+str(role))
  check(shapes[0].shape is BoxShape3D,"Native soldier contact uses sourceboxgeometry")
  var batch:MultiMesh=crowd.batches[role].multimesh
  check(batch.mesh is ArrayMesh and batch.mesh.get_surface_count()>1,"The visible soldier uses its actual textured mesh")
  check(batch.use_custom_data,"Soldier batch carries a sourcepose index per independent actor")
  var actor=Actor.new();actor.forest_id=role;actor.variant=role;actor.position=Vector3(role*4,0,0);actor.add_child(actor.model);game.add_child(actor);game.enemies.append(actor)
  game.model.enemies[role]={"id":role,"variant":role,"pos":actor.position,"facing":.3,"velocity":Vector3.ZERO,"walk_phase":0.0}
 crowd._process(.016)
 for role in [0,1,3]:
  var batch:MultiMesh=crowd.batches[role].multimesh
  check(batch.visible_instance_count==1,"Each actor draws one independent soldier")
  var state=Soldier.frame_state(game.model.enemies[role]);var record=batch.get_instance_custom_data(0)
  # DummyRenderer retains no GPUinstancebuffer; sourceclip selection andnative
  # model shape are verified here, rendered palette readback is a native test.
  check(state.clip==Soldier.data(role).get_meta("semantics").idle,"Idle uses the original sentry stream")
  var initial=Soldier.frame_state(game.model.enemies[role]);game.model.enemies[role].soldier_pose_tick=12
  var advanced=Soldier.frame_state(game.model.enemies[role])
  check(advanced.tick==12 and advanced.row!=initial.row,"Original40frame idle stream advances")
  crowd._process(0)
  check(float(crowd._poses[role].get("soldier_pose_tick",0))==12,"Render snapshot tracks idle source clock")
  var held=game.model.enemies[role].duplicate(true);held.frozen=2;held.frozen_pose=game.model.enemies[role].duplicate(true);held.soldier_pose_tick=25
  check(Soldier.frame_state(held).tick==12,"Freeze keeps the held native idle pose")
  var actor=game.enemies[[0,1,3].find(role)]
  var conversion=Basis(Vector3( -1,0,0),Vector3(0,-1,0),Vector3(0,0,1))
  var expected=Basis(Vector3.UP,.3)*conversion*Basis(Vector3.RIGHT,actor.soldier_corpse_pitch)*conversion.inverse()
  check(Crowd.presentation_transform(actor,game.model.enemies[role],.1).basis.is_equal_approx(expected),"Corpse root pitch conjugates the original source axes")
  var formation:Dictionary=crowd._formations[role]
  check(formation.roots.size()==1 and formation.parts.size()==1,"No replicated cosmetic bodies return")
  var world=Transform3D(Basis(Vector3.UP,.3),game.model.enemies[role].pos)
  var prepared=Contact.prepare(game.model.enemies[role].merged({"block_contacts":true}),formation)
  check(prepared.bounds.is_equal_approx(world*Soldier.hurt_bounds()),"Attack queries use the native oriented actorbox at the drawn root")
  check(not Contact.segment_contact(game.model.enemies[role].merged({"block_contacts":true}),world*Vector3(0,1,0),world*Vector3(0,1,0),0,prepared).is_empty(),"Sourcebodyinterior is damageable")
 if RenderingServer.get_rendering_device()!=null:
  var full=Crowd.new();full.game=game;full.low_fidelity=false;game.add_child(full);full.set_process(false)
  for role in [0,1,3]:
   var actor=game.enemies[[0,1,3].find(role)];game.model.enemies[role].frozen=2.0
   full._process(0)
   check(full.batches[role].multimesh.get_instance_custom_data(0).g>.9,"Full renderer freezes the living soldier palette")
   actor.dead=true;full._process(.1)
   check(full.batches[role].multimesh.get_instance_custom_data(0).g<.1,"Full renderer clears frozen corpse tint")
 game.queue_free();await process_frame
 print("THIRSTQUENCHER_RENDER_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
