class_name Sanctuary
extends Node3D

var playable_bounds=WorldExpansion.bounds(0)
var outposts: Array[Vector3]=[]
var outer_routes: Array=[]
var generation_seed=90824
var area_index=0
var rng = RandomNumberGenerator.new()
var water_material: ShaderMaterial
var spawn_point = Vector3(0,2.5,41)
var landmarks = {"TIDEFALL TEMPLE": Vector3(-10,0,-37), "VERMILION CROSSING": Vector3(24,0,-8), "WHISPERING GROTTO": Vector3(-44,0,-5), "THE STORM COURT": Vector3(45,0,-42)}
var breeze: Array[Node3D] = []
var birds: Array[Node3D] = []
var motes: Array[Node3D] = []
var elapsed = 0.0

func height_at(x: float, z: float) -> float:
	var h=coastal_height(x,z)
	for side in [-1,1]:
		var distance=Vector2(x-side*76,z+51).length()
		if distance<17:h=lerpf(coastal_height(side*76,-51),h,smoothstep(12,17,distance))
	return WorldExpansion.flatten(self,x,z,h)

func raw_height(x: float,z: float)->float:return coastal_height(x,z)

func coastal_height(x: float,z: float)->float:
	var h = 1.0 + maxf(0,25-maxf(z,-125))*0.062 + sin(x*0.052)*sin(z*0.052)*1.1
	h += smoothstep(35,65,abs(x))*4.5
	var river = 24.0 + 3.0*sin(z*0.055)
	if abs(x-river)<5.5 and z> -125:
		h = lerpf(h,lerpf(-1.7,h,smoothstep(3.4,5.5,abs(x-river))),smoothstep(-125,-100,z))
	if z>47: h -= (z-47)*0.24
	return h

func _ready():
	rng.seed = generation_seed
	WorldExpansion.plan(self)
	lighting()
	terrain()
	water()
	paths()
	atmosphere()
	architecture()
	nature()
	WorldExpansion.dress(self)
	# Expanded outer loop links two spacious side courts with the temple approach.
	for side in [-1,1]:
		var court=Vector3(side*76,0,-51);court.y=height_at(court.x,court.z)
		path_segment(Vector3(side*43,0,-24),court,5.5)
		path_segment(court,Vector3(side*38,0,-81),5.5)
		path_segment(Vector3(side*38,0,-81),Vector3(-10,0,-56),5.5)
		Geo.cylinder(self,court,12,.18,EdoEnvironment.material("d0bd92"),true)
		Geo.torus(self,court+Vector3.UP*.1,10.8,11,EdoEnvironment.material("cba95f",.2))
		torii(court.x,court.z+12,10)
		for offset in [-7,7]:lantern(court+Vector3(offset,0,-6))
	landmarks["WESTERN TRAINING COURT"]=Vector3(-76,0,-51)
	landmarks["EASTERN WATCH COURT"]=Vector3(76,0,-51)
	for i in range(12):
		var b = Node3D.new()
		add_child(b)
		Geo.beam(b,Vector3(-0.5,0.13,0),Vector3.ZERO,0.04,EdoEnvironment.material("eef5df"))
		Geo.beam(b,Vector3.ZERO,Vector3(0.5,0.13,0),0.04,EdoEnvironment.material("eef5df"))
		b.position = Vector3(rng.randf_range(-50,50),rng.randf_range(20,32),rng.randf_range(-65,30))
		birds.append(b)
	for i in range(24):
		var p = Vector3(-3+sin(i*0.7)*5,0,32-i*2.65)
		if i>13: p = Vector3(9+(i-14)*3.2,0,-8)
		p.y = height_at(p.x,p.z)+1.1
		if i>17: p.y=7.3
		var mote=Node3D.new()
		add_child(mote)
		mote.position=p
		Geo.sphere(mote,Vector3.ZERO,Vector3(0.28,0.44,0.28),EdoEnvironment.material("ffe78c",0.5,0.7))
		var ring=Geo.torus(mote,Vector3.ZERO,0.30,0.34,EdoEnvironment.material("ffdc70",0.5,0.4))
		ring.rotation.x=PI/2
		motes.append(mote)

	# New town composition is exclusive to the main sanctuary.
	var town=TidefallTown.new()
	town.world=self
	add_child(town)

