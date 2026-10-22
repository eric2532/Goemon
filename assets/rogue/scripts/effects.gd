extends Node3D
## Native, short-lived combat geometry. Ribbons reveal a moving cutting edge;
## thrusts have a solid spearhead, pressure vanes and expanding shock collars.
## The game ticks this explicitly so pause and hit-stop keep visual timing exact.

const GOLD: Color = Color("ffd487")
const TEAL: Color = Color("6ef7dc")
const Ink = preload("res://assets/rogue/scripts/ink_brush_style.gd")
const BLADE_SHADER = preload("res://assets/rogue/shaders/blade_trail.gdshader")
const MAX_EFFECTS: int = 700
var quality: int = 1
var army_trails: bool = false
const MAX_IDLE_ARROWS=12
var idle_arrows:Dictionary={}
var idle_arrow_count=0
static var _army_ranger_mesh: ArrayMesh
static var _army_spears: Dictionary={}
static var _army_diamonds: Dictionary={}
static var _army_rings: Dictionary={}
const ARMY_FEEDBACK_LIMITS={"impact":12,"particle-burst":12,"ring":12,"streak":24,"magic-brush":12,"damage":4,"dragon-eruption":4,"dragon-descent":4}
var effect_budget: int = 320
var burst_material: ShaderMaterial
var impact_frame: int = -1
var impacts_this_frame: int = 0
var particle_frame: int = -1
var particle_bursts_this_frame: int = 0
var ring_frame: int = -1
var rings_this_frame: int = 0
var feedback_live: Dictionary = {}
var streak_frame: int = -1
var streaks_this_frame: int = 0
var shake: float = 0.0
var flash: float = 0.0
var reduced_flashes: bool = false
var items: Array = []
var time: float = 0.0
var sphere_geometry: SphereMesh
var spark_geometry: BoxMesh
var geometry_cache: Dictionary = {}
var previous_poses: Dictionary = {}
var previous_blade: Array = []
var previous_blade_weapon: int = 0

func apply_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	effect_budget = [180,320,420][quality]
	while items.size()>effect_budget:
		var oldest: Dictionary = items.pop_front()
		_release_feedback(oldest)
		if is_instance_valid(oldest.node): oldest.node.queue_free()

func _ensure_geometry() -> void:
	if sphere_geometry != null:
		return
	sphere_geometry = SphereMesh.new()
	sphere_geometry.radius = 1.0
	sphere_geometry.height = 2.0
	sphere_geometry.radial_segments = 8
	sphere_geometry.rings = 4
	spark_geometry = BoxMesh.new()
	spark_geometry.size = Vector3.ONE
	burst_material = ShaderMaterial.new()
	burst_material.shader = preload("res://assets/rogue/shaders/energy_sparks.gdshader")

func _material(color: Color, opacity: float = 1.0, additive: bool = true) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.emission_enabled = additive
	material.emission = color
	material.emission_energy_multiplier = 1.25 if reduced_flashes else 1.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.disable_fog = true
	material.albedo_color = Color(color.r, color.g, color.b, opacity * (0.43 if reduced_flashes and additive else 1.0))
	material.set_meta("base_alpha", material.albedo_color.a)
	return material

func _mesh(geometry: Mesh, color: Color, opacity: float = 1.0, additive: bool = true) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = geometry
	node.material_override = Ink.material(color,.42 if reduced_flashes else (1.0 if additive else .5),opacity)
	node.material_override.set_meta("base_fade",opacity)
	node.set_meta("ink_materials",[node.material_override])
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _array_mesh(vertices: PackedVector3Array, indices: PackedInt32Array, uvs: PackedVector2Array = PackedVector2Array()) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	if uvs.is_empty():
		# Every procedural pigment surface needs UVs, including thrust facets.
		var bounds=AABB(vertices[0],Vector3.ZERO)
		for point in vertices:bounds=bounds.expand(point)
		var longitudinal=2 if bounds.size.z>bounds.size.x else 0
		for point in vertices:
			var u=(point[longitudinal]-bounds.position[longitudinal])/maxf(.001,bounds.size[longitudinal])
			var v=(point.y-bounds.position.y)/maxf(.001,bounds.size.y)
			uvs.append(Vector2(u,v if bounds.size.y>.001 else .8))
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _blade(radius: float, width: float, arc: float, direction: float, tilt: float) -> ArrayMesh:
	var key: String = "blade_%0.3f_%0.3f_%0.3f_%0.3f_%0.3f" % [radius, width, arc, direction, tilt]
	if geometry_cache.has(key):
		return geometry_cache[key]
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var segments: int = 64
	for i in range(segments + 1):
		var u: float = float(i) / float(segments)
		var theta: float = direction * (u - 0.5) * arc
		var taper: float = pow(maxf(0, sin(PI * u)), 0.62)
		var outer: float = radius * (0.96 + 0.04 * sin(PI * u))
		for v in [0.0, 1.0]:
			var r: float = outer - (1.0 - v) * width * taper
			vertices.append(Vector3(sin(theta) * r, sin(theta) * r * tilt, cos(theta) * r))
			uvs.append(Vector2(u, v))
		if i < segments:
			var n: int = i * 2
			indices.append_array(PackedInt32Array([n, n + 1, n + 2, n + 1, n + 3, n + 2]))
	var mesh: ArrayMesh = _array_mesh(vertices, indices, uvs)
	if geometry_cache.size() < 180:
		geometry_cache[key] = mesh
	return mesh

func _spear(length_: float = 1.4, width: float = 0.32, height: float = 0.22) -> ArrayMesh:
	var key=Vector3(length_,width,height)
	if army_trails and _army_spears.has(key):return _army_spears[key]
	var shoulder: float = length_ * 0.26
	var mesh=_array_mesh(PackedVector3Array([Vector3.ZERO, Vector3(-width, 0, shoulder), Vector3(0, height, shoulder), Vector3(width, 0, shoulder), Vector3(0, -height, shoulder), Vector3(0, 0, length_)]), PackedInt32Array([0, 2, 1, 0, 3, 2, 0, 4, 3, 0, 1, 4, 5, 1, 2, 5, 2, 3, 5, 3, 4, 5, 4, 1]))
	if army_trails and _army_spears.size()<180:_army_spears[key]=mesh
	return mesh

func _diamond(length_: float = 1.5, width: float = 0.13) -> ArrayMesh:
	var key=Vector2(length_,width)
	if army_trails and _army_diamonds.has(key):return _army_diamonds[key]
	var mesh=_array_mesh(PackedVector3Array([Vector3(-length_ / 2, 0, 0), Vector3(0, width, 0), Vector3(length_ / 2, 0, 0), Vector3(0, -width, 0)]), PackedInt32Array([0, 1, 2, 0, 2, 3]))
	if army_trails and _army_diamonds.size()<180:_army_diamonds[key]=mesh
	return mesh

func _ring_geometry(radius: float, width: float, arc: float = TAU, segments: int = 64) -> ArrayMesh:
	var key: String = "ring_%0.3f_%0.3f_%0.3f_%d" % [radius, width, arc, segments]
	var cache: Dictionary=_army_rings if army_trails else geometry_cache
	if cache.has(key):return cache[key]
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		var a: float = float(i) / float(segments) * arc
		vertices.append(Vector3(sin(a), cos(a), 0) * maxf(0.01, radius - width))
		vertices.append(Vector3(sin(a), cos(a), 0) * radius)
		uvs.append(Vector2(float(i)/segments,0));uvs.append(Vector2(float(i)/segments,1))
		if i < segments:
			var n: int = i * 2
			indices.append_array(PackedInt32Array([n, n + 1, n + 2, n + 1, n + 3, n + 2]))
	var mesh: ArrayMesh = _array_mesh(vertices, indices,uvs)
	if cache.size() < 180:cache[key] = mesh
	return mesh

func _fade(node: Node, multiplier: float) -> void:
	if node is MeshInstance3D:
		var material = node.material_override
		if material is StandardMaterial3D:
			var color: Color = material.albedo_color
			color.a = float(material.get_meta("base_alpha", 1.0)) * multiplier
			material.albedo_color = color
		elif material is ShaderMaterial and material.shader==preload("res://assets/rogue/shaders/magic_ink_brush.gdshader"):
			material.set_shader_parameter("fade",float(material.get_meta("base_fade",1.0))*multiplier)
	for child in node.get_children():
		_fade(child, multiplier)

