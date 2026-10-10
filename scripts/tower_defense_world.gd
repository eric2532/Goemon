class_name TowerDefenseWorld
extends Sanctuary
## Three long, unobstructed approaches with solid cover on the shoulders.
## Coordinates stay in world space so the defense director can share the routes.

const CastleWall=preload("res://scripts/defense_castle_wall.gd")

var beta_mode=false
var redesign_mode=false
var mine_sites: Array=[]
var mine_position: Vector3:
	get:return mine_sites[0].position if not mine_sites.is_empty() else Vector3(-18,0,189)
var mine_build_position: Vector3:
	get:return mine_position+Vector3(0,.15,4)
var lanes: Array=[]
var lane_names: Array[String]=["WEST · JADE", "CENTER · GOLD", "EAST · EMBER"]
var lane_colors: Array[Color]=[Color("6ce1c0"), Color("ffcf69"), Color("ff886b")]
var cannon_sites: Array=[]
var cover_walls: Array[StaticBody3D]=[]
var base_position=Vector3(0,0,300)
var dog_spawn_position=Vector3(0,.15,195)
var hero_spawn_position=Vector3(0,.15,203)
var defense_banners: Array[Node3D]=[]
var spirit_lantern_positions: Array[Vector3]=[]
var shrine_halo: MeshInstance3D
const LANE_X=[-160.0,0.0,160.0]
const STATIONS=[-170.0,0.0,160.0]
var defense_stations: Array=STATIONS.duplicate()

func _ready():
	if redesign_mode:beta_mode=true
	descent_mode=false
	playable_bounds=Rect2(-80,50,160,310) if beta_mode else Rect2(-320,-400,640,760)
	spawn_point=Vector3(0,.15,195 if beta_mode else -140)
	if beta_mode:
		defense_stations=[170.0,230.0]
		dog_spawn_position=Vector3(0,.15,245)
		hero_spawn_position=Vector3(0,.15,253)
	rng.seed=generation_seed
	landmarks={"JADE APPROACH":Vector3(-160,0,-170), "GOLD APPROACH":Vector3(0,0,-170), "EMBER APPROACH":Vector3(160,0,-170), "THE LAST SHRINE":base_position}
	if beta_mode:landmarks={"GOLD APPROACH":Vector3(0,0,170), "THE LAST SHRINE":base_position}
	for lane in range(3):
		var x: float=LANE_X[lane]
		lanes.append([Vector3(x,0,-340),Vector3(x,0,-170),Vector3(x,0,0),Vector3(x,0,160),Vector3(x,0,205),Vector3(x*.46875,0,260),base_position])
	if beta_mode:
		lanes[1]=[Vector3(0,0,110),Vector3(0,0,170),Vector3(0,0,230),Vector3(0,0,260),base_position]
	lighting()
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.fog_density=.00025
			child.environment.fog_light_color=Color("b4cac3")
			child.environment.ambient_light_energy=.43
			child.environment.tonemap_exposure=1.0
			child.environment.sky.sky_material.sky_top_color=Color("537b91")
			child.environment.sky.sky_material.sky_horizon_color=Color("f2dec0")
		if child is DirectionalLight3D:
			child.light_color=Color("ffe5b4")
			child.light_energy=1.05
			child.directional_shadow_max_distance=130
	_build_ground()
	_build_routes()
	_build_defenses()
	_build_shrine()
	if beta_mode:
		_build_kennel_marker()
		_build_barracks_marker()
	_build_woodland()
	_build_horizon()
	if redesign_mode:
		preload("res://scripts/neon_shrine.gd").apply(self)
		_install_spirit_effects()
	# Fixed defenses must remain visible during flight and across the valley.
	# This compact map uses instanced woodland, so strategic scenery stays drawn;
	# the floating labels retain their own short readability range.

func height_at(_x: float, _z: float)->float:return 0.0

func _install_spirit_effects():
	var effects=preload("res://scripts/spirit_fortress_effects.gd").new()
	effects.name="SpiritFortressEffects"
	add_child(effects)

