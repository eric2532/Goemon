extends SceneTree
func _initialize():
 var balance=preload("res://scripts/character_balance.gd")
 var roster=preload("res://scripts/rogue_roster.gd")
 for id in range(-2,100):
  var expected="goemon" if id==1 else "edo" if id==2 else roster.class_id(id)
  assert(balance.key_for(id)==expected)
  assert(balance.key_for(id)==expected)
 var baseline=PrototypeTuning.DEFAULTS.duplicate(true)
 var profiles={"ben":{"walk_speed":12.0}}
 assert(balance.value(baseline,profiles,15,"walk_speed")==12.0)
 profiles.ben.walk_speed=18.0
 assert(balance.value(baseline,profiles,15,"walk_speed")==18.0)
 print("CHARACTER_PROFILE_KEYS_RESULT checks=206 failures=0");quit()
