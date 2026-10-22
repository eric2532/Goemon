extends Node3D
## The approved ROM body and fitted Blender equipment on the existing Thief kit.
## Existing drivers retain class-specific poses; ordinary motion and pipe cuts
## consume the same original matrices as Goemon. Combat reads the visible tip.
const Body=preload("res://scripts/recovered_goemon_body.gd")
const Pose=preload("res://scripts/recovered_goemon_pose.gd")
const Profile=preload("res://scripts/recovered_goemon_combat_profile.gd")
const HEIGHT=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT
var actor:Node3D
var legacy:RefCounted
var sampler=Pose.new()
var parts:Dictionary={}
var reference:Dictionary={}
var costume:Node3D
var equipment_skeleton:Skeleton3D
var weapon:MeshInstance3D
var weapon_rest:Transform3D
var rom_grip:Transform3D
var weapon_alignment:Basis
var contact_axis=Vector3.ZERO
var hold_axis=Vector3.UP
var source_scale=1.0
var source_offset=Vector3.ZERO
var source_action=0
var source_time=0.0
var age=0.0
var air_age=0.0
var fall_age=0.0
var previous_vertical=0.0
var land_age=1.0
var grounded=true
var shader_materials:Array[ShaderMaterial]=[]

func setup(owner_actor:Node3D,old_rig:RefCounted):
	actor=owner_actor;legacy=old_rig;name="ROMMasterThief"
	var idle:Dictionary=sampler.sample_source(0,0)
	var low=INF;var high=-INF
	for pointer in Body.data().parts:
		for vertex in Body.data().parts[pointer].vertices:
			var p:Vector3=idle[pointer]*Vector3(vertex.position[0],vertex.position[1],vertex.position[2])
			low=minf(low,p.y);high=maxf(high,p.y)
	source_scale=HEIGHT/(high-low);source_offset=Vector3(0,-low*source_scale,0)
	parts=Body.create_parts()
	for pointer in parts:
		add_child(parts[pointer]);reference[pointer]=normalized(idle[pointer])
		var mesh:MeshInstance3D=parts[pointer].get_node("normal" if pointer==Body.HEAD_POINTER else "mesh")
		for surface in mesh.mesh.get_surface_count():
			var material:ShaderMaterial=mesh.mesh.surface_get_material(surface)
			material.set_shader_parameter("costume_palette",2 if pointer==Body.HEAD_POINTER and surface==0 else (0 if pointer==Body.HEAD_POINTER else 1))
			shader_materials.append(material)
	costume=load("res://assets/models/characters/rom_goemon_base/master_thief_equipment.glb").instantiate()
	add_child(costume);costume.rotation.y=PI # glTF -Z front -> native +Z.
	equipment_skeleton=costume.find_child("Skeleton3D",true,false)
	weapon=costume.find_child("MasterThief_Weapon",true,false)
	weapon_rest=global_transform.affine_inverse()*weapon.global_transform
	var ready:Dictionary=sampler.sample_source(104,0)
	rom_grip=ready["0x9005868"].affine_inverse()*ready["0x9002518"]
	var carry=normalized(idle["0x9005868"]*rom_grip)
	weapon_alignment=carry.basis.orthonormalized().inverse()*weapon_rest.basis
	var axis: Array=weapon.get_meta("extras")["contact_axis"]
	contact_axis=Vector3(axis[0],axis[1],axis[2])
	var held: Array=weapon.get_meta("extras")["rom_hold_axis"]
	hold_axis=Vector3(held[0],held[1],held[2])
	update({},0,0)

func normalized(source:Transform3D)->Transform3D:
	return Transform3D(source.basis.scaled(Vector3.ONE*source_scale),source.origin*source_scale+source_offset)

func reset():
	age=0;air_age=0;fall_age=0;previous_vertical=0;land_age=1;grounded=true;source_action=0;source_time=0

func hand_position(side:String)->Vector3:
	if side=="R":return weapon.global_position
	return parts[Pose.PTR.Forearm_R].to_global(Vector3(0,-22,0))

