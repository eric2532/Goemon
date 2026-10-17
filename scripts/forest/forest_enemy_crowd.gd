class_name ForestEnemyCrowd
extends Node3D
# Approved source assets are merged once, retaining their material surfaces.
# Per-instance rigid transforms also drive Forest combat contact queries.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const PATHS=Roles.PATHS
const HEIGHTS=Roles.HEIGHTS
const GROUPS=["body","foot_l","foot_r","fist_l","fist_r","arm_l","arm_r"]
const POSE_WIDTH=43 # Affine transforms (0–20), frozen tint (21), normal bases (22–42).
const CROWD_TEXTURE_LIMIT=1024
const POSE_KEYS=["pos","facing","velocity","walk_phase","attack_progress","action","attack_point","pose_motion","frozen","frozen_pose","walk_feet","hit_recoil","hit_direction","hit_heavy"]
var game: Node
var low_fidelity=true
var primitive_batches: Array=[]
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const PROXY_COLORS=[Color("d98470"),Color("82b497"),Color("dbaf61"),Color("b591d2")]
var batches: Array[MultiMeshInstance3D]=[]
var materials: Array[ShaderMaterial]=[]
var species_materials: Array=[]
var pose_textures: Array[ImageTexture]=[]
var pose_images: Array[Image]=[]
var _poses: Dictionary={}
var _death_age: Dictionary={}
var _row_poses: Array=[[],[],[],[]]
var _local_bounds: Array[AABB]=[]
var _artwork_cache: Dictionary={}

func _ready():
	process_priority=40
	if low_fidelity:
		_ready_primitives();return
	var shader=load("res://assets/materials/forest_enemy_crowd.gdshader")
	for kind in range(4):
		var source: Node3D=load(PATHS[kind]).instantiate()
		var by_material: Dictionary={}
		_append_parts(source,Transform3D.IDENTITY,by_material,kind)
		var merged=ArrayMesh.new();var kind_materials: Array[ShaderMaterial]=[]
		for original in by_material:
			var arrays=by_material[original]
			merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var material=_animated_material(original,shader)
			merged.surface_set_material(merged.get_surface_count()-1,material)
			kind_materials.append(material);materials.append(material)
		var instance=MultiMeshInstance3D.new();instance.name="forest_enemy_%d_batch"%kind
		instance.multimesh=MultiMesh.new();instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		instance.multimesh.use_custom_data=true;instance.multimesh.mesh=merged
		instance.multimesh.instance_count=32;instance.multimesh.visible_instance_count=0
		# Include the massive fist's animated reach in the instance culling bounds.
		var bounds=merged.get_aabb();instance.multimesh.custom_aabb=bounds.grow(HEIGHTS[kind]*.7)
		_local_bounds.append(bounds.grow(HEIGHTS[kind]*.7))
		# Ordinary crowds avoid repeating their detailed mesh in every shadow cascade.
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind==2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var image=Image.create(POSE_WIDTH,32,false,Image.FORMAT_RGBAF)
		var texture=ImageTexture.create_from_image(image);pose_textures.append(texture);pose_images.append(image)
		for material in kind_materials:material.set_shader_parameter("pose_texture",texture)
		species_materials.append(kind_materials);batches.append(instance);add_child(instance);source.free()

func _animated_material(source: StandardMaterial3D,shader: Shader)->ShaderMaterial:
	var material=ShaderMaterial.new();material.shader=shader
	material.resource_name=source.resource_name
	material.set_shader_parameter("albedo_color",source.albedo_color)
	material.set_shader_parameter("has_albedo_texture",source.albedo_texture!=null)
	if source.albedo_texture!=null:material.set_shader_parameter("albedo_texture",_crowd_artwork(source.albedo_texture))
	material.set_shader_parameter("roughness",source.roughness)
	material.set_shader_parameter("metallic",source.metallic)
	material.set_shader_parameter("emission_color",source.emission if source.emission_enabled else Color.BLACK)
	material.set_shader_parameter("emission_energy",source.emission_energy_multiplier)
	if source.emission_texture!=null:
		material.set_shader_parameter("has_emission_texture",true)
		material.set_shader_parameter("emission_texture",_crowd_artwork(source.emission_texture))
	return material

