extends RefCounted
const WOOD="795239"
const DARK="3e362b"
const GOLD="d3a653"
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const StoneFort=preload("res://scripts/forest/forest_stone_fort.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const Worker=preload("res://scripts/forest/forest_worker_warcraft.gd")
const WallDamage=preload("res://scripts/forest/forest_wall_damage.gd")
static func solid(parent: Node3D,offset: Vector3,size_: Vector3,layer: int=1,halo_material: String=""):
	var body=StaticBody3D.new();body.collision_layer=layer;body.collision_mask=0;parent.add_child(body)
	if not halo_material.is_empty():body.set_meta("halo_material",halo_material)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size_;shape.shape=box;shape.position=offset;body.add_child(shape)
	return body
static func roof(parent: Node3D,p: Vector3,size_: Vector3,color: String):
	var mesh=PrismMesh.new();mesh.size=size_
	return Geo.mesh(parent,mesh,p,Geo.mat(color))
static func building(b: Dictionary)->Node3D:
	var root=Node3D.new();root.name="Building_%d"%b.id;root.set_meta("halo_material","stone")
	var meadow=bool(b.get("wind_meadow",false))
	match b.kind:
		"barracks":
			if meadow:Meadow.building(root,"barracks")
			else:preload("res://scripts/forest/forest_barracks_art.gd").build(root)
			solid(root,Vector3(0,Profile.BARRACKS_BODY_HEIGHT*.5,0),Vector3(17.2,Profile.BARRACKS_BODY_HEIGHT,17.2))
			solid(root,Vector3(0,Profile.BARRACKS_DECK_CENTER,0),Vector3(17.8,Profile.BARRACKS_DECK_THICKNESS,17.8))
			for side in [-1,1]:
				solid(root,Vector3(0,Profile.BARRACKS_DECK_HEIGHT+.6,side*8.15),Vector3(17.2,1.2,.9))
				solid(root,Vector3(side*8.15,Profile.BARRACKS_DECK_HEIGHT+.6,0),Vector3(.9,1.2,17.2))
				for slot in [-6,-2,2,6]:
					solid(root,Vector3(slot,Profile.BARRACKS_DECK_HEIGHT+1.7,side*8.15),Vector3(2.2,1.0,1.1))
					solid(root,Vector3(side*8.15,Profile.BARRACKS_DECK_HEIGHT+1.7,slot),Vector3(1.1,1.0,2.2))
		"shrine":
			StoneFort.shrine(root)
			solid(root,Vector3(0,1.4,0),Vector3(17,2.8,17))
			solid(root,Vector3(0,17.8,0),Vector3(13,30,12))
		"mine":
			for i in range(7):
				var pos=Vector3((i%3-1)*4,1.2+(i%2)*.5,(i/3-1)*3)
				Geo.sphere(root,pos,Vector3(5.5,4.5,5),Geo.mat("747c72"))
				Geo.spike(root,pos+Vector3(.5,1,1.2),pos+Vector3(.8,3.8,1.5),.6,Geo.mat(GOLD,.5,.2))
			for x in [-3.2,3.2]:Geo.box(root,Vector3(x,2,5),Vector3(.65,4,.7),Geo.mat(WOOD))
			Geo.box(root,Vector3(0,4,5),Vector3(7.2,.75,.9),Geo.mat(WOOD))
			Geo.box(root,Vector3(0,1.9,4.7),Vector3(5.7,3.8,.5),Geo.mat("252d29"))
			for x in [-1.4,1.4]:Geo.box(root,Vector3(x,.2,6.2),Vector3(.14,.14,3.5),Geo.mat("8e978e",.4))
			Geo.box(root,Vector3(4,1.1,5.6),Vector3(2.4,1.8,2),Geo.mat(WOOD))
			Geo.sphere(root,Vector3(4,2.1,5.6),Vector3(2,.5,1.6),Geo.mat(GOLD,.4,.15))
			solid(root,Vector3(0,2,0),Vector3(17.6,4,11.6))
		"tower","cannon_tower":
			if b.kind=="cannon_tower":Meadow.building(root,"cannon_tower")
			elif meadow:Meadow.building(root,"watchtower")
			else:StoneFort.tower(root)
			if b.kind=="cannon_tower":solid(root,Vector3(0,11.83,0),Vector3(8.34,23.66,8.18))
			else:
				solid(root,Vector3(0,Profile.TOWER_BODY_HEIGHT*.5,0),Vector3(10,Profile.TOWER_BODY_HEIGHT,10))
				var deck=solid(root,Vector3(0,Profile.TOWER_DECK_CENTER,0),Vector3(11,Profile.TOWER_DECK_THICKNESS,11));deck.name="TowerDeck"
				solid(root,Vector3(0,Profile.TOWER_LOOKOUT_CENTER,-4),Vector3(11.8,Profile.TOWER_LOOKOUT_THICKNESS,4))
				var pillar_height=Profile.TOWER_LOOKOUT_HEIGHT-Profile.TOWER_DECK_HEIGHT-.5
				for x in [-4.7,4.7]:solid(root,Vector3(x,Profile.TOWER_DECK_HEIGHT+pillar_height*.5,-4.7),Vector3(.85,pillar_height,.85))
				for side in [-1,1]:
					solid(root,Vector3(0,Profile.TOWER_DECK_HEIGHT+.6,side*5),Vector3(10.5,1.2,.35))
					solid(root,Vector3(side*5,Profile.TOWER_DECK_HEIGHT+.6,0),Vector3(.35,1.2,10.5))
		"wall":
			var span: int=b.get("span",preload("res://scripts/forest/forest_model.gd").SIZES.wall.x)
			var extension: Vector2=b.get("wall_extensions",Vector2.ZERO)
			if b.rotation%4 in [1,2]:extension=Vector2(extension.y,extension.x)
			var length_=span*6+extension.x+extension.y
			var center_x=(extension.y-extension.x)*.5
			if meadow:Meadow.wall(root,length_,center_x)
			else:StoneFort.wall(root,length_,center_x)
			var damage=WallDamage.new();root.add_child(damage);damage.setup(b,length_,center_x)
			var height=16.0 if b.get("enemy_castle",false) else Profile.WALL_HEIGHT
			# Reuse the authored 16 m wall and fractures; enemy castles retain their size.
			for visual:Node3D in root.get_children():
				visual.position.y*=height/16.0;visual.scale.y*=height/16.0
			solid(root,Vector3(center_x,height*.5,0),Vector3(length_,height,Profile.WALL_CAP_THICKNESS))
			solid(root,Vector3(center_x,.4,0),Vector3(length_,.8,Profile.WALL_BASE_THICKNESS))
		"gate":
			if b.get("freyja_arch",false):
				var parts=load("res://scripts/forest/forest_falan_fort_parts.gd")
				var original=parts.gate_spec(b)
				if original.is_empty():StoneFort.freyja_arch(root)
				else:
					var node=Geo.mesh(root,parts.prepare(original[0]),Vector3.ZERO,null);node.transform=original[1]
					root.set_meta("falan_gate_source_graphic",original[0])
					var bounds:AABB=original[1]*node.mesh.get_aabb();solid(root,bounds.get_center(),bounds.size)
					for joint:AABB in parts.gate_supports(b):
						Geo.box(root,joint.get_center(),joint.size,parts.stone_paint).set_meta("falan_gate_shoulder",true)
						solid(root,joint.get_center(),joint.size)
				for side in [-1,1]:solid(root,Vector3(side*6.15,8.25,0),Vector3(2.7,16.5,4.5))
				if original.is_empty():
					solid(root,Vector3(0,12.2,0),Vector3(9.6,2.4,3.6));add_foundation(root,b)
				root.rotation.y=b.rotation*PI*.5
				return root
			if meadow:Meadow.gate(root)
			else:StoneFort.gate(root)
			var damage=WallDamage.new();root.add_child(damage);damage.setup(b,Profile.GATE_DOOR_WIDTH)
			for x in [-Profile.GATE_PILLAR_X,Profile.GATE_PILLAR_X]:solid(root,Vector3(x,Profile.GATE_HEIGHT*.5,0),Vector3(Profile.GATE_PILLAR_WIDTH,Profile.GATE_HEIGHT,Profile.GATE_FRAME_DEPTH))
			solid(root,Vector3(0,Profile.GATE_HEADER_Y,0),Vector3(Profile.GATE_WIDTH,Profile.GATE_HEADER_HEIGHT,Profile.GATE_FRAME_DEPTH))
			var door=root.get_node("GateDoor");var footing=maxf(0.0,float(b.get("foundation_depth",0.0)))
			door.mesh.size.y+=footing;door.position.y-=footing*.5;door.set_meta("foundation_depth",footing)
			var door_body=solid(door,Vector3.ZERO,Vector3(Profile.GATE_DOOR_WIDTH,Profile.GATE_DOOR_HEIGHT+footing,Profile.GATE_DOOR_THICKNESS),32);door_body.name="GateDoorCollider"
	add_foundation(root,b)
	root.rotation.y=b.rotation*PI*.5
	return root
static func add_foundation(root:Node3D,b:Dictionary):
	var depth=float(b.get("foundation_depth",0.0))
	if not is_finite(depth) or depth<=.001 or b.kind not in ["tower","cannon_tower","barracks","wall","gate"]:return
	var foundation=Node3D.new();foundation.name="TerrainFoundation";root.add_child(foundation)
	var pieces=[];var color=Color("68796f")
	match b.kind:
		"tower","cannon_tower":pieces.append([0.0,11.7,11.7])
		"barracks":pieces.append([0.0,17.8,17.8])
		"wall":
			var extension:Vector2=b.get("wall_extensions",Vector2.ZERO)
			if b.rotation%4 in [1,2]:extension=Vector2(extension.y,extension.x)
			pieces.append([(extension.y-extension.x)*.5,b.get("span",6)*6+extension.x+extension.y,Profile.WALL_BASE_THICKNESS]);color=Color("727f75")
		"gate":
			for x in [-Profile.GATE_PILLAR_X,Profile.GATE_PILLAR_X]:pieces.append([x,Profile.GATE_PILLAR_WIDTH,4.0])
			color=Color("6c7a70")
	# Overlap the existing plinth slightly; its top, deck and doorway stay fixed.
	for piece in pieces:
		var position_=Vector3(piece[0],(.05-depth)*.5,0);var size_=Vector3(piece[1],depth+.05,piece[2])
		Geo.box(foundation,position_,size_,StoneFort.material(color))
		solid(foundation,position_,size_,1,"stone")
static func worker(id: int)->Node3D:
	var root=Node3D.new();root.name="Worker_%d"%id
	var body=Worker.new();root.add_child(body);body.setup()
	var bag=Node3D.new();root.add_child(bag);bag.name="Cargo";bag.hide() # Native Gold clips carry the original sack.
	var ring=Geo.torus(root,Vector3(0,.08,0),.72,.85,Geo.mat("f4d68b",0,.6));ring.name="Selected";ring.hide()
	var bow=Node3D.new();bow.name="Bow";root.add_child(bow);bow.hide();bow.position=Profile.TOWER_MUZZLE_OFFSET-Profile.BOW_LOCAL_GRIP
	Geo.beam(bow,Vector3(.7,.65,.95),Profile.BOW_LOCAL_GRIP,.07,Geo.mat(WOOD))
	Geo.beam(bow,Profile.BOW_LOCAL_GRIP,Vector3(.7,1.85,.95),.07,Geo.mat(WOOD))
	Geo.beam(bow,Vector3(.7,.65,.95),Vector3(.7,1.85,.95),.018,Geo.mat("ddd1ae"))
	return root
static func animate_worker(node:Node3D,worker_:Dictionary,age:float)->bool:
	return node.get_node("WorkerBody").update_worker(worker_,age)
static func label(parent: Node3D,text_: String,height: float)->Label3D:
	var label_=Label3D.new();label_.text=text_;label_.position.y=height
	label_.font_size=48;label_.pixel_size=.045;label_.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label_.modulate=Color("f4e6bb");label_.outline_modulate=Color("182923");label_.outline_size=8
	parent.add_child(label_);return label_
