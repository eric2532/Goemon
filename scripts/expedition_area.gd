class_name ExpeditionArea
extends Sanctuary

var centers: Array[Vector3]=[]
var routes: Array=[]
var enemy_spawns: Array[Vector2]=[]
var boss_position=Vector3.ZERO
var exit_point=Vector3.ZERO
var entrance_point=Vector3.ZERO
var seed_offset=0.0

func base_height(x: float,z: float)->float:
	return 2.0+(52-clampf(z,-125,85))*0.018+sin((x+seed_offset)*0.045)*0.65+cos(z*0.04)*0.55

func height_at(x: float,z: float)->float:
	var h=base_height(x,z)
	for c in centers:
		var dist=Vector2(x-c.x,z-c.z).length()
		if dist<14: h=lerpf(base_height(c.x,c.z),h,smoothstep(10,14,dist))
	return WorldExpansion.flatten(self,x,z,h)

func raw_height(x: float,z: float)->float:return base_height(x,z)

func plan_layout():
	rng.seed=generation_seed
	seed_offset=rng.randf_range(-80,80)
	centers=[Vector3(0,0,64),Vector3(rng.randf_range(-49,-35),0,30),Vector3(rng.randf_range(30,47),0,rng.randf_range(0,12)),Vector3(rng.randf_range(-42,-27),0,-28),Vector3(rng.randf_range(-14,24),0,-67)]
	for i in range(centers.size()): centers[i].y=base_height(centers[i].x,centers[i].z)
	routes=[]
	for i in range(4): routes.append([centers[i],centers[i+1]])
	routes.append([centers[1],centers[3]])
	routes.append([centers[2],centers[4]])
	boss_position=centers[4]
	exit_point=Vector3(boss_position.x+24,0,boss_position.z)
	exit_point.y=height_at(exit_point.x,exit_point.z)
	entrance_point=Vector3(0,height_at(0,77),77)
	spawn_point=Vector3(0,height_at(0,60)+0.3,60)
	routes.append([centers[4],exit_point])
	routes.append([centers[0],entrance_point])
	enemy_spawns=[]
	for i in range(1,4):
		for j in range(4):
			var a=j*TAU/4+rng.randf_range(-0.3,0.3)
			enemy_spawns.append(Vector2(centers[i].x+cos(a)*7,centers[i].z+sin(a)*7))
	landmarks={}
	landmarks[["", "JADE LANTERN HALL", "PETAL GARDEN", "VERMILION BASTION"][area_index]]=centers[1]
	landmarks[["", "CRYSTAL COURT", "SAKURA PAVILION", "SUNFORGE COURT"][area_index]]=centers[4]

func _ready():
	playable_bounds=WorldExpansion.bounds(area_index)
	plan_layout()
	WorldExpansion.plan(self)
	lighting()
	for n in get_children():
		if n is WorldEnvironment and area_index==1:
			n.environment.fog_light_color=Color("446c83")
			n.environment.fog_density=0.004
			n.environment.ambient_light_color=Color("a4ccd9")
			n.environment.ambient_light_energy=0.48
		if n is DirectionalLight3D and area_index==3:
			n.light_color=Color("ffd7a0")
	floor_mesh()
	for route in routes: path_segment(route[0],route[1],5.8)
	for i in range(centers.size()):
		var c=centers[i]
		Geo.cylinder(self,c-Vector3.UP*0.045,11.2 if i<4 else 14,0.16,Geo.mat("99b2a2" if area_index==1 else "d0bd92"),true)
		Geo.torus(self,c+Vector3.UP*0.045,10.3 if i<4 else 13.1,10.45 if i<4 else 13.3,Geo.mat("cba95f",0.2))
		if i>0:
			for side in [-1,1]: lantern(c+Vector3(side*10,0,3))
	var boss=centers[4]
	temple(boss.x,boss.z-17,17,9,2 if area_index==1 else 3)
	temple(centers[1].x-11,centers[1].z-7,8,7,1)
	torii(centers[0].x,centers[0].z-8,9)
	torii(boss.x,boss.z+12,9)
	confine()
	dress_area()
	if area_index!=1: atmosphere()
	make_trail_motes()
	WorldExpansion.dress(self)

func floor_mesh():
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors=[Color("62ad57"),Color("477e78"),Color("70a866"),Color("b58b5a")]
	var edge=playable_bounds.grow(5)
	for xi in range(ceili(edge.size.x/2.5)):
		for zi in range(ceili(edge.size.y/2.5)):
			var x=edge.position.x+xi*2.5
			var z=edge.position.y+zi*2.5
			var points=[Vector3(x,height_at(x,z),z),Vector3(x+2.5,height_at(x+2.5,z),z),Vector3(x,height_at(x,z+2.5),z+2.5),Vector3(x+2.5,height_at(x+2.5,z+2.5),z+2.5)]
			var c=colors[area_index].lightened(0.025 if (xi+zi)%3==0 else 0)
			for idx in [0,1,2,1,3,2]:
				st.set_color(c.srgb_to_linear())
				st.add_vertex(points[idx])
	st.generate_normals()
	var material=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=0.95
	Geo.mesh(self,st.commit(),Vector3.ZERO,material,true)