# This cache belongs only to the enemy renderer: portraits, hero and UI retain
# their source textures. Resize once during scene preparation, retaining mipmaps.
func _crowd_artwork(source: Texture2D)->Texture2D:
	var key=source.get_instance_id()
	if _artwork_cache.has(key):return _artwork_cache[key]
	var result=source
	var longest=maxi(source.get_width(),source.get_height())
	if longest>CROWD_TEXTURE_LIMIT:
		var image=source.get_image()
		if image.is_compressed():image.decompress()
		var ratio=float(CROWD_TEXTURE_LIMIT)/longest
		image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		result=ImageTexture.create_from_image(image)
	_artwork_cache[key]=result
	return result

func _append_parts(node: Node,parent: Transform3D,by_material: Dictionary,kind: int):
	var transform=parent
	if node is Node3D:transform=parent*node.transform
	if node is MeshInstance3D:
		var center=transform*node.mesh.get_aabb().get_center()
		var group=_part_group(str(node.name),center,kind)
		for slot in range(node.mesh.get_surface_count()):
			var original=node.get_active_material(slot)
			if not by_material.has(original):
				var blank=[];blank.resize(Mesh.ARRAY_MAX)
				blank[Mesh.ARRAY_VERTEX]=PackedVector3Array();blank[Mesh.ARRAY_NORMAL]=PackedVector3Array()
				blank[Mesh.ARRAY_TEX_UV]=PackedVector2Array();blank[Mesh.ARRAY_TEX_UV2]=PackedVector2Array();blank[Mesh.ARRAY_INDEX]=PackedInt32Array()
				by_material[original]=blank
			var destination: Array=by_material[original];var arrays=node.mesh.surface_get_arrays(slot)
			var offset=destination[Mesh.ARRAY_VERTEX].size()
			var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uvs=arrays[Mesh.ARRAY_TEX_UV]
			var normal_basis=transform.basis.inverse().transposed()
			for index in range(vertices.size()):
				destination[Mesh.ARRAY_VERTEX].append(transform*vertices[index])
				destination[Mesh.ARRAY_NORMAL].append((normal_basis*normals[index]).normalized())
				destination[Mesh.ARRAY_TEX_UV].append(uvs[index] if uvs!=null else Vector2.ZERO)
				destination[Mesh.ARRAY_TEX_UV2].append(Vector2(group,0))
			var indices=arrays[Mesh.ARRAY_INDEX]
			if indices!=null and not indices.is_empty():
				for index in indices:destination[Mesh.ARRAY_INDEX].append(offset+index)
			else:
				for index in range(vertices.size()):destination[Mesh.ARRAY_INDEX].append(offset+index)
	for child in node.get_children():_append_parts(child,transform,by_material,kind)

static func _part_group(part: String,center: Vector3,kind: int)->int:
	var label=part.to_lower();var left=center.x<0
	if kind==2:
		if label.begins_with("foot_") or label.begins_with("ankle_"):return 1 if left else 2
		if label.begins_with("fist_") or label.begins_with("wrist_"):return 3 if left else 4
		if label.begins_with("arm_"):return 5 if left else 6
		return 0
	if kind==3:return 1 if label.begins_with("leg_") else 0
	for token in ["foot","toe","sandal","shin","trouser","ankle","leg linen"]:
		if token in label:return 1 if left else 2
	for token in ["forearm","finger","thumb","glove","hand","club","bow","upper arm","elbow","wrist","short sleeve","padded shoulder"]:
		if token in label:return 3 if left else 4
	return 0

# Local Z offsets compensate root movement throughout the stance half-cycle.
# The swing returns the foot smoothly and lifts it; no global TIME is involved.
static func walking_foot_offset(phase: float,stride: float,lift: float)->Vector3:
	var cycle=fposmod(phase,TAU)/TAU
	if cycle<.5:return Vector3(0,0,(cycle-.25)*stride)
	var swing=(cycle-.5)*2.0;var eased=swing*swing*(3.0-2.0*swing)
	return Vector3(0,sin(swing*PI)*lift,(.25-.5*eased)*stride)

