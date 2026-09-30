class_name MusashiModel
extends HeroModel
var combat: Node
const REVIEW_MODEL="res://assets/characters/musashi/preview/edo_ember_v01.glb"
const ORIGINAL_MODEL="res://assets/characters/musashi/model/edo_refined.glb"
func _ready():
	body=Node3D.new();add_child(body)
	var model_path=ORIGINAL_MODEL if "--edo-original" in OS.get_cmdline_user_args() else REVIEW_MODEL
	rig_visual=load(model_path).instantiate();body.add_child(rig_visual)
	skeleton=rig_visual.find_child("Skeleton3D",true,false)
	head=driver("Head",Vector3(0,1.65,0))
	arms.assign([driver("Arm_L",Vector3(.16,1.47,0)),driver("Arm_R",Vector3(-.18,1.47,0))])
	legs.assign([driver("Leg_L",Vector3(.15,.95,0)),driver("Leg_R",Vector3(-.12,.95,0))])
	pipe=Node3D.new();body.add_child(pipe);coin=Node3D.new();body.add_child(coin)
	scarf=Node3D.new();body.add_child(scarf)
	locomotion=MusashiMotion.new(self)
	process_priority=30
func animate(delta: float,speed: float,grounded: bool,vertical: float,_attack: float,_heavy: bool,_combo: int,dodge: bool):
	body.transform=Transform3D.IDENTITY
	locomotion.update(delta,locomotion_velocity,grounded,vertical,0,dodge)
	locomotion.evaluate()
func sync_skeleton():
	if locomotion:locomotion.evaluate()
func set_surge(_active: bool):pass
func hand_position(side: String="R")->Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Hand_"+side)).origin
