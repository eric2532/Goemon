class_name DefenseHero
extends DefenseDog

const AllyModel=preload("res://scripts/defense_hero_model.gd")
var combo_stage=1
var combo_clock=0.0
var combo_contacts_emitted=0

func create_model()->Node3D:
	var visual=AllyModel.new();visual.asset_path=String(profile.asset)
	return visual

func collision_height()->float:return 1.9
func health_bar_height()->float:
	var top=2.15
	for mesh in model.rig_visual.find_children("*","MeshInstance3D",true,false):
		var bounds=mesh.get_aabb()
		for corner in range(8):
			top=maxf(top,to_local(mesh.global_transform*bounds.get_endpoint(corner)).y)
	return top+.20

func attack_duration()->float:
	var duration=0.0
	for stage in PipeCombo.DURATIONS:duration+=float(stage)
	return duration

func contact_time()->float:
	var elapsed=0.0
	for index in range(PipeCombo.DURATIONS.size()):
		if index==combo_contacts_emitted:return elapsed+float(PipeCombo.DURATIONS[index])*float(PipeCombo.CONTACT[index])
		elapsed+=float(PipeCombo.DURATIONS[index])
	return INF

func play_animation(action: String,restart: bool=false):
	if animation_name==action and not restart:return
	animation_name=action
	if action=="attack":
		combo_stage=1;combo_clock=0;combo_contacts_emitted=0
	advance_animation(0)

func attack_contact():
	if not active_run() or dead or hit_done or state!="attack":return
	# Each contact is consumed once, even if its locked target moved, died or
	# reached cover. A large physics step cannot lose or duplicate a stage.
	while combo_contacts_emitted<PipeCombo.DURATIONS.size() and attack_age>=contact_time():
		hit_done=false
		super.attack_contact()
		combo_contacts_emitted+=1
		hit_done=combo_contacts_emitted>=PipeCombo.DURATIONS.size()

func advance_animation(delta: float):
	if model==null or model.locomotion==null:return
	var attack=0.0
	model.pipe_combo_active=state=="attack"
	if state=="attack":
		var remaining=attack_age
		combo_stage=1
		for index in range(PipeCombo.DURATIONS.size()):
			combo_stage=index+1
			if remaining<float(PipeCombo.DURATIONS[index]) or index==PipeCombo.DURATIONS.size()-1:break
			remaining-=float(PipeCombo.DURATIONS[index])
		combo_clock=clampf(remaining/float(PipeCombo.DURATIONS[combo_stage-1]),0,1)
		attack=1.0-combo_clock
	model.locomotion_velocity=velocity if state=="run" else Vector3.ZERO
	model.animate(delta,Vector2(velocity.x,velocity.z).length(),is_on_floor() or position.y<.3,velocity.y,attack,false,combo_stage,false)
	model.sync_skeleton()
	if state=="hurt":
		var recoil=sin(clampf((.45-hurt_left)/.45,0,1)*PI)
		model.body.rotation.x=-.22*recoil;model.body.position.y=-.06*recoil
	elif dead:
		var fall=smoothstep(0,.72,.95-death_left)
		model.body.rotation.x=-PI*.5*fall;model.body.position.y=.18*fall