func _release_feedback(item: Dictionary) -> void:
	if feedback_live.has(item.kind):
		feedback_live[item.kind] = maxi(0, int(feedback_live[item.kind])-1)

func _feedback_available(kind: String) -> bool:
	# Army cosmetics wait for room instead of evicting/rebuilding a small pool
	# on every hit. Existing ribbons and trails update without this admission.
	if army_trails and items.size()>=mini(MAX_EFFECTS,effect_budget):return false
	if army_trails:
		var owner: Node=get_parent() if get_parent()!=null else self
		if owner.get_meta("army_feedback_frame",-1)==Engine.get_process_frames():
			var counts: Dictionary=owner.get_meta("army_feedback_counts")
			if int(counts.get(kind,0))>=int(ARMY_FEEDBACK_LIMITS.get(kind,12)):return false
	if kind=="magic-brush":return int(feedback_live.get(kind,0))<[2,3,4][quality]
	return int(feedback_live.get(kind,0)) < ([16,32,48][quality] if kind=="streak" else [6,12,18][quality])

func _reserve_army_feedback(kind: String) -> void:
	if not army_trails:return
	# Effects from one game are direct siblings. Parent-owned counters cannot
	# leak admission limits into another game, and reset on displayed frames.
	var owner: Node=get_parent() if get_parent()!=null else self
	var frame=Engine.get_process_frames()
	if owner.get_meta("army_feedback_frame",-1)!=frame:
		owner.set_meta("army_feedback_frame",frame);owner.set_meta("army_feedback_counts",{})
	var counts: Dictionary=owner.get_meta("army_feedback_counts")
	counts[kind]=int(counts.get(kind,0))+1

func _add(node: Node3D, life: float, kind: String, data: Dictionary = {}) -> Node3D:
	if items.size() >= mini(MAX_EFFECTS,effect_budget):
		var oldest_index=0
		if army_trails:
			# Native damage waves can fill a five-slot army pool in one landing.
			# Reuse ordinary feedback slots before discarding its attached dragon.
			for i in items.size():
				if items[i].kind not in ["dragon-descent","dragon-eruption"]:oldest_index=i;break
		var oldest: Dictionary = items[oldest_index]
		items.remove_at(oldest_index)
		_release_feedback(oldest)
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()
	add_child(node)
	_register_ink(node)
	data.merge({"node": node, "life": life, "max": life, "kind": kind}, true)
	items.append(data)
	if kind in ["impact","particle-burst","ring","streak","magic-brush","dragon-eruption","dragon-descent"]:
		feedback_live[kind]=int(feedback_live.get(kind,0))+1
	return node

func sword_brush_sample(attack: Variant, weapon: Node3D, axis: Vector3, crimson: bool = false, accelerated: bool = false, tempo: float = 1.0) -> void:
	_sample_weapon_brush(attack,[{"node":weapon,"axis":axis}],Color.WHITE,accelerated,tempo,true,crimson)

func weapon_brush_sample(attack: Variant, blades: Array, tint: Color, accelerated: bool=false, tempo: float=1.0) -> void:
	_sample_weapon_brush(attack,blades,tint,accelerated,tempo,false,false)

func _sample_weapon_brush(attack: Variant, blades: Array, tint: Color, accelerated: bool, tempo: float, legacy: bool, crimson: bool) -> void:
	var current: Array = []
	var previous: Array = []
	for blade in blades.slice(0,2):
		if not is_instance_valid(blade.node):return
		var uid=blade.node.get_instance_id()
		var pose=[blade.node.to_global(Vector3.ZERO),blade.node.to_global(blade.axis)]
		if previous_poses.has(uid):previous.append(previous_poses[uid])
		current.append(pose);previous_poses[uid]=pose
	if current.is_empty():return
	if previous.size()!=current.size():previous.clear()
	if attack==null:return
	# Emit through the same windup/contact/follow-through phases as actor._phase.
	var contact: float = attack.contact
	var follow: float = float(attack.get("brushEnd",minf(attack.duration*.78, contact+minf(.09,(attack.duration-contact)*.24))))
	var item: Dictionary = attack.get("magicBrush",{})
	var last_observed: float = attack.get("brushObservedTime",0.0)
	attack.brushObservedTime=attack.time
	var crossed_follow: bool = last_observed<follow and attack.time>follow
	if attack.time<float(attack.get("brushStart",contact*.52)) or (attack.time>follow and not crossed_follow):return
	var life: float = .08/maxf(1.0,tempo) if accelerated else (.16 if crimson else .20)
	if item.is_empty():
		# A full army pool must not enter the native newest-cut eviction fallback.
		if army_trails and not _feedback_available("magic-brush"):return
		if not _feedback_available("magic-brush") and accelerated:
			# Keep the newest boosted cut visible without exceeding the ribbon cap.
			for old in items:
				if old.kind=="magic-brush":
					_release_feedback(old);old.node.queue_free();items.erase(old);break
		if not _feedback_available("magic-brush"):return
		_reserve_army_feedback("magic-brush")
		var ribbon = preload("res://assets/rogue/scripts/magic_sword_brush.gd").new()
		ribbon.name=("SamuraiSwordInkBrush" if crimson else "MagicSwordInkBrush") if legacy else "RosterSwordInkBrush"
		if legacy:ribbon.material_override.set_shader_parameter("crimson",crimson)
		else:ribbon.material_override=preload("res://assets/rogue/scripts/ink_brush_style.gd").material(tint)
		item = {}
		item.cut_index=attack.index
		_add(ribbon,life,"magic-brush",item)
		attack.magicBrush=item
		if not previous.is_empty():ribbon.sample_blades(previous)
	# A cancelled/evicted ribbon must never resurrect from a stale attack handle.
	if not is_instance_valid(item.node) or item.node.is_queued_for_deletion():return
	item.life=life
	item.sampleTime=attack.time
	item.node.material_override.set_shader_parameter("fade",1.0)
	item.node.material_override.set_shader_parameter("energy",.42 if reduced_flashes else (1.15 if attack.index==(4 if crimson else 2) else 1.0))
	item.node.sample_blades(current)

func particles(pos: Vector3, color: Color = GOLD, count: int = 12, power: float = 1.0) -> void:
	var amount: int = mini(count, [6,16,24][quality])
	if amount<=0:return
	# A piercing spell can contact hundreds of enemies in one combat step.
	# Count displayed frames: catch-up physics steps share one allocation budget.
	# Reject excess cosmetic allocations before creating meshes or spark data.
	var frame: int = Engine.get_process_frames()
	if frame!=particle_frame:
		particle_frame=frame;particle_bursts_this_frame=0
	if particle_bursts_this_frame >= [3,8,12][quality] or not _feedback_available("particle-burst"):return
	particle_bursts_this_frame+=1
	_reserve_army_feedback("particle-burst")
	_ensure_geometry()
	var batch := MultiMeshInstance3D.new()
	batch.name = "EnergySparks"
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true
	batch.multimesh.instance_count = amount
	batch.multimesh.mesh = spark_geometry
	batch.material_override = burst_material
	batch.position = pos + Vector3.UP*.8
	var sparks: Array = []
	for i in range(amount):
		var angle: float = randf()*TAU
		var size_: float = randf_range(.035,.085)*power
		var spark = {"position": Vector3.ZERO, "velocity": Vector3(sin(angle)*randf_range(2,6),randf_range(2,6),cos(angle)*randf_range(2,6))*power,
			"size": Vector3(size_,size_*.55,size_*3.5)}
		sparks.append(spark)
		batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(spark.size),Vector3.ZERO))
		batch.multimesh.set_instance_color(i,Color(color.r,color.g,color.b,.43 if reduced_flashes else 1.0))
	_add(batch,.42,"particle-burst",{"sparks":sparks,"color":color,"opacity":.43 if reduced_flashes else 1.0})

func ring(pos: Vector3, color: Color = GOLD, radius: float = 2.0, life: float = 0.4) -> Node3D:
	var frame: int = Engine.get_process_frames()
	if frame!=ring_frame:
		ring_frame=frame;rings_this_frame=0
	if rings_this_frame >= [3,8,12][quality] or not _feedback_available("ring"):return null
	rings_this_frame+=1
	_reserve_army_feedback("ring")
	var mesh: MeshInstance3D = _mesh(_ring_geometry(1, 0.045), color, 0.8)
	mesh.position = pos + Vector3(0, 0.065, 0)
	mesh.rotation.x = -PI / 2
	mesh.scale = Vector3.ONE * 0.25
	return _add(mesh, life, "ring", {"radius": radius})

