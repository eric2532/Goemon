class_name RecoveredGoemonVFX
extends Node3D
## ROM pixels/geometry. Hit sprite composition adapts the source player effect
## atlas to the current game's hit locations; it is not a replay of enemy code.
## Golden cone is the actual 10-frame ROM AnimatedSkeleton090006B8 +DL09008AA8.
const Weapons = preload("res://scripts/recovered_goemon_weapons.gd")
const ROOT := "res://assets/characters/recovered_goemon/vfx/"
var age: float = 0.0
var lifetime: float = 0.3
var mode := "hit"
var burst: Sprite3D
var stars: Sprite3D
var aura: MeshInstance3D
var native_motion: Dictionary = {}
var source_scale: float = 0.016

func _init():
	process_mode=Node.PROCESS_MODE_PAUSABLE

static func hit(parent: Node3D, position_: Vector3, heavy: bool = false) -> Node3D:
	if parent.get_tree().get_nodes_in_group("original_goemon_hit_pixels").size()>=24:return null
	var effect := RecoveredGoemonVFX.new()
	effect.name = "OriginalGoemonHitPixels"
	parent.add_child(effect)
	effect.add_to_group("original_goemon_hit_pixels")
	effect.global_position = position_
	effect.lifetime = 0.32 if heavy else 0.24
	effect.burst = effect._sprite("burst_0.png", 0.026 if heavy else 0.021)
	effect.stars = effect._sprite("stars_0.png", 0.035 if heavy else 0.027)
	effect.stars.rotation.z = 0.35 if heavy else -0.18
	return effect

static func golden(parent: Node3D, position_: Vector3, scale_: float = 0.016) -> Node3D:
	var effect := RecoveredGoemonVFX.new()
	effect.name = "OriginalGoemonGoldenAura"
	effect.mode = "golden"
	effect.lifetime = 0.7
	effect.source_scale = scale_
	effect.native_motion = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "golden_aura_motion.json"))
	effect.aura = Weapons.create_part("golden_aura")
	for surface in range(effect.aura.mesh.get_surface_count()):
		var material := effect.aura.mesh.surface_get_material(surface) as StandardMaterial3D
		if material != null:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.albedo_color = Color(1.0, 0.84, 0.24, 1.0)
	effect.add_child(effect.aura)
	parent.add_child(effect)
	effect.global_position = position_
	effect._update_aura()
	return effect

func _sprite(file_name: String, pixel_size_: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = load(ROOT + file_name) as Texture2D
	sprite.pixel_size = pixel_size_
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = false
	sprite.shaded = false
	add_child(sprite)
	return sprite

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	if mode == "golden":
		_update_aura()
	elif is_instance_valid(burst):
		var frame := mini(3, int(age / lifetime * 4.0))
		burst.texture = load(ROOT + "burst_%d.png" % frame) as Texture2D
		stars.texture = load(ROOT + "stars_%d.png" % frame) as Texture2D
		var expansion := lerpf(0.7, 1.55, age / lifetime)
		burst.scale = Vector3.ONE * expansion
		stars.scale = Vector3.ONE * lerpf(0.8, 1.7, age / lifetime)
		var alpha := 1.0 - smoothstep(0.45, 1.0, age / lifetime)
		burst.modulate.a = alpha
		stars.modulate.a = alpha

func _update_aura() -> void:
	if native_motion.is_empty() or not is_instance_valid(aura):
		return
	var frames: Array = native_motion.get("frames", [])
	if frames.is_empty():
		return
	var frame := mini(frames.size() - 1, int(age * 30.0))
	var v: Array = frames[frame]
	var native := Transform3D(Basis(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), Vector3(v[6], v[7], v[8])), Vector3(v[9], v[10], v[11]))
	aura.transform = Transform3D(native.basis.scaled(Vector3.ONE * source_scale), native.origin * source_scale)
	var alpha := 1.0 - smoothstep(0.48, lifetime, age)
	for surface in range(aura.mesh.get_surface_count()):
		var material := aura.mesh.surface_get_material(surface) as StandardMaterial3D
		if material != null:
			material.albedo_color.a = alpha
