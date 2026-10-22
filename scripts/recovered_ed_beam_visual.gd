extends Node3D
## SC06/016 source tubes, palette animation, startup annuli and glow primitives.
## Source coordinates are centimetres; the caller supplies Ed's uniform fit.
const ROOT="res://assets/characters/recovered_leaders/ed/beam/"
const MAIN=preload(ROOT+"main.glb")
const COMPANION=preload(ROOT+"companion.glb")
const INDICES=preload(ROOT+"indices.png")
const TUBE_SHADER=preload(ROOT+"native_tube.gdshader")
const GLOW_SHADER=preload(ROOT+"native_glow.gdshader")
const ORANGE=Color(1.0,64.0/255.0,0.0)
const ENTRY_CENTERS=[Vector3(-5,32,-128),Vector3(-11,30,-128),Vector3(-16,28,-128),Vector3(-21,24,-128),Vector3(-25,20,-128),Vector3(-28,15,-128),Vector3(-30,9,-128),Vector3(-31,4,-128),Vector3(-31,-2,-128)]
var main: Node3D
var companion: Node3D
var main_material: ShaderMaterial
var companion_material: ShaderMaterial
var strips: MeshInstance3D
var entry: MeshInstance3D
var entry_frames: Array[ArrayMesh]=[]
var glows: Array[MeshInstance3D]=[]
var impacts: Array[MeshInstance3D]=[]
var materials: Array[ShaderMaterial]=[]
var source_tick=1
var release_tick=-1
var global_phase=0
var last_source_tick=0
var wall_glow_color=Vector3(128,128,128)

func _ready():
	name="EdOriginalBeamVisual"
	main_material=_material(TUBE_SHADER);main_material.set_shader_parameter("index_page",INDICES);main_material.set_shader_parameter("palettes",preload(ROOT+"main_palettes.png"))
	main_material.set_shader_parameter("native_lit",true)
	main_material.set_shader_parameter("native_normals",preload(ROOT+"main_normals.png"))
	companion_material=_material(TUBE_SHADER);companion_material.set_shader_parameter("index_page",INDICES);companion_material.set_shader_parameter("palettes",preload(ROOT+"companion_palettes.png"));companion_material.set_shader_parameter("palette_rows",8)
	main=_tube(MAIN,main_material,"SourceMain801913BC")
	companion=_tube(COMPANION,companion_material,"SourceCompanion80191CC4")
	var strip_material=_material(GLOW_SHADER);strip_material.set_shader_parameter("strip",true)
	strips=_mesh(_strip_mesh(),strip_material,"SourceReleaseStrips");strips.hide()
	for tick in range(1,10):entry_frames.append(_annulus_mesh(64*tick))
	entry=_mesh(entry_frames[0],_material(GLOW_SHADER),"SourceEntryAnnuli");entry.position=Vector3(0,32,-128)
	for i in 4:
		var material=_material(GLOW_SHADER);material.set_shader_parameter("billboard",true);material.set_shader_parameter("source_tint",Vector3(1,64.0/255.0,0))
		var glow=_mesh(_disc_mesh(160),material,"SourceGlow%d"%i);glow.position.z=-64-i*160;glows.append(glow)
	for i in 2:
		var material=_material(GLOW_SHADER);material.set_shader_parameter("billboard",true)
		var impact=_mesh(_disc_mesh(224 if i==0 else 192),material,"SourceWallGlow%d"%i);impact.hide();impacts.append(impact)

func _material(shader: Shader)->ShaderMaterial:
	var material=ShaderMaterial.new();material.shader=shader;materials.append(material);return material

func _tube(asset: PackedScene,material: ShaderMaterial,label: String)->Node3D:
	var node=Node3D.new();node.name=label;add_child(node)
	var model=asset.instantiate();model.rotation.y=PI;node.add_child(model)
	# Mesh nodes retain source state/bounds for gameplay and diagnostics. The
	# native packet pass owns drawing, so no spatial shader can double the beam.
	for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.layers=0;mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _mesh(mesh: ArrayMesh,material: ShaderMaterial,label: String)->MeshInstance3D:
	var node=MeshInstance3D.new();node.layers=0;node.name=label;node.mesh=mesh;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node

static func release_width(tick: int)->float:
	var remaining=16-maxi(0,tick-1)
	return float(maxi(256,int(float(remaining-5)*4096.0/11.0)))/4096.0