func lighting():
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("256ca4")
	sky_mat.sky_horizon_color = Color("a7e3df")
	sky_mat.ground_bottom_color = Color("477f8e")
	sky_mat.ground_horizon_color = Color("a7e3df")
	sky_mat.sky_curve = 0.17
	sky.sky_material = sky_mat
	e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("b7d7ee")
	e.ambient_light_energy=0.32
	e.tonemap_mode=Environment.TONE_MAPPER_ACES
	e.tonemap_exposure=0.90
	e.ssao_enabled=true
	e.ssao_radius=1.5
	e.ssao_intensity=1.8
	e.glow_enabled=true
	e.glow_intensity=0.35
	e.glow_bloom=0.06
	e.adjustment_enabled=true
	e.adjustment_saturation=1.12
	e.fog_enabled=true
	e.fog_light_color=Color("90cdd5")
	e.fog_density=0.0022
	env.environment=e
	add_child(env)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-43,-32,0)
	sun.light_color=Color("fff0cf")
	sun.light_energy=0.85
	sun.light_angular_distance=0.65
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=110
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias=0.035
	add_child(sun)

func terrain():
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step=2.5
	var edge=playable_bounds.grow(5)
	for xi in range(ceili(edge.size.x/step)):
		for zi in range(ceili(edge.size.y/step)):
			var x=edge.position.x+xi*step
			var z=edge.position.y+zi*step
			var pts=[Vector3(x,height_at(x,z),z),Vector3(x+step,height_at(x+step,z),z),Vector3(x,height_at(x,z+step),z+step),Vector3(x+step,height_at(x+step,z+step),z+step)]
			var c=Color("60ae59") if (xi+zi)%3 else Color("64b35b")
			if z>40: c=Color("e6cf93") if (xi+zi)%2 else Color("ead9a3")
			if abs(x-(24+3*sin(z*0.055)))<6: c=Color("8f9c6a")
			for idx in [0,1,2,1,3,2]:
				st.set_color(c.srgb_to_linear())
				st.add_vertex(pts[idx])
	st.generate_normals()
	var m=StandardMaterial3D.new()
	m.vertex_color_use_as_albedo=true
	m.roughness=0.95
	Geo.mesh(self,st.commit(),Vector3.ZERO,EdoEnvironment.ground(area_index),true)
	# Checker-cut coastal escarpments, composed as massive geological blocks.
	for side in [-1,1]:
		for zi in range(25):
			for row in range(4):
				var z=playable_bounds.position.y+zi*playable_bounds.size.y/24
				var x=side*(playable_bounds.end.x+3+sin(zi*1.7)*1.3)
				Geo.box(self,Vector3(x,-7+row*3.5,z),Vector3(5.0,3.48,6.98),EdoEnvironment.material("987247" if (zi+row)%2 else "bb9359"),true)
	for i in range(11):
		var x=playable_bounds.position.x+18+i*(playable_bounds.size.x-36)/10
		var h=15+rng.randf()*16
		Geo.cylinder(self,Vector3(x,h/2-2,playable_bounds.position.y-6),9,h,EdoEnvironment.material("927c59"),true,6)
		Geo.cylinder(self,Vector3(x,h-1,playable_bounds.position.y-6),7.1,2.8,EdoEnvironment.material("3e8f55"),false,5.7)
		for layer in range(int(h/3)):
			Geo.cylinder(self,Vector3(x,layer*3-1,playable_bounds.position.y-6),9.1-layer*0.24,1.45,EdoEnvironment.material("a58a5b" if layer%2 else "847553"),false,8.5-layer*0.22)
	# Distant sea stacks frame the coast.
	for i in range(18):
		var x=rng.randf_range(-220,220)
		var z=rng.randf_range(85,190)
		Geo.cylinder(self,Vector3(x,-1,z),rng.randf_range(4,11),rng.randf_range(8,28),EdoEnvironment.material("548b91"),false,3)

