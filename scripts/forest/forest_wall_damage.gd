extends Node3D
## Surface fractures only. Health, navigation and collision remain model-owned.
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const FRACTURE_SHADER=preload("res://scripts/forest/forest_wall_damage.gdshader")
const IMPACT_SECONDS=.22
var stage:int=0
var impact_left:float=0.0
var last_hp:float=-1.0
var _gate:MeshInstance3D
var _material:ShaderMaterial
var _vertices=PackedVector3Array()
var _normals=PackedVector3Array()
var _uvs=PackedVector2Array()
var _colors=PackedColorArray()
var _indices=PackedInt32Array()
var _length:float
var _center:float
var _is_gate:bool=false

func setup(building:Dictionary,length_:float=Profile.GATE_DOOR_WIDTH,center_x:float=0.0):
	name="WallDamage"
	_length=length_;_center=center_x;_is_gate=building.kind=="gate"
	if _is_gate:_gate=get_parent().get_node("GateDoor")
	var rng=RandomNumberGenerator.new();rng.seed=int(building.id)*7919+113
	var height=Profile.GATE_DOOR_HEIGHT if _is_gate else 15.3
	# A fracture in each masonry bay makes the first hit legible at eye level
	# from either approach, even on a long six-cell wall section.
	var bays=maxi(1,ceili(_length/6.0))
	for side in [-1.0,1.0]:
		for bay in (bays if _is_gate else bays+1):
			var x=_center+_length*((bay+.5)/bays-.5) if _is_gate else _center+_length*(float(bay)/bays-.5)
			x=clampf(x,_center-_length*.5+.8,_center+_length*.5-.8)
			_fracture(rng,x,height,side,false)
	# Short faces also show damage when a player approaches a wall endpoint.
	for side in [-1.0,1.0]:
		_fracture(rng,0.0,height,side,true)
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=_vertices;arrays[Mesh.ARRAY_NORMAL]=_normals
	arrays[Mesh.ARRAY_TEX_UV]=_uvs;arrays[Mesh.ARRAY_COLOR]=_colors;arrays[Mesh.ARRAY_INDEX]=_indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_material=ShaderMaterial.new();_material.shader=FRACTURE_SHADER
	var cracks=MeshInstance3D.new();cracks.name="Fractures";cracks.mesh=mesh
	cracks.material_override=_material;cracks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cracks)
	_vertices.clear();_normals.clear();_uvs.clear();_colors.clear();_indices.clear()
	hide()

func sync_health(hp:float,max_hp:float,delta:float):
	var damage=clampf(1.0-hp/maxf(1.0,max_hp),0.0,1.0)
	var next_stage=0 if damage<=0.0 else (4 if damage>=.8 else (3 if damage>=.55 else (2 if damage>=.25 else 1)))
	var previous_impact=impact_left
	impact_left=maxf(0.0,impact_left-maxf(0.0,delta))
	if last_hp>=0.0:
		if hp<last_hp:impact_left=IMPACT_SECONDS
		elif hp>last_hp:impact_left=0.0
	last_hp=hp
	if stage!=next_stage:
		stage=next_stage;_material.set_shader_parameter("damage_stage",float(stage))
	visible=stage>0
	if stage==0:impact_left=0.0
	if impact_left!=previous_impact:_material.set_shader_parameter("impact",impact_left/IMPACT_SECONDS)
	if _is_gate and is_instance_valid(_gate):position.y=_gate.position.y-Profile.GATE_CLOSED_Y

func _fracture(rng:RandomNumberGenerator,x:float,height:float,side:float,endcap:bool):
	var face_width=(Profile.GATE_DOOR_THICKNESS if _is_gate else Profile.WALL_THICKNESS) if endcap else _length
	var min_x=-face_width*.5+.07 if endcap else _center-_length*.5+.08
	var max_x=face_width*.5-.07 if endcap else _center+_length*.5-.08
	var spread=minf(1.45,face_width*.28)
	var point=Vector2(x+rng.randf_range(-.15,.15),.9 if not _is_gate else .3)
	point.x=clampf(point.x,min_x,max_x)
	var steps=18
	var trunk:Array[Vector2]=[point]
	for i in range(1,steps+1):
		var y=lerpf(trunk[0].y,height-.1,(float(i)+rng.randf_range(-.23,.0))/steps)
		var drift=clampf(point.x-x+rng.randf_range(-.68,.68),-spread*.58,spread*.58)
		var next=Vector2(clampf(x+drift,min_x,max_x),y)
		var tier=1 if i<=5 else (2 if i<=9 else (3 if i<=13 else 4))
		_ribbon(point,next,(.16 if not endcap else .12)*rng.randf_range(.7,1.05),tier,side,endcap)
		trunk.append(next);point=next
	# Branches start at existing joints; sharp asymmetric forks avoid a painted
	# zigzag pattern while each new tier extends the same persistent damage.
	for branch in [3,6,9,12,15]:
		var start:Vector2=trunk[branch]
		var sign_=-1.0 if branch%2==0 else 1.0
		var reach=spread*rng.randf_range(.65,1.15)
		var tip=Vector2(clampf(start.x+sign_*reach,min_x,max_x),minf(height-.12,start.y+rng.randf_range(.4,1.3)))
		var middle=start.lerp(tip,.5)+Vector2(sign_*.12,-.22)
		middle.x=clampf(middle.x,min_x,max_x)
		var tier=2 if branch<=6 else (3 if branch<=12 else 4)
		_ribbon(start,middle,.11,tier,side,endcap)
		_ribbon(middle,tip,.065,tier,side,endcap)
		if branch in [6,12]:
			var fork=Vector2(clampf(middle.x+sign_*reach*.5,min_x,max_x),maxf(.25,middle.y-.8))
			_ribbon(middle,fork,.06,mini(4,tier+1),side,endcap)

func _surface(point:Vector2,side:float,endcap:bool)->Vector3:
	if endcap:return Vector3(_center+side*(_length*.5+.018),point.y,point.x)
	var depth=Profile.GATE_DOOR_THICKNESS*.5 if _is_gate else Profile.WALL_THICKNESS*.5
	if not _is_gate:
		var count=maxi(1,ceili(_length/6.0))
		var bay=floori((point.x-(_center-_length*.5))/(_length/count))
		var support_x=_center-_length*.5+(bay+.5)*_length/count
		if point.y<=.81 or point.y>=15.29 or (absf(point.x-support_x)<=.41 and point.y<=14.66):depth=Profile.WALL_CAP_THICKNESS*.5
	return Vector3(point.x,point.y,side*(depth+.018))

func _ribbon(from:Vector2,to:Vector2,width:float,tier:int,side:float,endcap:bool):
	var tangent=(to-from).normalized();var across=Vector2(-tangent.y,tangent.x)*width*.5
	var normal=Vector3(side,0,0) if endcap else Vector3(0,0,side)
	# Small subdivisions keep ribbons on the base and buttress surfaces.
	var steps=maxi(1,ceili(from.distance_to(to)/.16))
	for i in steps:
		var a=from.lerp(to,float(i)/steps);var b=from.lerp(to,float(i+1)/steps)
		var first=_vertices.size()
		for vertex in [a-across,a+across,b-across,b+across]:
			_vertices.append(_surface(vertex,side,endcap));_normals.append(normal)
			_colors.append(Color(float(tier)/4.0,0.0,0.0,1.0))
		_uvs.append_array(PackedVector2Array([Vector2(-1,0),Vector2(1,0),Vector2(-1,1),Vector2(1,1)]))
		_indices.append_array(PackedInt32Array([first,first+1,first+2,first+2,first+1,first+3]))