func raw_height(_x: float, _z: float)->float:return 0.0
func surface_height_at(_point: Vector3)->float:return 0.0
func active_lane_indices()->Array:return [1] if beta_mode else [0,1,2]

func _process(delta):
	elapsed+=delta
	for i in range(defense_banners.size()):
		defense_banners[i].rotation.z=sin(elapsed*1.8+i*.7)*.035
	if is_instance_valid(shrine_halo):shrine_halo.rotation.y+=delta*.18

func _solid_box(p: Vector3,size: Vector3,material: Material,label: String)->StaticBody3D:
	var body=StaticBody3D.new()
	body.name=label
	body.position=p
	body.collision_layer=1
	body.collision_mask=0
	add_child(body)
	Geo.box(body,Vector3.ZERO,size,material)
	var shape=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	return body

func _build_ground():
	var floor_body=StaticBody3D.new()
	floor_body.name="DefenseFloor"
	floor_body.collision_layer=1
	floor_body.collision_mask=0
	add_child(floor_body)
	var shape=CollisionShape3D.new()
	var box=BoxShape3D.new()
	var field_center=playable_bounds.get_center()
	box.size=Vector3(playable_bounds.size.x,4,playable_bounds.size.y)
	shape.shape=box
	shape.position=Vector3(field_center.x,-2,field_center.y)
	floor_body.add_child(shape)
	var ground_root=Node3D.new()
	ground_root.name="TerrainChunks"
	add_child(ground_root)
	var shader=Shader.new()
	shader.code="""shader_type spatial;
uniform bool night_theme=false;
varying vec3 ground_pos;
void vertex(){ground_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float large=sin(ground_pos.x*.041)*sin(ground_pos.z*.027);
 float fleck=sin(ground_pos.x*1.83+sin(ground_pos.z*2.31))*sin(ground_pos.z*2.07);
 ALBEDO=mix(vec3(.23,.32,.19),vec3(.37,.43,.26),large*.5+.5)+fleck*.017;
 if(night_theme){ALBEDO=mix(vec3(.045,.07,.105),vec3(.09,.12,.17),large*.5+.5)+fleck*.008;}
 ROUGHNESS=1.0;
}
"""
	var material=ShaderMaterial.new()
	material.shader=shader
	var columns=maxi(1,ceili(playable_bounds.size.x/80.0))
	var rows=maxi(1,ceili(playable_bounds.size.y/76.0))
	var tile_width=playable_bounds.size.x/columns
	var tile_height=playable_bounds.size.y/rows
	for x in range(columns):
		for z in range(rows):
			var center=playable_bounds.position+Vector2((x+.5)*tile_width,(z+.5)*tile_height)
			Geo.box(ground_root,Vector3(center.x,-.12,center.y),Vector3(tile_width,.24,tile_height),material)
	# Low stone boundaries keep the playable field distinct from the scenery.
	for x in [playable_bounds.position.x+1,playable_bounds.end.x-1]:
		_solid_box(Vector3(x,1,field_center.y),Vector3(2,2,playable_bounds.size.y),Geo.mat("5c6960"),"OuterBoundary")
	_solid_box(Vector3(field_center.x,1,playable_bounds.position.y+1),Vector3(playable_bounds.size.x,2,2),Geo.mat("5c6960"),"NorthBoundary")
	_solid_box(Vector3(field_center.x,1,playable_bounds.end.y-1),Vector3(playable_bounds.size.x,2,2),Geo.mat("5c6960"),"SouthBoundary")

func _road(a: Vector3,b: Vector3,width: float,material: Material,lane: int=-1):
	var middle=(a+b)*.5
	middle.y+=.035
	var road=Geo.box(self,middle,Vector3(width,.05,a.distance_to(b)+.6),material)
	road.rotation.y=atan2(b.x-a.x,b.z-a.z)
	road.set_meta("defense_lane",lane)