func ninja_finisher(pos: Vector3,angle: float,reach: float,width: float,range_scale: float,height: float)->Node3D:
	return preload("res://scripts/ninja_finisher_effect.gd").spawn(self,pos,angle,reach,width,range_scale,height)

func slash(pos: Vector3, angle: float, combo: int = 0, color: Color = GOLD, reach: float = 3.0, options: Dictionary = {}) -> Node3D:
	var hit: int = absi(combo) % 3
	var requested_style: String = str(options.get("style", "sword"))
	var aliases: Dictionary = {"cutlass": "sword", "ninja": "dagger", "heavy": "cleave", "claymore": "magic", "twin": "dagger", "pipe": "cleave", "low-pipe": "spin", "iaijutsu": "katana"}
	var style: String = aliases.get(requested_style, requested_style)
	var presets: Dictionary = {
		"sword": {"width": 0.6, "life": 0.29, "arc": 2.25},
		"katana": {"width": 0.5, "life": 0.31, "arc": 2.05},
		"dagger": {"width": 0.4, "life": 0.21, "arc": 1.9},
		"cleave": {"width": 0.9, "life": 0.36, "arc": 2.65},
		"magic": {"width": 0.8, "life": 0.38, "arc": 2.6},
		"spin": {"width": 0.48, "life": 0.37, "arc": PI * 1.98},
	}
	var preset: Dictionary = presets.get(style, presets.sword)
	var arc: float = minf(TAU, float(options.get("arc", preset.arc + hit * 0.17)))
	var direction: float = float(options.get("direction", -1.0 if hit % 2 else 1.0))
	var tilt: float = float(options.get("tilt", 0.035 if style == "spin" else [0.12, -0.2, 0.26][hit]))
	var life: float = float(options.get("life", preset.life))
	var group: Node3D = Node3D.new()
	group.name = "AttackSlash_" + style
	group.position = pos + Vector3(0, float(options.get("height", 0.95)), 0)
	group.rotation.y = angle
	group.rotation.z = float(options.get("plane", 0.0))
	var shader_materials: Array = []
	for settings in [[reach, preset.width, 0.96, 0, 0], [reach - preset.width * 0.66, preset.width * 0.24, 0.42, 0.055, -0.025], [reach + 0.045, 0.045, 0.4, 0.015, 0.045]]:
		var material: ShaderMaterial = Ink.material(color,settings[2]*(.42 if reduced_flashes else 1.0),settings[2])
		material.set_meta("base_fade",settings[2])
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = _blade(settings[0], settings[1], arc, direction, tilt)
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position.y = settings[4]
		group.add_child(mesh)
		shader_materials.append(material)
	return _add(group, life, "slash", {"materials": shader_materials})

func thrust(pos: Vector3, angle: float, reach: float = 4.3, color: Color = Color("9eeaff"), combo: int = 0) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = "LancePressureThrust"
	group.position = pos + Vector3(0, 1.06, 0)
	group.rotation.y = angle
	var length_: float = minf(1.65, reach * 0.4)
	var tip: MeshInstance3D = _mesh(_spear(length_, 0.32, 0.2), color, 0.5)
	group.add_child(tip)
	var core: MeshInstance3D = _mesh(_spear(length_ * 0.84, 0.115, 0.065), Color("f0feff"), 0.95)
	core.position.z = length_ * 0.16
	tip.add_child(core)
	var vanes: Array = []
	for i in range(3):
		var vane: MeshInstance3D = _mesh(_spear(1, 0.22 if i == 0 else 0.105, 0.012), color, 0.18 if i == 0 else 0.32)
		vane.rotation.z = (i - 1) * PI / 3.0
		group.add_child(vane)
		vanes.append(vane)
	var collars: Array = []
	for i in range(3):
		var collar: MeshInstance3D = _mesh(_ring_geometry(0.36, 0.022, PI * 1.65, 36), color, 0.6)
		collar.rotation.z = i * 2.1 + combo * 0.6
		group.add_child(collar)
		collars.append(collar)
	return _add(group, 0.33, "thrust", {"tip": tip, "core": core, "vanes": vanes, "collars": collars, "reach": reach, "length": length_})

func weapon_impact(pos: Vector3, angle: float, style: String = "sword", color: Color = GOLD, heavy: bool = false) -> Node3D:
	var frame: int = Engine.get_process_frames()
	if frame!=impact_frame:
		impact_frame=frame;impacts_this_frame=0
	if impacts_this_frame >= [3,8,12][quality] or not _feedback_available("impact"):return null
	impacts_this_frame+=1
	_reserve_army_feedback("impact")
	var group: Node3D = Node3D.new()
	group.name = "WeaponImpact_" + style
	group.position = pos + Vector3(0, 1.0, 0)
	group.rotation.y = angle
	var strength: float = 1.35 if heavy else 1.0
	var pieces: Array = []
	var magic_ring: MeshInstance3D
	if not style.is_empty():
		var crimson: bool = style=="samurai-cut"
		var legacy: bool=style in ["claymore","wave","samurai-cut"]
		group.name=("SamuraiInkImpact" if crimson else "MagicInkImpact") if legacy else "RosterInkImpact_"+style
		for i in range(4 if quality==0 else 6):
			var core: bool = i<2
			var pigment: Color=(Color("ff2848") if crimson else Color("9852f4")) if legacy else color
			var shard_color: Color = pigment.lightened(.82) if core else pigment
			var shard = _mesh(_diamond((1.45 if core else .75)*strength,.16 if core else .09),shard_color,.9 if core else .72)
			var a: float = -.55+i*PI/3.0
			shard.rotation.z=a
			group.add_child(shard)
			pieces.append({"node":shard,"drive":0.0,"velocity":Vector3(cos(a),sin(a),.12)*(0 if core else 2.4*strength)})
		magic_ring=_mesh(_ring_geometry(1.0,.10 if style=="gold-pipe" else .055,TAU,32),(Color("ff4965") if crimson else Color("b37aff")) if legacy else color,.65)
		group.add_child(magic_ring)
		particles(pos,(Color("ff2848") if crimson else Color("ad72ff")) if legacy else color,12 if heavy else 8,.85)
	elif style in ["pierce", "arrow", "crimson-arrow", "lance", "thrust"]:
		for i in range(5):
			var shard: MeshInstance3D = _mesh(_spear((1.4 if i == 0 else 0.65) * strength, 0.12 if i == 0 else 0.045, 0.035), Color("ecfcff") if i == 0 else color, 0.85 if i == 0 else 0.5)
			var side: float = float(i - 2)
			shard.position = Vector3(side * 0.065, sin(i * 2.4) * 0.17, -0.2)
			shard.rotation = Vector3(sin(i * 2.4) * 0.1, side * 0.105, 0)
			group.add_child(shard)
			pieces.append({"node": shard, "drive": 1.4 + i * 0.25})
		particles(pos, color, 7 if heavy else 4, 0.48)
	else:
		var bash: bool = style in ["bash", "pipe", "low-pipe", "staff", "slam"]
		for i in range(5 if bash else 3):
			var mesh: MeshInstance3D = _mesh(_diamond((1.75 if i == 0 else 0.78) * strength, 0.13 if bash else (0.065 if i == 0 else 0.035)), Color("fffae8") if i == 0 else color, 0.9 if i == 0 else 0.55)
			mesh.rotation.z = i * PI / 5.0 if bash else (-0.16 if style == "iaijutsu" else -0.58) + (1.45 if i == 1 else (0.08 if i == 2 else 0.0))
			mesh.position = Vector3(0, 0.16 if i == 2 else 0.0, i * 0.015)
			group.add_child(mesh)
			pieces.append({"node": mesh, "drive": 0.0})
		particles(pos, color, 12 if heavy else 6, 0.85 if bash else 0.6)
		if bash or heavy:
			ring(pos, color, 1.65 if bash else 1.1, 0.24)
	shake = maxf(shake, 0.22 if heavy else 0.105)
	return _add(group, (0.30 if heavy else 0.24) if magic_ring!=null else (0.24 if heavy else 0.18), "impact", {"pieces": pieces,"magicRing":magic_ring,"strength":strength})

