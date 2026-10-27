extends "res://scripts/master_chief_viewmodel.gd"
## Prepared hands share Chief's overlay, camera, bob and muzzle mapping.
const HANDS="res://assets/models/characters/warcraft/demon-hunter/first_person.glb"
var skeleton:Skeleton3D
var hand_bone=-1
var left_hand_bone=-1
var hand_meshes:Array[MeshInstance3D]=[]
var hand_triangles=0
var muzzle_offset=Transform3D.IDENTITY

func _ready():
	_setup_presentation()
	weapon_camera.cull_mask=1
	weapon=load(GameAssets.model_path(HANDS)).instantiate();weapon_pivot.add_child(weapon)
	_prepare_meshes(weapon)
	skeleton=weapon.find_child("Skeleton3D",true,false)
	animations=weapon.find_child("AnimationPlayer",true,false)
	animations.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	hand_bone=skeleton.find_bone("frame r wriste")
	left_hand_bone=skeleton.find_bone("frame l wriste")
	muzzle_anchor=weapon.find_child("Muzzle",true,false)
	assert(hand_bone>=0 and left_hand_bone>=0 and muzzle_anchor!=null)
	muzzle_offset=muzzle_anchor.transform
	muzzle_anchor.reparent(weapon_view)
	for part in weapon.find_children("*","MeshInstance3D",true,false):
		# The isolated viewport uses its own lit layer.
		part.layers=1
		hand_meshes.append(part)
		for surface in part.mesh.get_surface_count():hand_triangles+=part.mesh.surface_get_array_index_len(surface)/3
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0)
	light.light_color=Color("e8e6ee");light.light_energy=1.4
	light.light_cull_mask=1;light.shadow_enabled=false;weapon_view.add_child(light)
	pose("Stand Alternate",0)

func pose(clip:String,time:float):
	animations.play(clip)
	animations.seek(clampf(time,0,animations.get_animation(clip).length),true)
	skeleton.force_update_all_bone_transforms()
	# BoneAttachment updates later in the frame; combat needs this exact release pose now.
	muzzle_anchor.global_transform=skeleton.global_transform*skeleton.get_bone_global_pose(hand_bone)*muzzle_offset

func update_motion(delta:float,speed:float,grounded:bool):
	super.update_motion(delta,speed,grounded)
	var combat=_game_context().player.active_ability
	pose("Attack Alternate" if combat.mode=="attack" else "Stand Alternate",combat.elapsed if combat.mode=="attack" else 0.0)

func stop():
	if is_instance_valid(animations):pose("Stand Alternate",0)