func _build_routes():
	var sand=EdoEnvironment.surface("sand")
	var edge=Geo.mat("8a9272")
	for lane in active_lane_indices():
		var path: Array=lanes[lane]
		for index in range(path.size()-1):
			_road(path[index],path[index+1],22,edge,lane)
			_road(path[index]+Vector3.UP*.02,path[index+1]+Vector3.UP*.02,18,sand,lane)
		var gate_z=96 if redesign_mode else (130 if beta_mode else -320)
		_gate(Vector3(LANE_X[lane],0,gate_z),lane,25)
		_world_label(lane_names[lane]+" APPROACH",Vector3(LANE_X[lane],9.0,gate_z+1),lane_colors[lane],.035)
		# Milestones, colored shoulders and a clear visual direction of attack.
		for z in range(gate_z,260 if beta_mode else 210,24):
			for side in [-1,1]:
				Geo.box(self,Vector3(LANE_X[lane]+side*9.7,.085,z),Vector3(.42,.10,10),Geo.mat(lane_colors[lane].darkened(.25).to_html(false)))
			var arrow=Geo.box(self,Vector3(LANE_X[lane]-1,.105,z),Vector3(.35,.045,3),Geo.mat("e9d5a5"))
			arrow.rotation.y=-.7
			arrow=Geo.box(self,Vector3(LANE_X[lane]+1,.105,z),Vector3(.35,.045,3),Geo.mat("e9d5a5"))
			arrow.rotation.y=.7
		for z in ([145,205] if beta_mode else [-255,85]):
			for side in [-1,1]:_field_lantern(Vector3(LANE_X[lane]+side*14,0,z),lane_colors[lane])
	# Crossroads behind each defense line let the player move between all lanes.
	for z in defense_stations:
		if beta_mode:
			_road(Vector3(-27,0,z+17),Vector3(27,0,z+17),7,Geo.mat("aaa37e"))
			if z==defense_stations[-1]:
				_road(Vector3(-51,0,z+39),Vector3(51,0,z+39),6,Geo.mat("aaa37e"))
			continue
		_road(Vector3(-181,0,z+17),Vector3(181,0,z+17),7,Geo.mat("aaa37e"))
		for x in [-80,80]:
			Geo.cylinder(self,Vector3(x,.10,z+17),6,.12,sand)
			Geo.torus(self,Vector3(x,.19,z+17),4.7,4.9,Geo.mat("dbba72",.15))

func _build_defenses():
	var plaster=EdoEnvironment.surface("plaster")
	var stone=EdoEnvironment.surface("stone")
	var wood=Geo.mat("49392d")
	for lane in active_lane_indices():
		for station in range(defense_stations.size()):
			var center=Vector3(LANE_X[lane],0,defense_stations[station])
			var accent=Geo.mat(lane_colors[lane].darkened(.3).to_html(false),.12)
			if beta_mode and station==defense_stations.size()-1:
				cover_walls.append_array(CastleWall.build(self,center))
				if redesign_mode:continue
				for offset in [-16.0,-9.0,9.0,16.0]:
					var side_label="WEST" if offset<0 else "EAST"
					_cannon_mount(center,lane,offset,"CASTLE WALL · %s %s" % [side_label,"OUTER" if absf(offset)>12 else "INNER"],6.85)
				continue
			# Low parapets face the incoming ranks; the center remains a 12m gap.
			for side in [-1,1]:
				var wall=center+Vector3(side*13,1.25,0)
				cover_walls.append(_solid_box(wall,Vector3(14,2.5,2.1),plaster,"Cover_%d_%d_%d" % [lane,station,side]))
				Geo.box(self,wall+Vector3(0,-.95,0),Vector3(14.4,.6,2.4),stone)
				Geo.box(self,wall+Vector3(0,1.26,0),Vector3(14.5,.20,2.65),wood)
				Geo.box(self,wall+Vector3(0,.25,-1.08),Vector3(13.7,.22,.09),accent)
				for dx in [-6.1,0,6.1]:
					var pillar=wall+Vector3(dx,.15,0)
					_solid_box(pillar,Vector3(.6,2.8,2.5),wood,"ParapetPost")
					Geo.box(self,pillar+Vector3(0,1.48,0),Vector3(1,.16,2.9),Geo.mat("263e3d"))
				# Short return provides useful lateral cover without closing the lane.
				cover_walls.append(_solid_box(center+Vector3(side*19.5,1.1,3.0),Vector3(1.2,2.2,5),stone,"CoverReturn"))
				_banner(center+Vector3(side*21,0,-1.0),lane_colors[lane])
			if beta_mode:
				# These offsets clear every parapet post and keep the four pads distinct.
				for offset in [-16.0,-9.0,9.0,16.0]:
					var side_label="WEST" if offset<0 else "EAST"
					_cannon_mount(center,lane,offset,"LINE %02d · %s %s" % [station+1,side_label,"OUTER" if absf(offset)>12 else "INNER"])
			else:
				var offset=-11.0 if (lane+station)%2==0 else 11.0
				_cannon_mount(center,lane,offset,["FORWARD","MIDDLE","REAR"][station])
	if redesign_mode:
		for x in [-12.0,12.0]:
			for z in [116.0,130.0,144.0,158.0]:_approach_mount(Vector3(x,.15,z))
		for point in [Vector3(-18,0,189),Vector3(18,0,189),Vector3(-18,0,208),Vector3(-16,0,282)]:
			mine_sites.append({"position":point,"footprint":Vector2(2.3,2.365)})