func spell_burst(pos: Vector3, angle: float = 0.0, color: Color = Color("9cbcff"), radius: float = 2.3) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = "SpellRunicBurst"
	group.position = pos + Vector3(0, 0.09, 0)
	group.rotation.y = angle
	for i in range(2):
		var circle: MeshInstance3D = _mesh(_ring_geometry(radius * (0.8 if i else 1.0), 0.024 if i else 0.045), color, 0.4 if i else 0.75)
		circle.rotation.x = -PI / 2
		group.add_child(circle)
	var crystals: Array = []
	for i in range(8):
		var a: float = float(i) / 8.0 * TAU
		var rune: MeshInstance3D = _mesh(_spear(0.48, 0.13, 0.055), color, 0.65)
		rune.rotation.y = a
		rune.position = Vector3(sin(a) * radius * 0.77, 0, cos(a) * radius * 0.77)
		group.add_child(rune)
		var shard: MeshInstance3D = _mesh(_spear(0.72, 0.08, 0.08), color if i % 2 else Color("f0eaff"), 0.6)
		shard.rotation.x = -PI / 2
		shard.position = Vector3(sin(a) * radius * 0.55, 0.1, cos(a) * radius * 0.55)
		group.add_child(shard)
		crystals.append(shard)
	return _add(group, 0.56, "spell", {"crystals": crystals, "angle": angle})

func muzzle(pos: Vector3, angle: float = 0.0, color: Color = GOLD, style: String = "gun") -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = "Muzzle_" + style
	group.position = pos + Vector3(0, 1.08, 0)
	group.rotation.y = angle
	if style == "shield":
		var vertices: PackedVector3Array = PackedVector3Array([Vector3(-0.44, 0.37, 0), Vector3(0, 0.52, 0), Vector3(0.44, 0.37, 0), Vector3(0.38, -0.16, 0), Vector3(0, -0.56, 0), Vector3(-0.38, -0.16, 0)])
		var shield: MeshInstance3D = _mesh(_array_mesh(vertices, PackedInt32Array([0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 5])), color, 0.2)
		shield.position.z = 1.05
		group.add_child(shield)
		for i in range(vertices.size()):
			var edge: MeshInstance3D = _shaft(vertices[i], vertices[(i + 1) % vertices.size()], color, 0.016)
			edge.position.z += 1.06
			group.add_child(edge)
		return _add(group, 0.26, "shield", {"origin": group.position, "angle": angle})
	var gun: bool = style == "gun"
	var spell: bool = style in ["spell", "wand"]
	var wave: bool = style == "wave"
	var light: MeshInstance3D = _mesh(_spear(0.85 if gun else (0.75 if wave else 0.6), 0.18 if gun else (0.32 if wave else 0.085), 0.07), color, 0.75 if gun else 0.4)
	light.position.z = 0.8
	group.add_child(light)
	if gun or style == "star":
		for i in range(2):
			var flare: MeshInstance3D = _mesh(_diamond(0.65 if gun else 0.34, 0.045), Color("fff4dc"), 0.8 if gun else 0.5)
			flare.rotation.z = i * PI / 2.0 + (0.0 if gun else PI / 4)
			flare.position.z = 0.98
			group.add_child(flare)
	if spell or style == "bow":
		var circle: MeshInstance3D = _mesh(_ring_geometry(0.24 if spell else 0.3, 0.02, TAU if spell else PI * 1.4, 40), color, 0.65 if spell else 0.38)
		circle.position.z = 0.95
		circle.rotation.z = PI * 0.3
		group.add_child(circle)
		if spell:
			for i in range(4):
				var a: float = i * PI / 2.0
				var petal: MeshInstance3D = _mesh(_diamond(0.18, 0.035), color, 0.6)
				petal.position = Vector3(sin(a) * 0.3, cos(a) * 0.3, 0.95)
				petal.rotation.z = -a + PI / 2
				group.add_child(petal)
	if wave:
		for side in [-1.0, 1.0]:
			var fin: MeshInstance3D = _mesh(_spear(0.8, 0.1, 0.04), color, 0.4)
			fin.position = Vector3(side * 0.42, 0, 0.45)
			fin.rotation.y = -side * 0.25
			group.add_child(fin)
	if gun:
		smoke(pos + Vector3(sin(angle), 0.3, cos(angle)), 3, Color("abbcc4"))
	return _add(group, 0.115 if gun else (0.22 if spell else 0.16), "muzzle", {"spell": spell})

func _shaft(a: Vector3, b: Vector3, color: Color, width: float = 0.04) -> MeshInstance3D:
	var length_: float = maxf(0.0001, a.distance_to(b))
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = width
	cylinder.bottom_radius = width
	cylinder.height = length_
	cylinder.radial_segments = 5
	var mesh: MeshInstance3D = _mesh(cylinder, color)
	mesh.position = (a + b) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized()) if a.distance_squared_to(b) > 0.000001 else Quaternion.IDENTITY
	return mesh

func streak(a: Vector3, b: Vector3, color: Color = Color("ffe2a8"), width: float = 0.065, life: float = 0.16) -> Node3D:
	# Trails are cosmetic; projectile movement and collision run independently.
	var frame: int = Engine.get_process_frames()
	if frame!=streak_frame:
		streak_frame=frame;streaks_this_frame=0
	if streaks_this_frame >= [8,16,24][quality] or not _feedback_available("streak"):return null
	streaks_this_frame+=1
	_reserve_army_feedback("streak")
	return _add(_shaft(a, b, color, width), life, "streak")

func ranger_trail(pr: Dictionary, start: Vector3, end: Vector3) -> void:
	# One reusable mesh/material per arrow, rather than one node per flight tick.
	if start.distance_squared_to(end) < .000001: return
	if army_trails:
		_army_ranger_trail(pr,start,end)
		return
	var life: float = .26 if pr.get("power", false) else .14
	var item: Dictionary = pr.get("rangerTrail", {})
	if item.is_empty() or not is_instance_valid(item.node) or item.node.is_queued_for_deletion():
		var mesh: MeshInstance3D = _mesh(ImmediateMesh.new(), pr.color)
		mesh.material_override.set_shader_parameter("use_vertex_alpha",true)
		item = {"points": [{"pos": start, "time": time}], "width": (.055 if pr.get("power", false) else .014) * pr.rangeScale}
		_add(mesh, life, "ranger-trail", item)
		pr.rangerTrail = item
	item.life = life
	item.points.append({"pos": end, "time": time})
	while item.points.size()>32:item.points.pop_front()
	while item.points.size() > 2 and item.points[1].time < time - life:
		item.points.pop_front()
	var geometry: ImmediateMesh = item.node.mesh
	geometry.clear_surfaces()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, item.points.size()):
		var a: Vector3 = item.points[i-1].pos
		var b: Vector3 = item.points[i].pos
		var tangent: Vector3 = (b-a).normalized()
		if tangent.length_squared() < .01: continue
		var side: Vector3 = tangent.cross(Vector3.UP).normalized()
		if side.length_squared() < .01: side = Vector3.RIGHT
		var alpha: float = clampf(1.0-(time-item.points[i].time)/life, 0.0, 1.0)
		geometry.surface_set_color(Color(1, 1, 1, alpha))
		for axis in [side, tangent.cross(side).normalized()]:
			var offset: Vector3 = axis * item.width
			var positions=[a-offset,a+offset,b+offset,a-offset,b+offset,b-offset]
			var uvs=[Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]
			for vertex in range(6):
				geometry.surface_set_uv(uvs[vertex]);geometry.surface_add_vertex(positions[vertex])
	geometry.surface_end()

static func _army_ranger_geometry() -> ArrayMesh:
	if _army_ranger_mesh!=null:return _army_ranger_mesh
	# Unit-width crossed ribbons, from local Z=0 (tail) to Z=1 (head).
	# Geometry and its alpha gradient are immutable and shared by the army.
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,0,0),Vector3(1,0,0),Vector3(1,0,1),Vector3(-1,0,1),Vector3(0,-1,0),Vector3(0,1,0),Vector3(0,1,1),Vector3(0,-1,1)])
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)])
	arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0),Color.WHITE,Color.WHITE,Color(1,1,1,0),Color(1,1,1,0),Color.WHITE,Color.WHITE])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3,4,5,6,4,6,7])
	_army_ranger_mesh=ArrayMesh.new()
	_army_ranger_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return _army_ranger_mesh

