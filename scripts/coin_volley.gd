extends GoldCoin
# One controller and a few instanced meshes per volley, including at level 99.
# Coins still sweep independently; nearby candidates and hit feedback are shared.
static var mesh_parts: Array=[]
static var original_mesh_parts:Array=[]
var visual_parts:Array=[]
var points=PackedVector3Array()
var velocities=PackedVector3Array()
var alive=PackedByteArray()
var contacts: Array[Dictionary]=[]
var batches: Array[MultiMeshInstance3D]=[]
var age=0.0
var wake_batch: MultiMeshInstance3D
var active_count=0
var ray_query: PhysicsRayQueryParameters3D

static func cache_parts(node: Node,accumulated: Transform3D):
	var pose=accumulated*node.transform if node is Node3D else accumulated
	if node is MeshInstance3D:
		mesh_parts.append({"mesh":node.mesh,"transform":pose,"material":node.material_override})
	for child in node.get_children():cache_parts(child,pose)

func _ready():
	add_to_group("projectiles");add_to_group("coin_volleys")
	process_mode=Node.PROCESS_MODE_PAUSABLE
	if mesh_parts.is_empty():
		var model=GameAssets.instantiate_model("weapons/koban")
		cache_parts(model,Transform3D.IDENTITY);model.free()
	visual_parts=mesh_parts
	if get_meta("original_goemon_coin",false):
		if original_mesh_parts.is_empty():
			var original=preload("res://scripts/recovered_goemon_weapons.gd").create_coin()
			var part=original.get_child(0) as MeshInstance3D
			original_mesh_parts.append({"mesh":part.mesh,"transform":part.transform,"material":part.material_override});original.free()
		visual_parts=original_mesh_parts
	points.resize(coin_count);velocities.resize(coin_count);alive.resize(coin_count);alive.fill(1)
	active_count=coin_count
	var spacing=minf(.065,.45/maxf(1,ceilf((coin_count-1)*.5)))
	for i in range(coin_count):
		# The central coin always retains exact auto aim, then pairs fan outward.
		var angle=0.0 if i==0 else ceilf(i*.5)*spacing*(1 if i%2 else -1)
		velocities[i]=velocity.rotated(Vector3.UP,angle)
		contacts.append({})
	for part in visual_parts:
		var batch=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new()
		batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh=part.mesh;batch.material_override=part.material
		batch.multimesh.instance_count=coin_count;batch.multimesh.visible_instance_count=coin_count
		batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch);batches.append(batch)
	if game.camera_combat():
		wake_batch=MultiMeshInstance3D.new();wake_batch.name="PaintedCoinWakes"
		wake_batch.multimesh=MultiMesh.new();wake_batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		wake_batch.multimesh.mesh=preload("res://assets/rogue/scripts/ink_brush_style.gd").wake_mesh()
		wake_batch.material_override=preload("res://assets/rogue/scripts/ink_brush_style.gd").material(Color("ffd487"),.6,.65)
		wake_batch.multimesh.instance_count=mini(coin_count,[16,32,64][clampi(int(game.settings.quality),0,2)])
		wake_batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(wake_batch)
		set_meta("ink_materials",[wake_batch.material_override])
	ray_query=PhysicsRayQueryParameters3D.new();ray_query.collision_mask=1;ray_query.hit_from_inside=true
	update_batch()

func cast_ray(from: Vector3,to: Vector3)->Dictionary:
	ray_query.from=from;ray_query.to=to
	return get_world_3d().direct_space_state.intersect_ray(ray_query)

