extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func run():
 var fixture=load('res://tests/forest-shrine/large_army_fixture.gd').new();root.add_child(fixture)
 var game=await fixture.make_game('original');fixture.clear_targets()
 var p=fixture.reset_player(13);p.set_physics_process(false);p.position=Vector3(0,.05,60)
 for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
 p.velocity=Vector3.ZERO
 var c=p.active_ability;var m=p.model
 var front=fixture.add_target(p.position+Vector3.FORWARD*3.9);front.hp=10000;front.max_hp=10000
 var back=fixture.add_target(p.position+Vector3.BACK*3.9);back.hp=10000;back.max_hp=10000
 await physics_frame;await physics_frame
 c.select_number(1)
 p.jump_buffer=.15;p._physics_musashi(1.0/30.0)
 check(p.jumps_used==0 and not c.locomotion._jump_pending,'ground special discards attempted jump and pending intent')
 check(c.mode=='rotation' and c.clip=='Extra__800d5360' and not c.guarding(),'1 begins actual Norm rotation without charging')
 check(m.sword_trail.trail_index==2 and m.sword_trail.length_divisor==49,'normal spin uses recovered descriptor8')
 c.tick(8.0/30.0)
 check(c.rotation_ticks==8 and c.rotation_angle==0 and not c.contact_done,'eight original windup ticks before turn/contact')
 check(front.hp==10000 and back.hp==10000,'windup cannot damage either target')
 var angles=[286,602,948,1324,1730,2166,2632,3128,3654,4210]
 for i in 10:
  c.tick(1.0/30.0)
  if i==0:check(front.hp<10000 and back.hp==10000,'first spin update contacts its swept front arc, not enemies behind')
  check(c.rotation_angle==angles[i] and c.clip=='Extra__800d5360' and is_equal_approx(c.elapsed,8.0/30.0),'paused pose with source accelerating yaw%d'%i)
  m.animate(0,0,true,0,1,true,1,false)
  check(absf(wrapf(m.body.rotation.y+angles[i]*TAU/4096.0,-PI,PI))<.0001,'rig body really turns with native yaw%d'%i)
 check(back.hp<10000,'later sweep reaches the target behind')
 var bone=m.skeleton.find_bone('Part_25_weapon_attachment')
 check(m.skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE*1.25),'spin scales only drawn Lumina by source maximum1.25')
 m.animate(0,0,true,0,1,true,1,false)
 check(m.skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE*1.25),'paused pose resampling does not compound sword scale')
 check(m.rotation_effect.vortices.is_empty(),'ordinary Rotation does not borrow Mighty Strike vortex')
 c.tick(1.0/30.0);m.animate(0,0,true,0,1,true,1,false)
 check(c.action_key=='rotation_end' and c.clip=='Recovered__800d53a4' and m.body.rotation.y==0,'following source update restores facing and resumes original tail')
 c.tick(4.0/30.0);check(not c.is_attacking(),'four tail ticks end spin')
 c.select_number(2)
 c.tick(1.0/30.0);m.animate(0,0,true,0,1,true,1,false)
 check(m.skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE*(0x19EB/4096.0)),'Mighty Strike uses original1.62x Lumina size')
 check(c.mode=='counter' and c.clip=='Table_23__800d552c','2 selects distinct original Mighty Strike stream')
 check(m.sword_trail.length_divisor==39,'Mighty Strike uses descriptor7')
 c.tick(9.0/30.0);check(m.rotation_effect.vortices.is_empty(),'counter effects wait for source11')
 c.tick(1.0/30.0);check(m.rotation_effect.vortices.size()==2,'counter original vortex emits at11')
 p.select_character(1)
 check(m.rotation_effect.vortices.is_empty() and m.sword_trail.samples.is_empty(),'fighter switch clears both special effect families')
 p.select_character(13);p.position.y+=10;p.velocity=Vector3.UP;p.move_and_slide();c.select_number(1)
 check(not c.is_attacking(),'airborne quick spin is rejected without latent intent')
 await fixture.close();fixture.queue_free();await process_frame
 print('MUSASHI_CHARGED_ACTION_TEST checks=',checks,' failures=',failures);quit(1 if failures else 0)
