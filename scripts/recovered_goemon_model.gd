extends HeroModel
## Original N64 rigid display-list parts animated by their native world matrices.
## Compatibility pivots serve current controls and equipment, never deform the mesh.
const Profile=preload("res://scripts/recovered_goemon_combat_profile.gd")
const OriginalWeapons=preload("res://scripts/recovered_goemon_weapons.gd")
const OriginalBody=preload("res://scripts/recovered_goemon_body.gd")
const OriginalLocomotion=preload("res://scripts/recovered_goemon_locomotion.gd")
const OriginalPose=preload("res://scripts/recovered_goemon_pose.gd")
const Proportions=preload("res://scripts/character_proportions.gd")
var native_parts:Dictionary={}
var sampler:RefCounted
var source_scale=1.0
var source_offset=Vector3.ZERO
var transform_age=-1.0
var golden_requested=false
var original_ranged_age=-1.0
var original_ranged_action=0x7C
var original_ranged_rate=1.0
var native_bones:Dictionary={}
var robe_skeleton:Skeleton3D

func _ready():
	set_meta("original_goemon",true)
	set_meta("original_pipe_tier",3)
	body=Node3D.new();body.name="OriginalN64Goemon";add_child(body)
	rig_visual=Node3D.new();rig_visual.name="NativeSourceSpace";rig_visual.rotation.y=PI;body.add_child(rig_visual)
	head=driver("Head",Vector3.ZERO)
	arms.assign([driver("Arm_L",Vector3.ZERO),driver("Arm_R",Vector3.ZERO)])
	legs.assign([driver("Leg_L",Vector3.ZERO),driver("Leg_R",Vector3.ZERO)])
	scarf=driver("Sash",Vector3.ZERO)
	hair_normal=Node3D.new();hair_normal.name="NormalHeadActive";body.add_child(hair_normal)
	hair_gold=Node3D.new();hair_gold.name="GoldenHeadActive";body.add_child(hair_gold);hair_gold.hide()
	sampler=OriginalPose.new()
	native_parts=OriginalBody.create_parts()
	for pointer in native_parts:rig_visual.add_child(native_parts[pointer])
	# Preserve the established Goemon height, hence Ben/Edo's accepted proportions.
	var reference:Dictionary=sampler.sample_source(0,0)
	var bounds=AABB();var first=true
	for pointer in native_parts:
		if not reference.has(pointer):continue
		var points:Array[Vector3]=[]
		_mesh_points(native_parts[pointer],Transform3D.IDENTITY,points)
		for point in points:
			var p:Vector3=reference[pointer]*point
			if first:bounds=AABB(p,Vector3.ZERO);first=false
			else:bounds=bounds.expand(p)
	source_scale=Proportions.GOEMON_HEIGHT/maxf(.001,bounds.size.y)
	source_offset=Vector3(0,-bounds.position.y*source_scale,0)
	sampler.source_scale=source_scale
	_build_compatibility_skeleton(reference)
	pipe=Node3D.new();pipe.name="OriginalPipe";rig_visual.add_child(pipe)
	OriginalWeapons.install(self)
	coin=Node3D.new();coin.name="OriginalHeldCoin";rig_visual.add_child(coin);coin.add_child(OriginalWeapons.create_coin());coin.hide()
	chain_pipe=ChainPipeVisual.new();chain_pipe.link_thickness=1.0;rig_visual.add_child(chain_pipe);chain_pipe.hide()
	OriginalWeapons.install_chain(self)
	locomotion=OriginalLocomotion.new(self)
	process_priority=30
	apply_native_pose(0,0)

func _mesh_points(node:Node3D,parent_transform:Transform3D,points:Array[Vector3]):
	if not node.visible:return
	var local=parent_transform*node.transform
	if node is MeshInstance3D and node.mesh!=null:
		for surface in range(node.mesh.get_surface_count()):
			for p in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:points.append(local*p)
	for child in node.get_children():
		if child is Node3D:_mesh_points(child,local,points)

func _build_compatibility_skeleton(reference:Dictionary):
	skeleton=Skeleton3D.new();skeleton.name="NativeEquipmentSkeleton";rig_visual.add_child(skeleton)
	for name_ in OriginalPose.PTR:
		skeleton.add_bone(name_)
		var index=skeleton.get_bone_count()-1;native_bones[name_]=index
		var source:Transform3D=reference[OriginalPose.PTR[name_]]
		skeleton.set_bone_rest(index,Transform3D(source.basis,source.origin*source_scale+source_offset))
	for name_ in ["Hand_L","Hand_R"]:
		skeleton.add_bone(name_);native_bones[name_]=skeleton.get_bone_count()-1
		skeleton.set_bone_rest(native_bones[name_],Transform3D.IDENTITY)
	# The garment was authored facing game -Z; native rigid parts face +Z.
	# Give shared cloth an equipment frame in game space, without changing
	# the source matrices or its native-space weapon compatibility skeleton.
	robe_skeleton=Skeleton3D.new();robe_skeleton.name="GoemonRobeSkeleton";body.add_child(robe_skeleton)
	robe_skeleton.add_bone("Chest")
	robe_skeleton.set_bone_rest(0,_robe_pose(skeleton.get_bone_rest(native_bones.Chest)))