func _approach_mount(mount: Vector3):
	var pad=Vector3(mount.x,.15,mount.z+3.5)
	cannon_sites.append({"position":mount,"lane":1,"label":"%s APPROACH · %d" % ["WEST" if mount.x<0 else "EAST",int(mount.z)],"build_position":pad,"footprint":Vector2(1.4,1.4)})
	# Only visual geometry: the open center route and work pads cannot trap actors.

func _cannon_mount(center: Vector3,lane: int,offset: float,line_name: String,mount_height: float=2.65):
	var mount=center+Vector3(offset,mount_height,0)
	cannon_sites.append({"position":mount,"lane":lane,"label":"%s · %s" % [lane_names[lane],line_name],"build_position":center+Vector3(offset,.05,3.5 if redesign_mode else 5.3),"footprint":Vector2(1.4,1.4)})
	if redesign_mode:return
	Geo.cylinder(self,mount-Vector3.UP*.04,1.55,.20,Geo.mat("8b7957",.45))
	Geo.torus(self,mount+Vector3.UP*.08,1.20,1.32,Geo.mat("e3bd6f",.6))
	# Distinct purchasing pad on the protected side of the wall.
	var pad=center+Vector3(offset,.08,5.3)
	Geo.cylinder(self,pad,1.7 if beta_mode else 2.35,.1,Geo.mat("435956"))
	Geo.torus(self,pad+Vector3.UP*.06,1.40 if beta_mode else 2.05,1.54 if beta_mode else 2.19,Geo.mat(lane_colors[lane].to_html(false),.3,.35))
	Geo.box(self,pad+Vector3.UP*.08,Vector3(1.25,.05,.15),Geo.mat("ffdf93",.4))
	Geo.box(self,pad+Vector3.UP*.08,Vector3(.15,.05,1.25),Geo.mat("ffdf93",.4))
	# Prebuilt beta guns already display their live upgrade level. A second
	# long mount label would overlap the neighboring cannon in each battery.
	if not beta_mode:_world_label("CANNON · "+line_name,center+Vector3(offset,4.2,1.4),lane_colors[lane],.018)

func _build_kennel_marker():
	var seal=Node3D.new();seal.name="CastleKennel";seal.position=Vector3(dog_spawn_position.x,.15,dog_spawn_position.z);add_child(seal)
	var jade=Geo.mat("7bdcca",.18,.2)
	Geo.torus(seal,Vector3.ZERO,3.05,3.18,jade)
	Geo.torus(seal,Vector3(0,.015,0),2.65,2.70,Geo.mat("cfb477",.35))
	Geo.sphere(seal,Vector3(0,.04,.55),Vector3(1.15,.06,1.02),jade)
	for i in range(4):
		var x=(float(i)-1.5)*.62
		Geo.sphere(seal,Vector3(x,.04,-.48+absf(x)*.22),Vector3(.38,.06,.48),jade)
	var sign=Label3D.new();sign.name="KennelSign";seal.add_child(sign)
	sign.text="CASTLE KENNEL\nG · SUMMON";sign.position=Vector3(-5.5,1.5,0)
	sign.font_size=28;sign.pixel_size=.01;sign.modulate=Color("9ce6dc")
	sign.outline_modulate=Color("172b2d");sign.outline_size=5
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.visibility_range_end=55

