class_name TidefallTown
extends Node3D
## Main-area-only streets and closed buildings, outside the original routes/courts.
## No seeded RNG calls; all original world collision owners are retained.
var world # Avoid a circular script dependency with Sanctuary, which owns this node.
var buildings: Array[Node3D]=[]
var footprints: Array[Rect2]=[]
var streets: Array=[]
const HEIGHTS={"timber_house":5.6,"noren_shop":4.4,"corner_house":5.6,"plaster_storehouse":4.4,"two_story_inn":6.7}

static func layout()->Array:
	var result=[]
	# Aligned frontages with 7m cross-passages preserve short enemy approaches.
	for i in range(3):
		result.append([Vector2(-15,45-i*15),PI/2,["two_story_inn","noren_shop","timber_house"][i]])
		result.append([Vector2(5 if i==2 else 10,50 if i==0 else 45-i*15),-PI/2,["corner_house","noren_shop","plaster_storehouse"][i]])
	# Relocated inn anchors the residential entrance; the plaza stays open.
	result.append([Vector2(-60,60),PI/2,"two_story_inn"])
	result.append([Vector2(-15,-14),PI/2,"plaster_storehouse"])
	result.append([Vector2(10,-20),-PI/2,"noren_shop"])
	result.append([Vector2(10,-33),-PI/2,"timber_house"])
	# Waterfront street has staggered blocks and open cross-passages to the bridge.
	for i in range(5):
		result.append([Vector2(39,60-i*15),PI/2,["timber_house","plaster_storehouse","noren_shop","timber_house","corner_house"][i]])
		result.append([Vector2(56,45-i*15),-PI/2,["corner_house","noren_shop","timber_house","plaster_storehouse","two_story_inn"][i]])
	# Quiet western residential frontage; the grotto approach remains untouched.
	for i in range(4):
		result.append([Vector2(-60,45-i*15),PI/2,["corner_house","timber_house","noren_shop","plaster_storehouse"][i]])
	for i in range(result.size()):result[i].append("tidefall-building-%02d" % (i+1))
	return result

func _ready():
	name="TidefallTown"
	assert(world.area_index==0,"Town dressing belongs only to Tidefall")
	for item in layout():place_building(item[0],item[1],item[2],item[3])
	# Terrain-following visual street surfaces do not flatten terrain or add floor collision.
	street(Vector2(-2,53),Vector2(-2,-19),18)
	street(Vector2(-2,-8),Vector2(13,-8),8)
	street(Vector2(-2,39),Vector2(-52,39),6)
	street(Vector2(-52,65),Vector2(-52,-5),9)
	street(Vector2(-52,13),Vector2(-44,12),5)
	street(Vector2(47.5,65),Vector2(47.5,-24),11)
	street(Vector2(47.5,-8),Vector2(37.52,-8),8)
	street(Vector2(47.5,-24),Vector2(42,-29),6)
	# Tuck foliage inside actual solid houses out of view; retain its old collision.
	# Nothing outside a solid building footprint is removed, including street trees.
	for child in world.get_children():
		if child==self:continue
		if child is Node3D and child.scene_file_path.contains("/edo/"):
			var file=child.scene_file_path.get_file()
			if file in ["cherry_tree.glb","green_tree.glb","palm.glb","moss_rock.glb"] and contains_body(Vector2(child.position.x,child.position.z)):
				child.hide()
		if child is MultiMeshInstance3D and child.multimesh.instance_count==3400:
			for i in range(child.multimesh.instance_count):
				var t=child.multimesh.get_instance_transform(i)
				if contains_body(Vector2(t.origin.x,t.origin.z)) or contains_street(Vector2(t.origin.x,t.origin.z)):
					t.origin.y-=12
					child.multimesh.set_instance_transform(i,t)

func contains_street(p: Vector2)->bool:
	for road in streets:
		if Geometry2D.get_closest_point_to_segment(p,road[0],road[1]).distance_to(p)<road[2]*.5:return true
	return false

func contains_body(p: Vector2)->bool:
	for rect in footprints:
		if rect.has_point(p):return true
	return false

func place_building(p: Vector2,angle: float,kind: String,building_id: String):
	# All frontages face east/west. Body footprint is 6m across X, 8m along Z.
	var rect=Rect2(p-Vector2(3,4),Vector2(6,8))
	footprints.append(rect)
	var y=-INF
	for dx in [-3,3]:
		for dz in [-4,4]:y=maxf(y,world.height_at(p.x+dx,p.y+dz))
	var house=GameAssets.place(self,"town/"+kind,Vector3(p.x,y,p.y))
	house.name=building_id
	house.rotation.y=angle
	house.set_meta("town_variant",kind)
	house.set_meta("footprint",rect)
	buildings.append(house)
	# Filled box hull rejects inside-building spawns and blocks player/projectiles.
	# Surface-only triangle meshes would allow actors to spawn inside closed houses.
	var body=StaticBody3D.new();body.name="ClosedBuildingCollision";house.add_child(body)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new()
	box.size=Vector3(8,HEIGHTS[kind]+2,6)
	shape.shape=box;shape.position.y=(HEIGHTS[kind]-2)/2;body.add_child(shape)
	# The Blender roof (including lean-to) is solid and catches jumps/camera probes.
	GameAssets.collision_for(house.find_child("Roof",true,false))

func street(a: Vector2,b: Vector2,width: float):
	streets.append([a,b,width])
	var side=(b-a).orthogonal().normalized()*width*.5
	var count=ceili(a.distance_to(b)/1.5)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(count):
		var p=a.lerp(b,float(i)/count);var q=a.lerp(b,float(i+1)/count)
		var across=ceili(width/1.5)
		for j in range(across):
			var left=side*lerpf(-1,1,float(j)/across)
			var right=side*lerpf(-1,1,float(j+1)/across)
			for v in [p+left,p+right,q+left,p+right,q+right,q+left]:
				st.add_vertex(Vector3(v.x,world.height_at(v.x,v.y)+.095,v.y))
	st.generate_normals()
	var paving=Geo.mesh(self,st.commit(),Vector3.ZERO,EdoEnvironment.surface("sand"))
	paving.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