func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning:return
	lifetime-=delta;age+=delta
	if is_instance_valid(wake_batch):preload("res://assets/rogue/scripts/ink_brush_style.gd").animate(self,delta)
	if lifetime<=0:queue_free();return
	var origin=global_position
	var sweep=AABB();var initialized=false
	for i in range(coin_count):
		if not alive[i]:continue
		var start=origin+points[i];var finish=start+velocities[i]*delta
		if not initialized:sweep=AABB(start,Vector3.ZERO);initialized=true
		sweep=sweep.expand(start).expand(finish)
	if not initialized:queue_free();return
	# A single broad-phase pass avoids scanning the whole crowd for each coin.
	var candidates=[]
	for victim in game.enemies:
		if not is_instance_valid(victim) or victim.dead:continue
		var aim=AttackChain.aim_point(victim)
		if (victim.has_method("combat_bounds") and sweep.grow(hit_radius).intersects(victim.combat_bounds())) or sweep.grow(hit_radius+victim.body_radius).has_point(aim):
			candidates.append({"enemy":victim,"point":aim,"radius":hit_radius+victim.body_radius,"id":victim.get_instance_id()})
	var enemy_hits={};var building_hits={}
	for i in range(coin_count):
		if not alive[i]:continue
		var start=origin+points[i];var next=start+velocities[i]*delta
		var wall=cast_ray(start,next)
		var finish=next if wall.is_empty() else wall.position
		var closest=INF;var chosen=null;var contact=Vector3.ZERO
		for candidate in candidates:
			if contacts[i].has(candidate.id):continue
			var hit_contact=AttackChain.segment_contact(candidate.enemy,start,finish,hit_radius)
			if hit_contact.is_empty():continue
			var nearest: Vector3=hit_contact.point
			var hurt=AttackChain.aim_point(candidate.enemy,nearest)
			if not cast_ray(nearest,hurt).is_empty():continue
			if piercing:
				contacts[i][candidate.id]=true
				add_hit(enemy_hits,candidate.enemy,nearest,velocities[i])
			else:
				var distance=start.distance_squared_to(nearest)
				if distance<closest:closest=distance;chosen=candidate.enemy;contact=nearest
		if chosen!=null:
			add_hit(enemy_hits,chosen,contact,velocities[i]);alive[i]=0;active_count-=1
		elif not wall.is_empty():
			var building=BreakableBuilding.from_collider(wall.collider)
			if building!=null:add_hit(building_hits,building,finish,velocities[i])
			alive[i]=0;active_count-=1
		points[i]=next-origin
	# Same-frame coin damage is summed per victim, preserving the total damage
	# while avoiding a damage label, sound and recoil update for every coin.
	for victim in enemy_hits:
		var hit=enemy_hits[victim]
		victim.take_hit(damage*hit.count,hit.direction,heavy,attack_ticket)
		if get_meta("original_goemon_coin",false):game.confirm_impact(victim,hit.point,hit.direction,2 if heavy else 0,true,1)
		else:game.confirm_impact(victim,hit.point,hit.direction,2 if heavy else 0,true)
		game.chain+=hit.count;game.chain_timer=3
	for building in building_hits:
		var hit=building_hits[building]
		building.take_hit(damage*hit.count,attack_ticket,hit.point)
	if not building_hits.is_empty():game.sound("environment_hit",.35)
	if active_count<=0:queue_free();return
	update_batch()

func add_hit(hits: Dictionary,victim: Node,point: Vector3,heading: Vector3):
	if hits.has(victim):hits[victim].count+=1
	else:hits[victim]={"count":1,"point":point,"direction":heading.normalized()}

func update_batch():
	var index=0
	for i in range(coin_count):
		if not alive[i]:continue
		var spin=Basis(Vector3.UP,age*8)*Basis(Vector3.BACK,age*24+i*.37)
		var pose=Transform3D(spin.scaled(Vector3.ONE*visual_size),points[i])
		for part in range(batches.size()):batches[part].multimesh.set_instance_transform(index,pose*visual_parts[part].transform)
		if is_instance_valid(wake_batch) and index<wake_batch.multimesh.instance_count:
			var basis=Basis(Quaternion(Vector3.FORWARD,velocities[i].normalized()))
			wake_batch.multimesh.set_instance_transform(index,Transform3D(basis.scaled(Vector3.ONE*visual_size),points[i]))
		index+=1
	for batch in batches:batch.multimesh.visible_instance_count=index

	if is_instance_valid(wake_batch):wake_batch.multimesh.visible_instance_count=mini(index,wake_batch.multimesh.instance_count)