func _build_barracks_marker():
	var seal=Node3D.new();seal.name="CastleBarracks";seal.position=hero_spawn_position;add_child(seal)
	var gold=Geo.mat("dfc17a",.25,.15)
	Geo.torus(seal,Vector3.ZERO,3.05,3.18,gold)
	Geo.torus(seal,Vector3(0,.015,0),2.65,2.70,Geo.mat("7494a4",.2))
	# A flat sword crest marks the rally point without obstructing the gateway.
	Geo.box(seal,Vector3(0,.055,-.18),Vector3(.25,.04,1.8),gold)
	Geo.box(seal,Vector3(0,.055,.60),Vector3(1.0,.04,.15),gold)
	Geo.box(seal,Vector3(0,.055,.93),Vector3(.17,.04,.5),gold)
	var sign=Label3D.new();sign.name="BarracksSign";seal.add_child(sign)
	sign.text="CASTLE BARRACKS\nH · SUMMON";sign.position=Vector3(5.5,1.5,0)
	sign.font_size=28;sign.pixel_size=.01;sign.modulate=Color("efd69b")
	sign.outline_modulate=Color("172b2d");sign.outline_size=5
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.visibility_range_end=55

func _banner(p: Vector3,color: Color):
	Geo.cylinder(self,p+Vector3(0,3.5,0),.12,7,Geo.mat("3f352b"))
	Geo.sphere(self,p+Vector3(0,7.1,0),Vector3(.36,.5,.36),Geo.mat("dbc482",.3))
	var flag=Node3D.new()
	flag.position=p+Vector3(0,6.6,0)
	add_child(flag)
	Geo.box(flag,Vector3(.85,-1.25,0),Vector3(1.7,2.5,.06),Geo.mat(color.darkened(.2).to_html(false)))
	Geo.box(flag,Vector3(.85,-1.25,-.045),Vector3(.13,1.85,.03),Geo.mat("f4e5bf"))
	Geo.box(flag,Vector3(.85,-1.25,-.047),Vector3(1.05,.13,.03),Geo.mat("f4e5bf"))
	defense_banners.append(flag)

func _gate(p: Vector3,lane: int,width: float):
	var wood=Geo.mat("873f32")
	for side in [-1,1]:
		_solid_box(p+Vector3(side*width*.5,4.5,0),Vector3(.95,9,1.1),wood,"ApproachGatePost_%d_%d" % [lane,side])
		Geo.box(self,p+Vector3(side*width*.5,.35,0),Vector3(1.55,.7,1.7),Geo.mat("344442"))
	Geo.box(self,p+Vector3(0,7.3,0),Vector3(width+1.8,.65,1.3),wood)
	Geo.box(self,p+Vector3(0,9,0),Vector3(width+4,.65,2),Geo.mat("243d3f"))
	Geo.box(self,p+Vector3(0,8.95,0),Vector3(width+4.1,.12,2.15),Geo.mat("b5975c",.3))
	Geo.box(self,p+Vector3(0,7.7,.7),Vector3(2,1.8,.18),Geo.mat(lane_colors[lane].darkened(.3).to_html(false)))
	for side in [-1,1]:_banner(p+Vector3(side*(width*.5+4),0,0),lane_colors[lane])

func _world_label(text_value: String,p: Vector3,color: Color,pixel: float):
	var label=Label3D.new()
	label.text=text_value
	label.position=p
	label.font_size=48
	label.pixel_size=pixel
	label.modulate=color
	label.outline_modulate=Color("172b2d")
	label.outline_size=12
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=false
	label.visibility_range_end=160
	add_child(label)

