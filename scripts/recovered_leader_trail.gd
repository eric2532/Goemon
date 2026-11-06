extends MeshInstance3D
## Shared Magic Swordsman crescent, sampled from each fighter's existing endpoints.
## Vertices are world-space samples, independent of later player turns/travel.
const LIFETIME=.22
var lifetime=LIFETIME
var light_color=Color("bdeaff")
var heavy_color=Color("fff0b0")
var opacity=.9
var additive=false
var original=false
var sample_interval=0.0
var sample_clock=0.0
var samples: Array=[]
var trail_material
var prepared_mesh=ArrayMesh.new()
var brush_clock=0.0
var actor:Node
var redraw_queued=false
var render_tint=Color.WHITE
var render_opacity=1.0
var render_lifetime=LIFETIME
const Brush=preload("res://assets/rogue/scripts/magic_sword_brush.gd")
func _ready():
	top_level=true;global_transform=Transform3D.IDENTITY
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if additive or original:
		trail_material=StandardMaterial3D.new()
		trail_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		trail_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		trail_material.vertex_color_use_as_albedo=true
		trail_material.cull_mode=BaseMaterial3D.CULL_DISABLED
		if additive:trail_material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	else:
		trail_material=preload("res://assets/rogue/scripts/ink_brush_style.gd").material(light_color)
		trail_material.set_shader_parameter("strong_energy",true)
		trail_material.set_shader_parameter("use_vertex_alpha",true)
	material_override=trail_material
	var parent=get_parent()
	while parent!=null:
		if parent.has_method("melee_reach_setting"):actor=parent;break
		parent=parent.get_parent()

func clear():
	samples.clear();prepared_mesh.clear_surfaces();mesh=null;sample_clock=sample_interval;brush_clock=0;redraw_queued=false
func advance(delta: float,segment: PackedVector3Array,enabled: bool,heavy: bool):
	# Borrowed skills keep the source collision rig, but never draw its blade ribbon.
	if layers==0:
		if mesh!=null or not samples.is_empty():clear()
		return
	sample_clock+=delta
	if samples.is_empty() and (not enabled or segment.size()!=2):return
	for sample in samples:sample.life-=delta
	samples=samples.filter(func(sample):return sample.life>0)
	if enabled and segment.size()==2 and sample_clock>=sample_interval:
		sample_clock=fposmod(sample_clock,sample_interval) if sample_interval>0 else 0
		if samples.is_empty() or samples.back().tip.distance_to(segment[1])>.005 or samples.back().base.distance_to(segment[0])>.005:
			samples.append({"base":segment[0],"tip":segment[1],"life":lifetime})
			if samples.size()>Brush.MAX_SAMPLES:samples.pop_front()
	if samples.size()<2:
		prepared_mesh.clear_surfaces();mesh=null;redraw_queued=false;return
	render_tint=heavy_color if heavy else light_color;render_opacity=opacity;render_lifetime=lifetime
	var energy=.42 if is_instance_valid(actor) and actor.game.settings.get("reduced_flashes",false) else 1.0
	if additive or original:trail_material.albedo_color.a=energy
	else:
		brush_clock+=delta
		trail_material.set_shader_parameter("ink_tint",render_tint)
		trail_material.set_shader_parameter("brush_clock",brush_clock)
		trail_material.set_shader_parameter("energy",energy)
	if redraw_queued:return
	redraw_queued=true
	# Retain every physics sample; only the final surface is needed for this render.
	if not RenderingServer.frame_pre_draw.is_connected(flush_mesh):RenderingServer.frame_pre_draw.connect(flush_mesh,CONNECT_ONE_SHOT)

func flush_mesh():
	if not redraw_queued:return
	redraw_queued=false
	if samples.size()<2:return
	prepared_mesh.clear_surfaces()
	if additive or original:
		var vertices=PackedVector3Array();var colors=PackedColorArray()
		var tint=render_tint
		vertices.resize((samples.size()-1)*6);colors.resize(vertices.size())
		for i in range(1,samples.size()):
			var a=samples[i-1];var b=samples[i];var at=(i-1)*6
			var color_a=tint;color_a.a=render_opacity*a.life/render_lifetime
			var color_b=tint;color_b.a=render_opacity*b.life/render_lifetime
			vertices[at]=a.base;vertices[at+1]=a.tip;vertices[at+2]=b.tip
			vertices[at+3]=a.base;vertices[at+4]=b.tip;vertices[at+5]=b.base
			colors[at]=color_a;colors[at+1]=color_a;colors[at+2]=color_b
			colors[at+3]=color_a;colors[at+4]=color_b;colors[at+5]=color_b
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
		prepared_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh=prepared_mesh
		return
	var poses=[]
	for sample in samples:poses.append([sample.base,sample.tip])
	var arrays=Brush.surface_arrays(poses)
	var colors=PackedColorArray()
	var tint=render_tint
	for uv in arrays[Mesh.ARRAY_TEX_UV]:
		var at=uv.x*(samples.size()-1);var index=mini(floori(at),samples.size()-2)
		var color=tint;color.a=render_opacity*lerpf(samples[index].life,samples[index+1].life,at-index)/render_lifetime
		colors.append(color)
	arrays[Mesh.ARRAY_COLOR]=colors
	prepared_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh=prepared_mesh

static func extend_to_reach(segment:PackedVector3Array,origin:Vector3,reach:float)->PackedVector3Array:
	if segment.size()!=2:return segment
	var offset=segment[1]-origin
	var horizontal=Vector2(offset.x,offset.z).length()
	if horizontal>.001 and horizontal<reach:
		segment[1].x=origin.x+offset.x*reach/horizontal
		segment[1].z=origin.z+offset.z*reach/horizontal
	return segment

func paint_arc(base:Vector3,tip:Vector3,axis:Vector3,arc:float):
	clear()
	for angle in [-arc,0.0,arc]:
		sample_clock=sample_interval
		advance(0,PackedVector3Array([base,base+(tip-base).rotated(axis,angle)]),true,false)
