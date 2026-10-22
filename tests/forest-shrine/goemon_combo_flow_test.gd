extends "res://tests/forest-shrine/goemon_three_hit_test.gd"
const Combo=preload("res://scripts/pipe_combo.gd")
func run():
 var duration=0.0
 for t in Combo.DURATIONS:duration+=t
 check(duration<=1.0,"The authored triplet fits in one second before impact pauses")
 for stage in [1,2]:
  var end=Combo.sample(stage,1.0);var start=Combo.sample(stage+1,0.0)
  var same=true
  for channel in end:
   if end[channel] is Vector3:same=same and end[channel].is_equal_approx(start[channel])
   else:same=same and is_equal_approx(end[channel],start[channel])
  check(same,"Stage %d flows continuously into stage %d"%[stage,stage+1])
  check(end.weight>.95 and end.wrist.distance_to(Combo.Strike.REST.wrist)>.3,"Stage %d keeps an active loaded stance instead of dropping to idle"%stage)
 for stage in [1,2,3]:
  var phase=.25
  var pose=Combo.sample(stage,phase,phase);var hit=Combo.Strike.key(stage,"contact")
  check(pose.wrist.is_equal_approx(hit.wrist) and pose.aim.is_equal_approx(hit.aim),"Stage %d retains its exact contact pose"%stage)
 check(Combo.sample(3,1.0).wrist.is_equal_approx(Combo.Strike.REST.wrist),"Finishing recovery still settles into idle")
 await setup_fixture();var p=game.player
 fresh();tap("light_attack");var elapsed=0.0
 for i in 150:
  await step(1);elapsed+=1.0/60
  if p.attack_left<=0 and not p.quick_attacks.active:break
 check(contacts==[1,2,3] and elapsed<=1.12,"Actual three-contact combo finishes within 1.12 seconds including hit pauses (%.3fs)"%elapsed)
 # Jump preserves and dodge interrupts each stage during windup, contact freeze and recovery.
 for stage in [1,2,3]:
  for phase in ["windup","contact","recovery"]:
   for action in ["jump","dodge"]:
    fresh();p.jumps_used=0;p.coyote=.13;p.jump_buffer=0;p.jump_windup=0;p.dodge_time=0;p.dodge_cooldown=0
    tap("light_attack");var reached=false
    for i in 150:
     if p.combo==stage and p.attack_left>0:
      var progress=1-p.attack_left/p.attack_duration
      reached=(not p.hit_done if phase=="windup" else (p.hit_done and p.impact_pause>0 if phase=="contact" else progress>.72))
     if reached:break
     await step(1)
    check(reached,"Reached stage %d %s for %s cancellation"%[stage,phase,action])
    var before=contacts.duplicate();p.jumps_used=0;p.coyote=.13;p.jump_windup=0;p.dodge_cooldown=0
    tap(action)
    check(p.attack_left>0 if action=="jump" else p.attack_left==0 and p.impact_pause==0,"Jump preserves and dodge cancels stage %d %s (%s)"%[stage,phase,action])
    await step(85)
    check((contacts==[1,2,3] if action=="jump" else contacts==before) and not p.quick_attacks.active,"Jump completes and dodge stops stage %d %s (%s)"%[stage,phase,action])
 game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_COMBO_FLOW_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
