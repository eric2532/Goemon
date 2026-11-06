extends "res://scripts/recovered_goemon_gameplay_tests.gd"
func run():
 await setup_fixture()
 var p=game.player
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 check(mirrors.reinforce(1,ORIGIN),"Goemon uses the existing native hero pool")
 var body=mirrors.bodies[0]
 check(body.model.is_processing(),"Leased hero presentation follows its normal render clock")
 body.perform(0,ORIGIN+Vector3.FORWARD*4)
 var shown=false
 for tick in 30:
  var state={"position":body.global_position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO}
  body.step(1.0/60,state)
  await process_frame
  body.model.reach_trail.flush_mesh()
  if body.model.reach_trail.mesh!=null:shown=true
 check(body.model.locomotion.source_action>=0,"Pooled Goemon evaluates his original deferred body pose")
 check(shown,"Pooled Goemon presents the original full-reach wave while attacking")
 var pose=body.model.sampler.sample_source(body.model.locomotion.source_action,body.model.locomotion.source_time)
 if not pose.is_empty():
  var pointer=body.model.OriginalPose.PTR.Head
  var expected:Transform3D=pose[pointer]
  expected=Transform3D(expected.basis.scaled(Vector3.ONE*body.model.source_scale),expected.origin*body.model.source_scale+body.model.source_offset)
  check(body.model.native_parts[pointer].transform.is_equal_approx(expected),"The displayed native part follows the exact current source pose")
 mirrors.clear();check(not body.model.is_processing(),"Retired hero presentation stops until reuse")
 mirrors.dispose();game.queue_free();await frames(3);DirAccess.remove_absolute(cfg)
 print("HERO_MIRROR_POSE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