func confine():
	var rock=Geo.mat("405d68" if area_index==1 else ("946d4f" if area_index==3 else "6a8165"))
	WorldExpansion.walls(self,rock)
	for side in [-1,1]:
		for i in range(16):
			var p=Vector3(side*(playable_bounds.end.x-1),8,playable_bounds.position.y+i*playable_bounds.size.y/15)
			Geo.cylinder(self,p,5.5,20+rng.randf()*8,rock,false,4.2)
			if area_index!=1: Geo.sphere(self,p+Vector3(0,12,0),Vector3(11,3,11),Geo.mat("548954"))
	if area_index==1:
		# Solid cavern roof with skylight slots; camera probes collide with it.
		for x in [-78,-39,0,39,78]:
			Geo.box(self,Vector3(x,26,-10),Vector3(33,4,190),rock,true)
			for z in [-90,-45,0,45,75]:
				Geo.spike(self,Vector3(x,22,z),Vector3(x+2,17,z+1),2.2,rock)

func clear_route(p: Vector3)->bool:
	for c in centers:
		if Vector2(p.x-c.x,p.z-c.z).length()<14: return false
	for route in routes:
		var a=Vector3(route[0].x,0,route[0].z)
		var b=Vector3(route[1].x,0,route[1].z)
		if Geometry3D.get_closest_point_to_segment(Vector3(p.x,0,p.z),a,b).distance_to(Vector3(p.x,0,p.z))<6: return false
	# Keep the temple approaches, doorways and exit pad unobstructed.
	if p.z<boss_position.z-4 and absf(p.x-boss_position.x)<17: return false
	return true

func dress_area():
	for i in range(145):
		var p=Vector3(rng.randf_range(-86,86),0,rng.randf_range(-94,78))
		if not clear_route(p): continue
		p.y=height_at(p.x,p.z)
		if area_index==1:
			for j in range(4):
				var start=p+Vector3(j*0.4,0,sin(j)*0.5)
				Geo.spike(self,start,start+Vector3(rng.randf_range(-0.4,0.4),rng.randf_range(1.2,3.1),0),0.43,Geo.mat("59cbbb" if i%2 else "8b9ad9",0.25,0.25))
			if i%8==0:
				var light=OmniLight3D.new()
				light.position=p+Vector3.UP*2
				light.light_color=Color("58dbca")
				light.light_energy=1.2
				light.omni_range=9
				add_child(light)
		elif area_index==2: tree(p,true,false)
		elif i%3==0: tree(p,false,true)
		else:
			Geo.cylinder(self,p+Vector3.UP*2,0.75,4,Geo.mat("ab7351"),true,0.65)
			Geo.box(self,p+Vector3.UP*4,Vector3(2,0.4,2),Geo.mat("e1b45f"),true)
	for i in range(38):
		var p=Vector3(rng.randf_range(-86,86),0,rng.randf_range(-94,78))
		if not clear_route(p): continue
		p.y=height_at(p.x,p.z)
		GameAssets.place(self,"environments/moss_rock",p+Vector3.UP*0.35,Vector3(1.2,0.8,1.1))
	# A real rock tunnel is an alternative route between the middle courts.
	var z=centers[3].z
	var x=centers[3].x
	for k in range(4):
		var p=Vector3(x,height_at(x,z+7+k*2.5),z+7+k*2.5)
		for side in [-1,1]: Geo.box(self,p+Vector3(side*4.7,2.5,0),Vector3(2,5.5,2.7),Geo.mat("536d68"),true)
		Geo.box(self,p+Vector3(0,5.5,0),Vector3(11,1.1,2.7),Geo.mat("536d68"),true)

func make_trail_motes():
	for route in routes:
		for j in range(1,5):
			var p=route[0].lerp(route[1],j/5.0)
			p.y=height_at(p.x,p.z)+1
			var mote=Node3D.new()
			add_child(mote)
			mote.position=p
			Geo.sphere(mote,Vector3.ZERO,Vector3(0.28,0.44,0.28),Geo.mat("ffe78c",0.5,0.7))
			var ring=Geo.torus(mote,Vector3.ZERO,0.30,0.34,Geo.mat("ffdc70",0.5,0.4))
			ring.rotation.x=PI/2
			motes.append(mote)
