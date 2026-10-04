class_name EnemyCrowd
extends Node3D
# Four textured rigid-part batches; ordinary actors never instantiate skeletons.
# Guardians retain their authored rig. Combat/collision remain in Ninja.
const VIEW_DISTANCE=110.0
const ASSET_IDS=["masked_foot_soldier","straw_hat_bandit","daruma_bruiser","lantern_yokai"]
var game: Node
var batches: Array[MultiMeshInstance3D]=[]
# Compatibility handle for existing diagnostic scripts (first species only).
var batch: MultiMeshInstance3D
var materials: Array[ShaderMaterial]=[]
var age=0.0

func _ready():
	process_priority=40
	var shader=load("res://assets/materials/original_enemy_crowd.gdshader")
	for kind in range(ASSET_IDS.size()):
		var source=GameAssets.instantiate_model("enemies/original_set/"+ASSET_IDS[kind])
		var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		append_parts(source,Transform3D.IDENTITY,surface)
		var instance=MultiMeshInstance3D.new();instance.multimesh=MultiMesh.new()
		instance.name=ASSET_IDS[kind]+"_batch"
		instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		instance.multimesh.use_custom_data=true
		instance.multimesh.mesh=surface.commit()
		instance.multimesh.instance_count=64;instance.multimesh.visible_instance_count=0
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material=ShaderMaterial.new();material.shader=shader
		material.set_shader_parameter("atlas",load("res://assets/textures/enemies/original_set/enemy_atlas.png"))
		material.set_shader_parameter("species",kind)
		instance.material_override=material
		materials.append(material);batches.append(instance);add_child(instance);source.free()
	batch=batches[0]

# Merge the rigid named export groups once, retaining texture UV and encoding
# the animation group in UV2. No per-actor scene tree or duplicate mesh resource.
func append_parts(node: Node, parent_transform: Transform3D, surface: SurfaceTool):
	var transform=parent_transform
	if node is Node3D:transform=parent_transform*node.transform
	if node is MeshInstance3D:
		var limb=0
		for part in ["Leg_L","Leg_R","Arm_L","Arm_R"]:
			if str(node.name).begins_with(part):limb=["Leg_L","Leg_R","Arm_L","Arm_R"].find(part)+1
		for slot in range(node.mesh.get_surface_count()):
			var arrays=node.mesh.surface_get_arrays(slot)
			var vertices=arrays[Mesh.ARRAY_VERTEX]
			var normals=arrays[Mesh.ARRAY_NORMAL]
			var uvs=arrays[Mesh.ARRAY_TEX_UV]
			var indices=arrays[Mesh.ARRAY_INDEX]
			var count=indices.size() if indices!=null and indices.size()>0 else vertices.size()
			for corner in range(count):
				var index=indices[corner] if indices!=null and indices.size()>0 else corner
				surface.set_normal((transform.basis.inverse().transposed()*normals[index]).normalized())
				surface.set_uv(uvs[index]);surface.set_uv2(Vector2(float(limb)/8.0,0))
				surface.add_vertex(transform*vertices[index])
	for child in node.get_children():append_parts(child,transform,surface)

func clear():
	for instance in batches:instance.multimesh.visible_instance_count=0

func _process(delta):
	if not game.playing or game.paused or game.transitioning:return
	age+=delta
	for material in materials:material.set_shader_parameter("clock",age)
	var counts=[0,0,0,0];var needed=[0,0,0,0]
	var focus=game.player.global_position
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.boss:needed[visual_species(enemy)]+=1
	# Allocate before writing; reallocating a MultiMesh clears its transforms.
	for kind in range(batches.size()):
		if needed[kind]>batches[kind].multimesh.instance_count:
			batches[kind].multimesh.instance_count=nearest_po2(needed[kind])
	for enemy in game.enemies:
		if not is_instance_valid(enemy):continue
		var distance=enemy.global_position.distance_squared_to(focus)
		var view_distance=360.0 if game.tower_defense_mode else (260.0 if enemy.ground_giant else VIEW_DISTANCE)
		var shown=distance<view_distance*view_distance or enemy.practice
		enemy.render_full=enemy.boss
		enemy.distance_asleep=not shown;enemy.visible=shown;enemy.model.visible=shown and enemy.boss
		if enemy.name_tag!=null:enemy.name_tag.visible=shown and distance<18*18
		if not shown or enemy.boss:continue
		var kind=visual_species(enemy)
		var transform=visual_transform(enemy)
		batches[kind].multimesh.set_instance_transform(counts[kind],transform)
		batches[kind].multimesh.set_instance_custom_data(counts[kind],actor_data(enemy))
		counts[kind]+=1
	for kind in range(batches.size()):batches[kind].multimesh.visible_instance_count=counts[kind]

func actor_data(enemy: Ninja)->Color:
	var motion=clampf(Vector2(enemy.velocity.x,enemy.velocity.z).length()/7.0,0,1)
	var attack=0.0
	if enemy.state=="windup":attack=.65
	elif enemy.state=="strike":attack=-clampf(enemy.timer/.3,0,1)
	if enemy.dead:motion=0;attack=0
	return Color(float(enemy.get_instance_id()%100)*.13,motion,attack,1 if enemy.frozen_left>0 else 0)

func visual_species(enemy: Ninja)->int:
	# Survival keeps its existing three combat archetypes. Alternate standard
	# melee appearances so the fourth design does not introduce ranged attacks.
	if enemy.swarm and enemy.variant==0 and enemy.formation_index%2==1:return 3
	return enemy.variant

func visual_transform(enemy: Ninja)->Transform3D:
	var transform=enemy.global_transform
	transform.basis=transform.basis*enemy.model.basis
	if not enemy.dead and enemy.frozen_left<=0:
		var response=exp(-enemy.recoil_age*10)*cos(enemy.recoil_age*15)*enemy.recoil_strength
		var recoil=Vector3(enemy.recoil_direction.z*response,enemy.recoil_direction.x*response*.45,-enemy.recoil_direction.x*response)
		transform.basis=transform.basis*Basis.from_euler(recoil)
	return transform
