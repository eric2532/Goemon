extends Node3D
# A scattered archipelago with occasional cloud crossings and free-flight gaps.
const COLUMNS=8
const ROWS=7
const PER_LAYER=COLUMNS*ROWS
const LAYERS=14
const COUNT=PER_LAYER*LAYERS
const DROP=52.0
const RADIUS=11.5
const BRIDGES_PER_LAYER=0
const CLUSTER_SIZE=7
const NAMES=["DAWN CROWN","SILK CLOUD","JADE PERCH","WIND CHAPEL","SUNLIT STEP","CLOUD GARDEN","AMBER REST","RAIN SHRINE","BLUE LANTERN","DRIFTWOOD","MOSS CITADEL","LAST CLOUD","LOWER WATCH","HOMEWARD"]
var islands: Array[Vector3]=[]
var world: Node3D
var ground_point=Vector3.ZERO
var markers: Array[Node3D]=[]
var clouds: Array[Node3D]=[]
var cloud_origins: Array[Vector3]=[]
var cloud_sizes: Array[Vector2]=[]
var bridges: Array[Vector2i]=[]
var cedar_count=0
var outlines: Array[PackedVector2Array]=[]
var radii: Array[float]=[]
var shape_ids: Array[int]=[]
var island_sizes: Array[float]=[]
var jump_routes: Array[Vector2i]=[]
var shape_kit=preload("res://scripts/island_shapes.gd").new()

func _ready():
	ground_point=world.outposts[0]+Vector3.UP*.15
	var bounds=world.playable_bounds.grow(-55)
	var center=Vector3(bounds.get_center().x,ground_point.y,bounds.get_center().y)
	# Local seed keeps retries stable and does not perturb combat randomness.
	var rng=RandomNumberGenerator.new();rng.seed=world.generation_seed
	var clusters: Array[Vector3]=[]
	var cluster_angles: Array[float]=[]
	for i in range(COUNT):
		var layer=layer_of(i)
		var slot=i%PER_LAYER
		var cluster=floori(slot/float(CLUSTER_SIZE));var member=slot%CLUSTER_SIZE
		if member==0:
			var column=cluster%4;var row=floori(cluster/4.0)
			clusters.append(Vector3(lerpf(bounds.position.x+80,bounds.end.x-80,column/3.0)+rng.randf_range(-24,24),ground_point.y+(LAYERS-layer)*DROP,lerpf(bounds.position.y+85,bounds.end.y-85,row)+rng.randf_range(-28,28)))
			cluster_angles.append(rng.randf_range(-PI,PI))
		var shape_id=rng.randi_range(0,shape_kit.OUTLINES.size()-1)
		var size=rng.randf_range(1.15,1.5) if member==0 else rng.randf_range(.78,1.22)
		var angle=rng.randf_range(-PI,PI)
		var outline=PackedVector2Array();var radius=0.0
		for vertex in shape_kit.OUTLINES[shape_id]:
			var rotated=Vector3(vertex.x,0,vertex.y).rotated(Vector3.UP,angle)*size
			outline.append(Vector2(rotated.x,rotated.z));radius=maxf(radius,rotated.length())
		outlines.append(outline);radii.append(radius);shape_ids.append(shape_id);island_sizes.append(size)
		var point=clusters[-1]
		if member>0:
			var hub=i-member
			var bearing=cluster_angles[-1]+(member-1)*TAU/6+rng.randf_range(-.045,.045)
			# Real air gaps remain between nearby islands. Sprint/double jump can
			# cross these; the longer gaps between groups invite descending/flight.
			point+=Vector3(cos(bearing),0,sin(bearing))*(radii[hub]+radius+rng.randf_range(7,10))
			jump_routes.append(Vector2i(hub,i))
		islands.append(point)
		shape_kit.place(self,shape_id,point,angle,size)
		var marker=Node3D.new();add_child(marker);marker.position=point;markers.append(marker)
		Geo.torus(marker,Vector3.UP*.09,2.4,2.48,Geo.mat("d1c792",.1,.25))
		var label=Label3D.new();label.text="%02d · %s" % [i+1,island_name(i)];label.position=Vector3(0,5.5,0);label.visibility_range_end=110;label.font_size=36;label.pixel_size=.017;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color("fff0c1");marker.add_child(label)
		var id=["cloud_pine","sakura","cedar","torii","bamboo_cluster"][i%5]
		var prop=load("res://assets/models/cedar_pass/"+id+".glb").instantiate()
		add_child(prop);prop.position=interior_point(i,angle-PI/2,.7);prop.scale=Vector3.ONE*(.7 if id=="torii" else .65)
		for mesh in prop.find_children("*","MeshInstance3D",true,false):mesh.material_override=preload("res://assets/models/cedar_pass/shared_matte.tres");mesh.visibility_range_end=180
		cedar_count+=1
		# Small isolated resting clouds, always below the island plane; never roads.
		if rng.randf()<.32:
			for attempt in range(6):
				var bearing=rng.randf_range(-PI,PI)
				var cloud_point=point+Vector3(cos(bearing)*(radius+16),-rng.randf_range(18,28),sin(bearing)*(radius+16))
				var clear=true
				for previous in cloud_origins:
					if absf(previous.y-cloud_point.y)<14 and Vector2(previous.x-cloud_point.x,previous.z-cloud_point.z).length()<22:clear=false;break
				if clear:
					add_cloud(cloud_point,rng.randf_range(-PI,PI),Vector3(rng.randf_range(.65,1),1,rng.randf_range(.9,1.3)));break
	var halo=GameAssets.place(self,"sky_descent/sun_halo",center+Vector3(100,LAYERS*DROP+100,-340),Vector3.ONE*3.7)
	halo.rotation_degrees.x=65
	for mesh in halo.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Geo.torus(self,ground_point+Vector3.UP*.06,5.0,5.12,Geo.mat("ffdc80",.15,.7)).name="GroundArrivalSeal"

