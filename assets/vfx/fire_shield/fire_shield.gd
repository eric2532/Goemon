class_name FireShieldVisual
extends Node3D
var age=0.0
var rings=[]
var ending=false
var energy_material: ShaderMaterial
func _ready():
	position.y=1.2
	var material=ShaderMaterial.new();material.shader=preload("res://assets/vfx/fire_shield/surge_energy.gdshader")
	material.set_shader_parameter("energy",preload("res://assets/vfx/edo/spell_style.gd").energy_scale(self))
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
