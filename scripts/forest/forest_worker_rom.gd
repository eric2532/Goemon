extends Node3D
## Shared rigid ROM parts and cached poses keep a full workforce lightweight.
const Body=preload("res://scripts/recovered_goemon_body.gd")
const Pose=preload("res://scripts/recovered_goemon_pose.gd")
const HEIGHT=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT
const EQUIPMENT=preload("res://assets/models/forest/rom_worker_equipment.glb")
static var prototype:PackedScene
static var frames:Dictionary={}
static var normalization_scale=1.0
static var normalization_offset=Vector3.ZERO
static var native_grip=Transform3D.IDENTITY
var parts:Dictionary={}
var pickaxe:MeshInstance3D
var hat:MeshInstance3D
var hat_rest=Transform3D.IDENTITY
var head_rest=Transform3D.IDENTITY
var weapon_alignment=Basis.IDENTITY
var source_scale=1.0
var source_offset=Vector3.ZERO
var rom_grip=Transform3D.IDENTITY
var source_action=0
var source_frame=-1
var source_garrison=false

static func normalized(value:Transform3D)->Transform3D:
	return Transform3D(value.basis.scaled(Vector3.ONE*normalization_scale),value.origin*normalization_scale+normalization_offset)

static func prepare():
	if prototype!=null:return
	var sampler=Pose.new()
	var idle:Dictionary=sampler.sample_source(0,0)
	var low=INF;var high=-INF
	for pointer in Body.data().parts:
		for vertex in Body.data().parts[pointer].vertices:
			var p:Vector3=idle[pointer]*Vector3(vertex.position[0],vertex.position[1],vertex.position[2])
			low=minf(low,p.y);high=maxf(high,p.y)
	normalization_scale=HEIGHT/(high-low);normalization_offset=Vector3(0,-low*normalization_scale,0)
	var ready:Dictionary=sampler.sample_source(104,0)
	native_grip=ready["0x9005868"].affine_inverse()*ready["0x9002518"]
	var template=Node3D.new()
	var source_parts=Body.create_parts()
	for pointer in source_parts:
		var part:Node3D=source_parts[pointer];template.add_child(part)
		if pointer==Body.HEAD_POINTER:
			var golden=part.get_node("golden");part.remove_child(golden);golden.free()
		else:
			for mesh in part.get_children():
				for index in mesh.mesh.get_surface_count():
					var mat:ShaderMaterial=mesh.mesh.surface_get_material(index)
					mat.set_shader_parameter("costume_palette",1)
					mat.set_shader_parameter("costume_maroon",Color("327c72"))
					mat.set_shader_parameter("costume_navy",Color("293f4a"))
					mat.set_shader_parameter("costume_gold",Color("ba9959"))
	var equipment=EQUIPMENT.instantiate();template.add_child(equipment)
	equipment.rotation.y=PI # Blender +Y -> glTF -Z -> native Goemon +Z.
	for piece_name in ["WorkerHat","Pickaxe"]:
		var piece:MeshInstance3D=equipment.find_child(piece_name,true,false)
		var local:Transform3D=piece.transform
		var parent=piece.get_parent()
		while parent!=template:
			local=parent.transform*local;parent=parent.get_parent()
		piece.owner=null;piece.reparent(template,false);piece.transform=local
	equipment.free()
	for child in template.find_children("*","",true,false):child.owner=template
	prototype=PackedScene.new()
	# Release exports omit assert expressions, so packing must happen separately.
	var packed=prototype.pack(template);assert(packed==OK);template.free()
	# Bake once for every worker: quarter-source-frame sampling, with the ROM's
	# actual action rates. No per-worker JSON decoding, skeleton or mesh copies.
	for action in [0,15,104]:
		var samples:Array=[]
		for index in range((sampler.frame_count(action)-1)*4+1):
			var time=float(index)/(120.0*sampler.native_rate(action))
			var native_pose:Dictionary=sampler.sample_source(action,time)
			var poses:Dictionary={}
			for pointer in source_parts:poses[pointer]=normalized(native_pose[pointer])
			var weapon:Transform3D=native_pose.get("0x9002518",native_pose["0x9005868"]*native_grip)
			var weapon_pose=Transform3D(weapon.basis.orthonormalized(),weapon.origin*normalization_scale+normalization_offset)
			samples.append({"parts":poses,"weapon":weapon_pose,"source":native_pose})
		frames[action]={"samples":samples,"duration":sampler.duration(action),"rate":sampler.native_rate(action)}

func setup():
	name="GoemonBody";prepare()
	set_meta("rom_base","assets/blender/characters/rom_goemon_base/worker.blend")
	set_meta("source_model","res://assets/characters/recovered_goemon/body/body.json")
	var instance=prototype.instantiate()
	instance.name="ROMParts";add_child(instance)
	for child in instance.get_children():
		if child.has_meta("rom_display_list"):parts[child.get_meta("rom_display_list")]=child
	hat=instance.get_node("WorkerHat");pickaxe=instance.get_node("Pickaxe")
	hat_rest=hat.transform
	head_rest=frames[0].samples[0].parts[Body.HEAD_POINTER]
	weapon_alignment=frames[0].samples[0].weapon.basis.inverse()*pickaxe.basis
	source_scale=normalization_scale;source_offset=normalization_offset;rom_grip=native_grip
	update_worker({"state":"idle","id":0},0)

func source_pose()->Dictionary:return frames[source_action].samples[source_frame].source

func update_worker(worker:Dictionary,age:float):
	var state:String=worker.state
	var moving=state in ["follow","travel","deliver","move","retreat"]
	var working=state in ["mine","repair"]
	var garrison=state=="garrison"
	var action=15 if moving else 104 if working else 0
	var clock=age*(.38 if working else 1.0)+int(worker.id)*.053
	var data:Dictionary=frames[action]
	var time=fposmod(clock,data.duration)
	var index=0 if garrison else mini(int(floor(time*120.0*float(data.rate))),data.samples.size()-1)
	pickaxe.visible=state not in ["garrison","wounded"]
	if action==source_action and index==source_frame and garrison==source_garrison:return
	source_action=action;source_frame=index;source_garrison=garrison
	var sample:Dictionary=data.samples[index]
	for pointer in parts:parts[pointer].transform=sample.parts[pointer]
	hat.transform=sample.parts[Body.HEAD_POINTER]*head_rest.affine_inverse()*hat_rest
	pickaxe.transform=sample.weapon*Transform3D(weapon_alignment,Vector3.ZERO)
	if garrison:
		# Retain the old raised archer arms without changing the original motions.
		for side in ["L","R"]:
			var arm:String=Pose.PTR["Arm_"+side]
			var forearm:String=Pose.PTR["Forearm_"+side]
			var shoulder:Vector3=parts[arm].position
			var turn=Basis(Vector3.RIGHT,-.9 if side=="L" else -.6)
			var delta=Transform3D(turn,shoulder-turn*shoulder)
			parts[arm].transform=delta*parts[arm].transform
			parts[forearm].transform=delta*parts[forearm].transform
			if side=="L":pickaxe.transform=delta*pickaxe.transform