func _army_ranger_trail(pr: Dictionary,start: Vector3,end: Vector3) -> void:
	var life: float=.26 if pr.get("power",false) else .14
	var item: Dictionary=pr.get("rangerTrail",{})
	if item.is_empty() or not is_instance_valid(item.node) or item.node.is_queued_for_deletion():
		# Keep admitted tails stable when many arrows share a small army budget.
		# Ordinary impacts may still evict them through _add; new tails wait for
		# room instead of reallocating every arrow on each catch-up physics tick.
		if items.size()>=mini(MAX_EFFECTS,effect_budget):return
		var mesh: MeshInstance3D=_mesh(_army_ranger_geometry(),pr.color)
		mesh.material_override.set_shader_parameter("use_vertex_alpha",true)
		item={"distance":0.0,"width":(.055 if pr.get("power",false) else .014)*pr.rangeScale}
		_add(mesh,life,"ranger-trail",item)
		pr.rangerTrail=item
	item.life=life
	var segment: Vector3=end-start
	item.distance+=segment.length()
	if pr.get("deferPresentation",false):
		# Retain the final resolved endpoint even if the projectile retires before
		# drawing. Its existing tail still expires on the ordinary effect clock.
		item.pending_start=start;item.pending_end=end;item.pending_speed=Vector3(pr.vel).length()
		item.pending_pose=true
		if not item.get("drawn",false):item.node.hide()
		return
	_pose_army_ranger_trail(item,start,end,Vector3(pr.vel).length(),life)

func _pose_army_ranger_trail(item:Dictionary,start:Vector3,end:Vector3,speed:float,life:float)->void:
	var length_: float=minf(item.distance,speed*life)
	var direction: Vector3=(end-start).normalized()
	var basis=Basis(Quaternion(Vector3.BACK,direction))*Basis.from_scale(Vector3(item.width,item.width,length_))
	# Only the cosmetic tail approximates a curve. Native flight and collision
	# retain every physics sample and supply this post-collision endpoint.
	item.node.transform=Transform3D(basis,end-direction*length_)

func lightning(a: Vector3, b: Vector3) -> void:
	var start: Vector3 = a + Vector3.UP
	var end: Vector3 = b + Vector3.UP
	var previous: Vector3 = start
	for i in range(1, 8):
		var point: Vector3 = start.lerp(end, float(i) / 7.0)
		if i < 7:
			point += Vector3(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25), randf_range(-0.25, 0.25))
		streak(previous, point, Color("d8c5ff"), 0.038, 0.24)
		previous = point
	particles(b, Color("baa2ff"), 7, 0.65)

func smoke(pos: Vector3, count: int = 9, color: Color = Color("adbfc0")) -> void:
	_ensure_geometry()
	for i in range(mini(count, 32)):
		var mesh: MeshInstance3D = _mesh(sphere_geometry, color, 0.17, false)
		mesh.position = pos + Vector3(0, 0.8, 0)
		mesh.scale = Vector3.ONE * randf_range(0.17, 0.37)
		_add(mesh, randf_range(0.7, 1.1), "smoke", {"velocity": Vector3(randf_range(-1, 1), randf_range(0.7, 1.7), randf_range(-1, 1))})

