extends Node3D
## Reed Archer arrows follow the director's simulated flight and shared fog.
var game
var visuals: Dictionary={}
var effects: Node3D
func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	effects=preload("res://assets/rogue/scripts/effects.gd").new();add_child(effects)
	effects.apply_quality(int(game.settings.quality))
func launch(event: Dictionary):
	var arrow=Node3D.new();arrow.name="ReedArrow";add_child(arrow)
	Geo.beam(arrow,Vector3(0,0,-1.2),Vector3(0,0,.1),.055,Geo.mat("82623d",.1,.15))
	Geo.spike(arrow,Vector3.ZERO,Vector3(0,0,.45),.16,Geo.mat("e6e0c4",.4,.3))
	for side in [-1.0,1.0]:
		var fin=Geo.box(arrow,Vector3(side*.09,0,-1.05),Vector3(.2,.04,.4),Geo.mat("ce7555",0,.1));fin.rotation.y=side*-.3
	visuals[event.id]=arrow;arrow.position=event.from
	var direction: Vector3=event.to-event.from
	if direction.length_squared()>.001:arrow.quaternion=Quaternion(Vector3.BACK,direction.normalized())
	arrow.visible=game.forest_point_visible(event.from)
func impact(event: Dictionary):
	var point: Vector3=event.point
	if game.forest_point_visible(point):effects.impact(point,false,Color("cf8662"))
func sync(delta: float):
	effects.tick(delta)
	for item in effects.items:item.node.visible=game.forest_point_visible(item.node.global_position)
	var arrows: Dictionary=game.model.waves.projectiles
	for id in visuals.keys():
		var node: Node3D=visuals[id]
		if not arrows.has(id):node.queue_free();visuals.erase(id);continue
		var arrow: Dictionary=arrows[id];node.position=arrow.pos
		var direction: Vector3=arrow.get("direction",arrow.to-arrow.pos)
		if direction.length_squared()>.001:node.quaternion=Quaternion(Vector3.BACK,direction.normalized())
		node.visible=game.forest_point_visible(arrow.pos)
func clear():
	for node in visuals.values():node.queue_free()
	visuals.clear()
	if is_instance_valid(effects):effects.clear()
