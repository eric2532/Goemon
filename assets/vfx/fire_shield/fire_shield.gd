class_name FireShieldVisual
extends Node3D
var age=0.0
var rings=[]
var ending=false
var energy_material: ShaderMaterial
func _ready():
	position.y=1.2
	var shader=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform float clock=0.0;
void fragment(){
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.6);
 float ripple=pow(0.5+0.5*sin(UV.y*65.0-clock*3.0+sin(UV.x*24.0)),12.0)*0.065;
 ALBEDO=vec3(0.025,0.32,0.95);
 EMISSION=vec3(0.04,0.48,1.0)*(0.2+rim*1.6);
 float pigment=0.65+0.35*smoothstep(-0.5,0.4,sin(UV.y*143.0+sin(UV.x*23.0-clock)*0.8));
 ALPHA=(0.025+rim*0.30+ripple)*pigment;
}"""
	var material=ShaderMaterial.new();material.shader=shader
	energy_material=material
	var sphere=Geo.sphere(self,Vector3.ZERO,Vector3.ONE*3.25,material)
	sphere.mesh.radial_segments=64;sphere.mesh.rings=32
	sphere.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(2):
		var ring=Geo.torus(self,Vector3.ZERO,1.60,1.615,preload("res://assets/rogue/scripts/ink_brush_style.gd").material(Color("60cfff"),.6,.5))
		ring.rotation=Vector3(.7+i*1.2,0,.3+i);rings.append(ring)
		ring.transparency=.50
		ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light=OmniLight3D.new();light.light_color=Color("379bff");light.light_energy=1.1;light.omni_range=5;add_child(light)
	# Keep the existing shield audio untouched.
	var loop=AudioStreamPlayer3D.new();loop.stream=load("res://assets/characters/musashi/audio/fire_loop.wav");loop.stream=loop.stream.duplicate();loop.stream.loop_end=int(loop.stream.get_length()*loop.stream.mix_rate);loop.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;loop.volume_db=-15;add_child(loop);loop.play()
	scale=Vector3.ONE*.05
func _process(delta):
	age+=delta
	energy_material.set_shader_parameter("clock",age)
	if not ending:scale=Vector3.ONE*lerpf(.05,1.0,smoothstep(0,.24,age))*(1+sin(age*3)*.012)
	for i in range(rings.size()):rings[i].rotate_y(delta*(.3+i*.15));rings[i].rotate_z(delta*.12)
func dissipate():
	ending=true
	var tween=create_tween();tween.tween_property(self,"scale",Vector3.ONE*.01,.22);tween.tween_callback(queue_free)
