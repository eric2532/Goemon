extends RefCounted
## Original effect packets, projected through the current game's camera.
## World pose/occlusion adapt the painterly scene; all effect geometry, UVs,
## native animation, lighting, screen-space expansion and colors stay integer.
const DATA="res://assets/characters/recovered_leaders/ed/beam/geometry.json"
const Visual=preload("res://scripts/recovered_ed_beam_visual.gd")
const TO_TUBE=Vector3(-1,-1,1)
const TO_WORLD=Vector3(1,-1,-1)
const BLACK=Vector3i.ZERO
const ORANGE=Vector3i(255,64,0)
static var models: Dictionary={}
var packets=PackedInt32Array()
var camera: Camera3D
var beam: Node3D
var extent: Vector2i
var screen_scale: Vector2
var unit: float
var rejected=0
var submitted=0
var occlusion_enabled=true

func _init():
	if models.is_empty():models=JSON.parse_string(FileAccess.get_file_as_string(DATA)).models

func build(effect: Node3D,view: Camera3D,size: Vector2i)->PackedInt32Array:
	packets=PackedInt32Array();rejected=0;submitted=0
	beam=effect;camera=view;extent=size
	screen_scale=Vector2(size)/camera.get_viewport().get_visible_rect().size
	unit=beam.visual.scale.x
	var native: Dictionary=beam.native_state()
	var scale3: Vector3=beam.visual.main_material.get_shader_parameter("native_scale")
	var native_scale=Vector3i((scale3*4096).round())
	if beam.visual.main.is_visible_in_tree():_tube("main",native.roll_basis_q12,int(native.main_palette_row),native_scale)
	if beam.visual.companion.is_visible_in_tree():_tube("companion",Basis.IDENTITY*4096,16+int(native.companion_palette_row),native_scale)
	if is_instance_valid(beam.shield) and beam.shield.is_visible_in_tree():_shield(native)
	var unscaled_pose=_source_rotation(Basis.IDENTITY*4096)
	for glow in beam.visual.glows:
		if glow.is_visible_in_tree():_disc(_source_world(Vector3i(0,0,roundi(glow.position.z)),unscaled_pose),160,ORANGE)
	for i in beam.visual.impacts.size():
		var glow: MeshInstance3D=beam.visual.impacts[i]
		if glow.is_visible_in_tree():
			var tint: Vector3=glow.material_override.get_shader_parameter("source_tint")
			_disc(_source_world(Vector3i(0,0,roundi(glow.position.z)),unscaled_pose),224 if i==0 else 192,Vector3i((tint*255).round()))
	if beam.visual.entry.is_visible_in_tree():_entry()
	if beam.visual.strips.is_visible_in_tree():_ribbon()
	return packets

static func transform_q12(matrix: Basis,point: Vector3i)->Vector3i:
	return Vector3i((int(matrix.x.x)*point.x+int(matrix.y.x)*point.y+int(matrix.z.x)*point.z)>>12,
		(int(matrix.x.y)*point.x+int(matrix.y.y)*point.y+int(matrix.z.y)*point.z)>>12,
		(int(matrix.x.z)*point.x+int(matrix.y.z)*point.y+int(matrix.z.z)*point.z)>>12)

static func scaled_q12(matrix: Basis,factor: Vector3i)->Basis:
	var result=Basis()
	for column in 3:
		var v=Vector3i(matrix[column]);var scale_=factor[column]
		result[column]=Vector3((v.x*scale_)>>12,(v.y*scale_)>>12,(v.z*scale_)>>12)
	return result

static func multiply_q12(a: Basis,b: Basis)->Basis:
	return Basis(Vector3(transform_q12(a,Vector3i(b.x))),Vector3(transform_q12(a,Vector3i(b.y))),Vector3(transform_q12(a,Vector3i(b.z))))

