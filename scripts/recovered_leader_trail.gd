extends MeshInstance3D
## A short ribbon swept by the two endpoints of the actual rigid-part blade.
## Vertices are world-space samples, independent of later player turns/travel.
const LIFETIME=.11
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
	material_override=trail_material
func clear():
	samples.clear();mesh=null
func advance(delta: float,segment: PackedVector3Array,enabled: bool,heavy: bool):
	for sample in samples:sample.life-=delta
	samples=samples.filter(func(sample):return sample.life>0)
	if enabled and segment.size()==2:
		if samples.is_empty() or samples.back().tip.distance_to(segment[1])>.005 or samples.back().base.distance_to(segment[0])>.005:
			samples.append({"base":segment[0],"tip":segment[1],"life":LIFETIME})
	if samples.size()<2:mesh=null;return
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint=Color("fff0b0") if heavy else Color("bdeaff")
	for i in range(1,samples.size()):
		var a=samples[i-1];var b=samples[i]
		for vertex in [[a,"base"],[a,"tip"],[b,"tip"],[a,"base"],[b,"tip"],[b,"base"]]:
			var color=tint;color.a=.34*vertex[0].life/LIFETIME
			surface.set_color(color);surface.add_vertex(vertex[0][vertex[1]])
	mesh=surface.commit()
