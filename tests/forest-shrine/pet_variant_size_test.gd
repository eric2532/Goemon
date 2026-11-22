extends "res://tests/forest-shrine/dragon_lizard_test.gd"

func xl(skin:int)->bool:return "XL" in Pets.label(skin)
func skins()->Array:
 var families=[]
 for skin in Pets.COUNT:
  if xl(skin) and Pets.category(skin) not in families:families.append(Pets.category(skin))
 return range(Pets.COUNT).filter(func(skin):return Pets.category(skin) in families)
func run():
 var selected=skins();var large=selected.filter(xl)
 check(selected.size()==282 and large.size()==70,"All 70 XL and 212 normal appearances across 16 families are covered")
 var factors:PackedFloat32Array=Pets.make_mesh().material.get_shader_parameter("pet_scales")
 var geometry=Dimensions.geometry(null)
 for skin in selected:
  check(Dimensions.bounds(geometry,19,skin).is_equal_approx(Dimensions.companion_body(skin)),"Native body matches sized artwork: "+Pets.title(skin))
  check(is_equal_approx(geometry[Dimensions.offset(19,skin)+6],factors[skin]),"Native reach and actual shader share the variant scale: "+Pets.title(skin))
  if skin<82:check(is_equal_approx(Dimensions.size_variant_scale(skin),1.5 if xl(skin) else .9),"Core size classification matches its picker label")
 for skin in large:
  var normal=skin-15 if skin<41 else skin-16 if skin<82 else selected.filter(func(s):return Pets.category(s)==Pets.category(skin) and not xl(s))[0]
  var regular=Dimensions.companion_body(normal);var bigger=Dimensions.companion_body(skin)
  check(bigger.size.is_equal_approx(regular.size*(1.5/.9)) and bigger.position.is_equal_approx(regular.position*(1.5/.9)),"XL body is 150% of the previous baseline versus normal at 90%: "+Pets.title(skin))
 await super.run()
