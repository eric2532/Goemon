extends SceneTree
const Actor = preload("res://assets/rogue/scripts/actor.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var actor = Actor.new()
	root.add_child(actor)
	actor.setup("samurai")
	var scarf = actor.scarf_wind
	check(scarf != null and is_instance_valid(scarf.tail), "Samurai exports a separate continuous scarf tail")
	if scarf != null and is_instance_valid(scarf.tail):
		var rest: PackedVector3Array = scarf.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(scarf.length_ > 1.2, "Scarf tail retains its long authored silhouette")
		var root_index: int = 0
		var tip_index: int = 0
		for i in range(rest.size()):
			if rest[i].z > rest[root_index].z: root_index = i
			if rest[i].z < rest[tip_index].z: tip_index = i
		var second = Actor.new()
		root.add_child(second)
		second.setup("samurai")
		check(second.scarf_wind.mesh != scarf.mesh, "Each Samurai owns an independent cloth mesh")
		for i in range(30): scarf.tick({}, 1.0 / 60)
		var idle: PackedVector3Array = scarf.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(idle[root_index].distance_to(rest[root_index]) < 0.001, "Wind leaves the attachment root fixed")
		check(idle[tip_index].distance_to(rest[tip_index]) > 0.015, "Tail waves visibly while idle")
		check(second.scarf_wind.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == rest, "One actor's wind cannot mutate another actor")
		scarf.tick({"motionSpeed": 20.0}, 0.0)
		check(scarf.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == idle, "Paused animation preserves the current scarf shape")
		for i in range(45): scarf.tick({"motionSpeed": 10.2}, 1.0 / 60)
		check(scarf.airflow > 0.95, "Running increases the scarf airflow")
		var valid: bool = true
		for normal in scarf.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
			valid = valid and normal.is_finite() and normal.length() > 0.9
		check(valid, "Animated cloth retains finite unit normals for lighting")
		var cloth_material = scarf.tail.get_active_material(0)
		check(actor.materials.any(func(entry): return entry.material == cloth_material), "Wind retains the actor's private hit-flash material")
		actor.reset_motion()
		check(scarf.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == rest, "Reset restores exact authored cloth geometry")
		check(scarf.clock == 0.0 and scarf.airflow == 0.0, "Reset clears accumulated wind")
		second.free()
	actor.setup("ninja")
	check(actor.scarf_wind == null, "Changing class clears the scarf controller")
	actor.free()
	print("ROGUE_SCARF_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