# The director retains these poses once a fixed-facing retreat begins. A stance
# is a world anchor, rather than an offset in the latest velocity direction:
# replacing that direction at an escape waypoint would move a planted foot.
# Replace both dictionaries every update so shallow frozen snapshots stay valid.
static func advance_walk_feet(data: Dictionary,old_root: Transform3D,old_phase: float,old_parts: Dictionary,delta: float):
	var root=Transform3D(Basis(Vector3.UP,float(data.facing)),data.pos)
	var advance=fposmod(float(data.walk_phase)-old_phase,TAU)
	var displacement=root.origin-old_root.origin
	var direction=displacement.normalized() if not displacement.is_zero_approx() else root.basis*Vector3.FORWARD
	var stride=float(Roles.DATA[int(data.variant)].stride)
	var states: Dictionary=data.get("walk_foot_state",{}).duplicate(true)
	var parts: Dictionary={}
	for group in ["foot_l","foot_r"]:
		var phase=fposmod(old_phase+(PI if group=="foot_r" else 0),TAU)
		var state: Dictionary=states.get(group,{"pose":old_root*old_parts[group]})
		var left=advance;var consumed=0.0
		if advance<.000001:
			# A stopped swing settles vertically; a grounded foot keeps its anchor.
			state.pose.origin.y=move_toward(state.pose.origin.y,root.origin.y,delta*1.4)
			state.erase("swing_to")
		while left>.000001:
			var boundary=PI if phase<PI-.000001 else TAU
			var amount=minf(left,boundary-phase)
			if boundary==TAU:
				if not state.has("swing_to"):
					state.swing_from=state.pose;state.swing_phase=phase
					var at_start=old_root.interpolate_with(root,consumed/advance)
					var until_landing=(TAU-phase)*stride/TAU
					state.swing_to=Transform3D(at_start.basis,at_start.origin+direction*(until_landing+stride*.25))
				var t=clampf((phase+amount-state.swing_phase)/(TAU-state.swing_phase),0,1)
				var eased=t*t*(3-2*t)
				state.pose=state.swing_from.interpolate_with(state.swing_to,eased)
				state.pose.origin.y=lerpf(state.swing_from.origin.y,state.swing_to.origin.y,t)+sin(t*PI)*.7
			phase+=amount;consumed+=amount;left-=amount
			if phase>=TAU-.000001:
				phase=0.0;state.pose=state.swing_to;state.erase("swing_to")
			elif phase>=PI-.000001 and boundary==PI:
				phase=PI;state.erase("swing_to")
		states[group]=state
		parts[group]=root.affine_inverse()*state.pose
	data.walk_foot_state=states;data.walk_feet=parts

static func _fist_contact(kind: int,left: bool)->Vector3:
	if kind==2:return Vector3(-10.637 if left else 10.637,6.0,-4.20)
	if kind==0:return Vector3(-1.05 if left else 1.05,2.0,-.75)
	return Vector3(-1.0 if left else 1.0,1.6,-.5)