func update(state:Dictionary,delta:float,time:float):
	age+=delta
	var on_floor=bool(state.get("grounded",true))
	var vertical=float(state.get("vertical",0))
	if not on_floor and (grounded or vertical>previous_vertical+3):air_age=0
	else:air_age+=delta
	if on_floor or (previous_vertical>0 and vertical<=0):fall_age=0
	elif vertical<=0:fall_age+=delta
	previous_vertical=vertical
	if on_floor and not grounded:land_age=0
	else:land_age+=delta
	grounded=on_floor
	var special=bool(state.get("blocking",false)) or bool(state.get("crouched",false)) or float(state.get("roll",0))>0 or float(state.get("flip",-1))>=0
	var attack=state.get("attack")
	var source:Dictionary={}
	source_action=-1;source_time=0
	if attack is Dictionary and attack.get("style","") in ["pipe","cutlass"]:
		var slot=posmod(int(attack.get("index",0)),3)
		source_action=104+slot
		var contact=maxf(.001,float(attack.get("contact",.105)))
		var duration=maxf(contact+.001,float(attack.get("duration",.38)))
		var elapsed=float(attack.get("time",0))
		var cue=minf(Profile.COMBO_CUE_FRAMES[slot],sampler.frame_count(source_action)-1)
		var frame=cue*clampf(elapsed/contact,0,1) if elapsed<=contact else lerpf(cue,sampler.frame_count(source_action)-1,clampf((elapsed-contact)/(duration-contact),0,1))
		source_time=frame/(30*sampler.native_rate(source_action))
	elif attack is Dictionary:
		special=true # Preserve crouched cuts, counter fire and all class skills.
	elif not special:
		if not grounded:
			source_action=24 if vertical>0 else 25;source_time=air_age if vertical>0 else fall_age
		elif land_age<sampler.duration(26):source_action=26;source_time=land_age
		else:
			source_action=15 if float(state.get("motionSpeed",0))>.25 else 0
			source_time=fposmod(age,sampler.duration(source_action))
	if source_action>=0:
		# Source parts already contain body bob, turns and landing compression.
		# Keep legacy root presentation only for the authored class special poses.
		actor.model.transform=Transform3D.IDENTITY
		source=sampler.sample_source(source_action,source_time)
	var deltas:Dictionary={}
	var old_space=global_transform.affine_inverse()*legacy.skeleton.global_transform
	for name_ in Pose.PTR:
		var pointer:String=Pose.PTR[name_]
		var target:Transform3D
		if not source.is_empty():target=normalized(source[pointer])
		else:
			# Native L/R labels are reversed relative to the authored class rig.
			# Map anatomical sides so its primary arm remains the weapon arm.
			var legacy_name:String=name_.trim_suffix("_L")+"_R" if name_.ends_with("_L") else (name_.trim_suffix("_R")+"_L" if name_.ends_with("_R") else name_)
			var index:int=legacy.skeleton.find_bone(legacy_name)
			var old_delta=legacy.skeleton.get_bone_global_pose(index)*legacy.bone_rest[index].affine_inverse()
			target=old_space*old_delta*old_space.affine_inverse()*reference[pointer]
		parts[pointer].transform=target
		deltas[name_]=target*reference[pointer].affine_inverse()
	if not source.is_empty():Body.set_face(parts,source_action,source_time)
	else:Body.set_face(parts,0,0)
	var space=global_transform.affine_inverse()*equipment_skeleton.global_transform
	for index in equipment_skeleton.get_bone_count():
		var name_=equipment_skeleton.get_bone_name(index)
		if deltas.has(name_):equipment_skeleton.set_bone_global_pose(index,space.affine_inverse()*deltas[name_]*space*equipment_skeleton.get_bone_global_rest(index))
	var weapon_pose:Transform3D=deltas.Forearm_L*weapon_rest
	if not source.is_empty():
		var native_weapon:Transform3D=source.get("0x9002518",source["0x9005868"]*rom_grip)
		weapon_pose=Transform3D(native_weapon.basis.orthonormalized()*weapon_alignment,native_weapon.origin*source_scale+source_offset)
	var size_=float(state.get("meleeVisualScale",1.0))*(3.0 if float(state.get("buffTime",0))>0 else 1.0)
	weapon_pose.basis=weapon_pose.basis.scaled(Vector3.ONE*size_)
	weapon.global_transform=global_transform*weapon_pose
	var old_axis:Vector3=actor.WEAPON_AXES[actor.id]
	if source_action<0:
		# Guard, low cuts and counter fire aim the pipe independently of the
		# forearm. Retain that authored aim about the newly fitted wrist.
		var intended:Vector3=actor.joints.Weapon_Cutlass.node.global_basis*old_axis
		# Aim the shaft separately from the geometry's actual contact point.
		var current:Vector3=weapon.global_basis*hold_axis
		weapon.global_basis=Basis(Quaternion(current.normalized(),intended.normalized()))*weapon.global_basis
	# The old driver remains the combat/trail socket. Its exact endpoint now
	# agrees with this fitted pipe, including range upgrades and Grand Smoke.
	var contact_basis=Basis(Quaternion(old_axis.normalized(),contact_axis.normalized())).scaled(Vector3.ONE*contact_axis.length()/old_axis.length())
	actor.joints.Weapon_Cutlass.node.global_transform=weapon.global_transform*Transform3D(contact_basis,Vector3.ZERO)
	var emission=Color.BLACK
	if actor.flash>0:
		emission=actor.flash_color*(.28 if actor.reduced_flashes else actor.flash_strength)*minf(1,actor.flash*24)
	elif bool(state.get("blocking",false)):
		emission=Color("e52b29")*(.38 if actor.reduced_flashes else .62+sin(time*5)*.07)
	for material in shader_materials:material.set_shader_parameter("costume_emission",emission)
