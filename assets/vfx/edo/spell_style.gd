extends RefCounted
## Keep flash reduction in the visual layer; spell damage and timing remain independent.
static func energy_scale(node: Node) -> float:
 var ancestor: Node=node
 while is_instance_valid(ancestor):
  if ancestor.has_method("is_fire_siege"):
   return .30 if ancestor.settings.get("reduced_flashes",false) else 1.0
  ancestor=ancestor.get_parent()
 return 1.0
