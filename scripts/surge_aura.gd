class_name SurgeAura
extends Node3D
var clock=0.0
var rays: Array[Node3D]=[]
var bands: Array[Node3D]=[]
var light: OmniLight3D
var intensity=1.0
var energy_material: ShaderMaterial
var energy_shell: MeshInstance3D
var ray_material: StandardMaterial3D
var food_colors:Array[Color]=[]
var food_flags=Vector3.ZERO
var current_tint=Color.TRANSPARENT

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
	energy_shell=Geo.cylinder(self,Vector3(0,1.7,0),0.85,3.5,material,false,0.30)
	# Geo materials are shared; this aura owns its one mutable ray tint.
	ray_material=Geo.mat("fff0a3",0,2).duplicate()
	for i in range(14):
		var ray=Geo.spike(self,Vector3.ZERO,Vector3(0,0.28,0),0.025,ray_material)
		rays.append(ray)
	light=OmniLight3D.new()
	light.position=Vector3(0,1.8,0)
	light.light_color=Color("ffc955")
	light.light_energy=1.1
	light.omni_range=5.5
	add_child(light)

func set_food_glow(flags:Vector3):
	if food_flags!=flags:
		food_flags=flags;food_colors.clear()
		if flags.x>0:food_colors.append(Color("ff2448"))
		if flags.y>0:food_colors.append(Color("2488ff"))
		if flags.z>0:food_colors.append(Color("38ff65"))
	apply_tint()

func apply_tint():
	var tint=Color.TRANSPARENT
	if get_parent().hp>0 and get_parent().surge_left<=0 and not food_colors.is_empty():
		tint=food_colors[int(clock/1.5)%food_colors.size()]
	var model=get_parent().model
	if model.has_method("set_food_glow"):model.set_food_glow(tint)
	if current_tint==tint:return
	current_tint=tint
	energy_shell.visible=tint.a<=0
	light.visible=tint.a<=0
	light.light_color=tint if tint.a>0 else Color("ffc955")
	ray_material.albedo_color=tint if tint.a>0 else Color("fff0a3")
	ray_material.emission=ray_material.albedo_color

func _process(delta):
	if get_parent().hp<=0:apply_tint();hide();return
	if not visible or get_parent().game.paused or get_parent().game.transitioning:return
	clock+=delta
	apply_tint()
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
