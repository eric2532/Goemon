extends RefCounted
const WOOD="795239"
const DARK="3e362b"
const GOLD="d3a653"
static var wall_post_mesh: CylinderMesh
static var wall_tip_mesh: CylinderMesh
static func wall_posts(parent: Node3D,count: int,center_x: float):
	if wall_post_mesh==null:
		wall_post_mesh=CylinderMesh.new();wall_post_mesh.bottom_radius=.49;wall_post_mesh.top_radius=.49;wall_post_mesh.height=3.6;wall_post_mesh.radial_segments=12
		wall_tip_mesh=CylinderMesh.new();wall_tip_mesh.bottom_radius=.49;wall_tip_mesh.top_radius=0;wall_tip_mesh.height=.7;wall_tip_mesh.radial_segments=12
	# The same rounded logs and pointed caps, with two draws per wall section.
	for part in range(2):
		var batch=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh=wall_post_mesh if part==0 else wall_tip_mesh;batch.multimesh.instance_count=count
		batch.material_override=Geo.mat("97704a" if part==0 else "bc9861")
		parent.add_child(batch)
		for i in range(count):batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(i-(count-1)*.5+center_x,1.8 if part==0 else 3.95,0)))
static func solid(parent: Node3D,offset: Vector3,size_: Vector3,layer: int=1):
	var body=StaticBody3D.new();body.collision_layer=layer;body.collision_mask=0;parent.add_child(body)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size_;shape.shape=box;shape.position=offset;body.add_child(shape)
	return body
static func roof(parent: Node3D,p: Vector3,size_: Vector3,color: String):
	var mesh=PrismMesh.new();mesh.size=size_
	return Geo.mesh(parent,mesh,p,Geo.mat(color))
static func building(b: Dictionary)->Node3D:
	var root=Node3D.new();root.name="Building_%d"%b.id
	match b.kind:
		"shrine":
			Geo.box(root,Vector3(0,.4,0),Vector3(17,.8,17),Geo.mat("827e65"))
			var shrine=GameAssets.place(root,"cedar_pass/shrine",Vector3.ZERO,Vector3.ONE*1.25)
			shrine.name="ShrineVisual"
			solid(root,Vector3(0,4,0),Vector3(15,8,14))
			for x in [-7,7]:
				Geo.cylinder(root,Vector3(x,3,7),.23,6,Geo.mat("a64d35"))
			Geo.box(root,Vector3(0,6,7),Vector3(17,.6,.6),Geo.mat("a64d35"))
			Geo.box(root,Vector3(0,5.2,7),Vector3(14,.25,.35),Geo.mat(DARK))
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
		"tower":
			for x in [-4.5,4.5]:
				for z in [-4.5,4.5]:
					Geo.box(root,Vector3(x,5,z),Vector3(.65,10,.65),Geo.mat(WOOD))
					solid(root,Vector3(x,5,z),Vector3(.65,10,.65))
			Geo.box(root,Vector3(0,8.7,0),Vector3(11,.5,11),Geo.mat("aa8654"))
			var deck=solid(root,Vector3(0,8.7,0),Vector3(11,.5,11));deck.name="TowerDeck"
			for side in [-1,1]:
				Geo.box(root,Vector3(0,10,side*5),Vector3(10.5,1.8,.35),Geo.mat(WOOD))
				solid(root,Vector3(0,10,side*5),Vector3(10.5,1.8,.35))
				Geo.box(root,Vector3(side*5,10,0),Vector3(.35,1.8,10.5),Geo.mat(WOOD))
				solid(root,Vector3(side*5,10,0),Vector3(.35,1.8,10.5))
				Geo.beam(root,Vector3(-4,1,side*4.5),Vector3(4,8,side*4.5),.15,Geo.mat(WOOD))
			for x in [-4.6,4.6]:
				for z in [-4.6,4.6]:Geo.box(root,Vector3(x,11,z),Vector3(.25,5,.25),Geo.mat(DARK))
			var canopy=roof(root,Vector3(0,13.6,-4),Vector3(12,2.4,4),"345963")
			canopy.create_trimesh_collision()
			for i in range(10):Geo.box(root,Vector3(0,i*.8+.4,5.25),Vector3(2,.14,.2),Geo.mat("c3a16c"))
		"wall":
			var span: int=b.get("span",preload("res://scripts/forest/forest_model.gd").SIZES.wall.x)
			var extension: Vector2=b.get("wall_extensions",Vector2.ZERO)
			if b.rotation%4 in [1,2]:extension=Vector2(extension.y,extension.x)
			var length_=span*6+extension.x+extension.y
			var center_x=(extension.y-extension.x)*.5
			var posts=int(length_)
			wall_posts(root,posts,center_x)
			for y in [1.1,2.7]:Geo.box(root,Vector3(center_x,y,.47),Vector3(length_,.2,.2),Geo.mat(DARK))
			solid(root,Vector3(center_x,2,0),Vector3(length_,4,1.3))
		"gate":
			for x in [-5.1,5.1]:
				Geo.box(root,Vector3(x,2.5,0),Vector3(1.1,5.0,1.1),Geo.mat(WOOD))
				solid(root,Vector3(x,2.5,0),Vector3(1.1,5,1.1))
			Geo.box(root,Vector3(0,5,0),Vector3(12,1,1.3),Geo.mat("ac8050"))
			var door=Geo.box(root,Vector3(0,2.4,0),Vector3(8.7,4.5,.4),Geo.mat("6b5237"));door.name="GateDoor"
			solid(root,Vector3(0,2.5,0),Vector3(9,5,.6),32)
	root.rotation.y=b.rotation*PI*.5
	return root