static func light_rgb(normal: Vector3i,rgb: Vector3i,rotation_q12: Basis)->Vector3i:
	# The GTE forms L*R before multiplying normals: preserve both shifts.
	var light=Basis(Vector3(0,0,0),Vector3(-4096,-1365,4096),Vector3(0,-3900,0))
	var transformed=transform_q12(multiply_q12(light,rotation_q12),normal)
	var ir=transformed.clamp(Vector3i.ZERO,Vector3i(32767,32767,32767))
	var color=Basis(Vector3(401,819,1220),Vector3(2875,2875,3276),Vector3(819,401,1638))
	ir=(transform_q12(color,ir)+Vector3i(2048,2048,2048)).clamp(Vector3i.ZERO,Vector3i(32767,32767,32767))
	return Vector3i((rgb.x*ir.x)>>12,(rgb.y*ir.y)>>12,(rgb.z*ir.z)>>12).clamp(Vector3i.ZERO,Vector3i(255,255,255))

static func screen_ratio(point: Vector2i,center: Vector2i,ratio: int)->Vector2i:
	var delta=point-center
	return center+Vector2i((delta.x*ratio)>>12,(delta.y*ratio)>>12)

static func ribbon_offset(a: Vector2i,b: Vector2i,width_q12: int)->Vector2i:
	var delta=b-a
	# 80180940 shifts the positive X product, then80180944 negates it.
	return Vector2i((delta.y*width_q12)>>12,-((delta.x*width_q12)>>12))

static func shield_color(phase: int,band: int,release_step: int)->Vector3i:
	var p=posmod(phase+307*band,1536)
	var blue=0 if p<256 or p>=1280 else p%256 if p<512 else 255 if p<1024 else 255-p%256
	var intensity=maxi(0,4096-release_step*256)
	return Vector3i(((blue>>2)*intensity)>>12,((blue>>1)*intensity)>>12,(blue*intensity)>>12)

func project(point: Vector3)->Vector2i:
	# Native GPU receives integer pixel positions. Keep square native pixels at
	# 240 rows, adapting only the current port's camera/aspect (not a room replay).
	return Vector2i((camera.unproject_position(point)*screen_scale).floor())

func _depth(point: Vector3)->float:return -camera.to_local(point).z

static func ordering_bucket(depths: Array,kind: String="polygon")->int:
	if kind=="disc":return maxi(0,(int(depths[0])>>2)+1-96)
	if kind=="entry":return (int(depths[0])>>2)+1
	if kind=="ribbon":return int(depths[0])>>2
	var total=0
	for depth in depths:total+=int(depth)
	return clampi((total*341)>>12 if depths.size()==3 else total>>4,0,65535)

func _visible(points: Array,kind: String="polygon")->bool:
	var center=Vector3.ZERO
	var depths: Array=[]
	for point in points:
		if _depth(point)<=camera.near:return false
		center+=point
		depths.append(clampi(floori(_depth(point)/unit),0,65535))
	center/=points.size()
	if not occlusion_enabled:return true
	# The ROM orders complete primitives, not fragments. The modern world has
	# collision geometry rather than an original OT: use one center visibility
	# decision per primitive, preserving the native discs' -96 bucket bias.
	var screen=camera.unproject_position(center)
	var start=camera.project_ray_origin(screen)
	var ordered_depth=float(ordering_bucket(depths,kind))*4*unit
	var ray_depth=_depth(center)-_depth(start)
	var end=start+(center-start)*((ordered_depth-_depth(start))/maxf(.000001,ray_depth))
	if (end-start).dot(center-start)<=0:return true
	var ray=PhysicsRayQueryParameters3D.create(start,end,1)
	ray.exclude=[beam.hero.get_rid()]
	ray.hit_from_inside=true
	return beam.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _tube(key: String,local_q12: Basis,palette: int,native_scale: Vector3i=Vector3i(4096,4096,4096)):
	var model: Dictionary=models[key]
	var worlds: Array[Vector3]=[]
	var pixels: Array[Vector2i]=[]
	var lit_basis=_source_rotation(local_q12,native_scale)
	for raw in model.vertices:
		var world=_source_world(Vector3i(int(raw[0]),int(raw[1]),int(raw[2])),lit_basis)
		worlds.append(world);pixels.append(project(world))
	for primitive in model.primitives:
		var count: int=primitive.vertices.size()
		var polygon_world: Array=[];var xy: Array=[];var uv: Array=[];var colors: Array=[]
		for corner in count:
			var index=int(primitive.vertices[corner])
			polygon_world.append(worlds[index]);xy.append(pixels[index])
			uv.append(Vector2i(int(primitive.uv[corner][0]),int(primitive.uv[corner][1])))
			var base: Array=primitive.colors[corner]
			var color=Vector3i(int(base[0]),int(base[1]),int(base[2]))
			if key=="main":
				var n: Array=model.normals[int(primitive.normals[corner])]
				color=light_rgb(Vector3i(int(n[0]),int(n[1]),int(n[2])),color,lit_basis)
			colors.append(color)
		if (int(primitive.flag)&2)==0 and _nclip(xy[0],xy[1],xy[2])<=0:continue
		if not _visible(polygon_world):rejected+=1;continue
		# Companion emitter clears raw, supplying neutral RGB128.
		_polygon(xy,uv,colors,int(primitive.mode)&~1,palette)