func add_cloud(point: Vector3,angle: float,size: Vector3):
	var cloud=GameAssets.place(self,"sky_descent/cloud_platform_"+str(clouds.size()%2),point,size)
	cloud.rotation.y=angle;clouds.append(cloud);cloud_origins.append(point);cloud_sizes.append(Vector2(size.x*9.0,size.z*4.0))
	GameAssets.collision_for(cloud,true)
	for body in cloud.find_children("*","StaticBody3D",true,false):body.set_meta("sky_cloud_index",clouds.size()-1)
	for mesh in cloud.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.visibility_range_end=480;mesh.visibility_range_end_margin=40

func layer_of(index: int)->int:return floori(index/float(PER_LAYER))

func layer_at_height(height: float)->int:
	return clampi(floori((ground_point.y+LAYERS*DROP-height+2)/DROP),0,LAYERS-1)

func island_name(index: int)->String:
	return NAMES[layer_of(index)]+" · "+String.chr(65+(index%PER_LAYER)%COLUMNS)+str(1+floori((index%PER_LAYER)/float(COLUMNS)))

func enemy_count(index: int)->int:return 4+mini(6,floori(layer_of(index)/2.0))

func total_enemies()->int:
	var total=0
	for i in range(COUNT):total+=enemy_count(i)
	return total

func next_point(index: int)->Vector3:
	return islands[index+PER_LAYER] if index+PER_LAYER<islands.size() else ground_point

func island_at(point: Vector3,tolerance: float=1.0)->int:
	var layer=layer_at_height(point.y)
	# Adjacent layers cover queries near the layer boundary, including tolerances.
	for i in range(maxi(0,layer-1)*PER_LAYER,mini(LAYERS,layer+2)*PER_LAYER):
		if absf(point.y-islands[i].y)<tolerance and contains_point(i,point):return i
	return -1

func contains_point(index: int,point: Vector3,margin: float=0.0)->bool:
	var local=Vector2(point.x-islands[index].x,point.z-islands[index].z)
	if local.length_squared()>radii[index]*radii[index]:return false
	var polygon=outlines[index]
	if not Geometry2D.is_point_in_polygon(local,polygon):return false
	if margin>0:
		for i in range(polygon.size()):
			if local.distance_to(Geometry2D.get_closest_point_to_segment(local,polygon[i],polygon[(i+1)%polygon.size()]))<margin:return false
	return true

func interior_point(index: int,angle: float,fraction: float=.65)->Vector3:
	var direction=Vector2(cos(angle),sin(angle))
	var edge=radii[index]
	var polygon=outlines[index]
	for i in range(polygon.size()):
		var hit=Geometry2D.segment_intersects_segment(Vector2.ZERO,direction*(radii[index]+1),polygon[i],polygon[(i+1)%polygon.size()])
		if hit!=null:edge=minf(edge,hit.length())
	return islands[index]+Vector3(direction.x,0,direction.y)*edge*fraction

func cloud_at(point: Vector3,tolerance: float=1.0)->int:
	var hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.25,point-Vector3.UP*tolerance,1))
	return int(hit.collider.get_meta("sky_cloud_index")) if not hit.is_empty() and hit.collider.has_meta("sky_cloud_index") else -1

func surface_height(point: Vector3)->float:
	# Query the actual mesh: cloud rims, gaps and sloped bedrock stay consistent
	# with teleport/meteor placement rather than inventing an invisible surface.
	var bottom=world.height_at(point.x,point.z)
	var hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,Vector3(point.x,bottom-5,point.z),1))
	return hit.position.y if not hit.is_empty() else bottom

func nearby_islands(point: Vector3,limit: int=10)->Array:
	var candidates=[]
	var layer=layer_at_height(point.y)
	for i in range(maxi(0,layer-2)*PER_LAYER,mini(LAYERS,layer+3)*PER_LAYER):
		if absf(islands[i].y-point.y)>DROP*1.7:continue
		# Compute distances once instead of inside every sort comparison.
		candidates.append(Vector2(islands[i].distance_squared_to(point),i))
	candidates.sort()
	var result=[]
	for i in range(mini(limit,candidates.size())):result.append(int(candidates[i].y))
	return result

func highlight(index: int):
	var point=islands[index]
	var game=world.get_parent()
	if is_instance_valid(game.get("player")):point=game.player.position
	for i in range(markers.size()):markers[i].visible=islands[i].distance_squared_to(point)<220*220

