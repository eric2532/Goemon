class_name DefenseCastleWall
extends RefCounted
## One Edo-inspired fortification. All positions below are local to its center.
## Decoration is merged by material; collision remains ordinary static geometry.

const WIDTH=160.0
const GALLERY_HEIGHT=6.5
const PLINTH_HEIGHT=6.75
const GATE_HALF_WIDTH=6.0
const GATE_CLEARANCE=12.0
const RAMP_X=46.0
const RAMP_WIDTH=6.5
const RAMP_REAR=35.0
const WALL_REAR=3.0
var root: Node3D
var bodies: Array[StaticBody3D]=[]
var collision_groups: Dictionary={}
var batches: Dictionary={}
var materials: Dictionary={}
var unit_box: Mesh

static func build(world: Node3D,center: Vector3=Vector3(0,0,180))->Array[StaticBody3D]:
	var builder=load("res://scripts/defense_castle_wall.gd").new()
	return builder._build(world,center)

func _build(world: Node3D,center: Vector3)->Array[StaticBody3D]:
	root=Node3D.new();root.name="MainCastleWall";root.position=center;world.add_child(root)
	root.set_meta("gallery_height",GALLERY_HEIGHT)
	root.set_meta("gun_plinth_top",PLINTH_HEIGHT)
	root.set_meta("gateway_clearance",GATE_CLEARANCE)
	root.set_meta("gateway_half_width",GATE_HALF_WIDTH)
	root.set_meta("ramp_toes",[center+Vector3(-RAMP_X,0,RAMP_REAR),center+Vector3(RAMP_X,0,RAMP_REAR)])
	root.set_meta("ramp_tops",[center+Vector3(-RAMP_X,GALLERY_HEIGHT,WALL_REAR),center+Vector3(RAMP_X,GALLERY_HEIGHT,WALL_REAR)])
	var primitive=BoxMesh.new();primitive.size=Vector3.ONE
	var unindexed=SurfaceTool.new();unindexed.create_from(primitive,0);unindexed.deindex();unit_box=unindexed.commit()
	materials={
		"stone":Geo.mat("788883",.04),
		"light_stone":Geo.mat("939c91",.04),
		"dark_stone":Geo.mat("62726f",.06),
		"teal":Geo.mat("253f43",.35),
		"wood":Geo.mat("443b30"),
		"gold":Geo.mat("c4a166",.5),
		"flag":Geo.mat("d6b25c",.06),
	}
	# A roof is also visible from the ground beneath its projecting eaves.
	var roof_material: StandardMaterial3D=materials["teal"].duplicate()
	roof_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	materials["roof_teal"]=roof_material
	for side in [-1,1]:
		_build_wing(side)
		_build_ramp(side)
		for x in [28.0,70.0]:_build_watchtower(side*x)
	_build_high_gate()
	for x in [-16.0,-9.0,9.0,16.0]:
		# Slightly raised gun beds clear the deck even for a shallow sideways jet.
		var p=Vector3(x,(GALLERY_HEIGHT+PLINTH_HEIGHT)*.5,0)
		var size=Vector3(3.1,PLINTH_HEIGHT-GALLERY_HEIGHT,2.0)
		_box(p,size,"dark_stone")
		_collide_box("CastleGunBeds",p,size)
		_box(Vector3(x,PLINTH_HEIGHT+.015,0),Vector3(3.13,.03,2.02),"gold")
	for key in batches:
		var surface: SurfaceTool=batches[key]
		surface.generate_normals()
		var mesh=MeshInstance3D.new();mesh.name="Castle_%s" % key
		mesh.mesh=surface.commit();mesh.material_override=materials[key];root.add_child(mesh)
	return bodies

func _box(p: Vector3,size: Vector3,material: String,basis: Basis=Basis.IDENTITY):
	if not batches.has(material):
		var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);batches[material]=surface
	var transform=Transform3D(basis*Basis.from_scale(size),p)
	batches[material].append_from(unit_box,0,transform)

func _triangle(a: Vector3,b: Vector3,c: Vector3,material: String):
	if not batches.has(material):
		var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);batches[material]=surface
	var surface: SurfaceTool=batches[material]
	surface.add_vertex(a);surface.add_vertex(b);surface.add_vertex(c)

