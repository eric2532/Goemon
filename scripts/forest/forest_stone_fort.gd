extends RefCounted
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const SHADER=preload("res://assets/materials/forest_stone.gdshader")
const ROCK=preload("res://assets/textures/edo/rock.png")
static var materials:Dictionary={}
static func material(color:Color=Color("92998c"),masonry:bool=true)->ShaderMaterial:
	var key=str(color)+str(masonry)
	if materials.has(key):return materials[key]
	var mat=ShaderMaterial.new();mat.shader=SHADER;mat.set_shader_parameter("stone_color",color)
	mat.set_shader_parameter("rock_texture",ROCK);mat.set_shader_parameter("masonry",masonry);materials[key]=mat;return mat
static func wall(parent:Node3D,length_:float,center_x:float):
	Geo.box(parent,Vector3(center_x,7.7,0),Vector3(length_,15.4,Profile.WALL_THICKNESS),material())
	Geo.box(parent,Vector3(center_x,.4,0),Vector3(length_,.8,Profile.WALL_BASE_THICKNESS),material(Color("727f75")))
	Geo.box(parent,Vector3(center_x,15.65,0),Vector3(length_,.7,Profile.WALL_CAP_THICKNESS),material(Color("b0b4a2"),false))
	var supports=MultiMeshInstance3D.new();supports.name="StoneButtresses";supports.multimesh=MultiMesh.new();supports.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	var mesh=BoxMesh.new();mesh.size=Vector3(.8,14.5,Profile.WALL_CAP_THICKNESS);supports.multimesh.mesh=mesh;supports.material_override=material(Color("778779"))
	var count=maxi(1,ceili(length_/6));supports.multimesh.instance_count=count;parent.add_child(supports)
	for i in count:supports.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(center_x-length_*.5+(i+.5)*length_/count,7.4,0)))
static func gate(parent:Node3D):
	for side in [-1,1]:
		Geo.box(parent,Vector3(side*Profile.GATE_PILLAR_X,Profile.GATE_HEIGHT*.5,0),Vector3(Profile.GATE_PILLAR_WIDTH,Profile.GATE_HEIGHT,Profile.GATE_FRAME_DEPTH),material(Color("889284")))
		Geo.box(parent,Vector3(side*Profile.GATE_PILLAR_X,.5,0),Vector3(Profile.GATE_PILLAR_WIDTH,1,4.0),material(Color("6c7a70")))
	Geo.box(parent,Vector3(0,Profile.GATE_HEADER_Y,0),Vector3(Profile.GATE_WIDTH,Profile.GATE_HEADER_HEIGHT,Profile.GATE_FRAME_DEPTH),material())
	Geo.box(parent,Vector3(0,Profile.GATE_HEIGHT-.35,0),Vector3(Profile.GATE_WIDTH,.7,4),material(Color("b0b4a2"),false))
	var door=Geo.box(parent,Vector3(0,Profile.GATE_CLOSED_Y,0),Vector3(Profile.GATE_DOOR_WIDTH,Profile.GATE_DOOR_HEIGHT,Profile.GATE_DOOR_THICKNESS),material(Color("727f78")));door.name="GateDoor"
static func freyja_arch(parent:Node3D):
	var boxes=preload("res://scripts/forest/forest_static_boxes.gd").new()
	var limestone=material(Color("bab8a3"))
	var coping=material(Color("d5c9a9"),false)
	var brick=material(Color("91694f"),false)
	var recess=material(Color("4d5046"),false)
	boxes.add(Vector3(0,12.2,0),Vector3(9.6,2.4,3.6),limestone)
	boxes.add(Vector3(0,13.5,0),Vector3(9.6,.35,4.0),coping)
	for side in [-1,1]:
		var x=side*6.15
		boxes.add(Vector3(x,8.25,0),Vector3(2.7,16.5,4.5),limestone)
		boxes.add(Vector3(x,.60,0),Vector3(2.9,1.2,4.7),limestone)
		boxes.add(Vector3(x,16.25,0),Vector3(3.0,.55,4.8),coping)
		for face in [-1,1]:
			var z=face*2.26
			boxes.add(Vector3(x,13.1,z),Vector3(.41,2.7,.06),recess)
			boxes.add(Vector3(x,7.6,z),Vector3(.22,2.2,.06),recess)
			for edge in [-1,1]:
				for level in 13:
					var shift=.18 if level%2==0 else .08
					boxes.add(Vector3(x+edge*(1.17-shift),.8+level*1.15,z),Vector3(.35+shift,.43,.08),brick)
			for edge in [-1,0,1]:
				boxes.add(Vector3(x+edge*1.04,17.0,face*2.02),Vector3(.64,1.0,.70),coping)
	for x in [-3.9,-2.34,-.78,.78,2.34,3.9]:
		for z in [-1.65,1.65]:boxes.add(Vector3(x,13.95,z),Vector3(.85,.65,.6),coping)
	boxes.build(parent)