func water():
	var shader=Shader.new()
	shader.code="""shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 deep_color : source_color = vec4(0.025,0.23,0.52,1.0);
void vertex(){ VERTEX.y += sin(VERTEX.x*0.17+TIME*0.9)*0.10 + cos(VERTEX.z*0.22+TIME)*0.08; }
void fragment(){float w=sin(UV.x*260.0+sin(UV.y*180.0+TIME)*2.0+TIME)*sin(UV.y*280.0-TIME); float foam=smoothstep(0.82,1.0,w); ALBEDO=deep_color.rgb+vec3(0.12,0.24,0.20)*foam; ROUGHNESS=0.85; METALLIC=0.0;}
"""
	water_material=ShaderMaterial.new()
	water_material.shader=shader
	var plane=PlaneMesh.new()
	plane.size=Vector2(800,800)
	plane.subdivide_width=70
	plane.subdivide_depth=70
	Geo.mesh(self,plane,Vector3(0,-2.4,0),water_material)
	for z in range(-75,55,4):
		Geo.box(self,Vector3(24+3*sin(z*0.055),-0.18,z),Vector3(8.0,0.10,4.3),water_material)
	# Cascades spill from the high ridge into the river.
	var cascade=ShaderMaterial.new()
	var s=Shader.new()
	s.code="""shader_type spatial; render_mode unshaded; void fragment(){float stripe=sin(UV.x*65.0+sin(UV.y*12.0-TIME*5.0)); ALBEDO=mix(vec3(0.22,0.73,0.85),vec3(0.85,1.0,0.96),smoothstep(-0.5,0.7,stripe));}"""
	cascade.shader=s
	for i in range(3):
		Geo.box(self,Vector3(24+i*1.7,8-i*1.0,-73+i*2.0),Vector3(2.5,19-i*2.0,0.45),cascade)
		for j in range(5): Geo.sphere(self,Vector3(22+i*2+rng.randf()*4,0.2,-70+rng.randf()*5),Vector3(1.3,0.18,1.5),EdoEnvironment.material("c2f4e5",0,0.2))

func path_segment(a: Vector3,b: Vector3,width: float):
	var dist=a.distance_to(b)
	for i in range(int(dist/1.4)+1):
		var p=a.lerp(b,float(i)/maxf(1,int(dist/1.4)))
		p.y=height_at(p.x,p.z)+0.035
		var stone=Geo.cylinder(self,p,width*0.5,0.10,EdoEnvironment.material("d6c599"),false)
		stone.scale.z=0.65
		stone.rotation.y=rng.randf()*0.2

func paths():
	path_segment(Vector3(0,0,44),Vector3(-8,0,-29),4.8)
	path_segment(Vector3(-4,0,-8),Vector3(16,0,-8),4)
	path_segment(Vector3(32,0,-8),Vector3(45,0,-36),4)
	path_segment(Vector3(-7,0,8),Vector3(-43,0,-5),3)
	path_segment(Vector3(-43,0,-5),Vector3(-23,0,-36),3)

func roof(p: Vector3, w: float, d: float, h: float):
	var visual=GameAssets.place(self,"architecture/temple_roof",p,Vector3(w/10,h/2.8,d/10))
	GameAssets.collision_for(visual)
	visual.hide() # Original roof remains the exact collision/camera-probe source.
	GameAssets.place(self,"edo/roof",p,Vector3(w/10,h/2.8,d/10))

func temple(x: float,z: float,w: float,d: float,levels: int):
	var y=height_at(x,z)
	var stone=EdoEnvironment.material("8b9992")
	Geo.box(self,Vector3(x,y+0.35,z),Vector3(w+2,0.7,d+2),stone,true)
	# Stairs meet the sloping terrain at their foot and the platform at their crest.
	var front_z=z+d/2+8.0
	var back_z=z+d/2+0.8
	var front_y=height_at(x,front_z)+0.025
	var back_y=y+0.71
	var rise=back_y-front_y
	for i in range(16):
		var t=float(i+1)/16.0
		var top_y=lerpf(front_y,back_y,t)
		Geo.box(self,Vector3(x,(front_y+top_y)/2-0.08,lerpf(front_z,back_z,t)),Vector3(w*0.6,top_y-front_y+0.16,0.48),stone)
	var ramp=Geo.box(self,Vector3(x,(front_y+back_y)/2-0.12,(front_z+back_z)/2),Vector3(w*0.6,0.24,sqrt(7.2*7.2+rise*rise)),stone,true)
	ramp.rotation.x=atan2(rise,7.2)
	for level in range(levels):
		var ly=y+0.7+level*4.5
		var lw=w*pow(0.76,level)
		var ld=d*pow(0.76,level)
		if level>0: Geo.box(self,Vector3(x,ly,z),Vector3(lw,0.35,ld),EdoEnvironment.material("923c2c"),true)
		for sx in [-1,1]:
			for sz in [-1,1]:
				Geo.cylinder(self,Vector3(x+sx*(lw/2-0.55),ly+1.8,z+sz*(ld/2-0.55)),0.30,3.6,EdoEnvironment.material("bf4532"),true)
			Geo.box(self,Vector3(x+sx*lw*0.49,ly+1.4,z),Vector3(0.18,2.6,ld*0.64),EdoEnvironment.material("eee0bc"),true)
			for k in range(6): Geo.box(self,Vector3(x+sx*lw*0.50,ly+1.4,z-ld*0.27+k*ld*0.108),Vector3(0.22,2.6,0.09),EdoEnvironment.material("724634"))
		Geo.box(self,Vector3(x,ly+3.1,z+ld/2-0.3),Vector3(lw,0.45,0.42),EdoEnvironment.material("ad3d30"))
		Geo.box(self,Vector3(x,ly+3.1,z-ld/2+0.3),Vector3(lw,0.45,0.42),EdoEnvironment.material("ad3d30"))
		roof(Vector3(x,ly+3.55,z),lw+3.6,ld+3.6,2.8)
		EdoEnvironment.temple_details(self,x,z,ly,lw,ld)
		for sx in [-1,1]: lantern(Vector3(x+sx*(lw/2-0.4),ly+2.3,z+ld/2+0.2),false)
	# Interior altar and tall illuminated crest.
	Geo.box(self,Vector3(x,y+1.1,z-d*0.27),Vector3(3,0.8,1.2),EdoEnvironment.material("88342a"),true)
	var crest=Geo.torus(self,Vector3(x,y+2.8,z-d*0.29),0.65,0.80,EdoEnvironment.material("ffd47a",0.6,0.3))
	crest.rotation.x=PI/2