func sample(tick: int,world_tick: int,unit: float,range_scale: float,wall_distance: float,release: int=-1):
	source_tick=maxi(1,tick);release_tick=release;global_phase=world_tick
	scale=Vector3(unit,unit,unit*range_scale)
	# The first actor update enters growth with scale zero; four subsequent
	# updates establish .25, .5, .75 and1.0 (8017F8E8/8017F918).
	var growing=clampf(float(source_tick-1)/4.0,0.0,1.0)
	var width=release_width(release) if release>=0 else growing
	main.scale=Vector3(width,width,1.0 if release>=0 else growing);companion.scale=main.scale
	main_material.set_shader_parameter("native_scale",main.scale)
	main.rotation.z=float(posmod(source_tick*120,4096))*TAU/4096.0
	main_material.set_shader_parameter("palette_row",posmod(source_tick-1,16));companion_material.set_shader_parameter("palette_row",posmod(world_tick,8))
	strips.visible=release>=0;strips.material_override.set_shader_parameter("strip_width",width)
	entry.visible=release<0 and source_tick<=9
	if entry.visible:
		entry.mesh=entry_frames[source_tick-1]
		entry.position=ENTRY_CENTERS[source_tick-1]
		var channel=posmod(255-mini(255,32*source_tick-33),256)
		entry.material_override.set_shader_parameter("source_tint",Vector3(channel,channel,int(channel/2))/255.0)
	var hold=release<0 and source_tick>=6
	if hold and wall_distance>=0:
		for _tick in range(maxi(6,last_source_tick+1),source_tick+1):
			wall_glow_color=Vector3(192,96,96) if wall_glow_color.z==176 else Vector3(176,176,176)
	last_source_tick=maxi(last_source_tick,source_tick)
	for glow in glows:glow.visible=hold
	for i in impacts.size():
		var impact=impacts[i];impact.visible=hold and wall_distance>=0
		if impact.visible:
			impact.position.z=-wall_distance*1.25/(unit*range_scale)
			var rgb=Vector3(128,128,128) if i==1 else wall_glow_color
			impact.material_override.set_shader_parameter("source_tint",rgb/255.0)
	var environment=get_world_3d().environment
	for material in materials:
		material.set_shader_parameter("compensate_filmic",environment!=null and environment.tonemap_mode==Environment.TONE_MAPPER_FILMIC)
		material.set_shader_parameter("scene_exposure",environment.tonemap_exposure if environment!=null else 1.0)
		material.set_shader_parameter("scene_white",environment.tonemap_white if environment!=null else 1.0)

static func _circle(index: int,radius: int,ratio: int=4096)->Vector3:
	# Source800233CC samples four sine-table pairs, scales, then mirrors.
	var i=posmod(index,12);var flip_x=i>6
	if flip_x:i=12-i
	var flip_y=i>3
	if flip_y:i=6-i
	var pairs=[Vector2i(0,4096),Vector2i(2046,3548),Vector2i(3545,2052),Vector2i(4096,6)]
	var x=(pairs[i].x*radius)>>12;var y=(pairs[i].y*radius)>>12
	if flip_x:x=-x
	if flip_y:y=-y
	return Vector3(-((x*ratio)>>12),-((y*ratio)>>12),0)

static func _arrays(vertices: PackedVector3Array,colors: PackedColorArray,indices: PackedInt32Array,uv: PackedVector2Array=PackedVector2Array(),uv2: PackedVector2Array=PackedVector2Array())->ArrayMesh:
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	if not uv.is_empty():arrays[Mesh.ARRAY_TEX_UV]=uv
	if not uv2.is_empty():arrays[Mesh.ARRAY_TEX_UV2]=uv2
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

static func _disc_mesh(radius: int)->ArrayMesh:
	var vertices=PackedVector3Array([Vector3.ZERO]);var colors=PackedColorArray([Color.WHITE]);var indices=PackedInt32Array()
	for i in 12:vertices.append(_circle(i,radius));colors.append(Color.BLACK)
	for i in 12:indices.append_array(PackedInt32Array([0,1+i,1+(i+1)%12]))
	return _arrays(vertices,colors,indices)

static func _annulus_mesh(radius: int)->ArrayMesh:
	var vertices=PackedVector3Array();var colors=PackedColorArray();var indices=PackedInt32Array()
	for ratio in [0xc00,0x1400]:
		var start=vertices.size()
		for i in 12:vertices.append(_circle(i,radius));colors.append(Color.WHITE);vertices.append(_circle(i,radius,ratio));colors.append(Color.BLACK)
		for i in 12:
			var a=start+i*2;var b=start+((i+1)%12)*2
			indices.append_array(PackedInt32Array([a,b,a+1,b,b+1,a+1]))
	return _arrays(vertices,colors,indices)

static func _strip_mesh()->ArrayMesh:
	var vertices=PackedVector3Array();var colors=PackedColorArray();var indices=PackedInt32Array();var uv=PackedVector2Array();var uv2=PackedVector2Array()
	for segment in 5:
		var a=64.0-128.0*segment;var b=a-128.0
		for side in [-1.0,1.0]:
			var start=vertices.size()
			for point in 4:
				vertices.append(Vector3(0,0,a if point%2==0 else b));uv.append(Vector2(0 if point<2 else side,0));uv2.append(Vector2(a,b))
				colors.append((Color.BLACK if segment==0 and point==0 else ORANGE) if point<2 else Color.BLACK)
			indices.append_array(PackedInt32Array([start,start+1,start+2,start+1,start+3,start+2]))
	return _arrays(vertices,colors,indices,uv,uv2)
