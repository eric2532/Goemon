extends HeroModel
## Keeps Hero's model contract while class poses drive the shared Goemon base.
## This wrapper handles menus and the +Z (Rogue) to -Z (Sonic) visual convention.

const Actor = preload("res://assets/rogue/scripts/actor.gd")
const VISUAL_SCALE = 1.0
var class_id = "pirate"
var actor: Node3D
var combat: Node

class LocomotionBridge extends RefCounted:
	var step_events = 0
	var jump_compression = 0.0
	var free_feet = false
	var _travel = 0.0
	func reset() -> void:
		step_events = 0
		jump_compression = 0.0
		free_feet = false
		_travel = 0.0
	func tick(dt: float, speed: float, grounded: bool) -> void:
		if grounded and not free_feet:
			_travel += speed * dt
			if _travel >= 1.8:
				step_events += floori(_travel / 1.8)
				_travel = fmod(_travel, 1.8)
	func evaluate() -> void:
		pass

class WeaponPlaceholder extends ChainPipeVisual:
	func _ready() -> void:
		set_process(false)
	func _process(_dt: float) -> void:
		pass
	func update_chain() -> void:
		pass

func _ready() -> void:
	body = Node3D.new()
	body.name = "RogueBody"
	add_child(body)
	actor = Actor.new()
	actor.name = "RogueActor"
	actor.rotation.y = PI
	# Keep the readability boost outside native joint/weapon animation scales.
	actor.scale = Vector3.ONE * VISUAL_SCALE
	body.add_child(actor)
	actor.setup(class_id)
	rig_visual = actor.model
	# Shared player lifecycle code may hide a coin or reset a limb even when a
	# different kit is equipped. Empty nodes satisfy that contract without
	# importing, drawing, or animating any of Goemon's equipment.
	head = _placeholder("HeadCompatibility")
	arms.assign([_placeholder("LeftArmCompatibility"), _placeholder("RightArmCompatibility")])
	legs.assign([_placeholder("LeftLegCompatibility"), _placeholder("RightLegCompatibility")])
	pipe = _placeholder("PipeCompatibility")
	coin = _placeholder("CoinCompatibility")
	scarf = _placeholder("ScarfCompatibility")
	hair_normal = _placeholder("HairCompatibility")
	hair_gold = _placeholder("SurgeCompatibility")
	chain_pipe = WeaponPlaceholder.new()
	chain_pipe.name = "ChainCompatibility"
	body.add_child(chain_pipe)
	chain_pipe.hide()
	locomotion = LocomotionBridge.new()
	process_priority = 30
	actor.animate_pose({}, 0, 0, 0)

func _placeholder(label: String) -> Node3D:
	var node = Node3D.new()
	node.name = label
	body.add_child(node)
	node.hide()
	return node

func _process(_delta: float) -> void:
	pass

func animate(delta: float, speed: float, grounded: bool, _vertical: float, _attack: float, _heavy: bool, _combo: int, _dodge: bool) -> void:
	locomotion.tick(delta, speed, grounded)
	landing = move_toward(landing, 0, delta * 5.0)
	if is_instance_valid(combat) and combat.active:
		return
	phase += delta
	body.transform = Transform3D.IDENTITY
	actor.animate_pose({}, delta, phase, clampf(speed / 5.0, 0, 1))

func sync_skeleton() -> void:
	pass

func cape_skeleton()->Skeleton3D:
	if is_instance_valid(actor) and is_instance_valid(actor.rom_thief):return actor.rom_thief.equipment_skeleton
	return actor.cosplay_rig.skeleton if is_instance_valid(actor) and actor.cosplay_rig!=null else null

func set_surge(_active: bool) -> void:
	pass

func apply_skin(_id: String) -> void:
	pass

func hand_position(side: String = "R") -> Vector3:
	if is_instance_valid(actor) and is_instance_valid(actor.rom_thief):return actor.rom_thief.hand_position(side)
	if is_instance_valid(actor) and actor.cosplay_rig!=null:
		var sk: Skeleton3D=actor.cosplay_rig.skeleton
		return sk.global_transform*sk.get_bone_global_pose(sk.find_bone("Hand_"+side)).origin
	if is_instance_valid(actor) and actor.joints.has("Arm_" + side):
		var arm: Node3D = actor.joints["Arm_" + side].node
		return arm.to_global(Vector3(0, -0.38, 0.2))
	return global_position + Vector3.UP * 1.1