func torii(x: float,z: float,width: float=8.0):
	var y=height_at(x,z)
	GameAssets.place(self,"edo/torii",Vector3(x,y,z),Vector3(width/8,1,1))
	# Keep the established obstacle footprint and collision layers.
	for side in [-1,1]:
		Geo.cylinder(self,Vector3(x+side*width*0.36,y+2.7,z),0.34,5.4,EdoEnvironment.material("d84a32"),true).hide()
		Geo.cylinder(self,Vector3(x+side*width*0.36,y+0.3,z),0.44,0.6,EdoEnvironment.material("29454e"),true).hide()

func lantern(p: Vector3,post: bool=true):
	if post:
		Geo.cylinder(self,p+Vector3(0,1,0),0.10,2,EdoEnvironment.material("634638"),true)
		p.y+=2
	GameAssets.place(self,"edo/lantern",p)

func architecture():
	temple(-10,-38,19,14,3)
	temple(-34,-43,9,8,2)
	temple(48,-50,15,11,2)
	temple(-23,21,8,7,1)
	torii(0,32,9)
	torii(-7,-23,10)
	torii(44,-27,9)
	# Walkable arched vermilion bridge: every deck segment has matching collision.
	var bridge_y=height_at(12,-8)-0.10
	for i in range(30):
		var x=12+i*0.88
		var y=lerpf(bridge_y,height_at(37.52,-8)-0.10,float(i)/29.0)+sin(float(i)/29.0*PI)*1.65
		var deck=Geo.box(self,Vector3(x,y,-8),Vector3(0.93,0.24,5.0),EdoEnvironment.material("a55235"),true)
		deck.rotation.z=cos(float(i)/29.0*PI)*0.195
		deck.hide() # Preserve every original bridge collision segment.
		var boards=GameAssets.place(self,"edo/bridge_deck",deck.position,Vector3(.93,.24,5.0))
		boards.rotation=deck.rotation
		for side in [-1,1]:
			if i%3==0: Geo.box(self,Vector3(x,y+0.68,-8+side*2.35),Vector3(0.17,1.5,0.17),EdoEnvironment.material("d64732"),true)
			Geo.box(self,Vector3(x,y+1.2,-8+side*2.35),Vector3(0.94,0.16,0.20),EdoEnvironment.material("e5663b"))
	# Boss courtyard sits on natural terrain; its rim gives clear arena boundaries.
	var ay=height_at(45,-40)
	Geo.cylinder(self,Vector3(45,ay-0.05,-40),11,0.20,EdoEnvironment.material("a4afa0"),true)
	Geo.torus(self,Vector3(45,ay+0.075,-40),8.6,8.75,EdoEnvironment.material("eacb85"))
	for i in range(12):
		var a=i*TAU/12
		var p=Vector3(45+cos(a)*10.7,ay,-40+sin(a)*10.7)
		if p.z<-34: lantern(p)
	# Rock grotto with open entrance, solid roof, and a passable winding floor.
	for i in range(10):
		var z=5-i*2.6
		var y=height_at(-44,z)
		GameAssets.place(self,"edo/grotto_bay",Vector3(-44,y,z))
		Geo.box(self,Vector3(-44,y+5,z),Vector3(10,1.8,3),EdoEnvironment.material("627870"),true).hide()
		for side in [-1,1]: Geo.box(self,Vector3(-44+side*4.2,y+2,z),Vector3(2,5,3),EdoEnvironment.material("61786c"),true).hide()
		if i%3==0:
			var crystal=Geo.spike(self,Vector3(-41,y,z),Vector3(-41.4,y+1.7,z),0.42,EdoEnvironment.material("58ddd8",0.3,0.5))
			var light=OmniLight3D.new()
			light.position=crystal.position+Vector3(-0.5,0.5,0)
			light.light_color=Color("50ddd2")
			light.omni_range=6
			light.light_energy=0.7
			add_child(light)
	# Ruined columns and a traversable broken sanctuary.
	for i in range(8):
		var p=Vector3(-31+(i%4)*4,0,-13-int(i/4)*7)
		p.y=height_at(p.x,p.z)
		Geo.cylinder(self,p+Vector3(0,1.2,0),0.65,2.4+rng.randf()*2.5,EdoEnvironment.material("99ab91"),true)
		Geo.box(self,p+Vector3(0,0.2,0),Vector3(1.9,0.4,1.9),EdoEnvironment.material("859980"),true)
	for i in range(10): lantern(Vector3(-4 if i%2==0 else 3,height_at(-4,27-i*5),27-i*5))