static func part_pose(group: String,data: Dictionary)->Transform3D:
	if data.get("frozen",0.0)>0 and data.has("frozen_pose"):data=data.frozen_pose
	if group in ["foot_l","foot_r"] and data.get("walk_feet",{}).has(group):return data.walk_feet[group]
	var kind=clampi(int(data.get("variant",0)),0,3)
	var phase=float(data.get("walk_phase",0.0))
	var progress=float(data.get("attack_progress",0.0))
	var action=str(data.get("action","walk"))
	var moving=1.0 if absf(phase)>.00001 else 0.0
	if data.has("velocity"):
		var velocity: Vector3=data.velocity
		moving=clampf(Vector2(velocity.x,velocity.z).length()/float(Roles.DATA[kind].speed),0,1)
	var motion=float(data.get("pose_motion",moving))
	var recoil=float(data.get("hit_recoil",0.0))
	if recoil>0:motion=0.0
	if action=="windup":motion*=1.0-smoothstep(0.0,.2,maxf(0,progress))
	elif action=="recover":motion=0.0
	var pose=Transform3D.IDENTITY
	var giant=kind==2
	if group=="foot_l" or group=="foot_r":
		var offset_phase=phase+(PI if group=="foot_r" else 0)
		pose.origin=walking_foot_offset(offset_phase,float(Roles.DATA[kind].stride),.7 if giant else (.6 if kind==3 else .26))*motion
		return pose
	if recoil>0 and not giant:
		# Tilt the body and carried weapon around the hips while the feet stay
		# grounded. Contact queries consume this exact same rigid transform.
		var direction: Vector3=Basis(Vector3.UP,float(data.get("facing",0))).inverse()*Vector3(data.get("hit_direction",Vector3.BACK))
		var axis=Vector3.UP.cross(direction)
		if axis.length_squared()>.001:
			var age=maxf(0,.28-recoil)
			var weight=sin(minf(1,age/.045)*PI*.5)*clampf(recoil/.28,0,1)
			var pivot=Vector3(0,HEIGHTS[kind]*.35,0)
			var basis=Basis(axis.normalized(),weight*(.27 if data.get("hit_heavy",false) else .18))
			return Transform3D(basis,pivot-basis*pivot+direction*weight*.08)
	var rock=sin(phase)*(.022 if giant else .018)*motion
	var pivot=Vector3(0,HEIGHTS[kind]*.35,0)
	pose.basis=Basis(Vector3.FORWARD,rock)
	pose.origin=pivot-pose.basis*pivot+Vector3(0,absf(sin(phase))*HEIGHTS[kind]*.003*motion,0)
	if kind==3:
		pose.origin.y+=absf(sin(phase))*.2*motion
		return pose
	if group=="body":return pose
	var left=group.ends_with("_l")
	var shoulder=Vector3((-8.5 if left else 8.5) if giant else (-.72 if left else .72),12.0 if giant else HEIGHTS[kind]*.59,0)
	var swing=-sin(phase+(0 if left else PI))*(.06 if giant else .24)*motion
	var rotation=Basis(Vector3.RIGHT,swing)
	var arm_pose=Transform3D(rotation,shoulder-rotation*shoulder)
	if kind==1 and absf(progress)>.00001:
		# Ranged contact remains at the worker; the hands draw the local bowstring.
		var draw=smoothstep(0,1,absf(progress))
		return Transform3D(Basis.IDENTITY,Vector3(.18,.75,-.75)*draw if left else Vector3(-1.3,.8,-.15)*draw)
	if not left and absf(progress)>.00001 and data.has("attack_point"):
		# Lift/retract through most of the windup, then drive to exact visible contact.
		var contact=_fist_contact(kind,false)
		var wind=clampf(progress,0,1)
		var extension=smoothstep(.62,1.0,wind) if progress>=0 else smoothstep(0,1,clampf(-progress,0,1))
		var local_target=Basis(Vector3.UP,float(data.get("facing",0))).inverse()*(Vector3(data.attack_point)-Vector3(data.get("pos",Vector3.ZERO)))
		var lift=sin(wind*PI)*(.9 if giant else .35)
		var delta=(local_target-contact)*extension+Vector3(0,lift,(1.0-extension)*sin(wind*PI)*(.7 if giant else .15))
		# Preserve painted fist geometry; only the short connecting arm extends.
		if group=="arm_r" and giant:
			var rest=contact-shoulder;var next=rest+delta
			var align=Basis(Quaternion(rest.normalized(),next.normalized()))
			var axis=rest.normalized();var stretch=next.length()/rest.length()
			var scale_along=Basis.IDENTITY
			scale_along.x+=axis*axis.x*(stretch-1);scale_along.y+=axis*axis.y*(stretch-1);scale_along.z+=axis*axis.z*(stretch-1)
			var basis=align*scale_along
			return Transform3D(basis,shoulder-basis*shoulder)
		arm_pose=Transform3D(Basis.IDENTITY,delta)
		return arm_pose
	return pose*arm_pose

