class_name FireEnergy
extends Node3D
@export var charged=false
var age=0.0
var energy_material: ShaderMaterial
var sparks: CPUParticles3D
var flame_material: ShaderMaterial
func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	var energy=preload("res://assets/vfx/edo/spell_style.gd").energy_scale(self)
	preload("res://assets/rogue/scripts/ink_brush_style.gd").attach_wake(self,Color("ff7338"),1.35 if charged else .8)
	energy_material=ShaderMaterial.new();energy_material.shader=preload("res://assets/vfx/fireball/ember_energy.gdshader")
	energy_material.set_shader_parameter("energy",energy)
	var shell=Geo.sphere(self,Vector3.ZERO,Vector3.ONE*(.65 if charged else .44),energy_material)
	shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_material=Geo.mat("fff2ad",0,.75).duplicate();core_material.emission_energy_multiplier*=energy
	Geo.sphere(self,Vector3.ZERO,Vector3.ONE*.27,core_material)
	flame_material=ShaderMaterial.new();flame_material.shader=preload("res://assets/vfx/edo/painted_flame.gdshader")
	flame_material.set_shader_parameter("fade",.7)
	flame_material.set_shader_parameter("energy",energy)
	for i in range(5 if charged else 3):
		var flame=Geo.spike(self,Vector3(0,-.10,0),Vector3(.05,.48,0),.13,flame_material)
		flame.name="Flame"+str(i)
	if charged:
		var ring_material=Geo.mat("ffd579",0,.65).duplicate();ring_material.emission_energy_multiplier*=energy
		for i in range(2):
			var ring=Geo.torus(self,Vector3.ZERO,.28,.31,ring_material);ring.rotation=Vector3(i*1.5,.8,0)
	sparks=CPUParticles3D.new();sparks.amount=28 if charged else 12;sparks.lifetime=.28;sparks.explosiveness=0
	sparks.mesh=PrismMesh.new();sparks.mesh.size=Vector3(.025,.10,.025)
	sparks.material_override=Geo.mat("ff9639",0,1.3).duplicate()
	sparks.material_override.emission_energy_multiplier*=energy
	sparks.material_override.vertex_color_use_as_albedo=true
	sparks.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var gradient=Gradient.new();gradient.set_color(0,Color.WHITE);gradient.set_color(1,Color(1,1,1,0))
	sparks.color_ramp=gradient
	sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.direction=Vector3.UP;sparks.spread=150
	sparks.initial_velocity_min=.4;sparks.initial_velocity_max=1.8;sparks.gravity=Vector3(0,1,0);add_child(sparks)
func _process(delta):
	age+=delta
	preload("res://assets/rogue/scripts/ink_brush_style.gd").animate(self,delta)
	energy_material.set_shader_parameter("clock",age)
	flame_material.set_shader_parameter("clock",age)
	for child in get_children():
		if str(child.name).begins_with("Flame"):
			var i=float(str(child.name).trim_prefix("Flame"));var a=age*8+i*TAU/5
			child.position=Vector3(cos(a),.75+sin(a*1.3)*.3,sin(a))*.16
			child.rotation.z=sin(a)*.8
