class_name HeroModel
extends Node3D

var skin_id=HeroSkins.DEFAULT_ID

var hair_normal: Node3D
var hair_gold: Node3D
var body: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var pipe: Node3D
var coin: Node3D
var chain_pipe: ChainPipeVisual
var chain_selected=false
var wide_swing_active=false
var chain_pose: Dictionary={}
var scarf: Node3D
var ronin_scarf: RoninScarf
var skeleton: Skeleton3D
var bone_drivers: Dictionary={}
var rig_visual: Node3D
var phase = 0.0
var ninja = false
var crowd_proxy = false
var boss = false
var boss_variant=0
var equipped = true
var landing = 0.0
var charge_requested=false
var charge_release=-1.0
var charge_slot=1
var charge_pose_weight=0.0
const ROGUE_PIPE_PROFILE=preload("res://scripts/goemon_rogue_combo.gd")
var pipe_combo_active=false
var rogue_pipe_combo_active=false
var pipe_combo_stage=1
var pipe_contact_phase=-1.0
var pipe_combo_pose: Dictionary={}
var locomotion: RefCounted
var locomotion_velocity=Vector3.ZERO
const WeaponProportions=preload("res://scripts/weapon_proportions.gd")
var pipe_visual_scale=WeaponProportions.SCALE
var pipe_bounds: Array[Vector3]=[]

func visible_pipe_reach()->float:
	if pipe_bounds.is_empty():cache_pipe_bounds(pipe)
	var reach=0.0
	for corner in pipe_bounds:
		var delta=pipe.to_global(corner)-global_position
		reach=maxf(reach,Vector2(delta.x,delta.z).length())
	return reach

func cache_pipe_bounds(node: Node):
	if node is MeshInstance3D:
		var bounds: AABB=node.mesh.get_aabb()
		for i in range(8):pipe_bounds.append(pipe.to_local(node.to_global(bounds.get_endpoint(i))))
	for child in node.get_children():cache_pipe_bounds(child)

func _init(is_ninja: bool = false, is_boss: bool = false, variant: int=0):
	ninja = is_ninja
	boss = is_boss
	boss_variant=variant

func _ready():
	# Swarm actors use the shared animated crowd mesh, keeping thousands of
	# offscreen rigs, bones and weapons out of the scene tree.
	if crowd_proxy:
		set_process(false)
		return
	# Stable gameplay-facing pivots drive a proper imported, skinned Blender rig.
	# No movement, hit timing, collision or weapon behavior lives in the GLB.
	body=Node3D.new()
	add_child(body)
	head=driver("Head",Vector3(0,1.98,0))
	arms.assign([driver("Arm_L",Vector3(-0.49,1.58,0)),driver("Arm_R",Vector3(0.49,1.58,0))])
	legs.assign([driver("Leg_L",Vector3(-0.25,0.91,0)),driver("Leg_R",Vector3(0.25,0.91,0))])
	scarf=driver("Sash",Vector3(0.2,1.04,0.47))
	var asset="enemies/guardian_"+str(boss_variant) if boss else ("enemies/ninja_near" if ninja else "characters/kai")
	rig_visual=GameAssets.place(body,asset)
	skeleton=rig_visual.find_child("Skeleton3D",true,false) as Skeleton3D
	assert(skeleton!=null,"Imported character requires a Skeleton3D")
	hair_normal=rig_visual.find_child("Hair_Normal",true,false)
	hair_gold=rig_visual.find_child("Hair_Gold",true,false)
	if hair_gold==null:
		hair_gold=Node3D.new()
		body.add_child(hair_gold)
	hair_gold.hide()
	if not ninja and not boss and skin_id!=HeroSkins.DEFAULT_ID: apply_skin(skin_id)
	if not ninja and not boss:
		# Original source geometry is a T pose. Match its actual joints without
		# changing mesh proportions; lower arms in the visual adapter only.
		head.position=Vector3(0,1.448719,0)
		arms[0].position=Vector3(-0.406666,1.304718,0)
		arms[1].position=Vector3(0.406666,1.304718,0)
		legs[0].position=Vector3(-0.254166,0.965830,0)
		legs[1].position=Vector3(0.254166,0.965830,0)
	pipe=GameAssets.place(arms[1],"weapons/golden_pipe",Vector3(0,-0.59,-0.05))
	coin=GoldCoin.make_mesh(arms[1],0.78*WeaponProportions.SCALE)
	coin.position=Vector3(0,-0.6,-0.19)
	coin.hide()
	if not ninja and not boss:
		pipe.position=Vector3(0,-0.94,-0.025)
		coin.position=Vector3(0,-0.94,-0.14)
		chain_pipe=ChainPipeVisual.new();body.add_child(chain_pipe);chain_pipe.hide()
	process_priority=30
	if not ninja and not boss: locomotion=HeroLocomotion.new(self)
	if not ninja and not boss:
		ronin_scarf=RoninScarf.new();ronin_scarf.model=self;add_child(ronin_scarf)
	if ninja or boss:set_process(false)
	sync_skeleton()