func damage(pos: Vector3, amount, type: String = "normal") -> Node3D:
	# Keep cosmetic RNG progression identical even when army text has no room.
	var offset: float = randf_range(-0.25, 0.25)
	var drift: float = randf_range(-0.24, 0.24)
	if army_trails:
		if not _feedback_available("damage"):return null
		_reserve_army_feedback("damage")
	var label: Label3D = Label3D.new()
	label.text = str(roundi(float(amount))) if amount is float or amount is int else str(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 86 if type == "crit" else (68 if type == "player" else 58)
	label.outline_size = 10
	label.pixel_size = 0.0065
	label.modulate = {"crit": Color("ffe4a9"), "player": Color("ff8e80"), "ice": Color("b4edff"), "lightning": Color("d5bdff"), "fire": Color("ffb77a")}.get(type, Color("f6edcd"))
	label.outline_modulate = Color(0.005, 0.025, 0.035, 0.95)
	label.position = pos + Vector3(offset, 2.1, 0)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return _add(label, 0.85, "damage", {"origin": label.position, "drift": drift, "crit": type == "crit"})

func impact(pos: Vector3, heavy: bool = false, color: Color = GOLD) -> void:
	particles(pos, color, 22 if heavy else 12, 1.15 if heavy else 0.8)
	if heavy:
		ring(pos, color, 2.2, 0.27)
	shake = maxf(shake, 0.22 if heavy else 0.105)

func hurt() -> void:
	flash = 0.35
	shake = maxf(shake, 0.25)

func _arrow_pool_key(kind:String,color:Color)->Array:
	return [kind,color,reduced_flashes] if army_trails and kind in ["ranger-arrow","ranger-power-arrow","arrow","power-arrow","bow"] else []
func recycle_projectile(node:Node3D)->void:
	if node.get_meta("army_projectile_parked",false):return
	if not is_inside_tree() or is_queued_for_deletion() or not node.has_meta("army_projectile_key"):
		node.queue_free();return
	node.set_meta("army_projectile_generation",int(node.get_meta("army_projectile_generation",0))+1)
	node.set_meta("army_projectile_parked",true)
	node.hide();node.remove_from_group("rogue_projectiles")
	if idle_arrow_count>=MAX_IDLE_ARROWS:
		# A buff/palette change must be able to warm its own visuals even when
		# the previous variant filled the budget. Keep the same total bound.
		var oldest_key=idle_arrows.keys()[0]
		var oldest:Node3D=idle_arrows[oldest_key].pop_front()
		if idle_arrows[oldest_key].is_empty():idle_arrows.erase(oldest_key)
		oldest.queue_free();idle_arrow_count-=1
	if node.get_parent()!=self:node.reparent(self,false)
	node.transform=Transform3D.IDENTITY
	var key:Array=node.get_meta("army_projectile_key")
	if not idle_arrows.has(key):idle_arrows[key]=[]
	idle_arrows[key].append(node);idle_arrow_count+=1
func create_projectile(kind: String, color: Color = TEAL) -> Node3D:
	var pool_key=_arrow_pool_key(kind,color)
	if not pool_key.is_empty() and idle_arrows.has(pool_key):
		var arrow:Node3D=idle_arrows[pool_key].pop_back();idle_arrow_count-=1
		if idle_arrows[pool_key].is_empty():idle_arrows.erase(pool_key)
		remove_child(arrow);arrow.transform=Transform3D.IDENTITY;arrow.show()
		arrow.set_meta("army_projectile_parked",false)
		for ink in arrow.get_meta("ink_materials",[]):ink.set_shader_parameter("brush_clock",0.0)
		return arrow
	_ensure_geometry()
	var group: Node3D = Node3D.new()
	group.name = "Projectile_" + kind
	match kind:
		"crimson-arrow":
			var shaft = _mesh(_spear(1.8,.09,.09),color,.85)
			shaft.position.z=-1.0;group.add_child(shaft)
			var head = _mesh(_spear(.65,.22,.12),color,.95)
			head.position.z=.55;group.add_child(head)
			for side in [-1.0,1.0]:
				var fin = _mesh(_spear(.55,.12,.05),color,.55)
				fin.position=Vector3(side*.08,0,-.9);fin.rotation.y=side*-.65;group.add_child(fin)
		"ranger-arrow", "ranger-power-arrow":
			var power: bool = kind == "ranger-power-arrow"
			var shaft_geometry = CylinderMesh.new()
			shaft_geometry.top_radius = .021; shaft_geometry.bottom_radius = .021
			shaft_geometry.height = .95; shaft_geometry.radial_segments = 5
			var shaft = _mesh(shaft_geometry, color if power else Color("765331"), 1.0, power)
			shaft.rotation.x = PI / 2
			shaft.position.z = -.15
			group.add_child(shaft)
			var point = _mesh(_spear(.38, .1, .045), color if power else Color("b7c9cc"), 1.0, power)
			point.position.z = .3
			group.add_child(point)
			for side in [-1.0, 1.0]:
				var feather = _mesh(_spear(.23, .08, .012), color if power else Color("597c43"), .9, power)
				feather.position = Vector3(side * .04, 0, -.6)
				feather.rotation.y = side * -.35
				group.add_child(feather)
			if power:
				var aura = _mesh(_spear(.8, .14, .1), color, .22)
				aura.position.z = -.06
				group.add_child(aura)
		"bullet":
			# Previous shot streak radius was 0.055; visualScale=10 makes a 1.1 m round.
			var core = _mesh(sphere_geometry, Color("fff6c9"), 0.98)
			core.scale = Vector3.ONE * 0.055
			group.add_child(core)
			var shell = _mesh(sphere_geometry, Color("ffc267"), 0.25)
			shell.scale = Vector3.ONE * 0.068
			group.add_child(shell)
		"arrow", "power-arrow", "bow":
			var shaft: MeshInstance3D = _shaft(Vector3(0, 0, -0.65), Vector3(0, 0, 0.35), color, 0.025)
			group.add_child(shaft)
			var point: MeshInstance3D = _mesh(_spear(0.55, 0.115, 0.055), Color("ecfff4"), 0.9)
			point.position.z = 0.25
			group.add_child(point)
			for side in [-1.0, 1.0]:
				var feather: MeshInstance3D = _mesh(_spear(0.28, 0.1, 0.015), color, 0.8)
				feather.position = Vector3(side * 0.05, 0, -0.6)
				feather.rotation.y = side * -0.4
				group.add_child(feather)
		"star", "shuriken":
			for i in range(4):
				var blade: MeshInstance3D = _mesh(_spear(0.42, 0.12, 0.035), Color("e5d5ff"), 0.9)
				blade.rotation.y = i * PI / 2
				group.add_child(blade)
			var hub: MeshInstance3D = _mesh(_ring_geometry(0.13, 0.032, TAU, 24), color, 0.85)
			hub.rotation.x = PI / 2
			group.add_child(hub)
		"wave":
			var ink_materials: Array = []
			for layer in range(2):
				var blade = MeshInstance3D.new()
				blade.mesh=_blade(2.35 if layer==0 else 2.12,.68 if layer==0 else .36,1.95,1,0)
				blade.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var ink = ShaderMaterial.new()
				ink.shader=preload("res://assets/rogue/shaders/magic_ink_brush.gdshader")
				ink.set_shader_parameter("fade",1.0 if layer==0 else .4)
				ink.set_shader_parameter("energy",(.42 if reduced_flashes else 1.15) if layer==0 else (.24 if reduced_flashes else .5))
				blade.material_override=ink
				ink_materials.append(ink)
				# Canonical cutting edge lies in XY, centered on the projectile.
				# Release supplies its world plane from the actual sword stroke.
				blade.rotation.x=-PI/2
				var bounds: AABB=blade.mesh.get_aabb()
				blade.position=Vector3(0,-bounds.get_center().z,.04 if layer==0 else -.12)
				group.add_child(blade)
			group.set_meta("ink_materials",ink_materials)
		"fireball":
			for layer in [[0.26, 0.98], [0.39, 0.6], [0.52, 0.14]]:
				var flame = _mesh(sphere_geometry, Color("fff0b0") if layer[0] < 0.3 else Color("ff572a"), layer[1])
				flame.scale = Vector3.ONE * layer[0]
				group.add_child(flame)
			for i in range(3):
				var orbit = _mesh(_ring_geometry(0.43, 0.04, PI * 1.55, 32), Color("ffc34d"), 0.75)
				orbit.rotation = Vector3(i * 1.05, i * 0.7, i * 0.8)
				group.add_child(orbit)
		"bolt", "spell", "wand":
			var core: MeshInstance3D = _mesh(_spear(0.9, 0.19, 0.19), Color("f0eeff"), 0.95)
			core.position.z = -0.35
			group.add_child(core)
			for i in range(2):
				var orbit: MeshInstance3D = _mesh(_ring_geometry(0.29, 0.018, PI * 1.6, 24), color, 0.65)
				orbit.rotation = Vector3(i * 0.9, i * 0.4, i * PI)
				group.add_child(orbit)
		_:
			var core: MeshInstance3D = _mesh(sphere_geometry, color, 0.85)
			core.scale = Vector3.ONE * 0.16
			group.add_child(core)
			var halo: MeshInstance3D = _mesh(sphere_geometry, color, 0.15)
			halo.scale = Vector3.ONE * 0.28
			group.add_child(halo)
			var tail: MeshInstance3D = _mesh(_spear(0.8, 0.16, 0.16), color, 0.34)
			tail.rotation.y = PI
			group.add_child(tail)
	_register_ink(group)
	if not pool_key.is_empty():
		group.set_meta("army_projectile_owner",weakref(self));group.set_meta("army_projectile_key",pool_key)
		group.set_meta("army_projectile_generation",0);group.set_meta("army_projectile_parked",false)
	return group

func _register_ink(node: Node3D) -> Array:
	var inks: Array=[]
	if node is MeshInstance3D and node.material_override is ShaderMaterial and node.material_override.shader==preload("res://assets/rogue/shaders/magic_ink_brush.gdshader"):inks.append(node.material_override)
	for child in node.get_children():
		if child is Node3D:inks.append_array(_register_ink(child))
	node.set_meta("ink_materials",inks)
	return inks

func tick(dt: float) -> void:
	time += dt
	shake = maxf(0, shake - dt * 0.75)
	flash = maxf(0, flash - dt)
	for i in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[i]
		if not is_instance_valid(item.node):
			_release_feedback(item)
			items.remove_at(i)
			continue
		var node: Node3D = item.node
		if item.kind=="dragon-descent":
			var anchor=item.anchor.get_ref()
			if is_instance_valid(anchor) and not anchor.is_queued_for_deletion():
				item.life=item.max+dt;item.age+=dt
				_pose_diving_dragon(node,anchor,item.angle,item.size,item.player_facing)
			else:item.life=0.0
		if item.get("pending_pose",false):
			_pose_army_ranger_trail(item,item.pending_start,item.pending_end,item.pending_speed,item.max)
			item.pending_pose=false;item.drawn=true;node.show()
		Ink.animate(node,dt)
		# A new ribbon must reach one displayed frame before its short tail ages.
		var age_delta: float = dt
		if item.kind in ["magic-brush","ninja-finisher","dragon-eruption"] and not item.get("presented",false):
			item.presented=true;age_delta=0.0
		item.life -= age_delta
		if item.life <= 0:
			node.queue_free()
			_release_feedback(item)
			items.remove_at(i)
			continue
		var t: float = clampf(1.0 - float(item.life) / float(item.max), 0, 1)
		var remaining: float = 1.0 - t
		match str(item.kind):
			"dragon-descent":
				node.material_override.set_shader_parameter("flow_time",item.age)
			"dragon-eruption":
				node.material_override.set_shader_parameter("progress",t)
				node.rotation.y=float(item.angle)+sin(t*PI)*.4
			"magic-brush":
				node.material_override.set_shader_parameter("fade",pow(remaining,.85))
			"particle-burst":
				for j in range(item.sparks.size()):
					var spark: Dictionary = item.sparks[j]
					spark.position += spark.velocity*dt
					spark.velocity.y -= 14*dt
					var basis: Basis = Basis(Quaternion(Vector3.BACK,spark.velocity.normalized())) if spark.velocity.length_squared()>.00001 else Basis.IDENTITY
					node.multimesh.set_instance_transform(j,Transform3D(basis.scaled(spark.size*maxf(.01,remaining)),spark.position))
					var color: Color = item.color
					color.a = remaining*item.opacity
					node.multimesh.set_instance_color(j,color)
			"particle":
				node.position += item.velocity * dt
				item.velocity.y -= 14 * dt
				node.scale *= maxf(0.01, 1 - dt * 1.4)
				if item.spark and item.velocity.length_squared() > 0.00001:
					node.quaternion = Quaternion(Vector3.BACK, item.velocity.normalized())
				_fade(node, remaining)
			"ring":
				node.scale = Vector3.ONE * float(item.radius) * (0.25 + t * 0.85)
				_fade(node, remaining)
			"ninja-finisher":
				var age=float(item.max)-float(item.life)
				_fade(item.edge,1-smoothstep(.08,.38,age))
				_fade(item.area,1-smoothstep(.12,.38,age))
				_fade(item.rim,1-smoothstep(.22,.50,age))
			"crimson-slash":
				node.scale = Vector3.ONE * (0.83 + 0.17 * minf(1, t * 4))
				node.rotation.y = item.angle + (t - 0.3) * 0.12
				_fade(node, minf(1, remaining * 2.3))
			"wave-disc":
				node.scale = Vector3.ONE * item.radius * (1.0 if item.warning else (0.24 + 0.76 * (1 - pow(remaining, 2))))
				_fade(node, (0.7 + sin(t * PI) * 0.3) if item.warning else remaining)
			"nova":
				node.scale = Vector3.ONE * (0.15 + 0.85 * (1 - pow(remaining, 4)))
				_fade(node, pow(remaining, 0.7))
				node.rotation.y = t * 0.1
			"knight-shield-pulse":
				var distance=1.0+6.0*clampf((float(item.max)-float(item.life))/.18,0,1)
				node.position=item.origin+(Vector3.UP*3.3+Vector3(sin(item.angle),0,cos(item.angle))*distance)*float(item.rangeScale)
				_fade(node,minf(1,remaining*3))
			"shield-counter":
				node.position = item.origin + Vector3(sin(item.angle), 0, cos(item.angle)) * (1 - pow(remaining, 3)) * 3.8
				node.scale = Vector3.ONE * (0.8 + t * 0.65)
				_fade(node, minf(1, remaining * 2.8))
			"slash":
				for material in item.materials:
					material.set_shader_parameter("fade",float(material.get_meta("base_fade",1.0))*remaining)
				node.scale = Vector3.ONE * (0.94 + minf(t * 2.8, 1) * 0.06)
			"thrust":
				var drive: float = 1.0 - pow(1.0 - minf(t / 0.47, 1), 3)
				var front: float = 0.9 + drive * (float(item.reach) - 0.9)
				var fade: float = pow(remaining, 0.72)
				item.tip.position.z = front - float(item.length)
				item.tip.scale = Vector3(1 + t * 0.32, 1 + t * 0.32, 1)
				_fade(item.tip, fade)
				for j in range(item.vanes.size()):
					var vane: Node3D = item.vanes[j]
					vane.position.z = 0.55 + j * 0.18
					vane.scale.z = maxf(0.1, front - vane.position.z - 0.1)
					_fade(vane, fade)
				for j in range(item.collars.size()):
					var collar: Node3D = item.collars[j]
					var phase: float = clampf((t - j * 0.075) * 1.7, 0, 1)
					collar.position.z = 0.65 + phase * (float(item.reach) - 1.1)
					collar.scale = Vector3.ONE * (0.5 + phase * 1.55)
					_fade(collar, sin(phase * PI) * fade)
			"impact":
				_fade(node, pow(remaining, 0.65))
				if is_instance_valid(item.get("magicRing")):
					item.magicRing.scale=Vector3.ONE*(.25+t*1.65)*float(item.strength)
				for piece in item.pieces:
					if piece.has("velocity"):
						piece.node.position+=piece.velocity*dt
						piece.node.scale=Vector3.ONE*(1-t*.65)
					elif piece.drive > 0:
						piece.node.position.z += piece.drive * dt * 3.0
					else:
						piece.node.scale = Vector3(0.75 + t * 0.9, 1 - t * 0.7, 1)
			"spell":
				var reveal: float = minf(1, t * 6)
				node.scale = Vector3.ONE * (0.52 + (1.0 - pow(1.0 - reveal, 3)) * 0.48 + t * 0.06)
				_fade(node, remaining)
				for j in range(item.crystals.size()):
					item.crystals[j].position.y += dt * (1.25 + (j % 3) * 0.35)
					item.crystals[j].scale = Vector3.ONE * (1 - t * 0.65)
				node.rotation.y = float(item.angle) + t * 0.12
			"shield":
				node.position = item.origin + Vector3(sin(item.angle), 0, cos(item.angle)) * t * 0.7
				node.scale = Vector3.ONE * (0.9 + t * 0.6)
				_fade(node, remaining)
			"muzzle":
				_fade(node, remaining)
				node.scale = Vector3(1 - t * 0.35, 1 - t * 0.35, 0.8 + t * 0.6)
				if item.spell:
					node.rotation.z = t * 0.35
			"ranger-trail":
				# World-space vertices must retain their exact flight/contact position.
				_fade(node, remaining)
			"streak":
				_fade(node, remaining)
				node.scale.x = maxf(0.001, remaining)
				node.scale.z = maxf(0.001, remaining)
			"smoke":
				node.position += item.velocity * dt
				node.scale += Vector3.ONE * dt * 0.6
				_fade(node, remaining)
			"damage":
				node.position = item.origin + Vector3(float(item.drift) * t, 0.95 * (1.0 - pow(remaining, 2)), 0)
				var pop: float = 1.0 + sin(minf(1.0, t * 5) * PI) * (0.28 if item.crit else 0.14)
				node.scale = Vector3.ONE * pop
				node.modulate.a = minf(1, remaining * 3.2)
				node.outline_modulate.a = minf(0.95, remaining * 3.2)

func clear() -> void:
	previous_poses.clear();previous_blade.clear();previous_blade_weapon=0
	for item in items:
		if is_instance_valid(item.node):
			item.node.queue_free()
	items.clear()
	feedback_live.clear()
	impact_frame=-1;impacts_this_frame=0
	particle_frame=-1;particle_bursts_this_frame=0
	ring_frame=-1;rings_this_frame=0
	streak_frame=-1;streaks_this_frame=0
	shake = 0.0
	flash = 0.0

func charge_orb(pos: Vector3) -> Node3D:
	var orb = create_projectile("fireball", Color("ff7135"))
	orb.name = "HeldChargedFireball"
	orb.position = pos
	return _add(orb, 3600.0, "charge")

func cross_slash(pos: Vector3, angle: float, reach: float) -> void:
	for side in [-1, 1]:
		slash(pos, angle, 1, Color("ffe5b2"), reach, {"style": "katana", "arc": 1.8, "height": 1.15, "tilt": side * 0.85, "direction": side, "life": 0.35})

func lance_wave(pos: Vector3, radius: float, index: int) -> Node3D:
	_ensure_geometry()
	var group = Node3D.new()
	group.name = "LanceBlueWarning" if index < 0 else "LanceBlueShockwave"
	group.position = pos + Vector3.UP * 0.2
	var disc = _mesh(_ring_geometry(1.0, 0.96), Color("2463d5"), 0.34, false)
	disc.rotation.x = -PI / 2
	group.add_child(disc)
	for r in [1.0, 0.88]:
		var edge = _mesh(_ring_geometry(r, 0.038), Color("2779d9"), 0.9, false)
		edge.rotation.x = -PI / 2
		group.add_child(edge)
	if index >= 0:
		for i in range(16):
			var angle = i * TAU / 16
			var ray = _mesh(_spear(0.26, 0.014, 0.025), Color("bceaff"), 0.8)
			ray.position = Vector3(sin(angle), 0.012, cos(angle)) * 0.8
			ray.rotation.y = angle
			group.add_child(ray)
	group.scale = Vector3.ONE * radius * (1.0 if index < 0 else 0.24)
	return _add(group, 0.72 if index < 0 else 0.42, "wave-disc", {"radius": radius, "warning": index < 0})

func frost_nova(pos: Vector3, radius: float) -> Node3D:
	_ensure_geometry()
	var group = Node3D.new()
	group.name = "FrostNova"
	group.position = pos + Vector3.UP * 0.1
	for r in [1.0, 0.78, 0.43]:
		var edge = _mesh(_ring_geometry(radius * r, 0.065), Color("a3efff"), 0.74)
		edge.rotation.x = -PI / 2
		group.add_child(edge)
	var veil = _mesh(sphere_geometry, Color("6bc5ff"), 0.09, false)
	veil.scale = Vector3(radius, 0.5, radius)
	group.add_child(veil)
	for i in range(24):
		var angle = i * TAU / 24
		var distance = radius * (0.72 if i % 2 else 0.96)
		var crystal = _mesh(_spear(0.8 + (i % 3) * 0.22, 0.16, 0.16), Color("c0f4ff"), 0.72)
		crystal.position = Vector3(sin(angle), 0, cos(angle)) * distance
		crystal.rotation = Vector3(-PI / 2 + 0.25, angle, 0)
		group.add_child(crystal)
		var spoke = _shaft(Vector3.ZERO, Vector3(sin(angle), 0, cos(angle)) * distance, Color("549bd5"), 0.022)
		group.add_child(spoke)
	return _add(group, 0.9, "nova")

func knight_shield_pulse(pos: Vector3, angle: float, range_scale: float, index: int) -> Node3D:
	var group=Node3D.new()
	group.name="KnightShieldPulse%d"%(index+1)
	group.position=pos+(Vector3.UP*3.3+Vector3(sin(angle),0,cos(angle)))*range_scale
	group.rotation.y=angle
	group.scale=Vector3.ONE*range_scale
	var points=PackedVector3Array()
	for point in preload("res://scripts/knight_guard_counter.gd").FACE:points.append(Vector3(point.x,point.y,0))
	group.add_child(_mesh(_array_mesh(points,PackedInt32Array([0,1,2,0,2,3,0,3,4,0,4,5])),Color("19498c"),.38,false))
	for i in points.size():
		group.add_child(_shaft(points[i],points[(i+1)%points.size()],Color("77cfff"),.11))
	for pair in [[Vector3(-1.8,.6,.04),Vector3(1.8,.6,.04)],[Vector3(0,-1.7,.04),Vector3(0,2.2,.04)]]:
		group.add_child(_shaft(pair[0],pair[1],Color("e9d49b"),.13))
	return _add(group,.22,"knight-shield-pulse",{"origin":pos,"angle":angle,"rangeScale":range_scale,"index":index})

func energy_shield(pos: Vector3, angle: float, reach: float) -> Node3D:
	var group = Node3D.new()
	group.name = "NavyShieldCounter"
	group.position = pos + Vector3.UP * 1.8
	group.rotation.y = angle
	var points = PackedVector3Array([Vector3(-1.8, 1.3, 0), Vector3(0, 1.9, 0), Vector3(1.8, 1.3, 0), Vector3(1.6, -0.5, 0), Vector3(0, -1.8, 0), Vector3(-1.6, -0.5, 0)])
	var face = _mesh(_array_mesh(points, PackedInt32Array([0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 5])), Color("102957"), 0.76, false)
	face.position.z = 1.4
	group.add_child(face)
	for i in range(points.size()):
		var edge = _shaft(points[i], points[(i + 1) % points.size()], Color("548fea"), 0.06)
		edge.position.z = 1.4
		group.add_child(edge)
	for pair in [[Vector3(-0.7, 0.35, 1.42), Vector3(0.7, 0.35, 1.42)], [Vector3(0, -0.75, 1.42), Vector3(0, 1.0, 1.42)]]:
		group.add_child(_shaft(pair[0], pair[1], Color("80acff"), 0.08))
	slash(pos, angle, 2, Color("275ab1"), reach, {"style": "magic", "arc": 2.5, "height": 0.6, "tilt": 0.1})
	return _add(group, 0.46, "shield-counter", {"origin": group.position, "angle": angle})

func power_slash(pos: Vector3, angle: float, reach: float) -> Node3D:
	var group = Node3D.new()
	group.name = "CrimsonPowerSlash"
	group.position = pos + Vector3.UP * 1.1
	group.rotation.y = angle
	# A broad saturated body remains readable over bright terrain; its outer edge glows.
	for layer in [[reach, reach * 0.30, 0.15, 0.52], [reach * 0.98, reach * 0.10, -0.04, 0.38]]:
		var body = _mesh(_blade(layer[0], layer[1], 2.5, 1, layer[2]), Color("df102d"), layer[3], false)
		group.add_child(body)
	var rim = _mesh(_blade(reach + 0.04, 0.13, 2.5, 1, 0.15), Color("ff4651"), 0.8)
	group.add_child(rim)
	return _add(group, 0.56, "crimson-slash", {"angle": angle})

func _dragon_mesh(label:String,size:float,descending:bool=false)->MeshInstance3D:
	var dragon=MeshInstance3D.new();dragon.name=label
	dragon.mesh=preload("res://assets/rogue/effects/dragoon_energy_dragon.res")
	dragon.scale=Vector3.ONE*size
	dragon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var energy=ShaderMaterial.new();energy.shader=preload("res://assets/rogue/shaders/dragoon_energy.gdshader")
	energy.set_shader_parameter("intensity",.28 if reduced_flashes else .75)
	energy.set_shader_parameter("descending",descending)
	if descending:energy.set_shader_parameter("progress",.35)
	dragon.material_override=energy
	return dragon

func dragon_eruption(pos: Vector3, angle: float, size: float=1.0) -> Node3D:
	if army_trails and not _feedback_available("dragon-eruption"):return null
	_reserve_army_feedback("dragon-eruption")
	var scale_=clampf(size,.25,4.0)
	var dragon=_dragon_mesh("DragoonLandingDragon",scale_*1.7)
	dragon.position=pos+Vector3.UP*.12;dragon.rotation.y=angle
	ring(pos,Color("c5f5ff"),12.6*scale_,.32)
	shake=maxf(shake,.22)
	return _add(dragon,1.4,"dragon-eruption",{"angle":angle})

func dragon_descent(anchor:CharacterBody3D,angle:float,size:float=1.0,player_facing:bool=false)->Node3D:
	if army_trails and not _feedback_available("dragon-descent"):return null
	_reserve_army_feedback("dragon-descent")
	var scale_=clampf(size,.25,4.0)*1.15
	var dragon=_dragon_mesh("DragoonDivingDragon",scale_,true)
	_add(dragon,.35,"dragon-descent",{"anchor":weakref(anchor),"angle":angle,"size":scale_,"age":0.0,"player_facing":player_facing})
	_pose_diving_dragon(dragon,anchor,angle,scale_,player_facing)
	return dragon

func _pose_diving_dragon(dragon:Node3D,anchor:CharacterBody3D,angle:float,size:float,player_facing:bool=false)->void:
	var direction:Vector3=anchor.velocity.normalized() if anchor.velocity.length_squared()>.01 else Vector3.DOWN
	var forward=Vector3(sin(angle),0,cos(angle))
	if player_facing:
		# The mesh's +Y is head-up and +Z is muzzle-forward. Pitch its face
		# toward the landing point while keeping the jaw and horns upright.
		var pitch=clampf(atan2(maxf(0,-anchor.velocity.y),maxf(.01,anchor.velocity.dot(forward))),0,PI/6)
		var up=Vector3.UP*cos(pitch)+forward*sin(pitch)
		var muzzle=forward*cos(pitch)+Vector3.DOWN*sin(pitch)
		var player_pose=Basis(up.cross(muzzle),up,muzzle).scaled(Vector3.ONE*size)
		# Attach the body around Dragoon instead of anchoring the inverted horns.
		dragon.global_transform=Transform3D(player_pose,anchor.global_position+Vector3.UP*.6-player_pose*Vector3(0,6,-.1))
		return
	var depth=forward-direction*forward.dot(direction)
	if depth.length_squared()<.0001:depth=Vector3.UP-direction*Vector3.UP.dot(direction)
	depth=depth.normalized()
	var side=direction.cross(depth).normalized()
	var pose=Basis(side,direction,side.cross(direction)).scaled(Vector3.ONE*size)
	# Horns reach the spear tip; the curled tail streams upward behind the body.
	dragon.global_transform=Transform3D(pose,anchor.global_position+Vector3.UP*.6-pose*Vector3(0,13.8,-.1))

func finish_dragon_descent(dragon:Node3D)->void:
	for i in range(items.size()-1,-1,-1):
		if items[i].node==dragon:
			_release_feedback(items[i]);items.remove_at(i);break
	if is_instance_valid(dragon):dragon.queue_free()

func dive_slash(pos: Vector3, angle: float, reach: float, impact: bool) -> Node3D:
	var group = Node3D.new()
	group.name = "MoonbladeDiveImpact" if impact else "MoonbladeDiveTrail"
	group.position = pos + Vector3.UP * (0.3 if impact else 1.0)
	group.rotation.y = angle
	for layer in [[reach, reach * 0.28, 0.64], [reach * 0.98, 0.12, 0.94]]:
		var blade = _mesh(_blade(layer[0], layer[1], 2.5 if impact else 1.4, 1, 0.08), Color("6334c1") if layer[1] > 0.2 else Color("eee0ff"), layer[2], layer[1] <= 0.2)
		blade.rotation.x = 0.05 if impact else -0.8
		group.add_child(blade)
	if impact:
		ring(pos, Color("bc92ff"), reach, 0.5)
		particles(pos + Vector3.UP * 0.4, Color("e7caff"), 32, 2.2)
		shake = maxf(shake, 0.3)
	return _add(group, 0.55 if impact else 0.22, "dive-impact" if impact else "dive-trail")
