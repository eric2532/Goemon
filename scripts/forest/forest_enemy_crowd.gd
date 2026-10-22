class_name ForestEnemyCrowd
extends Node3D
## Native army presentation only; no alternate renderer or actor update loop.
var game:Node
var army:Node3D
func configure_army(owner_:Node):
 army=preload("res://scripts/forest/crowd/army_renderer.gd").new();add_child(army);army.configure(owner_)
func present_army(snapshot:Dictionary,events:Array):army.present(snapshot,events)
func clear():
 if is_instance_valid(army):army.clear()
