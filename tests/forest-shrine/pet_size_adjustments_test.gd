extends "res://tests/forest-shrine/dragon_lizard_test.gd"

const BEE_UNIT=.0375*preload("res://scripts/forest/forest_enemy_roles.gd").HOUND_SCALE
const FITS={
 "bosses":[1.3,AABB(Vector3(-.85,0,-.7),Vector3(1.7,4.347834975,1.4))],
 "Griffins":[2.0,AABB(Vector3(-1.15,.2,-1.5),Vector3(2.3,2.5,3))],
 "Large bats":[2.0,AABB(Vector3(-.4,.15,-.4),Vector3(.8,1.15,.8))],
 "Bees":[.8,AABB(Vector3(-16,24,-17)*BEE_UNIT,Vector3(32,52,34)*BEE_UNIT)],
}
func skins()->Array:return range(Pets.COUNT).filter(func(skin):return FITS.has(Pets.category(skin)))
func run():
 var selected=skins()
 check(selected.size()==94,"All 36 bosses, 25 griffins, 12 large bats and 21 bees are covered")
 var factors=Dimensions.scales(Pets.ROOT,Pets.motions())
 var geometry=Dimensions.geometry(null)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 var xl_bats=0
 for skin in selected:
  var family=Pets.category(skin);var fit:Array=FITS[family];var original:AABB=fit[1]
  var variant_scale=1.0
  if family in ["Bees","Large bats"]:variant_scale=1.5 if "XL" in Pets.label(skin) else .9
  var expected=AABB(original.position*fit[0]*variant_scale,original.size*fit[0]*variant_scale)
  var box=Dimensions.companion_body(skin)
  check(box.is_equal_approx(expected),"Requested body multiplier: "+Pets.title(skin))
  check(Dimensions.bounds(geometry,19,skin).is_equal_approx(expected),"Native contact body matches: "+Pets.title(skin))
  check(is_equal_approx(geometry[Dimensions.offset(19,skin)+6],factors[skin]),"Native reach and renderer share the size: "+Pets.title(skin))
  var actor=load("res://scripts/forest/crowd/army_enemy_target.gd").new()
  actor.runtime=runtime;actor.handle=runtime.spawn(90000+skin,0,19,Vector3.ZERO,3000,.5)
  actor.variant=19;actor.body_override=box;root.add_child(actor)
  check(actor.get_child(0).shape.size.is_equal_approx(box.size),"Physics body matches: "+Pets.title(skin))
  for axis in [Vector3.UP,Vector3.RIGHT,Vector3.BACK]:
   var edge=box.get_center()+axis*box.size*.5
   var along=Vector3.RIGHT if axis==Vector3.UP else Vector3.UP
   check(actor.combat_segment_hit(edge-axis*.02-along*20,edge-axis*.02+along*20,0),"Inside scaled body connects")
   check(not actor.combat_segment_hit(edge+axis*.02-along*20,edge+axis*.02+along*20,0),"Outside scaled body misses")
  runtime.despawn(actor.handle);actor.free()
  if family=="Large bats" and Pets.motions().variants[skin].xl:xl_bats+=1
  if family=="Bees":check(is_equal_approx(factors[skin],.8*variant_scale),"Bee family size and normal/XL distinction combine")
 check(xl_bats==5,"All five XL large bats keep the earlier 2x family size plus XL growth")
 for skin in range(61):
  var variant_scale=1.0 if skin<21 else 1.5 if "XL" in Pets.label(skin) else .9
  check(is_equal_approx(factors[skin],(.85 if skin>=21 and skin<41 else 1.0)*variant_scale),"Hounds stay unchanged; mantis/dragon size variants combine with family size")
 runtime.clear();runtime.free()
 await super.run()