func tree(p: Vector3, cherry: bool=false, palm: bool=false):
	var h=rng.randf_range(4.5,7)
	# Keep the enlarged grotto portal and its approach readable across seeds.
	if area_index==0 and Vector2(p.x+44,p.z-11).length()<12:return
	var kind="palm" if palm else ("cherry_tree" if cherry else "green_tree")
	if area_index==2 and posmod(roundi(p.x+p.z),4)==0:kind="bamboo"
	var visual=GameAssets.place(self,"edo/"+kind,p,Vector3(1,h/6,1))
	var canopy=visual.find_child("Canopy",true,false)
	if canopy: breeze.append(canopy)
	Geo.beam(self,p,p+Vector3(0.3,h,0.2),0.22 if palm else 0.38,EdoEnvironment.material("735344"),true).hide()

func nature():
	for i in range(108):
		var x=rng.randf_range(-65,65)
		var z=rng.randf_range(-68,49)
		if abs(x+4)<9 or abs(x-(24+3*sin(z*0.055)))<8: continue
		if z<-25 and (abs(x+10)<17 or abs(x-46)<15 or abs(x+34)<9): continue
		if abs(z+8)<5 or (abs(x+44)<7 and z<10): continue
		tree(Vector3(x,height_at(x,z),z),z<15 and i%3!=0,z>22 or i%5==0)
	for i in range(28):
		var x=rng.randf_range(-63,64)
		var z=rng.randf_range(-70,40)
		if abs(x+5)<7 or abs(z+8)<4 or abs(x-24)<8: continue
		var p=Vector3(x,height_at(x,z),z)
		GameAssets.place(self,"edo/moss_rock",p,Vector3(2+rng.randf()*3,1+rng.randf()*2,2+rng.randf()*3)*0.5)
	# Wind-deformed instanced grass keeps the large landscape inexpensive.
	var grass_shader=Shader.new()
	grass_shader.code="""shader_type spatial; render_mode cull_disabled; void vertex(){VERTEX.x += sin(TIME*1.7+MODEL_MATRIX[3].x*0.3+MODEL_MATRIX[3].z)*VERTEX.y*0.17;} void fragment(){ALBEDO=mix(vec3(0.17,0.39,0.20),vec3(0.49,0.68,0.28),UV.y); ROUGHNESS=1.0;}"""
	var gm=ShaderMaterial.new()
	gm.shader=grass_shader
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for turn in range(2):
		for pt in [Vector3(-0.25,0,0),Vector3(0,0.65,0),Vector3(0.25,0,0)]:
			st.set_uv(Vector2(0,pt.y/0.65))
			st.add_vertex(pt.rotated(Vector3.UP,turn*PI/2))
	st.generate_normals()
	var mm=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	var grass_asset=GameAssets.instantiate_model("edo/grass_tuft")
	mm.mesh=grass_asset.find_child("Body",true,false).mesh
	grass_asset.free()
	mm.instance_count=3400
	for i in range(3400):
		var x=rng.randf_range(-69,69)
		var z=rng.randf_range(-72,43)
		var y=height_at(x,z)
		var t=Transform3D(Basis(Vector3.UP,rng.randf()*TAU),Vector3(x,y,z))
		if abs(x+4)<4 or abs(z+8)<3 or abs(x-24)<6: t.origin.y-=3
		mm.set_instance_transform(i,t)
	var inst=MultiMeshInstance3D.new()
	inst.multimesh=mm
	inst.material_override=gm
	add_child(inst)
	for i in range(130):
		var x=rng.randf_range(-52,55)
		var z=rng.randf_range(-55,41)
		if abs(x-24)<7: continue
		var p=Vector3(x,height_at(x,z)+0.23,z)
		Geo.sphere(self,p,Vector3(0.35,0.15,0.35),EdoEnvironment.material(["fff0a4","f291b0","f3b066"][i%3]))