func _field_lantern(p: Vector3,color: Color):
	spirit_lantern_positions.append(p)
	Geo.cylinder(self,p+Vector3(0,1.6,0),.13,3.2,Geo.mat("453c30"))
	Geo.box(self,p+Vector3(0,3.0,0),Vector3(.85,1.0,.85),Geo.mat(color.lightened(.2).to_html(false),0,.8))
	Geo.box(self,p+Vector3(0,3.62,0),Vector3(1.3,.22,1.3),Geo.mat("263e3d"))
	Geo.box(self,p+Vector3(0,2.40,0),Vector3(1.1,.18,1.1),Geo.mat("263e3d"))

func _build_shrine():
	var stone=EdoEnvironment.surface("stone")
	Geo.cylinder(self,base_position+Vector3.UP*.065,28,.13,EdoEnvironment.surface("sand"))
	Geo.torus(self,base_position+Vector3.UP*.15,23.6,24.2,Geo.mat("bfa568",.3))
	Geo.torus(self,base_position+Vector3.UP*.16,10.2,10.65,Geo.mat("e9bd62",.3,.15))
	for side in [-1,1]:
		for z in [280,302,327]:_field_lantern(Vector3(side*25,0,z),Color("ffe3a3"))
		_banner(Vector3(side*14,0,278),Color("f6ce79"))
	var shrine=Vector3(0,0,331)
	_solid_box(shrine+Vector3.UP*.5,Vector3(29,1,17),stone,"ShrineFoundation")
	for level in range(3):
		var w=24-level*5.5
		var d=14-level*2.8
		var y=1+level*6.0
		if level>0:Geo.box(self,shrine+Vector3(0,y,0),Vector3(w,.5,d),Geo.mat("702f27"))
		for side in [-1,1]:
			for depth_side in [-1,1]:Geo.cylinder(self,shrine+Vector3(side*(w*.5-1),y+2.3,depth_side*(d*.5-1)),.38,4.6,Geo.mat("ae4732"))
			Geo.box(self,shrine+Vector3(side*(w*.5-.6),y+2.1,0),Vector3(.3,4,d-2.6),EdoEnvironment.surface("plaster"))
		Geo.box(self,shrine+Vector3(0,y+4.25,-d*.5+.65),Vector3(w,.55,.55),Geo.mat("ae4732"))
		GameAssets.place(self,"edo/roof",shrine+Vector3(0,y+4.6,0),Vector3((w+5)/10,1.2,(d+5)/10))
	# Shrine energy is visible from every approach without obstructing attackers.
	Geo.cylinder(self,base_position+Vector3.UP*2.5,1.2,5,Geo.mat("ffe1a0",.2,.8),false,.25)
	shrine_halo=Geo.torus(self,base_position+Vector3.UP*6,2.8,3.1,Geo.mat("ffe1a0",.4,.8))
	shrine_halo.rotation.x=PI/2
	Geo.sphere(self,base_position+Vector3.UP*6,Vector3(2.3,2.3,2.3),Geo.mat("fff0c2",.15,1.2))
	_world_label("THE LAST SHRINE",base_position+Vector3(0,11,0),Color("ffe1a0"),.045)

