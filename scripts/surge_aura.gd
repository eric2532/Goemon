class_name SurgeAura
extends Node3D
var clock=0.0
var rays: Array[Node3D]=[]
var bands: Array[Node3D]=[]
var light: OmniLight3D
var intensity=1.0
var energy_material: ShaderMaterial

func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	var shader=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float clock=0.0;
void vertex(){ VERTEX.xz *= 1.0+sin(clock*7.0+VERTEX.y*3.0)*0.065; }
void fragment(){
float flame=pow(max(0.0,sin(UV.x*62.8+sin(UV.y*8.0-clock*5.0))),5.0);
float edge=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
float fade=sin(UV.y*3.14159);
ALBEDO=vec3(1.0,0.61,0.08);
EMISSION=vec3(1.0,0.42,0.025)*(1.5+flame);
ALPHA=(flame*0.17+edge*0.15)*fade;
}"""
	var material=ShaderMaterial.new()
	material.shader=shader
	energy_material=material
	Geo.cylinder(self,Vector3(0,1.7,0),0.85,3.5,material,false,0.30)
	for i in range(14):
		var ray=Geo.spike(self,Vector3.ZERO,Vector3(0,0.28,0),0.025,Geo.mat("fff0a3",0,2))
		rays.append(ray)
	light=OmniLight3D.new()
	light.position=Vector3(0,1.8,0)
	light.light_color=Color("ffc955")
	light.light_energy=1.1
	light.omni_range=5.5
	add_child(light)

func _process(delta):
	if not visible: return
	clock+=delta
	energy_material.set_shader_parameter("clock",clock)
	for i in range(rays.size()):
		var t=fposmod(clock*0.6+i/14.0,1.0)
		var a=i*2.4+clock*1.5
		rays[i].position=Vector3(cos(a)*(0.8-t*0.35),t*3.8,sin(a)*(0.8-t*0.35))
		rays[i].scale=Vector3.ONE*(0.7+sin(t*PI)*0.7)
	for i in range(bands.size()):
		bands[i].rotation.y=clock*(1 if i==0 else -1)
		bands[i].scale=Vector3.ONE*(1+sin(clock*4+i)*0.06)
	light.light_energy=(1.0+sin(clock*9)*0.13)*intensity