func clear():
	for instance in batches:instance.multimesh.visible_instance_count=0
	for slots in primitive_batches:
		for slot in slots:slot.batch.multimesh.visible_instance_count=0
	_poses.clear();_death_age.clear();_row_poses=[[],[],[],[]]

func _pose_matches(cached: Dictionary,data: Dictionary,kind: int)->bool:
	if cached.get("variant",-1)!=kind:return false
	for key in POSE_KEYS:
		if key=="frozen":
			if (float(cached.get(key,0))>0)!=(float(data.get(key,0))>0):return false
			continue
		if cached.has(key)!=data.has(key) or cached.get(key)!=data.get(key):return false
	return true

func _snapshot_pose(data: Dictionary,kind: int)->Dictionary:
	var cached={"variant":kind}
	for key in POSE_KEYS:
		if data.has(key):cached[key]=data[key]
	return cached

func _process(delta):
	if game==null or not game.playing or game.paused or game.transitioning:return
	if low_fidelity:
		_process_primitives(delta);return
	var visible: Array=[[],[],[],[]]
	var live_ids: Dictionary={}
	for enemy in game.enemies:
		if not is_instance_valid(enemy):continue
		# Shared combat effects can temporarily add ordinary Ninja actors.
		var id=enemy.get("forest_id")
		if id==null:continue
		live_ids[id]=true
		var shown=game.forest_enemy_visible(enemy)
		enemy.distance_asleep=not shown;enemy.visible=shown;enemy.render_full=false
		if is_instance_valid(enemy.model):enemy.model.visible=false
		if enemy.name_tag!=null:enemy.name_tag.visible=false
		if not shown:continue
		var kind=clampi(enemy.variant,0,3)
		var data: Dictionary=game.model.enemies.get(id,{})
		if not enemy.dead or not _poses.has(id):
			if not _poses.has(id) or not _pose_matches(_poses[id],data,kind):
				_poses[id]=_snapshot_pose(data,kind)
		if enemy.dead:_death_age[id]=float(_death_age.get(id,0))+delta
		visible[kind].append({"actor":enemy,"data":_poses[id],"frozen":float(data.get("frozen",0))>0,"death":float(_death_age.get(id,0))})
	for id in _poses.keys():
		if not live_ids.has(id):_poses.erase(id);_death_age.erase(id)
	for kind in range(4):
		var multimesh=batches[kind].multimesh
		if visible[kind].size()>multimesh.instance_count:
			multimesh.instance_count=nearest_po2(visible[kind].size())
			pose_images[kind]=Image.create(POSE_WIDTH,multimesh.instance_count,false,Image.FORMAT_RGBAF)
			pose_textures[kind].set_image(pose_images[kind])
			_row_poses[kind].clear()
		var image=pose_images[kind]
		var rows: Array=_row_poses[kind]
		var old_count=rows.size();rows.resize(visible[kind].size())
		var dirty=false
		var world_bounds=AABB();var has_bounds=false
		for index in range(visible[kind].size()):
			var entry=visible[kind][index];var actor=entry.actor;var data: Dictionary=entry.data
			var transform=presentation_transform(actor,data,entry.death)
			var instance_bounds=transform*_local_bounds[kind]
			world_bounds=world_bounds.merge(instance_bounds) if has_bounds else instance_bounds
			has_bounds=true
			multimesh.set_instance_transform(index,transform)
			if index<old_count and is_same(rows[index].data,data) and rows[index].frozen==entry.frozen:continue
			rows[index]={"data":data,"frozen":entry.frozen};dirty=true
			multimesh.set_instance_custom_data(index,Color(0,0,0,index))
			for group in range(GROUPS.size()):
				_write_pose(image,index,group,part_pose(GROUPS[group],data))
			image.set_pixel(21,index,Color(1.0 if entry.frozen else 0.0,0,0,0))
		if has_bounds:multimesh.custom_aabb=world_bounds
		multimesh.visible_instance_count=visible[kind].size()
		if dirty:pose_textures[kind].update(image)