func _source_rotation(local_q12: Basis,native_scale: Vector3i=Vector3i(4096,4096,4096))->Basis:
	# C * current aim * native roll/scale * imported-axis adapter. This is the
	# original source-world matrix used by both GTE geometry and lighting.
	var aim=beam.global_basis.orthonormalized()
	var aim_q12=Basis((aim.x*TO_WORLD*4096).round(),(aim.y*TO_WORLD*4096).round(),(aim.z*TO_WORLD*4096).round())
	var source=multiply_q12(aim_q12,multiply_q12(local_q12,Basis.IDENTITY.scaled(TO_TUBE)*4096))
	# Native80020F34 scales completed actor rotation columns, not local roll.
	return scaled_q12(source,native_scale)

func _source_world(raw: Vector3i,source_rotation: Basis)->Vector3:
	# The requested longer reach is a separate source-Z adapter. Round it to
	# source units before GTE transformation; it never changes native lighting.
	raw.z=roundi(float(raw.z)*beam.visual.scale.z/beam.visual.scale.x)
	var source=transform_q12(source_rotation,raw)
	# Signed GTE shifts must happen before converting source-world Y/Z signs.
	return beam.global_position+Vector3(source)*TO_WORLD*unit

func _shield(native: Dictionary):
	var model: Dictionary=models.shield
	var scale3: Vector3=beam.shield.material.get_shader_parameter("native_scale")
	var scale_q12=Vector3i((scale3*4096).round())
	var scaled=scaled_q12(Basis.IDENTITY*4096,scale_q12)
	var worlds: Array[Vector3]=[];var pixels: Array[Vector2i]=[]
	for raw in model.vertices:
		var point=transform_q12(scaled,Vector3i(int(raw[0]),int(raw[1]),int(raw[2])))
		var world: Vector3=beam.shield.global_position+Vector3(point)*TO_WORLD*unit
		worlds.append(world);pixels.append(project(world))
	var step=int(beam.shield.material.get_shader_parameter("release_tick"))
	for primitive in model.primitives:
		var polygon_world: Array=[];var xy: Array=[];var colors: Array=[]
		for corner in primitive.vertices.size():
			var index=int(primitive.vertices[corner]);var source_y=-int(model.vertices[index][1])
			var band=4 if source_y>144 else 3 if source_y>122 else 2 if source_y>81 else 1 if source_y>28 else 0
			var n: Array=model.normals[int(primitive.normals[corner])]
			var rgb=shield_color(int(native.shield_phase),band,step)
			colors.append(light_rgb(Vector3i(int(n[0]),int(n[1]),int(n[2])),rgb,scaled))
			polygon_world.append(worlds[index]);xy.append(pixels[index])
		if (int(primitive.flag)&2)==0 and _nclip(xy[0],xy[1],xy[2])<=0:continue
		if not _visible(polygon_world):rejected+=1;continue
		_polygon(xy,[],colors,0x32,0)

