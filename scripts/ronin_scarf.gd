class_name RoninScarf
extends Node3D

var model: HeroModel
var cloth: ShaderMaterial
var flow=0.0
var clock=0.0
var sway=0.0
var chest_bone=-1
var previous_yaw=0.0
var airborne=0.0
var wind_angle=0.0

func _ready():
	process_priority=45
	chest_bone=model.skeleton.find_bone("Chest")
	previous_yaw=model.global_rotation.y
	var visual=GameAssets.place(self,"costumes/ronin_scarf")
	cloth=ShaderMaterial.new()
	cloth.shader=preload("res://scripts/ronin_scarf.gdshader")
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=cloth
		# Vertex animation can stream well outside the resting mesh bounds.
		mesh.extra_cull_margin=3.0
	hide()

func _process(delta):
	if not is_visible_in_tree():return
	clock+=delta
	var speed=Vector2(model.locomotion_velocity.x,model.locomotion_velocity.z).length()
	flow=lerpf(flow,clampf(speed/24.0,0,1),1-exp(-delta*6))
	airborne=lerpf(airborne,0.0 if model.locomotion.grounded else 1.0,1-exp(-delta*5))
	var yaw=model.global_rotation.y
	var turn=clampf(wrapf(yaw-previous_yaw,-PI,PI)/maxf(delta,.001),-5,5)
	previous_yaw=yaw
	var lateral=(model.global_basis.inverse()*model.locomotion_velocity).x
	sway=lerpf(sway,clampf(-turn*.10-lateral*.012,-.65,.65),1-exp(-delta*5))
	cloth.set_shader_parameter("cloth_clock",clock)
	cloth.set_shader_parameter("flow",flow)
	cloth.set_shader_parameter("sway",sway)
	cloth.set_shader_parameter("airborne",airborne)
	# Follow the final animated torso pose without changing Goemon's approved rig.
	global_transform=model.skeleton.global_transform*model.skeleton.get_bone_global_pose(chest_bone)*model.skeleton.get_bone_global_rest(chest_bone).affine_inverse()
	cloth.set_shader_parameter("hem_lift",maxf(0,model.global_position.y-global_position.y))
	var local_travel=global_basis.inverse()*model.locomotion_velocity
	var target_angle=atan2(-local_travel.x,-local_travel.z) if speed>1.0 else 0.0
	wind_angle=lerp_angle(wind_angle,target_angle,1-exp(-delta*(4 if speed>1 else 1.5)))
	cloth.set_shader_parameter("wind_direction",Vector2(sin(wind_angle),cos(wind_angle)))

func set_equipped(value: bool):
	visible=value
	flow=0;sway=0;previous_yaw=model.global_rotation.y
	if value:_process(0)