func driver(bone: String,p: Vector3)->Node3D:
	var pivot=Node3D.new()
	pivot.name=bone+"Driver"
	pivot.position=p
	body.add_child(pivot)
	bone_drivers[bone]=pivot
	return pivot

func _process(_delta):
	sync_skeleton()

func sync_skeleton():
	if locomotion!=null:
		locomotion.evaluate()
		return
	if not is_instance_valid(skeleton): return
	for i in range(skeleton.get_bone_count()):
		var bone=skeleton.get_bone_name(i)
		var rest=skeleton.get_bone_global_rest(i)
		if bone_drivers.has(bone):
			var transform=skeleton.global_transform.affine_inverse()*bone_drivers[bone].global_transform
			if not ninja and not boss and bone in ["Arm_L","Arm_R"]:
				transform.basis=transform.basis*Basis(Vector3.BACK,PI/2 if bone=="Arm_L" else -PI/2)
			transform.basis=transform.basis*rest.basis
			skeleton.set_bone_global_pose(i,transform)
		else:
			skeleton.set_bone_global_pose(i,rest)

func animate(delta: float, speed: float, grounded: bool, vertical: float, attack: float, heavy: bool, combo: int, dodge: bool):
	if locomotion!=null:
		body.position=Vector3.ZERO
		body.rotation=Vector3.ZERO
		body.scale=Vector3.ONE
		for arm in arms: arm.rotation=Vector3.ZERO
		for leg in legs: leg.rotation=Vector3.ZERO
		head.rotation=Vector3.ZERO
		landing=move_toward(landing,0,delta*5)
		var charge_target=1.0 if charge_requested else ((1.0-smoothstep(0.70,1.0,charge_release)) if charge_release>=0 else 0.0)
		charge_pose_weight=move_toward(charge_pose_weight,charge_target,delta*8.0)
		locomotion.update(delta,locomotion_velocity,grounded,vertical,attack,dodge)
		combat_pose(attack,heavy,combo,dodge)
		return
	phase += delta * (5.0 + speed*1.15)
	var move = clampf(speed/7.0,0,1)
	var sprint = clampf((speed-9.0)/8.0,0,1)
	landing = move_toward(landing,0,delta*5)
	body.position = Vector3(0,abs(sin(phase))*0.055*move + sin(phase*0.23)*0.018*(1-move),0)
	body.scale = Vector3(1+landing*0.15,1-landing*0.2,1+landing*0.15)
	body.rotation.x = -sprint*0.20
	body.rotation.z = sin(phase*0.5)*0.025*move
	body.rotation.y = 0
	for i in range(2):
		var wave = sin(phase + i*PI)
		legs[i].rotation.x = wave*0.8*move
		arms[i].rotation.x = -wave*0.7*move + sprint*0.65
		arms[i].rotation.z = (0.13+sprint*0.13)*(-1 if i==0 else 1)
		arms[i].rotation.y = 0
	if not grounded:
		legs[0].rotation.x = -0.5 if vertical>0 else 0.28
		legs[1].rotation.x = 0.5 if vertical>0 else -0.1
		arms[0].rotation.z = -0.60
		arms[1].rotation.z = 0.65
	combat_pose(attack,heavy,combo,dodge)
	head.rotation.z=sin(phase*0.22)*0.026*(1-move)
	scarf.rotation.x=-sprint*0.7+sin(phase*1.3)*0.13

