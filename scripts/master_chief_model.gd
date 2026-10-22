extends HeroModel
## Native retail Halo geometry adapted to Goemon's existing Hero interface.
const BODY_PATH="res://assets/characters/master_chief/master_chief.glb"
var combat:Node
var animations:AnimationPlayer
func _ready():
	set_meta("halo_source","Xbox retail map")
	body=Node3D.new();body.name="MasterChief";add_child(body)
	head=driver("Head",Vector3(0,1.8,0))
	arms.assign([driver("Arm_L",Vector3(-.35,1.5,0)),driver("Arm_R",Vector3(.35,1.5,0))])
	legs.assign([driver("Leg_L",Vector3(-.18,.8,0)),driver("Leg_R",Vector3(.18,.8,0))])
	scarf=driver("Sash",Vector3.ZERO)
	hair_normal=Node3D.new();body.add_child(hair_normal)
	hair_gold=Node3D.new();body.add_child(hair_gold);hair_gold.hide()
	pipe=Node3D.new();body.add_child(pipe)
	coin=Node3D.new();body.add_child(coin);coin.hide()
	chain_pipe=ChainPipeVisual.new();body.add_child(chain_pipe);chain_pipe.hide()
	if ResourceLoader.exists(BODY_PATH):
		rig_visual=load(BODY_PATH).instantiate();body.add_child(rig_visual)
		skeleton=rig_visual.find_child("Skeleton3D",true,false) as Skeleton3D
		animations=rig_visual.find_child("AnimationPlayer",true,false) as AnimationPlayer
		if animations!=null:
			for clip in ["idle","walk"]:
				if animations.has_animation(clip):animations.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
			if animations.has_animation("idle"):animations.play("idle")
	else:
		rig_visual=Node3D.new();body.add_child(rig_visual)
		push_error("Missing recovered Master Chief model: "+BODY_PATH)
	locomotion=preload("res://scripts/master_chief_locomotion.gd").new(self)
	process_priority=30
func animate(delta:float,_speed:float,grounded:bool,vertical:float,attack:float,heavy:bool,combo_:int,dodge:bool):
	locomotion.update(delta,locomotion_velocity,grounded,vertical,attack,dodge)
	locomotion.evaluate()
	if animations!=null:
		var clip="airborne" if not grounded else ("walk" if locomotion.actual_speed>.25 else "idle")
		if animations.has_animation(clip) and animations.current_animation!=clip:animations.play(clip,.12)
		animations.speed_scale=clampf(locomotion.actual_speed/3.2,.65,1.8) if clip=="walk" else 1.0
func sync_skeleton():
	if locomotion!=null:locomotion.evaluate()
func set_cloak(_equipped:bool,_gold:bool):pass
func combat_pose(_attack:float,_heavy:bool,_combo:int,_dodge:bool):pass
func set_surge(_active:bool):pass
func apply_skin(_id:String):pass