func _disc(center: Vector3,radius: int,rgb: Vector3i):
	if not _visible([center],"disc"):rejected+=1;return
	var xy: Array=[]
	var middle=project(center)
	for i in 12:
		var circle: Vector3=Visual._circle(i,radius)
		xy.append(project(center+(camera.global_basis.x*circle.x+camera.global_basis.y*circle.y)*unit))
	for i in 12:_triangle([middle,xy[i],xy[(i+1)%12]],[],[rgb,BLACK,BLACK],0x32,0)
	submitted+=1

func _entry():
	# Entry uses the unscaled actor matrix, including its persistent roll.
	var center=_source_world(Vector3i(0,-32,-128),_source_rotation(beam.native_state().roll_basis_q12))
	if not _visible([center],"entry"):rejected+=1;return
	var middle=project(center);var xy: Array=[]
	# Entry plane uses yaw only, even while the beam's aim pitches.
	var forward: Vector3=beam.direction;forward.y=0
	var yaw=Basis.IDENTITY if forward.length_squared()<.000001 else Basis.looking_at(forward.normalized())
	var yaw_source=Basis((yaw.x*TO_WORLD*-4096).round(),(yaw.y*TO_WORLD*-4096).round(),(yaw.z*TO_WORLD*4096).round())
	for i in 12:
		var circle: Vector3=Visual._circle(i,64*beam.visual.source_tick)
		var radial=transform_q12(yaw_source,Vector3i(-circle.x,-circle.y,0))
		xy.append(project(center+Vector3(radial)*TO_WORLD*unit))
	var tint: Vector3=beam.visual.entry.material_override.get_shader_parameter("source_tint")
	var rgb=Vector3i((tint*255).round())
	for ratio in [3072,5120]:
		for i in 12:
			var a: Vector2i=xy[i];var b: Vector2i=xy[(i+1)%12]
			_polygon([a,b,screen_ratio(a,middle,ratio),screen_ratio(b,middle,ratio)],[],[rgb,rgb,BLACK,BLACK],0x32,0)

func _ribbon():
	var width=roundi(Visual.release_width(beam.visual.release_tick)*4096)
	var unscaled_pose=_source_rotation(Basis.IDENTITY*4096)
	for segment in 5:
		var a=_source_world(Vector3i(0,0,64-128*segment),unscaled_pose)
		var b=_source_world(Vector3i(0,0,-64-128*segment),unscaled_pose)
		if not _visible([a],"ribbon") or _depth(b)<=camera.near:rejected+=1;continue
		var pa=project(a);var pb=project(b);var offset=ribbon_offset(pa,pb,width)
		for side in [-1,1]:
			_polygon([pa,pb,pa+offset*side,pb+offset*side],[],[BLACK if segment==0 else ORANGE,ORANGE,BLACK,BLACK],0x32,0)

static func _nclip(a: Vector2i,b: Vector2i,c: Vector2i)->int:
	return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)

func _polygon(xy: Array,uv: Array,colors: Array,mode: int,palette: int):
	_triangle([xy[0],xy[1],xy[2]],[uv[0],uv[1],uv[2]] if not uv.is_empty() else [],[colors[0],colors[1],colors[2]],mode,palette)
	if xy.size()==4:
		_triangle([xy[1],xy[3],xy[2]],[uv[1],uv[3],uv[2]] if not uv.is_empty() else [],[colors[1],colors[3],colors[2]],mode,palette)
	submitted+=1

func _triangle(xy: Array,uv: Array,colors: Array,mode: int,palette: int):
	packets.append_array(PackedInt32Array([mode,palette,0]))
	for i in 3:
		var coord: Vector2i=xy[i];var texel=Vector2i.ZERO if uv.is_empty() else Vector2i(uv[i]);var rgb: Vector3i=colors[i]
		packets.append_array(PackedInt32Array([coord.x,coord.y,texel.x,texel.y,rgb.x,rgb.y,rgb.z]))
