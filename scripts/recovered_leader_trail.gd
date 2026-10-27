extends MeshInstance3D
## A short ribbon swept by the two endpoints of the actual rigid-part blade.
## Vertices are world-space samples, independent of later player turns/travel.
const LIFETIME=.22
var lifetime=LIFETIME
var light_color=Color("bdeaff")
var heavy_color=Color("fff0b0")
var opacity=.34
var additive=false
var sample_interval=0.0
var sample_clock=0.0
var samples: Array=[]
var trail_material: StandardMaterial3D
func _ready():
	top_level=true;global_transform=Transform3D.IDENTITY
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_material=StandardMaterial3D.new()
	trail_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.vertex_color_use_as_albedo=true
	trail_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	if additive:trail_material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	material_override=trail_material
func clear():
	samples.clear();mesh=null;sample_clock=sample_interval
func advance(delta: float,segment: PackedVector3Array,enabled: bool,heavy: bool):
	# Borrowed skills keep the source collision rig, but never draw its blade ribbon.
	if layers==0:
		if mesh!=null or not samples.is_empty():clear()
		return
	sample_clock+=delta
	for sample in samples:sample.life-=delta
	samples=samples.filter(func(sample):return sample.life>0)
	if enabled and segment.size()==2 and sample_clock>=sample_interval:
		sample_clock=fposmod(sample_clock,sample_interval) if sample_interval>0 else 0
		if samples.is_empty() or samples.back().tip.distance_to(segment[1])>.005 or samples.back().base.distance_to(segment[0])>.005:
			samples.append({"base":segment[0],"tip":segment[1],"life":lifetime})
	if samples.size()<2:mesh=null;return
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint=heavy_color if heavy else light_color
	for i in range(1,samples.size()):
		var a=samples[i-1];var b=samples[i]
		for vertex in [[a,"base"],[a,"tip"],[b,"tip"],[a,"base"],[b,"tip"],[b,"base"]]:
			var color=tint;color.a=opacity*vertex[0].life/lifetime
			surface.set_color(color);surface.add_vertex(vertex[0][vertex[1]])
	mesh=surface.commit()