static func freyja_wall_segment(parent:Node3D,pose:Transform3D):
	var root=Node3D.new();root.transform=pose;parent.add_child(root)
	var boxes=preload("res://scripts/forest/forest_static_boxes.gd").new()
	var limestone=material(Color("bab8a3"))
	var coping=material(Color("d5c9a9"),false)
	var recess=material(Color("4d5046"),false)
	boxes.add(Vector3(0,6.65,0),Vector3(6,13.3,4.5),limestone)
	boxes.add(Vector3(0,1.05,0),Vector3(6,2.1,4.8),material(Color("8e8e74")))
	boxes.add(Vector3(0,13.32,0),Vector3(6,.46,4.85),coping)
	for side in [-1,1]:
		for x in [-2.4,-1.2,0,1.2,2.4]:
			boxes.add(Vector3(x,9.35,side*2.256),Vector3(.20,2.75,.07),recess)
		for x in [-2,0,2]:
			boxes.add(Vector3(x,13.9,side*2.04),Vector3(.87,.83,.82),coping)
	boxes.build(root)
static func tower(parent:Node3D):
	# Keep the occupied landing above the wall while retaining the compact footprint.
	var deck=Profile.TOWER_DECK_HEIGHT
	var body=Profile.TOWER_BODY_HEIGHT
	Geo.box(parent,Vector3(0,.35,0),Vector3(11.7,.7,11.7),material(Color("68796f")))
	Geo.box(parent,Vector3(0,body*.5,0),Vector3(10,body,10),material())
	Geo.box(parent,Vector3(0,Profile.TOWER_DECK_CENTER,0),Vector3(11,Profile.TOWER_DECK_THICKNESS,11),material(Color("adb29f"),false))
	for x in [-4.7,4.7]:
		for z in [-4.7,4.7]:
			Geo.box(parent,Vector3(x,(deck+.25)*.5,z),Vector3(1.15,deck+.25,1.15),material(Color("778779")))
			Geo.box(parent,Vector3(x,deck+.05,z),Vector3(1.45,.5,1.45),material(Color("b0b4a2"),false))
	for side in [-1,1]:
		Geo.box(parent,Vector3(0,deck+.6,side*5),Vector3(10.5,1.2,.65),material(Color("8c9788")))
		Geo.box(parent,Vector3(side*5,deck+.6,0),Vector3(.65,1.2,10.5),material(Color("8c9788")))
		for slot in [-3.5,0,3.5]:
			Geo.box(parent,Vector3(slot,deck+1.7,side*5),Vector3(1.7,1.0,.85),material(Color("a4ad99")))
			Geo.box(parent,Vector3(side*5,deck+1.7,slot),Vector3(.85,1.0,1.7),material(Color("a4ad99")))
	# Rear lookout remains a separate, higher stone landing.
	var pillar_height=Profile.TOWER_LOOKOUT_HEIGHT-deck-.5
	for x in [-4.7,4.7]:
		Geo.box(parent,Vector3(x,deck+pillar_height*.5,-4.7),Vector3(.85,pillar_height,.85),material(Color("889585")))
	Geo.box(parent,Vector3(0,Profile.TOWER_LOOKOUT_CENTER,-4),Vector3(11.8,Profile.TOWER_LOOKOUT_THICKNESS,4),material(Color("a4ad99"),false))
	for x in [-4,0,4]:
		Geo.box(parent,Vector3(x,Profile.TOWER_LOOKOUT_HEIGHT+.3,-5.4),Vector3(1.8,.6,.85),material(Color("b0b4a2")))
	# Recessed arrow slits read as a stone fort at combat-camera distance.
	for side in [-1,1]:
		Geo.box(parent,Vector3(0,body*.68,side*5.015),Vector3(.28,1.65,.035),Geo.mat("35433c"))
		Geo.box(parent,Vector3(side*5.015,body*.68,0),Vector3(.035,1.65,.28),Geo.mat("35433c"))
static func pedestal(parent:Node3D):
	Geo.box(parent,Vector3(0,.4,0),Vector3(17,.8,17),material(Color("68786e")))
	Geo.box(parent,Vector3(0,1.35,0),Vector3(15,1.1,15),material(Color("8b9789")))
	Geo.box(parent,Vector3(0,2.35,0),Vector3(15.8,.9,15.8),material(Color("b0b4a2"),false))
static func shrine(parent:Node3D):
	pedestal(parent)
	var scene=load("res://assets/models/forest/goemon_stone_statue.scn")
	if scene!=null:
		var statue=scene.instantiate();statue.name="GoemonStoneStatue";statue.position.y=Profile.PEDESTAL_HEIGHT;statue.rotation.y=PI;parent.add_child(statue)
