extends SceneTree
const C=preload("res://scripts/forest/forest_east_round_cactus.gd")
func _initialize():
 C.Base.Art.load_east()
 for token in C.data().graphics:
  var serial=int(token);var g:Dictionary=C.Base.Art.data().graphics[token];var m:Mesh=C.mesh(serial,g)
  print(serial," original=",g.rect," origin=",g.origin," box=",m.get_aabb())
 quit()