func _process(delta):
	elapsed+=delta
	for i in range(breeze.size()):
		breeze[i].rotation.z=sin(elapsed*1.1+i)*0.018
		var game=get_parent()
		if is_instance_valid(game.camera_rig) and game.playing:
			var cam=game.camera_rig.camera.global_position
			var near=Geometry3D.get_closest_point_to_segment(breeze[i].global_position,game.player.global_position+Vector3.UP*1.5,cam)
			var fade=0.83 if near.distance_to(breeze[i].global_position)<2.1 else 0.0
			breeze[i].transparency=lerpf(breeze[i].transparency,fade,minf(1,delta*8))
	for i in range(birds.size()):
		birds[i].position.x+=delta*(1.5+i*0.07)
		birds[i].position.y+=sin(elapsed*2+i)*delta*0.20
		if birds[i].position.x>80: birds[i].position.x=-80
	for i in range(motes.size()):
		if is_instance_valid(motes[i]) and motes[i].visible:
			motes[i].rotation.y+=delta*1.8
			motes[i].position.y+=sin(elapsed*2+i)*delta*0.18

func atmosphere():
	var mist=GPUParticles3D.new()
	mist.position=Vector3(26,0.4,-69)
	mist.amount=90
	mist.lifetime=2.3
	mist.visibility_aabb=AABB(Vector3(-9,-3,-9),Vector3(18,12,18))
	var pm=ParticleProcessMaterial.new()
	pm.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents=Vector3(3,0.15,2)
	pm.direction=Vector3.UP
	pm.spread=60
	pm.initial_velocity_min=1.2
	pm.initial_velocity_max=3.8
	pm.gravity=Vector3(0,-1.8,0)
	pm.scale_min=0.12
	pm.scale_max=0.42
	var grad=Gradient.new()
	grad.set_color(0,Color(0.75,0.98,1,0.55))
	grad.set_color(1,Color(0.85,1,1,0))
	var tex=GradientTexture1D.new()
	tex.gradient=grad
	pm.color_ramp=tex
	mist.process_material=pm
	var sphere=SphereMesh.new()
	sphere.radius=0.5
	sphere.height=1
	sphere.radial_segments=8
	sphere.rings=4
	var mat=StandardMaterial3D.new()
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo=true
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material=mat
	mist.draw_pass_1=sphere
	add_child(mist)
	var petals=GPUParticles3D.new()
	petals.position=Vector3(-5,8,-10)
	petals.amount=100
	petals.lifetime=12
	petals.preprocess=6
	petals.visibility_aabb=AABB(Vector3(-50,-20,-70),Vector3(100,40,140))
	var pp=ParticleProcessMaterial.new()
	pp.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pp.emission_box_extents=Vector3(39,5,47)
	pp.direction=Vector3(1,-0.2,0)
	pp.initial_velocity_min=0.6
	pp.initial_velocity_max=1.3
	pp.gravity=Vector3(0,-0.14,0)
	pp.angular_velocity_min=-90
	pp.angular_velocity_max=90
	pp.scale_min=0.05
	pp.scale_max=0.11
	pp.color=Color("ffc2d0")
	petals.process_material=pp
	var petal=SphereMesh.new()
	petal.radius=0.5
	petal.height=0.22
	petal.radial_segments=8
	petal.rings=4
	petal.material=EdoEnvironment.material("f9abc3")
	petals.draw_pass_1=petal
	add_child(petals)
	for i in range(7):
		var p=Vector3(-120+i*39,43+sin(i*2)*5,-135)
		for j in range(3): Geo.sphere(self,p+Vector3(j*5,sin(j*2)*2,0),Vector3(16,5,9),EdoEnvironment.material("d8f0e9"))
