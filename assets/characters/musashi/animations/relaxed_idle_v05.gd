extends "res://assets/characters/musashi/animations/motion.gd"
# V05's relaxed arms apply only to grounded, stationary, non-combat idle.
# Movement, jumping, dodging and combat delegate to the existing motion adapter.
func set_rot(bone_name: String, v: Vector3):
	var c=model.combat
	var is_rest=grounded and speed<.2 and not dodge and (c==null or c.state in [c.State.IDLE,c.State.MOVING])
	if is_rest:
		var side=1.0 if bone_name.ends_with("_L") else -1.0
		if bone_name.begins_with("Arm_"):v=Vector3(-.025,0,-side*.025)
		elif bone_name.begins_with("Forearm_"):v=Vector3(-.13,0,0)
	super.set_rot(bone_name,v)