func _beam(a: Vector3,b: Vector3,width: float,height: float,material: String):
	var direction=(b-a).normalized()
	_box((a+b)*.5,Vector3(width,height,a.distance_to(b)),material,Basis.looking_at(direction,Vector3.UP))

func _collision_group(name: String)->StaticBody3D:
	if collision_groups.has(name):return collision_groups[name]
	var body=StaticBody3D.new();body.name=name;body.collision_layer=1;body.collision_mask=0
	root.add_child(body);bodies.append(body);collision_groups[name]=body
	return body

func _collide_box(group: String,p: Vector3,size: Vector3):
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size
	shape.shape=box;shape.position=p;_collision_group(group).add_child(shape)

func _build_wing(side: int):
	var center=Vector3(side*43.0,GALLERY_HEIGHT*.5,1)
	var size=Vector3(74,GALLERY_HEIGHT,4)
	_box(center,size,"stone")
	_collide_box("CastleWestWing" if side<0 else "CastleEastWing",center,size)
	# Large staggered blocks make the long facade read as masonry in one draw.
	for row in range(5):
		for column in range(12):
			var x=GATE_HALF_WIDTH+3.0+column*6.1
			var width=minf(5.9,80.0-x)
			if width<=0:continue
			var shade="light_stone" if (row+column)%3==0 else "dark_stone"
			var offset=.30 if row%2==1 else 0.0
			for z in [-1.025,3.025]:
				_box(Vector3(side*(x+offset),.72+row*1.14,z),Vector3(width,1.06,.06),shade)
	_box(Vector3(side*43,.23,1),Vector3(74,.46,4.10),"dark_stone")
	_box(Vector3(side*43,6.25,1),Vector3(74,.30,4.16),"dark_stone")
	_box(Vector3(side*43,6.46,1),Vector3(74,.08,4.0),"light_stone")
	_box(Vector3(side*43,5.96,-1.065),Vector3(74,.12,.12),"gold")
	# Gun galleries |x|=6..20 remain completely free of forward parapets.
	for index in range(15):
		var x=22.0+index*4.0
		if absf(x-28.0)<4.2 or absf(x-70.0)<4.2:continue
		var p=Vector3(side*x,7.1,-.52)
		_box(p,Vector3(2.1,1.2,.96),"stone")
		_box(p+Vector3(0,.64,0),Vector3(2.22,.12,1.04),"teal")
		_collide_box("CastleBattlements",p,Vector3(2.1,1.2,.96))
	# Inset floor divisions and a thin rear edge leave both ramp landings open.
	for index in range(18):
		_box(Vector3(side*(7.6+index*4.0),6.51,1),Vector3(.045,.015,3.6),"dark_stone")
	for x in [36.0,58.0]:_flag(Vector3(side*x,0,-.68),7.6,1.15,2.3)

func _build_ramp(side: int):
	var x=side*RAMP_X
	var body=_collision_group("CastleRearRampWest" if side<0 else "CastleRearRampEast")
	var shape=CollisionShape3D.new();var hull=ConvexPolygonShape3D.new()
	hull.points=PackedVector3Array([
		Vector3(x-RAMP_WIDTH*.5,0,WALL_REAR),Vector3(x+RAMP_WIDTH*.5,0,WALL_REAR),
		Vector3(x-RAMP_WIDTH*.5,GALLERY_HEIGHT,WALL_REAR),Vector3(x+RAMP_WIDTH*.5,GALLERY_HEIGHT,WALL_REAR),
		Vector3(x-RAMP_WIDTH*.5,0,RAMP_REAR),Vector3(x+RAMP_WIDTH*.5,0,RAMP_REAR),
	])
	shape.shape=hull;body.add_child(shape)
	# Authored stone steps sit on a smooth physical incline for ordinary walking.
	for step in range(32):
		var top=GALLERY_HEIGHT*float(step+1)/32.0
		var z=RAMP_REAR-float(step)-.5
		_box(Vector3(x,top*.5,z),Vector3(RAMP_WIDTH,top,1),"stone" if step%2==0 else "light_stone")
		_box(Vector3(x,top+.015,z+.43),Vector3(RAMP_WIDTH,.03,.13),"dark_stone")
	for edge in [-1,1]:
		_beam(Vector3(x+edge*(RAMP_WIDTH*.5+.12),.18,RAMP_REAR),Vector3(x+edge*(RAMP_WIDTH*.5+.12),GALLERY_HEIGHT+.18,WALL_REAR),.24,.30,"dark_stone")
	_box(Vector3(x,.035,RAMP_REAR+1.35),Vector3(RAMP_WIDTH+1,.07,2.7),"dark_stone")