func _build_woodland():
	# Instanced woodland adds scale while keeping the huge field inexpensive.
	var trunk_mesh=CylinderMesh.new()
	trunk_mesh.bottom_radius=.48
	trunk_mesh.top_radius=.27
	trunk_mesh.height=1
	trunk_mesh.radial_segments=7
	var crown_mesh=CylinderMesh.new()
	crown_mesh.bottom_radius=3.6
	crown_mesh.top_radius=0
	crown_mesh.height=6
	crown_mesh.radial_segments=7
	var trunks: Array[Transform3D]=[]
	var cedar_crowns: Array[Transform3D]=[]
	var cherry_crowns: Array[Transform3D]=[]
	var cedar_dark: Array[Transform3D]=[]
	var tree_budget=75 if beta_mode else 370
	for i in range(tree_budget):
		var p=Vector3(rng.randf_range(playable_bounds.position.x+15,playable_bounds.end.x-15),0,rng.randf_range(playable_bounds.position.y+15,playable_bounds.end.y-20))
		if not _woodland_position(p):continue
		var h=rng.randf_range(7,16)
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1,h,1)),p+Vector3.UP*h*.5))
		if i%5==0:
			for lobe in range(3):
				var offset=Vector3((lobe-1)*2.0, h+sin(lobe)*1.6,cos(lobe*2.1)*1.4)
				cherry_crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(6.8,4,5.5)),p+offset))
		else:
			for layer in range(3):
				var scale_factor=(1.45-layer*.29)*h/12.0
				var transform=Transform3D(Basis(Vector3.UP,i*.71).scaled(Vector3.ONE*scale_factor),p+Vector3.UP*(h*.48+layer*h*.20))
				if i%2==0:cedar_crowns.append(transform)
				else:cedar_dark.append(transform)
	_make_instances("CedarTrunks",trunk_mesh,Geo.mat("534236"),trunks)
	_make_instances("JadeWoodland",crown_mesh,Geo.mat("3b6250"),cedar_crowns)
	_make_instances("DeepWoodland",crown_mesh,Geo.mat("294c40"),cedar_dark)
	var blossom=SphereMesh.new()
	blossom.radius=.5
	blossom.height=1
	blossom.radial_segments=8
	blossom.rings=4
	_make_instances("DistantSakura",blossom,Geo.mat("c996a0"),cherry_crowns)
	var rock_budget=14 if beta_mode else 34
	for i in range(rock_budget):
		var p=Vector3(rng.randf_range(playable_bounds.position.x+22,playable_bounds.end.x-22),0,rng.randf_range(playable_bounds.position.y+35,playable_bounds.end.y-15))
		if not _woodland_position(p):continue
		GameAssets.place(self,"edo/moss_rock",p,Vector3(rng.randf_range(2,5),rng.randf_range(1.5,4),rng.randf_range(2,5)))

func _woodland_position(p: Vector3)->bool:
	if beta_mode:
		var castle_z: float=defense_stations[-1]
		if absf(p.z-castle_z)<15:return false
		if p.z>castle_z and p.z<castle_z+46 and absf(absf(p.x)-46)<12:return false
		# Keep the whole road, wall shoulders and short crossing paths open.
		# Trees now form the nearby sides of one valley, including the shrine.
		if absf(p.x)<36:return false
		if p.z>250 and absf(p.x)<42:return false
		return true
	if p.z>205 and absf(p.x)<200:return false
	for x in LANE_X:
		if absf(p.x-x)<30:return false
	for z in defense_stations:
		if absf(p.z-z-17)<13:return false
	return true

func _make_instances(label: String,mesh_resource: Mesh,material: Material,transforms: Array[Transform3D]):
	if transforms.is_empty():return
	var multi=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=mesh_resource
	multi.instance_count=transforms.size()
	for i in range(transforms.size()):multi.set_instance_transform(i,transforms[i])
	var instance=MultiMeshInstance3D.new()
	instance.name=label
	instance.multimesh=multi
	instance.material_override=material
	add_child(instance)

func _build_horizon():
	var count=16 if beta_mode else 21
	for i in range(count):
		var angle=float(i)*TAU/count
		var p=Vector3(cos(angle)*(190 if beta_mode else 540),0,(215 if beta_mode else -35)+sin(angle)*(240 if beta_mode else 610))
		var h=rng.randf_range(68,125) if beta_mode else rng.randf_range(70,180)
		var radius=rng.randf_range(30,48) if beta_mode else rng.randf_range(80,135)
		var mountain=Geo.cylinder(self,p+Vector3.UP*(h*.5-16),radius,h,Geo.mat("657f7b" if i%2==0 else "718e85"),false,9)
		mountain.rotation.y=angle
		if i%(4 if beta_mode else 3)==0:
			Geo.cylinder(self,p+Vector3.UP*(h-(18 if beta_mode else 25)),14 if beta_mode else 23,22 if beta_mode else 30,Geo.mat("cccebb"),false,0)
