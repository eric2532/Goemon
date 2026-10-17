extends SceneTree
## Real imported actors: catches dropped rigs, idle T-poses and frozen skinning.
const Actor = preload("res://assets/rogue/scripts/actor.gd")
const Roster = preload("res://scripts/rogue_roster.gd")
var failures = 0
var checks = 0

func _initialize():
	call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", message)

func run():
	for hero in Roster.CLASS_IDS:
		var actor = Actor.new()
		root.add_child(actor)
		actor.setup(hero)
		var skeleton = actor.model.find_child("Skeleton3D", true, false) as Skeleton3D
		check(skeleton != null, hero + " uses the actual Goemon skeleton")
		if skeleton != null:
			check(skeleton.get_bone_count() == 22, hero + " keeps all Goemon bones")
			var hand = skeleton.find_bone("Hand_R")
			var head = skeleton.find_bone("Head")
			check(skeleton.get_bone_global_pose(hand).origin.y < 1.1, hero + " lowers Goemon's T-pose arms before its class stance")
			actor.animate_pose({"grounded":true}, 1.0/60, 0, 0)
			var before: Transform3D = skeleton.get_bone_global_pose(hand)
			actor.animate_pose({"grounded":true,"attack":{"style":"cutlass","duration":.4,"contact":.12,"time":.12,"index":0}}, 1.0/60, .12, 0)
			var after: Transform3D = skeleton.get_bone_global_pose(hand)
			check(not before.is_equal_approx(after), hero + " animates the visible skinned hand")
			check(skeleton.get_bone_global_pose(head).is_finite(), hero + " head pose remains finite")
			check(actor.model.scale.is_equal_approx(Vector3.ONE), hero + " preserves Goemon body depth")
			check(actor.joints.has("Weapon_Cutlass"), hero + " keeps its primary weapon")
			if hero == "pirate":
				# Drinking uses body-local flask coordinates, independently of the cutlass arm.
				actor.animate_pose({"grounded":true,"drinkGesture":.8}, 1.0/60, 0, 0)
				var flask: Node3D = actor.joints.Flask.node
				var held: Vector3 = flask.global_position
				actor.joints.Arm_R.node.rotate_x(.8)
				check(flask.global_position.distance_to(held) < .0001, "Pirate flask does not follow the cutlass arm during drinking")
				var body_local: Vector3 = actor.joints.Body.node.to_local(flask.global_position)
				check(body_local.distance_to(Vector3(.17,.64,.39)) < .001, "Pirate drinking flask uses the authored body-local position")
		actor.free()
	print("GOEMON_COSPLAY_RUNTIME checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