func _build_watchtower(x: float):
	var group="CastleWatchtower_%d" % int(x)
	var high=12.35 if absf(x)<40 else 11.8
	_box(Vector3(x,6.4,1),Vector3(7.2,.20,4),"dark_stone")
	for side in [-1,1]:
		for z in [-.64,2.64]:
			var p=Vector3(x+side*2.85,(GALLERY_HEIGHT+high)*.5,z)
			var size=Vector3(.7,high-GALLERY_HEIGHT,.72)
			_box(p,size,"stone");_collide_box(group,p,size)
			_box(Vector3(p.x,7.0,p.z),Vector3(.86,1.0,.72),"dark_stone")
	# Front window sills protect the watch position; the gallery stays open
	# from left to right between the front/rear corner posts.
	var sill=Vector3(x,7.05,-.65)
	_box(sill,Vector3(5.0,1.1,.7),"stone");_collide_box(group,sill,Vector3(5.0,1.1,.7))
	_box(Vector3(x,high-.30,1),Vector3(7.0,.6,4),"wood")
	_collide_box(group,Vector3(x,high-.30,1),Vector3(7.0,.6,4))
	for z in [-.8,2.8]:
		_box(Vector3(x,high-.37,z),Vector3(7.6,.22,.32),"gold")
		for ornament in [-1,1]:_box(Vector3(x+ornament*1.15,high-.55,z),Vector3(.22,1.05,.20),"wood")
	_roof(Vector3(x,high,1),9.2,6.4,1.9)
	_flag(Vector3(x,0,-.85),high-.45,1.25,3.0)

func _build_high_gate():
	# The two inner watchtowers carry this high central gatehouse. No post,
	# merlon or buttress intrudes on the 12m road or the neighboring gun bays.
	var beam=Vector3(0,12.40,1)
	_box(beam,Vector3(63,.8,4),"wood")
	_collide_box("CastleHighGateway",beam,Vector3(63,.8,4))
	_box(Vector3(0,12.83,1),Vector3(64,.10,4),"gold")
	_box(Vector3(0,13.25,1),Vector3(18,.75,3.2),"stone")
	_box(Vector3(0,13.20,-.68),Vector3(4.2,.68,.14),"teal")
	_box(Vector3(0,13.20,-.79),Vector3(.16,.45,.06),"gold")
	_box(Vector3(0,13.20,-.79),Vector3(2.7,.11,.06),"gold")
	_roof(Vector3(0,13.65,1),22,6.2,1.3)

func _roof(p: Vector3,width: float,depth: float,height: float):
	var a=p+Vector3(-width*.5,0,-depth*.5)
	var b=p+Vector3(width*.5,0,-depth*.5)
	var c=p+Vector3(width*.5,0,depth*.5)
	var d=p+Vector3(-width*.5,0,depth*.5)
	var left=p+Vector3(-width*.32,height,0)
	var right=p+Vector3(width*.32,height,0)
	for tri in [[a,left,right],[a,right,b],[b,right,c],[c,right,left],[c,left,d],[d,left,a]]:
		_triangle(tri[0],tri[2],tri[1],"roof_teal")
	for ends in [[a,b],[b,c],[c,d],[d,a]]:_beam(ends[0],ends[1],.17,.16,"gold")
	_beam(left,right,.30,.25,"teal")
	# Narrow raised tile ribs keep the dark roof legible without extra nodes.
	for i in range(1,8):
		var t=float(i)/8
		var ridge=left.lerp(right,t)
		for edge in [a.lerp(b,t),d.lerp(c,t)]:_beam(edge+Vector3.UP*.04,ridge+Vector3.UP*.04,.085,.075,"dark_stone")

func _flag(p: Vector3,top: float,width: float,length: float):
	_box(p+Vector3(0,top-length*.5,0),Vector3(width,length,.07),"flag")
	_box(p+Vector3(0,top-length*.5,-.041),Vector3(.09,length*.72,.025),"teal")
	_box(p+Vector3(0,top-length*.43,-.045),Vector3(width*.65,.10,.025),"teal")
	_box(p+Vector3(0,top+.035,0),Vector3(width+.18,.13,.16),"wood")
