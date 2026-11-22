extends "res://tests/forest-shrine/sponsor_pet_combat_test.gd"

func run():
 var geometry=Dimensions.geometry(null)
 var factors=Dimensions.scales(Pets.ROOT,Pets.motions())
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 for skin in skins():
  var box=Dimensions.companion_body(skin)
  check(Dimensions.bounds(geometry,19,skin).is_equal_approx(box),"Native body matches sponsor size: "+Pets.title(skin))
  check(is_equal_approx(geometry[Dimensions.offset(19,skin)+6],factors[skin]),"Native reach and renderer share sponsor scale: "+Pets.title(skin))
  var actor=load("res://scripts/forest/crowd/army_enemy_target.gd").new()
  actor.runtime=runtime;actor.handle=runtime.spawn(90000+skin,0,19,Vector3.ZERO,3000,.5)
  actor.variant=19;actor.body_override=box;root.add_child(actor)
  check(actor.get_child(0).shape.size.is_equal_approx(box.size),"Physics body matches sponsor size: "+Pets.title(skin))
  for axis in [Vector3.UP,Vector3.RIGHT,Vector3.BACK]:
   var edge=box.get_center()+axis*box.size*.5
   var along=Vector3.RIGHT if axis==Vector3.UP else Vector3.UP
   check(actor.combat_segment_hit(edge-axis*.02-along*20,edge-axis*.02+along*20,0),"Inside sponsor body connects")
   check(not actor.combat_segment_hit(edge+axis*.02-along*20,edge+axis*.02+along*20,0),"Outside sponsor body misses")
  runtime.despawn(actor.handle);actor.free()
 runtime.clear();runtime.free()
 await super.run()
