extends "res://scripts/recovered_leaders_tests.gd"
const Combat=preload("res://scripts/recovered_leader_combat.gd")
func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="user://ben-original-attacks-%s.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await frames(5)
 game.begin_forest();game.choose_rogue_character(15);game.start_wave();game.tuning.invincible=true;game.tuning.freeze_ai=true;await frames(10)
 var p=game.player;var c=p.active_ability;p.set_physics_process(false);p.model.set_process(false)
 c.cancel();c.start_attack(false)
 check("source_16__" in c.clip,"Ben polearm selects the original actor's source16")
 check(c.playback_rate==2,"Ben polearm plays its native key sequence at twice the speed")
 check(is_equal_approx(p.attack_duration,87.0/60.0),"Terminal hold0 ends native polearm at key87")
 c.elapsed=44.9/30.0;check(is_equal_approx(c.motion_time(),44.0/30.0),"Polearm samples original integer key44 without fractional rewind")
 c.finish_attack();c.start_attack(false)
 check("source_16__" in c.clip and c.combo==0 and c.playback_rate==2,"Repeated polearm uses native action, not the inherited three-step combo")
 c.cancel();c.start_utility()
 check("source_14__" in c.clip,"Projectile fan uses actual source14")
 check(is_equal_approx(p.attack_duration,25.0/60.0),"Terminal hold0 ends native projectile throw at key25")
 check(is_equal_approx(c.contact_time,10.0/30.0),"Projectile release remains original key10")
 p.model.blend_left=0;p.model._sample(c.clip,10.0/30.0,0)
 for mesh in p.model.ben_accessory_meshes:check(not mesh.visible,"Ground projectile throw leaves original propeller renderer hidden")
 if c.has_method("ben_ground_motion_frame"):
  var contact=[];var dash=[];var releases=[]
  for tick in range(88):
   var frame=c.ben_ground_motion_frame("polearm",tick)
   if frame.contact:contact.append(tick)
   if frame.dash:dash.append(tick)
   if tick<87:check(frame.body_key==tick,"Native polearm key order at tick%d"%tick)
  check(contact==range(1,44)+range(50,66),"Native spinning and dash proximity-contact windows")
  check(dash==range(50,66),"Native dash is16 update steps after setupkey49")
  for tick in range(26):
   if c.ben_ground_motion_frame("fan",tick).release:releases.append(tick)
  check(releases==[10],"Exactly one three-projectile release per native action")
 else:check(false,"Native ground action frame trace API exists")
 for grounded_key in ["source_00","Run","Land"]:
  p.model._sample(p.model.motion(grounded_key),0,.1)
  check(p.model.ben_accessory_meshes.all(func(mesh):return not mesh.visible),"Ground locomotion keeps the original propeller renderer hidden: "+grounded_key)
 p.model._sample(p.model.motion("source_19"),0,.1)
 check(p.model.ben_accessory_meshes.all(func(mesh):return mesh.visible),"Barrage explicitly restores the original propeller renderer")
 var bone_checks=0;var max_error=0.0
 for kind in ["polearm","fan"]:
  var original=p.model.motion("source_16" if kind=="polearm" else "source_14")
  for key in range(87 if kind=="polearm" else 25):
   p.model.animation_player.play(original);p.model.animation_player.seek(float(key)/30.0,true)
   var expected=[]
   for part in range(12):expected.append(p.model.skeleton.get_bone_pose(p.model.skeleton.find_bone("Part_%02d"%part)))
   p.model.current_clip=original;p.model.blend_left=0;p.model._sample(original,float(key)/30.0,0)
   for part in range(12):
    var actual=p.model.skeleton.get_bone_pose(p.model.skeleton.find_bone("Part_%02d"%part))
    var error=actual.origin.distance_to(expected[part].origin)
    for axis in range(3):error=maxf(error,actual.basis[axis].distance_to(expected[part].basis[axis]))
    max_error=maxf(max_error,error);bone_checks+=1
   for mesh in p.model.ben_accessory_meshes:check(not mesh.visible,"Ground renderer stays hidden at%s key%d"%[kind,key])
 check(max_error<.00001,"All original first12body matrices remain unchanged")
 print("NATIVE_GROUND_BONE_CHECKS ",bone_checks," max_error=",max_error)
 print("BEN_ORIGINAL_ATTACKS_RESULT checks=",checks," failures=",failures)
 stop_audio(game);game.move_audio.stop();await create_timer(.35).timeout;current_scene=null;game.queue_free();await frames(3);quit(1 if failures>0 else 0)