static func worker(id: int)->Node3D:
	var root=Node3D.new();root.name="Worker_%d"%id
	Geo.cylinder(root,Vector3(0,1.25,0),.45,1.15,Geo.mat("547f83"))
	Geo.sphere(root,Vector3(0,2.03,0),Vector3(.67,.65,.65),Geo.mat("d5b386"))
	var hat=CylinderMesh.new();hat.bottom_radius=.85;hat.top_radius=.1;hat.height=.4
	Geo.mesh(root,hat,Vector3(0,2.42,0),Geo.mat("c7ad71"))
	for side in [-1,1]:
		var limb=Geo.box(root,Vector3(side*.24,.48,0),Vector3(.26,.8,.3),Geo.mat("3c4c46"));limb.name="LegL" if side<0 else "LegR"
		var arm=Geo.box(root,Vector3(side*.52,1.2,0),Vector3(.25,.85,.28),Geo.mat("d0b389"));arm.name="ArmL" if side<0 else "ArmR"
	var bag=Geo.sphere(root,Vector3(0,1,.65),Vector3(.9,.9,.65),Geo.mat("c49b42"));bag.name="Cargo";bag.hide()
	var ring=Geo.torus(root,Vector3(0,.08,0),.72,.85,Geo.mat("f4d68b",0,.6));ring.name="Selected";ring.hide()
	var bow=Node3D.new();bow.name="Bow";root.add_child(bow);bow.hide()
	Geo.beam(bow,Vector3(.7,.65,.25),Vector3(.85,1.25,.6),.07,Geo.mat(WOOD))
	Geo.beam(bow,Vector3(.85,1.25,.6),Vector3(.7,1.85,.25),.07,Geo.mat(WOOD))
	Geo.beam(bow,Vector3(.7,.65,.25),Vector3(.7,1.85,.25),.018,Geo.mat("ddd1ae"))
	return root
static func label(parent: Node3D,text_: String,height: float)->Label3D:
	var label_=Label3D.new();label_.text=text_;label_.position.y=height
	label_.font_size=48;label_.pixel_size=.045;label_.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label_.modulate=Color("f4e6bb");label_.outline_modulate=Color("182923");label_.outline_size=8
	parent.add_child(label_);return label_
