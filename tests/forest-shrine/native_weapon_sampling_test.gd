extends SceneTree
class SasukeSampler extends "res://scripts/recovered_sasuke_pose.gd":
 var conversions=0
 func _transform(values:Array)->Transform3D:
  conversions+=1;return super._transform(values)
class YaeSampler extends "res://scripts/recovered_yae_pose.gd":
 var conversions=0
 func _transform(values:Array)->Transform3D:
  conversions+=1;return super._transform(values)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():
 for name_ in ["sasuke","yae"]:
  var sampler=SasukeSampler.new() if name_=="sasuke" else YaeSampler.new()
  var profile=load("res://scripts/recovered_%s_combat_profile.gd"%name_)
  var parts=["0x9002aa8","0x9002bc8","0x90063d8"] if name_=="sasuke" else ["0x9007478"]
  for action_ in profile.data().collision_spheres:
   var action=int(action_);var count=sampler.frame_count(action)
   for frame_ in count:
    for fraction in [0.0,.37]:
     var time_=(frame_+fraction)/(30.0*sampler.native_rate(action))
     var expected:Dictionary=sampler.sample_source(action,time_)
     for part in parts:
      if not expected.has(part):continue
      sampler.conversions=0
      var actual:Transform3D=sampler.sample_part(action,time_,part)
      check(actual.is_equal_approx(expected[part]),"%s weapon anchor matches full native pose: %X/%s/%.3f"%[name_,action,part,time_])
      check(sampler.conversions<=2,"Weapon anchor converts only its adjacent source matrices")
  check(sampler.sample_part(-1,0,parts[0])==Transform3D.IDENTITY,"Unknown action keeps the sampler's safe empty result")
  check(sampler.sample_part(0x68,0,"missing")==Transform3D.IDENTITY,"Unknown part keeps the sampler's safe empty result")
 print("NATIVE_WEAPON_SAMPLING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