func _write_pose(image: Image,index: int,group: int,pose: Transform3D):
	var normals=pose.basis.inverse().transposed()
	for axis in range(3):
		var column=pose.basis[axis]
		image.set_pixel(group*3+axis,index,Color(column.x,column.y,column.z,pose.origin[axis]))
		var normal=normals[axis]
		image.set_pixel(22+group*3+axis,index,Color(normal.x,normal.y,normal.z,0))

static func presentation_transform(actor: Node3D,data: Dictionary,death_age: float=0.0)->Transform3D:
	var transform=Transform3D(Basis(Vector3.UP,float(data.get("facing",0))),actor.global_position)
	if death_age>0:
		var death=clampf(death_age/.65,0,1)
		transform.basis=transform.basis*Basis(Vector3.RIGHT,death*.55).scaled(Vector3.ONE*maxf(.01,1-death*.95))
	return transform

func _ready_primitives():
	# One shared box per existing collision region. No GLB meshes, pose textures,
	# artwork, per-enemy rigs, lighting passes or enemy shadow cascades.
	for kind in range(4):
		var slots=[]
		var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo=true;material.albedo_color=Color.WHITE
		for item in Contact.shapes(kind):
			var mesh=BoxMesh.new();mesh.size=item.bounds.size;mesh.material=material
			var batch=MultiMeshInstance3D.new();batch.name="forest_enemy_%d_%s_proxy"%[kind,item.group]
			batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
			batch.multimesh.use_colors=true;batch.multimesh.mesh=mesh
			batch.multimesh.instance_count=32;batch.multimesh.visible_instance_count=0
			add_child(batch);slots.append({"item":item,"batch":batch})
		primitive_batches.append(slots);batches.append(slots[0].batch)

func _process_primitives(delta: float):
	var shown: Array=[[],[],[],[]];var live_ids={}
	for enemy in game.enemies:
		if not is_instance_valid(enemy):continue
		var id=enemy.get("forest_id")
		if id==null:continue
		live_ids[id]=true
		var visible_now=game.forest_enemy_visible(enemy)
		enemy.distance_asleep=not visible_now;enemy.visible=visible_now;enemy.render_full=false
		if is_instance_valid(enemy.model):enemy.model.visible=false
		if enemy.name_tag!=null:enemy.name_tag.visible=false
		if not visible_now:continue
		var data: Dictionary=game.model.enemies.get(id,{})
		if not data.is_empty():_poses[id]=data
		elif not _poses.has(id):continue
		if enemy.dead:_death_age[id]=float(_death_age.get(id,0))+delta
		shown[clampi(enemy.variant,0,3)].append({"actor":enemy,"data":_poses[id],"dead":enemy.dead,"death":float(_death_age.get(id,0))})
	for id in _poses.keys():
		if not live_ids.has(id):_poses.erase(id);_death_age.erase(id)
	for kind in range(4):
		var count=shown[kind].size()
		for slot in primitive_batches[kind]:
			var mm: MultiMesh=slot.batch.multimesh;var item: Dictionary=slot.item
			if count>mm.instance_count:mm.instance_count=nearest_po2(count)
			var bounds=AABB();var has_bounds=false
			for index in range(count):
				var entry: Dictionary=shown[kind][index];var data: Dictionary=entry.data
				var root_pose=presentation_transform(entry.actor,data,entry.death)
				var part=root_pose*part_pose("body" if item.group=="capsule" else item.group,data)
				var pose=part*Transform3D(Basis.IDENTITY,item.bounds.get_center())
				mm.set_instance_transform(index,pose)
				var color=Color("80cfff") if not entry.dead and float(data.get("frozen",0))>0 else PROXY_COLORS[kind]
				mm.set_instance_color(index,color)
				var box: AABB=part*item.bounds
				bounds=bounds.merge(box) if has_bounds else box;has_bounds=true
			if has_bounds:mm.custom_aabb=bounds
			mm.visible_instance_count=count