func combat_pose(attack: float,heavy: bool,combo: int,dodge: bool):
	pipe_combo_pose={}
	if is_instance_valid(chain_pipe):chain_pipe.visible=chain_selected and equipped
	if wide_swing_active and attack>0 and not dodge:
		var t=1.0-attack
		var windup=PipeCombo.interpolate(PipeCombo.IDLE,PipeCombo.LEFT_END,smoothstep(0,.22,t))
		var sweep=PipeCombo.interpolate(windup,PipeCombo.RIGHT_END,smoothstep(.30,.64,t))
		pipe_combo_pose=PipeCombo.interpolate(sweep,PipeCombo.IDLE,smoothstep(.72,1,t));pipe_combo_stage=2
		pipe.visible=equipped;return
	if chain_selected and not chain_pose.is_empty() and attack>0 and not dodge:
		pipe_combo_pose=chain_pose;pipe_combo_stage=2
		arms[1].rotation.y=.5;pipe.hide();return
	if pipe_combo_active and attack>0 and not heavy and not dodge:
		pipe_combo_stage=combo
		pipe_combo_pose=ROGUE_PIPE_PROFILE.sample(combo,(1.0-attack)*ROGUE_PIPE_PROFILE.duration(combo)) if rogue_pipe_combo_active else PipeCombo.sample(combo,1.0-attack,pipe_contact_phase)
		# Readable legacy driver values; the articulated rig consumes the pose below.
		arms[1].rotation.y=(1 if combo!=2 else -1)*0.8
		pipe.visible=equipped and not chain_selected
		return
	if charge_requested or charge_release>=0:
		pipe.visible=equipped and not chain_selected
		return
	if attack>0 and heavy and charge_slot==1 and not dodge:
		pipe_combo_pose=ROGUE_PIPE_PROFILE.Strike.sample(3,1.0-attack,.47);pipe_combo_stage=3
		pipe.visible=equipped;return
	if attack > 0:
		var t=1.0-attack
		# A coiled wind-up, quick contact, and eased follow-through for each stroke.
		var contact_phase=0.47 if heavy else 0.36
		var swing=smoothstep(contact_phase-0.10,contact_phase+0.08,t)
		var recover=smoothstep(0.68,1.0,t)
		var side=-1.0 if combo==2 else 1.0
		body.rotation.y=lerpf((-0.85+1.85*swing)*side,0.0,recover)
		body.rotation.x=-sin(t*PI)*(0.19 if combo==3 else 0.08)
		arms[1].rotation.x=lerpf(-1.35-(0.42 if combo==3 else 0.0),0.0,recover)
		arms[1].rotation.y=lerpf((-1.35+2.7*swing)*side,0.0,recover)
		arms[1].rotation.z=side*(0.35 if combo==2 else 0.16)*sin(t*PI)
		arms[0].rotation.x=-0.7*sin(t*PI)
		legs[combo%2].rotation.x=-0.25*sin(t*PI)
		if combo==3: body.position.y-=0.11*sin(t*PI)
		if heavy:
			arms[1].rotation.x=lerpf(-2.25+2.5*swing,0.0,recover)
			body.rotation.x=lerpf(0.10-0.42*swing,0.0,recover)
	if dodge:
		body.rotation.x = -0.6
		arms[0].rotation.x = 1.4
		arms[1].rotation.x = 1.4
	pipe.visible=equipped and not chain_selected

func set_surge(active: bool):
	hair_normal.visible=not active
	hair_gold.visible=active

# Swap only mesh resources. Keep the live rig, pose, weapons and cloth attachments.
func apply_skin(id: String):
	if ninja or boss:return
	id=HeroSkins.valid_id(id)
	var parts=HeroSkins.mesh_parts(id)
	for part in HeroSkins.PARTS:
		var target=rig_visual.find_child(part,true,false) as MeshInstance3D
		assert(target!=null,"Hero is missing skin part "+part)
		target.mesh=parts[part].mesh
		target.skin=parts[part].skin
	skin_id=id
	rig_visual.scale=Vector3.ONE*HeroSkins.CATALOG[1 if id=="ren" else 0].display_scale
	if locomotion!=null:
		locomotion.dirty=true
		sync_skeleton()
	if is_instance_valid(ronin_scarf) and ronin_scarf.visible:ronin_scarf._process(0)