func cape_skeleton()->Skeleton3D:return robe_skeleton

func _robe_pose(native_pose:Transform3D)->Transform3D:
	return rig_visual.transform*native_pose*rig_visual.transform.affine_inverse()

func apply_native_pose(action_id:int,seconds:float):
	var source:Dictionary=sampler.sample_source(action_id,seconds)
	if source.is_empty():return
	OriginalBody.set_face(native_parts,action_id,seconds)
	for pointer in native_parts:
		var part:Node3D=native_parts[pointer]
		part.visible=source.has(pointer)
		if not part.visible:continue
		var native:Transform3D=source[pointer]
		part.transform=Transform3D(native.basis.scaled(Vector3.ONE*source_scale),native.origin*source_scale+source_offset)
		part.visible=absf(native.basis.determinant())>.00000001
	for name_ in OriginalPose.PTR:
		var pointer:String=OriginalPose.PTR[name_]
		if source.has(pointer):
			var native:Transform3D=source[pointer]
			if absf(native.basis.determinant())>.00000001:
				skeleton.set_bone_global_pose(native_bones[name_],Transform3D(native.basis,native.origin*source_scale+source_offset))
	robe_skeleton.set_bone_global_pose(0,_robe_pose(skeleton.get_bone_global_pose(native_bones.Chest)))
	attach_native_weapons(source)

func attach_native_weapons(source:Dictionary):
	if not is_instance_valid(pipe):return
	var weapon_source=source
	if not source.has("0x9002518"):weapon_source=sampler.sample_source(0x68,0)
	var shaft:Transform3D=weapon_source["0x9002518"]
	pipe.transform=_pipe_transform(shaft,pipe_visual_scale)
	pipe.visible=equipped and not chain_selected and source.has("0x9002518")
	var hand:Transform3D=source.get("0x90074e8",shaft)
	var hand_pose=Transform3D(hand.basis,hand.origin*source_scale+source_offset)
	skeleton.set_bone_global_pose(native_bones.Hand_L,hand_pose)
	coin.transform=hand_pose;coin.hide()
	if is_instance_valid(chain_pipe):
		chain_pipe.transform=Transform3D(hand.basis.scaled(Vector3.ONE*source_scale/.01),hand_pose.origin)
		chain_pipe.visible=chain_selected and equipped and source.has("0x90074e8")

func _pipe_transform(native:Transform3D,visual_scale:float)->Transform3D:
	return Transform3D(native.basis.scaled(Vector3.ONE*source_scale*visual_scale/WeaponProportions.SCALE),native.origin*source_scale+source_offset)

func pipe_pose(action_id:int,time_seconds:float,visual_scale:float)->Transform3D:
	return _pipe_transform(sampler.sample_part(action_id,time_seconds,"0x9002518"),visual_scale)

func animate(delta:float,speed:float,grounded:bool,vertical:float,attack:float,heavy:bool,combo:int,dodge:bool):
	if original_ranged_age>=0:
		original_ranged_age+=delta*original_ranged_rate
		if original_ranged_age>=Profile.action_duration(original_ranged_action):original_ranged_age=-1
	if transform_age>=0:
		transform_age+=delta
		if golden_requested and transform_age>=Profile.cue_time(0x82,10):_set_golden(true)
	super.animate(delta,speed,grounded,vertical,attack,heavy,combo,dodge)

func combat_pose(_attack:float,heavy:bool,combo:int,_dodge:bool):
	pipe_combo_stage=3 if heavy else combo
	pipe_combo_pose={}

func _set_golden(active:bool):
	hair_normal.visible=not active;hair_gold.visible=active
	OriginalBody.set_golden(native_parts,active)

func set_surge(active:bool):
	golden_requested=active
	transform_age=0.0 if active else -1.0
	_set_golden(false)
	if locomotion!=null:locomotion.dirty=true

func begin_original_coin(action_id:int,playback_rate:float=1.0):
	original_ranged_action=action_id;original_ranged_age=0;original_ranged_rate=playback_rate
	if locomotion!=null:locomotion.dirty=true

func cancel_original_coin():
	original_ranged_age=-1
	if locomotion!=null:locomotion.dirty=true

func apply_skin(_id:String):
	# Saved alternate-skin preferences cannot replace the requested original model.
	skin_id=HeroSkins.DEFAULT_ID
